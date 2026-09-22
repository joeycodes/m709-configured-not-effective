# Network topology for the lab (M1).
#
# Address plan from docs/TECHNICAL-DESIGN.md section 3.1. The four Azure
# VNets fill 10.100.0.0/14 exactly, so the whole Azure side can be
# summarised to on-premises as a single route. An Azure VNet added outside
# that /14 breaks the summary -- revisit the plan before doing so.

locals {
  vnets = {
    hub    = "10.100.0.0/16"
    tier0  = "10.101.0.0/16"
    tier1  = "10.102.0.0/16"
    tier2  = "10.103.0.0/16"
    onprem = "10.0.0.0/16"
  }

  # Subnets Azure reserves by name for its managed services. They stay empty
  # during routine work and are populated only in time-boxed validation
  # windows. Reserving them now means a validation window changes what is
  # deployed, not the address plan, so self-hosted and managed runs remain
  # directly comparable.
  reserved_subnets = {
    AzureFirewallSubnet = "10.100.0.0/24"
    GatewaySubnet       = "10.100.1.0/24"
  }

  # Subnets carrying this project's own workloads. Each gets an NSG.
  workload_subnets = {
    "snet-hub-nva"        = { vnet = "hub", prefix = "10.100.2.0/24" }
    "snet-tier0-workload" = { vnet = "tier0", prefix = "10.101.0.0/24" }
    "snet-tier1-workload" = { vnet = "tier1", prefix = "10.102.0.0/24" }
    "snet-tier2-workload" = { vnet = "tier2", prefix = "10.103.0.0/24" }
    "snet-onprem-core"    = { vnet = "onprem", prefix = "10.0.0.0/24" }
  }

  spokes = toset(["tier0", "tier1", "tier2"])
}

resource "azurerm_virtual_network" "this" {
  for_each = local.vnets

  name                = "vnet-cne-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [each.value]
  tags                = local.common_tags
}

resource "azurerm_subnet" "reserved" {
  #checkov:skip=CKV2_AZURE_31:Azure does not support an NSG on GatewaySubnet or AzureFirewallSubnet
  for_each = local.reserved_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.this["hub"].name
  address_prefixes     = [each.value]
}

resource "azurerm_subnet" "workload" {
  for_each = local.workload_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet].name
  address_prefixes     = [each.value.prefix]
}

# Baseline NSGs, carrying Azure's default rules only. Those deny inbound
# traffic from the internet but ALLOW everything within and between peered
# virtual networks -- the VirtualNetwork service tag includes peered address
# space. So these NSGs do not segment the tiers from one another.
#
# That is deliberate and temporary: tier segmentation arrives with the hub
# NVA and user-defined routes in the next change. Until then, a passing
# policy scan means only that every subnet has an NSG, not that the tiers
# are isolated.
resource "azurerm_network_security_group" "workload" {
  for_each = local.workload_subnets

  name                = replace(each.key, "snet-", "nsg-")
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = local.workload_subnets

  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}

# Hub-and-spoke peering. Spokes peer only to the hub, never to each other, so
# every spoke-to-spoke path transits the hub where it can be inspected.
#
# allow_forwarded_traffic is needed on both sides: spoke-to-spoke traffic is
# forwarded by the hub NVA, so it arrives with a source outside the hub, and
# Azure drops forwarded traffic across a peering unless this is enabled.
#
# The on-premises VNet is deliberately NOT peered. It reaches Azure only
# through the IPsec tunnel. Peering it would open a path over the Azure
# backbone that bypasses the tunnel entirely: the tunnel would still show as
# up and BGP would still converge, while no traffic actually used it.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  # Azure rejects a peering change while a subnet on the same VNet is
  # still being updated (ReferencedResourceNotProvisioned). Nothing links
  # the two otherwise, so Terraform would create them at the same time.
  # The same applies to the spoke-to-hub peering below.
  depends_on = [
    azurerm_subnet.reserved,
    azurerm_subnet.workload,
    azurerm_subnet_network_security_group_association.workload,
  ]

  for_each = local.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.this["hub"].name
  remote_virtual_network_id = azurerm_virtual_network.this[each.key].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  depends_on = [
    azurerm_subnet.reserved,
    azurerm_subnet.workload,
    azurerm_subnet_network_security_group_association.workload,
  ]

  for_each = local.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.this[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.this["hub"].id
  allow_forwarded_traffic   = true
}
