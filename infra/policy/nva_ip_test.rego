package terraform.nva_ip

test_matched_hub_nic_ip_passes if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.hub",
			"type": "azurerm_network_interface",
			"change": {"after": {"ip_configuration": [{
				"private_ip_address": "10.100.2.4",
				"private_ip_address_allocation": "Static",
			}]}},
		}],
	}
}

test_mismatched_hub_nic_ip_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.hub",
			"type": "azurerm_network_interface",
			"change": {"after": {"ip_configuration": [{
				"private_ip_address": "10.100.2.5",
				"private_ip_address_allocation": "Static",
			}]}},
		}],
	}
}

test_hub_nic_dynamic_ip_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.hub",
			"type": "azurerm_network_interface",
			"change": {"after": {"ip_configuration": [{
				"private_ip_address_allocation": "Dynamic",
			}]}},
		}],
	}
}

test_dual_hub_nic_ip_passes if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.hub",
			"type": "azurerm_network_interface",
			"change": {"after": {"ip_configuration": [
				{
					"private_ip_address": "10.100.2.4",
					"private_ip_address_allocation": "Static",
				},
				{
					"private_ip_address": "10.100.2.10",
					"private_ip_address_allocation": "Static",
				},
			]}},
		}],
	}
}

test_non_hub_nic_not_checked if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.tier1",
			"type": "azurerm_network_interface",
			"change": {"after": {"ip_configuration": [{
				"private_ip_address": "10.102.0.4",
				"private_ip_address_allocation": "Static",
			}]}},
		}],
	}
}

test_change_after_null_skipped if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.hub",
			"type": "azurerm_network_interface",
			"change": {"after": null},
		}],
	}
}
