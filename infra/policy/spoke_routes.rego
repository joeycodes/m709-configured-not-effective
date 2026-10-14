package terraform.spoke_routes

import data.lab

required_prefixes := {"0.0.0.0/0", "10.100.0.0/14"}
allowed_refs := {"azurerm_network_interface.hub", "azurerm_network_interface.hub.private_ip_address"}

# Checked zones rely on the mandatory zone tags guaranteed by zone_tag.rego
checked_zones := {"tier0", "tier1", "tier2"}

routes_to_appliance(rc, prefix) if {
	some route in rc.change.after.route
	route.address_prefix == prefix
	route.next_hop_type == "VirtualAppliance"
}

next_hops_from_hub_nic(rc) if {
	some block in input.configuration.root_module.resources
	block.type == rc.type
	block.name == rc.name
	refs := block.expressions.route.references
	count(refs) > 0
	every ref in refs {
		ref in allowed_refs
	}
}

spoke_route_table(rc) if {
	rc.change.after != null
	rc.type == "azurerm_route_table"
	rc.change.after.tags.zone in checked_zones
}

spoke_route_next_hop(rc) if {
	some route in rc.change.after.route
	route.next_hop_type == "VirtualAppliance"
	next_hop_ip := route.next_hop_in_ip_address
	next_hop_ip != lab.nva_ip
}

deny contains msg if {
	some rc in input.resource_changes
	spoke_route_table(rc)
	some prefix in required_prefixes
	not routes_to_appliance(rc, prefix)
	msg := sprintf("%s: must route %s to a VirtualAppliance", [rc.address, prefix])
}

deny contains msg if {
	some rc in input.resource_changes
	spoke_route_table(rc)
	not next_hops_from_hub_nic(rc)
	msg := sprintf("Must link %s to allowed Hub references", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	spoke_route_table(rc)
	spoke_route_next_hop(rc)
	msg := sprintf("%s: illegal next hop address.", [rc.address])
}
