# Microsoft Sentinel on the observability workspace (ADR D21). Sentinel keeps no
# data of its own; its analytics rules query this workspace's tables.
# Onboarding starts the 31-day free trial (10 GB/day of ingestion and analysis
# waived); Removing this resource offboards the workspace and every rule on it.
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = azurerm_log_analytics_workspace.this.id
}