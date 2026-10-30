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

# Detection (b), scenario #3 (ADR D21): a connection that reached a tier-0 NIC
# from outside tier 0 with no matching fwd-accept line from the NVA. Traffic into
# tier 0 must cross the NVA, so a missing record means it was not inspected:
# either it bypassed the NVA (e.g. a spoke-to-spoke peering whose /16 route beats
# the /14 UDR) or the NVA accepted it with a rule that does not log.
# Limitation: the join matches on address and port, not time, so an earlier
# logged connection with the same tuple inside the query window masks a later one.
resource "azurerm_sentinel_alert_rule_scheduled" "t0_inbound_without_nva_record" {
  name                       = "t0-inbound-without-nva-record"
  description                = "A connection reached a tier-0 NIC from outside tier 0, but the NVA logged no fwd-accept line for it. All traffic into tier 0 is routed through the NVA, which logs every accepted new connection, so this connection was not inspected. Check the source NIC's effective routes for a more specific route than the 10.100.0.0/14 UDR (for example from a spoke-to-spoke peering), and the NVA's running ruleset (nft list ruleset) for an accept rule without log. Scenario #3; T1562."
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "T0 inbound without NVA record"
  severity                   = "High"
  query                      = file("${path.module}/../../detections/t0_inbound_without_nva_record.kql")
  query_frequency            = "PT10M"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["DefenseEvasion"]
  techniques                 = ["T1562"]
}