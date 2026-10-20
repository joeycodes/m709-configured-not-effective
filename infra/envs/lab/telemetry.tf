# Look up the Azure-created Network Watcher for the region
# (NetworkWatcher_<region> in NetworkWatcherRG); flow logs are its children
data "azurerm_network_watcher" "this" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}

# Retrieve the flow logs storage account at the persistent observability layer
data "azurerm_storage_account" "flowlogs" {
  name                = var.flowlogs_storage_account
  resource_group_name = var.observability_resource_group
}

# Retrieve the log analytics workspace that Traffic Analytics writes to
data "azurerm_log_analytics_workspace" "observability" {
  name                = var.observability_workspace
  resource_group_name = var.observability_resource_group
}

# One flow log per VNet: raw logs go to the flow-log storage account;
# Traffic Analytics processes them into the workspace every 10 minutes
resource "azurerm_network_watcher_flow_log" "vnet" {
  #checkov:skip=CKV_AZURE_12:retention_policy disabled on purpose; raw-log deletion is owned by the lifecycle policy on the flow-log account (30 days). The processed copy is kept in the workspace for 90 days. ADR D21
  for_each = azurerm_virtual_network.this

  name                 = replace(each.value.name, "vnet-", "fl-")
  network_watcher_name = data.azurerm_network_watcher.this.name
  resource_group_name  = data.azurerm_network_watcher.this.resource_group_name
  location             = data.azurerm_network_watcher.this.location

  target_resource_id = each.value.id
  storage_account_id = data.azurerm_storage_account.flowlogs.id
  enabled            = true
  version            = 2

  retention_policy {
    enabled = false
    days    = 0
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = data.azurerm_log_analytics_workspace.observability.workspace_id
    workspace_region      = azurerm_resource_group.lab.location
    workspace_resource_id = data.azurerm_log_analytics_workspace.observability.id
    interval_in_minutes   = 10
  }

  # Create the flow logs only after the network is finished. Azure allows one
  # change at a time on a VNet. Terraform already queues subnet, association
  # and peering changes so they do not clash, but it does not queue flow logs.
  # Without this, a flow log and a subnet hit the same VNet together on a fresh
  # build and the subnet fails with 409 AnotherOperationInProgress.
  depends_on = [
    azurerm_subnet.reserved,
    azurerm_subnet_network_security_group_association.workload,
    azurerm_subnet_route_table_association.spoke,
    azurerm_subnet.onprem,
    azurerm_subnet_network_security_group_association.onprem,
    azurerm_subnet_route_table_association.onprem-srv,
    azurerm_virtual_network_peering.hub_to_spoke,
    azurerm_virtual_network_peering.spoke_to_hub,
    azurerm_subnet.workload,
  ]

  tags = merge(local.common_tags, { "zone" = each.key })
}

# Look up the DCR in the observability layer (same pattern as the flow-log account)
data "azurerm_monitor_data_collection_rule" "nva_syslog" {
  name                = var.observability_dcr
  resource_group_name = var.observability_resource_group
}

# Azure Monitor Agent on the NVA: the process that reads syslog and sends it on
resource "azurerm_virtual_machine_extension" "nva_ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.hub.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = merge(local.common_tags, { "zone" = "hub" })
}

# Bind the NVA to the DCR: this is what tells the agent what to collect
resource "azurerm_monitor_data_collection_rule_association" "nva_syslog" {
  name                    = "dcra-cne-nva-syslog"
  target_resource_id      = azurerm_linux_virtual_machine.hub.id
  data_collection_rule_id = data.azurerm_monitor_data_collection_rule.nva_syslog.id
}