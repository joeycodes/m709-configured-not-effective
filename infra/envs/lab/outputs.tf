output "resource_group_name" {
  value       = azurerm_resource_group.lab.name
  description = "Name of the lab resource group, so later stages and the teardown can find it."
}

output "location" {
  value       = azurerm_resource_group.lab.location
  description = "Region everything in this environment is deployed to."
}

output "hub_private_ip" {
  value       = azurerm_network_interface.hub.private_ip_address
  description = "Private IP of the hub VM, so later stages can configure it as a next hop."
}

output "spoke_private_ips" {
  value       = { for k, nic in azurerm_network_interface.spoke : k => nic.private_ip_address }
  description = "Private IPs of the tier endpoints, used as source and target in the segmentation tests."
}

output "hub_vm_name" {
  value       = azurerm_linux_virtual_machine.hub.name
  description = "Name of the hub VM, so later stages can find it."
}

output "spoke_vm_names" {
  value       = { for k, vm in azurerm_linux_virtual_machine.spoke : k => vm.name }
  description = "Names of the tier endpoints, used as source and target in the segmentation tests."
}