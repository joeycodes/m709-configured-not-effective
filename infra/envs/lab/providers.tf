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
