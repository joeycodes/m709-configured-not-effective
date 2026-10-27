# Detection (a), scenario #1 (ADR D21): a flow from tier 2 accepted at a tier-0
# NIC. The NVA (fwd-t2t0-drop) and the tier-0 NSG (DenyTier2ToTier0) both block
# this path, so any row means at least one layer has failed. The query lives in
# infra/detections/; the rule sits in the persistent layer with the workspace it
# queries, so it survives the nightly destroy.
resource "azurerm_sentinel_alert_rule_scheduled" "t2_to_t0_accepted" {
  name                       = "t2-to-t0-accepted"
  description                = "A flow from tier 2 accepted at a tier-0 NIC. The NVA and the tier-0 NSG both block this path, so any match means at least one layer has failed. Scenario #1; tested with SSH (T1021.004)."
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "T2 to T0 Accepted"
  severity                   = "High"
  query                      = file("${path.module}/../../detections/t2_to_t0_accepted.kql")
  query_frequency            = "PT10M"
  query_period               = "PT30M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["LateralMovement"]
  techniques                 = ["T1021"]
}