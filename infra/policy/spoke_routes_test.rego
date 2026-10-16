package terraform.spoke_routes

test_routes_nva_passes if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_missing_default_route_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier0\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier0"},
				"route": [
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_default_route_wrong_nexthop_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier2\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier2"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "Internet"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_onprem_not_checked if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.onprem[\"onprem\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "onprem"},
				"route": [
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_spoke_nic_not_checked if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_network_interface.spoke[\"tier0\"]",
			"name": "spoke",
			"type": "azurerm_network_interface",
			"change": {"after": {"tags": {"zone": "tier0"}}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_default_route_none_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier2\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier2"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "None"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_two_bad_tables_two_messages if {
	count(deny) == 2 with input as {
		"resource_changes": [
			{
				"address": "azurerm_route_table.spoke[\"tier0\"]",
				"name": "spoke",
				"type": "azurerm_route_table",
				"change": {"after": {
					"tags": {"zone": "tier0"},
					"route": [
						{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
					],
				}},
			},
			{
				"address": "azurerm_route_table.spoke[\"tier1\"]",
				"name": "spoke",
				"type": "azurerm_route_table",
				"change": {"after": {
					"tags": {"zone": "tier1"},
					"route": [
						{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
					],
				}},
			},
		],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_only_bad_table_reported if {
	result := deny with input as {
		"resource_changes": [
			{
				"address": "azurerm_route_table.spoke[\"tier1\"]",
				"name": "spoke",
				"type": "azurerm_route_table",
				"change": {"after": {
					"tags": {"zone": "tier1"},
					"route": [
						{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
						{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
					],
				}},
			},
			{
				"address": "azurerm_route_table.spoke[\"tier2\"]",
				"name": "spoke",
				"type": "azurerm_route_table",
				"change": {"after": {
					"tags": {"zone": "tier2"},
					"route": [
						{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
					],
				}},
			},
		],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
	count(result) == 1
	some msg in result
	contains(msg, "tier2")
}

test_empty_routes_denied if {
	count(deny) == 2 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_route_reference_passes if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_spoke_route_reference_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.spoke.private_ip_address",
				"azurerm_network_interface.spoke",
				"azurerm_network_interface.spoke.private_ip_address",
				"azurerm_network_interface.spoke",
			]}},
		}]}},
	}
}

test_route_empty_reference_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": []}},
		}]}},
	}
}

test_separate_reference_name_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub2.private_ip_address",
				"azurerm_network_interface.hub2",
				"azurerm_network_interface.hub2.private_ip_address",
				"azurerm_network_interface.hub2",
			]}},
		}]}},
	}
}

test_empty_configuration_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
	}
}

test_separate_route_name_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "other",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_mismatched_nexthop_denied if {
	count(deny) == 1 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_in_ip_address": "10.103.0.4", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}

test_matched_nexthop_passes if {
	count(deny) == 0 with input as {
		"resource_changes": [{
			"address": "azurerm_route_table.spoke[\"tier1\"]",
			"name": "spoke",
			"type": "azurerm_route_table",
			"change": {"after": {
				"tags": {"zone": "tier1"},
				"route": [
					{"address_prefix": "0.0.0.0/0", "next_hop_in_ip_address": "10.100.2.4", "next_hop_type": "VirtualAppliance"},
					{"address_prefix": "10.100.0.0/14", "next_hop_type": "VirtualAppliance"},
				],
			}},
		}],
		"configuration": {"root_module": {"resources": [{
			"type": "azurerm_route_table",
			"name": "spoke",
			"expressions": {"route": {"references": [
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
				"azurerm_network_interface.hub.private_ip_address",
				"azurerm_network_interface.hub",
			]}},
		}]}},
	}
}
