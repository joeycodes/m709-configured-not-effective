# Lab and observability environments share the same backend storage account and container,
# but they have different keys. This is so that the two environments are independent of 
# each other.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sajianstutfstate"
    container_name       = "tfstate"

    # The key is separate from the lab.tfstate key in infra/envs/lab/backend.tf so that the
    # observability environment would not be affected by a lab environment destroy.
    key = "observability.tfstate"

    use_azuread_auth = true
  }
}