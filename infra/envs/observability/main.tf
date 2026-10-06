locals {
  # The nightly teardown is bounded by Terraform state, not by tags (ADR D12).
  # The tag exists so drift checks such as `az resource list --tag
  # layer=ephemeral` do not report this layer.
  common_tags = {
    project    = var.project
    layer      = "persistent"
    managed_by = "terraform"
  }
}

resource "azurerm_resource_group" "observability" {
  name     = "rg-cne-observability"
  location = var.location
  tags     = local.common_tags
}