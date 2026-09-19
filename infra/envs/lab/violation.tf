# ============================================================================
# DELIBERATE VIOLATION -- TEST ARTIFACT. DO NOT MERGE.
#
# Purpose: prove that the policy gate actually blocks a merge, rather than
# merely reporting. A control that has never been observed to fire is not a
# verified control -- which is the claim this whole project examines.
#
# This storage account is intentionally misconfigured: anonymous blob access
# permitted, plaintext HTTP allowed, TLS 1.0 accepted. Checkov has rules for
# all three.
#
# Expected outcome:
#   plan     green  (the configuration is syntactically valid)
#   checkov  RED    (three or more findings)
#   merge    blocked by the ruleset
#
# Close the pull request without merging, then delete this file.
# ============================================================================

resource "azurerm_storage_account" "violation" {
  name                            = "stcneviolationtest"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true
  https_traffic_only_enabled      = false
  min_tls_version                 = "TLS1_0"
}
