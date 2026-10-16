package terraform.zone_tag

test_valid_tag_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": {
						"zone": "tier2",
					},
				},
			},
		},
	]}
}

test_missing_zone_tag_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": {
						"layer": "ephemeral",
					},
				},
			},
		},
	]}
}

test_zone_tag_wrong_case_denied if {
	result := deny with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": {
						"zone": "Tier2",
					},
				},
			},
		},
	]}
	count(result) == 1
	some msg in result
	contains(msg, "is not allowed")
}

test_no_tags_skipped if {
	count(deny) == 0 with input as {"resource_changes": [
		{
			"address": "azurerm_subnet.workload[\"snet-tier2-workload\"]",
			"type": "azurerm_subnet",
			"change": {
				"after": {
					"name": "snet-tier2-workload",
				},
			},
		},
	]}
}

test_exempt_type_skipped if {
	count(deny) == 0 with input as {"resource_changes": [
		{
			"address": "azurerm_resource_group.this[\"lab\"]",
			"type": "azurerm_resource_group",
			"change": {
				"after": {
					"tags": {
						"layer": "ephemeral",
					},
				},
			},
		},
	]}
}

test_exemption_does_not_leak if {
	result := deny with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": {
						"layer": "ephemeral",
					},
				},
			},
		},
		{
			"address": "azurerm_resource_group.this[\"lab\"]",
			"type": "azurerm_resource_group",
			"change": {
				"after": {
					"tags": {
						"layer": "ephemeral",
					},
				},
			},
		},
	]}
	count(result) == 1
	some msg in result
	contains(msg, "azurerm_virtual_network")
}

test_tags_null_denied if {
	result := deny with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": null,
				},
			},
		},
	]}
	count(result) == 1
	some msg in result
	contains(msg, "missing zone tag")
}

test_empty_zone_denied if {
	result := deny with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": {
					"tags": {
						"zone": "",
					},
				},
			},
		},
	]}
	count(result) == 1
	some msg in result
	contains(msg, "is not allowed")
}

test_deleted_resource_skipped if {
	count(deny) == 0 with input as {"resource_changes": [
		{
			"address": "azurerm_virtual_network.this[\"tier2\"]",
			"type": "azurerm_virtual_network",
			"change": {
				"after": null,
			},
		},
	]}
}

test_unknown_tags_denied if {
	count(deny) == 1 with input as {"resource_changes": [
		{
			"address": "azurerm_route_table.onprem-srv",
			"type": "azurerm_route_table",
			"change": {
				"after": {"name": "onprem-srv"},
				"after_unknown": {"tags": true},
			},
		},
	]}
}
