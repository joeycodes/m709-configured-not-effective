# DNS query logging for detection (c) and scenario #4 (ADR-021, amendment
# of 2026-10-26). VMs keep resolving through Azure DNS (168.63.129.16); the
# policy records those queries, which never cross the NVA.
#
# Built with azapi: azurerm 4.81.0 has no resource for DNS security
# policies (Microsoft.Network/dnsResolverPolicies).
#
# The policies only log; they block nothing. There are no rules yet, and the
# documentation does not say whether a query that matches no rule is logged.
# The first lab run checks DNSQueryLogs; if it stays empty, the next change
# is a catch-all Allow rule (domain list ".").
#
# One policy per VNet. A single policy could serve all five VNets, but it
# would span zones, and zone_tag.rego deliberately has no shared value. One
# per VNet also matches the flow logs in telemetry.tf.
resource "azapi_resource" "dnssp" {
  for_each = azurerm_virtual_network.this

  type      = "Microsoft.Network/dnsResolverPolicies@2025-05-01"
  parent_id = azurerm_resource_group.lab.id
  location  = azurerm_resource_group.lab.location
  name      = replace(each.value.name, "vnet-", "dnssp-")
  tags      = merge(local.common_tags, { "zone" = each.key })

  # Empty on purpose: a policy has no required properties, and rules are
  # separate child resources.
  body = { properties = {} }
}

# Links each VNet to its own policy, so the policy sees the queries made by
# that VNet's workloads. The VNet must be in the policy's region, and the
# VNet ID cannot be changed after the link is created.
resource "azapi_resource" "vnl" {
  for_each = azurerm_virtual_network.this

  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2025-05-01"
  parent_id = azapi_resource.dnssp[each.key].id
  name      = replace(each.value.name, "vnet-", "vnl-")
  location  = azurerm_resource_group.lab.location
  tags      = merge(local.common_tags, { "zone" = each.key })
  body = { properties = {
    virtualNetwork = {
      id = each.value.id
    }
    }
  }
}

# Sends each policy's query log to log-cne-observability (table
# DNSQueryLogs), where detection (c) reads it. The "allLogs" group avoids
# naming the log category, which the DNS documentation does not state.
resource "azurerm_monitor_diagnostic_setting" "dns" {
  for_each = azurerm_virtual_network.this

  name                       = replace(each.value.name, "vnet-", "dns-diag-")
  target_resource_id         = azapi_resource.dnssp[each.key].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.observability.id
  enabled_log { category_group = "allLogs" }
}
