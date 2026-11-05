terraform {
  # Pin the CLI and the provider. An unpinned provider can change behaviour
  # between two runs of identical code, which would undermine the
  # reproducibility this project claims. Same reasoning as committing
  # .terraform.lock.hcl.
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  # Required but intentionally empty: this block is where provider-wide
  # behaviours are opted into. Nothing is needed yet.
  features {}

  # Required since azurerm 4.0. Earlier versions silently inherited the
  # Azure CLI's default subscription, so the same code could deploy to a
  # different subscription depending on who ran it. Stating it here makes
  # the target part of the code rather than part of the operator.
  subscription_id = var.subscription_id
}

# azapi calls the Azure Resource Manager REST API directly, so it can build
# resource types that azurerm does not cover yet; here, the DNS security
# policy in dns.tf. It reads the same ARM_* environment variables as
# azurerm, so CI authenticates it through the same OIDC login with no extra
# setup.
provider "azapi" {
  # Same reason as in the azurerm block above.
  subscription_id = var.subscription_id
}
