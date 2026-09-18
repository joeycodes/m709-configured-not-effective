# The loop test: one resource group, nothing more.
#
# The point of this file is not the resource group. It is to drive the
# whole chain -- pull request, plan, policy check, approval, apply, state
# written to the remote backend -- with the smallest possible payload, so
# that a failure anywhere in that chain is unambiguous.
#
# Real network resources arrive in M1, once this loop is proven.

locals {
  # Applied to everything. `layer = ephemeral` is what the nightly teardown
  # targets; rg-tfstate carries `layer = persistent` and is therefore never
  # touched by it (ADR D12).
  common_tags = {
    project    = var.project
    layer      = "ephemeral"
    managed_by = "terraform"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-cne-lab"
  location = var.location
  tags     = local.common_tags
}
