# Create network interface for each spoke virtual machine (tier 0-2)
resource "azurerm_network_interface" "spoke" {
  for_each = local.spokes

  name                = "nic-cne-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "${each.key}-nic-conf"
    subnet_id                     = azurerm_subnet.workload["snet-${each.key}-workload"].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create network interface for hub virtual machine with IP forwarding enabled.
resource "azurerm_network_interface" "hub" {
  #checkov:skip=CKV_AZURE_119:The NVA is the lab's single internet egress point and will terminate the IPsec tunnel. Inbound from the internet is denied by the subnet NSG.
  name                  = "nic-cne-hub"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  tags                  = local.common_tags
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "hub-nic-conf"
    subnet_id                     = azurerm_subnet.workload["snet-hub-nva"].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.100.2.4"
    public_ip_address_id          = azurerm_public_ip.hub.id
  }
}

# Create network interface for onprem server virtual machine
resource "azurerm_network_interface" "onprem-srv" {
  name                = "nic-cne-onprem-srv"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "onprem-srv-nic-conf"
    subnet_id                     = azurerm_subnet.onprem["snet-onprem-srv"].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create network interface for onprem gateway virtual machine
resource "azurerm_network_interface" "onprem-gw" {
  #checkov:skip=CKV_AZURE_119:The on-premises gateway terminates the IPsec tunnel and needs a public address for it. Inbound from the internet is denied by the subnet NSG.
  name                  = "nic-cne-onprem-gw"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  tags                  = local.common_tags
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "onprem-gw-nic-conf"
    subnet_id                     = azurerm_subnet.onprem["snet-onprem-gw"].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"
    public_ip_address_id          = azurerm_public_ip.onprem-gw.id
  }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "spoke" {
  #checkov:skip=CKV_AZURE_50:Extension operations are the only management path; no VM has a public IP or an inbound management port, so run-command replaces SSH rather than adding to it
  for_each = local.spokes

  name                = "vm-cne-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.endpoint_vm_size
  admin_username      = "azureuser"
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.spoke[each.key].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "hub" {
  #checkov:skip=CKV_AZURE_50:Extension operations are the only management path; no VM has a public IP or an inbound management port, so run-command replaces SSH rather than adding to it
  name                = "vm-cne-hub"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.nva_vm_size
  admin_username      = "azureuser"
  tags                = local.common_tags

  custom_data = base64encode(templatefile("${path.module}/cloud-init-nva.yaml", {
    psk          = random_password.ipsec_psk.result
    local_addr   = "10.100.2.4"
    peer_addr    = azurerm_public_ip.onprem-gw.ip_address
    local_id     = "hub.cne.lab"
    peer_id      = "onprem.cne.lab"
    tunnel_addr  = "169.254.100.1/30"
    start_action = "none"
  }))

  network_interface_ids = [
    azurerm_network_interface.hub.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "onprem-srv" {
  #checkov:skip=CKV_AZURE_50:Extension operations are the only management path; no VM has an inbound management port open, so run-command replaces SSH rather than adding to it
  name                = "vm-cne-onprem-srv"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.srv_vm_size
  admin_username      = "azureuser"
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.onprem-srv.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "onprem-gw" {
  #checkov:skip=CKV_AZURE_50:Extension operations are the only management path; no VM has an inbound management port open, so run-command replaces SSH rather than adding to it
  name                = "vm-cne-onprem-gw"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.gw_vm_size
  admin_username      = "azureuser"
  tags                = local.common_tags

  custom_data = base64encode(templatefile("${path.module}/cloud-init-gw.yaml", {
    psk          = random_password.ipsec_psk.result
    local_addr   = "10.0.0.4"
    peer_addr    = azurerm_public_ip.hub.ip_address
    local_id     = "onprem.cne.lab"
    peer_id      = "hub.cne.lab"
    tunnel_addr  = "169.254.100.2/30"
    start_action = "start"
  }))

  network_interface_ids = [
    azurerm_network_interface.onprem-gw.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}