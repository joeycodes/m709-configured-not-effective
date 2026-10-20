# Raw VNet flow logs (ADR D21): a staging area. Traffic Analytics processes
# them into the workspace, which holds the copy that is queried and kept.
# Separate from the evidence account: LRS, no versioning, deleted after 30
# days. Persistent so unprocessed logs survive the nightly destroy; same
# region as the VNets, as flow logs require.

resource "azurerm_storage_account" "flowlogs" {
  #checkov:skip=CKV_AZURE_59:Public endpoint kept for Network Watcher (writes) and Traffic Analytics (reads); restricting it to trusted Azure services is untested for flow logs. Access is Entra-only. Known gap, ADR D21
  #checkov:skip=CKV2_AZURE_33:Private endpoint not deployed; no persistent VNet exists to host it and the lab VNets are destroyed nightly. ADR D17
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys with infrastructure encryption; customer-managed keys address a threat outside this project's model
  #checkov:skip=CKV_AZURE_33:Queue service is not used by this account
  #checkov:skip=CKV_AZURE_206:LRS by design. Raw flow logs are processed into the workspace within minutes and deleted after 30 days; losing this region's copy loses nothing the workspace does not already hold. ADR D21
  name                              = "sacneflowlogs"
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

  # Public network access stays enabled. Only Azure services touch this data
  # plane: Network Watcher writes the logs and Traffic Analytics reads them.
  # The tighter setting, default deny with an exception for trusted Azure
  # services, has not been tested with flow logs; it is tried once flow logs
  # are shown to arrive with this one. Access is still Entra-only (shared key
  # is off), so this is exposure of an endpoint, not of the data. Known gap,
  # ADR D21.
  public_network_access_enabled = true
  tags                          = local.common_tags

  # A short soft-delete window: a buffer against deleting raw logs by hand
  # before Traffic Analytics has processed them. Routine removal is the
  # lifecycle rule below, not this.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_management_policy" "flowlogs" {
  storage_account_id = azurerm_storage_account.flowlogs.id

  rule {
    name    = "deleteRawFlowLogs"
    enabled = true
    filters {
      prefix_match = ["insights-logs-flowlogflowevent/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}