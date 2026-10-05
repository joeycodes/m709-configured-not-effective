resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-cne-observability"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = local.common_tags
  sku                 = "PerGB2018"

  # Disable the workspace shared key. With it enabled, anyone holding the key
  # can ingest and query without Entra ID, bypassing RBAC and the audit trail.
  # Same principle as disabling shared key on the storage accounts (ADR D7).
  local_authentication_enabled = false
}