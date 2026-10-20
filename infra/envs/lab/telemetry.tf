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

  tags = merge(local.common_tags, { "zone" = each.key })
}