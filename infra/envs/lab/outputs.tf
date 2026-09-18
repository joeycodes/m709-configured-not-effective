output "resource_group_name" {
  value       = azurerm_resource_group.lab.name
  description = "Name of the lab resource group, so later stages and the teardown can find it."
}

output "location" {
  value       = azurerm_resource_group.lab.location
  description = "Region everything in this environment is deployed to."
}
