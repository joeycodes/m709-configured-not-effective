# Where Terraform keeps its record of what it has built.
#
# This storage account was created by hand during bootstrap and is never
# managed by Terraform -- see docs/adr/ADR-000-bootstrap.md, decision D1.
#
# Note what is NOT here: use_oidc. That is supplied by the ARM_USE_OIDC
# environment variable, set only in CI. The file describes what is true
# everywhere; the environment supplies what differs between a laptop and
# a runner. Locally, Terraform falls back to your `az login` session.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sajianstutfstate"
    container_name       = "tfstate"
    key                  = "lab.tfstate"

    # Authenticate to the blob with Entra ID rather than a storage account
    # key. Shared key access is disabled on the account (ADR D7), so this
    # is not optional -- it is the only way in.
    use_azuread_auth = true
  }
}
