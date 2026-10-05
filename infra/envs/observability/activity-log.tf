data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-log"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = toset([
      "Administrative",
      "Security",
      "ServiceHealth",
      "Alert",
      "Recommendation",
      "Policy",
      "Autoscale",
      "ResourceHealth",
    ])
    content {
      category = enabled_log.value
    }
  }
}