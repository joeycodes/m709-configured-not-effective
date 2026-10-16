package terraform.pip_tier0

# A NIC entry with one or more ip_configurations.
# cfgs: the `after` side, e.g. [{"public_ip_address_id": null}]
# unknowns: the `after_unknown` side, aligned by index
nic(zone, cfgs, unknowns) := {
	"address": sprintf("azurerm_network_interface.spoke[%q]", [zone]),
	"type": "azurerm_network_interface",
	"change": {
		"after": {"tags": {"zone": zone}, "ip_configuration": cfgs},
		"after_unknown": {"ip_configuration": unknowns},
	},
}

pip(zone) := {
	"address": sprintf("azurerm_public_ip.%s", [zone]),
	"type": "azurerm_public_ip",
	"change": {"after": {"tags": {"zone": zone}}},
}

test_pip_tier0_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		nic("tier0", [{"public_ip_address_id": null}], [{"private_ip_address": true}]),
	]}
}

test_tier0_nic_known_pip_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		nic("tier0", [{"public_ip_address_id": "/subscriptions/x/publicIPAddresses/pip-t0"}], [{}]),
	]}
}

test_tier0_nic_unknown_pip_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		nic("tier0", [{"public_ip_address_id": null}], [{"public_ip_address_id": true}]),
	]}
}

test_tier0_nic_empty_pip_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		nic("tier0", [{"public_ip_address_id": ""}], [{}]),
	]}
}

test_tier0_pip_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		pip("tier0"),
	]}
}

test_tier0_dual_pip_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		nic("tier0", [{"public_ip_address_id": null}, {"public_ip_address_id": "/subscriptions/x/publicIPAddresses/pip-2"}], [{}, {}]),
	]}
}

test_non_tier0_pip_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		nic("tier1", [{"public_ip_address_id": "/subscriptions/x/publicIPAddresses/pip-t1"}], [{}]),
	]}
}

test_hub_pip_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		pip("hub"),
	]}
}

test_deleted_tier0_nic_skipped if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "azurerm_network_interface.spoke[\"tier0\"]",
		"type": "azurerm_network_interface",
		"change": {"after": null},
	}]}
}
