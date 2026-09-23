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
  }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "spoke" {
  for_each = local.spokes

  name                = "vm-cne-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B1s"
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
  name                = "vm-cne-hub"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B2ls_v2"
  admin_username      = "azureuser"
  tags                = local.common_tags

  custom_data = base64encode(file("${path.module}/cloud-init-nva.yaml"))

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