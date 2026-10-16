package terraform.pip_tier0

no_pip_values = {null, ""}

tier0_nic(r) if {
	r.type == "azurerm_network_interface"
	r.change.after.tags.zone == "tier0"
}

has_pip(r) if {
	some cfg in r.change.after.ip_configuration
	not cfg.public_ip_address_id in no_pip_values
}

has_pip(r) if {
	some cfg in r.change.after_unknown.ip_configuration
	cfg.public_ip_address_id == true
}

deny contains msg if {
	some r in input.resource_changes
	tier0_nic(r)
	has_pip(r)
	msg := sprintf("Tier 0 NIC '%s' must not be associated with a public IP address.", [r.address])
}

deny contains msg if {
	some r in input.resource_changes
	r.type == "azurerm_public_ip"
	r.change.after.tags.zone == "tier0"
	msg := sprintf("Public IP '%s' must not be tagged with tier0 zone.", [r.address])
}
