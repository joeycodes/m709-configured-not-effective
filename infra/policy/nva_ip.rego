package terraform.nva_ip

import data.lab

nva_nic(rc) if {
	rc.address == "azurerm_network_interface.hub"
	rc.type == "azurerm_network_interface"
	rc.change.after != null
}

nva_ip_static(rc) if {
	some cfg in rc.change.after.ip_configuration
	cfg.private_ip_address == lab.nva_ip
	cfg.private_ip_address_allocation == "Static"
}

deny contains msg if {
	some rc in input.resource_changes
	nva_nic(rc)
	not nva_ip_static(rc)
	msg := sprintf("%s: must hold %s, statically allocated.", [rc.address, lab.nva_ip])
}
