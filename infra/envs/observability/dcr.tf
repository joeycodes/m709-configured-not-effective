# DCR for the hub NVA's nftables logs (ADR D21): collect the kern facility
# at Warning and above, send it to the workspace. It names no VM; the lab
# layer binds the NVA to it with an association.
resource "azurerm_monitor_data_collection_rule" "nva_syslog" {
  name                = "dcr-cne-nva-syslog"
  resource_group_name = azurerm_log_analytics_workspace.this.resource_group_name
  location            = azurerm_log_analytics_workspace.this.location
  kind                = "Linux"
  description         = "nftables logs (kern facility, Warning+) from the hub NVA to the observability workspace"

  data_sources {
    syslog {
      name           = "kern-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["kern"]
      log_levels = [
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency"
      ]
    }
  }

  destinations {
    log_analytics {
      name                  = "workspace"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["workspace"]
  }

  tags = local.common_tags
}