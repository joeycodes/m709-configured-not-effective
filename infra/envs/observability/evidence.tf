resource "azurerm_storage_account" "evidence" {
  name                              = "sacneevidence"
  resource_group_name               = azurerm_resource_group.observability.name
  location                          = azurerm_resource_group.observability.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  local_user_enabled                = false

  # Public network access stays enabled: CI runners, the author's workstation
  # and the NVA all reach the data plane over the public endpoint, and none of
  # them has a private path yet. Access is still Entra-only (shared key is off),
  # so this is exposure of an endpoint, not of the data. Recorded as a known
  # gap in ADR D17 rather than scheduled.
  public_network_access_enabled = true
  tags                          = local.common_tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "evidence" {
  name                  = "evidence"
  storage_account_id    = azurerm_storage_account.evidence.id
  container_access_type = "private"
}