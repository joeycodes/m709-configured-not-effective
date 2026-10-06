output "workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "ID of the Log Analytics workspace."
}

output "workspace_customer_id" {
  value       = azurerm_log_analytics_workspace.this.workspace_id
  description = "Distinguish the GUID used for the query from the resource ID mentioned above."
}

output "evidence_storage_account_name" {
  value       = azurerm_storage_account.evidence.name
  description = "Name of the evidence storage account."
}

output "evidence_container_name" {
  value       = azurerm_storage_container.evidence.name
  description = "Name of the evidence storage container."
}