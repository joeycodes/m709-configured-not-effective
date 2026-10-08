# East-west enforcement, stage 1.
#
# A single supernet route covers tier-to-tier traffic without touching
# anything else: the spoke's own VNet (/16) and the hub (/16, via peering)
# both have more specific system routes, and Azure selects by longest
# prefix first, so that traffic still goes direct.
#
# Two routes per spoke:
#   - 10.100.0.0/14 -> NVA: tier-to-tier traffic.
#   - 0.0.0.0/0 -> NVA: internet egress, masqueraded by the NVA
#     (cloud-init-nva.yaml). The NVA is now on the path of everything a
#     tier sends off its own VNet, including whatever the run-command
#     management path needs to reach.
#
# Still incomplete in one way:
#   - A /14 does not survive a future spoke-to-spoke peering: the resulting
#     /16 system route is more specific and would bypass the NVA silently,
#     with this configuration unchanged. The end state replaces it with
#     explicit per-tier /16 routes plus a 0.0.0.0/0 default.

resource "azurerm_route_table" "spoke" {
  for_each = local.spokes

  name                = "rt-cne-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  route {
    name                   = "to-other-tiers-via-nva"
    address_prefix         = "10.100.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.hub.private_ip_address
  }

  route {
    name                   = "default-via-nva"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.hub.private_ip_address
  }
}

# The NVA subnet is deliberately not associated: a route table that sends
# the /14 to the NVA would send the NVA's own forwarded traffic back to
# itself.
resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = local.spokes

  subnet_id      = azurerm_subnet.workload["snet-${each.key}-workload"].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}

# The on-premises VNet is deliberately not peered to Azure. It reaches it
# only through the IPsec tunnel, so it needs its own route table to send
# traffic to the gateway. The gateway is the only path to Azure, so it
# receives the /14 and the default route.
resource "azurerm_route_table" "onprem-srv" {
  name                = "rt-cne-onprem-srv"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  route {
    name                   = "to-tiers-via-gw"
    address_prefix         = "10.100.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.onprem-gw.private_ip_address
  }

  route {
    name                   = "default-via-gw"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.onprem-gw.private_ip_address
  }
}

# The gateway subnet is deliberately not associated: a route table that sends
# the /14 to the gateway would send the gateway's own forwarded traffic back to
# itself.
resource "azurerm_subnet_route_table_association" "onprem-srv" {
  subnet_id      = azurerm_subnet.onprem["snet-onprem-srv"].id
  route_table_id = azurerm_route_table.onprem-srv.id
}