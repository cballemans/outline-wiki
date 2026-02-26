
locals {
  rg_name = coalesce(var.resource_group_name, "rg-${var.project_name}-prod")
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

# Networking
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-${var.project_name}-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# Delegated subnet for Azure PostgreSQL Flexible Server
resource "azurerm_subnet" "pg" {
  name                 = "snet-${var.project_name}-pg"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.pg_subnet_cidr]
  delegations {
    name = "pg-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Public IP + NSG + NIC
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.ssh_source_address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Ubuntu VM
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.project_name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  disable_password_authentication = true
}

# Azure PostgreSQL Flexible Server (VNet integrated)
resource "random_password" "pg" {
  length  = 20
  special = true
}

resource "azurerm_private_dns_zone" "pg" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pglink" {
  name                  = "pg-dnslink"
  private_dns_zone_name = azurerm_private_dns_zone.pg.name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-${var.project_name}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "14"
  delegated_subnet_id    = azurerm_subnet.pg.id
  private_dns_zone_id    = azurerm_private_dns_zone.pg.id
  administrator_login    = "outlineadmin"
  administrator_password = random_password.pg.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  backup_retention_days  = 7
  zone                   = 1

  high_availability { mode = "Disabled" }
  maintenance_window { day_of_week = 0 start_hour = 0 start_minute = 0 }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "outline"
  server_id = azurerm_postgresql_flexible_server.pg.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Storage for Blob (used via MinIO Azure gateway)
resource "azurerm_storage_account" "sa" {
  name                     = replace("st${var.project_name}", "-", "")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
  allow_nested_items_to_be_public = false
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "outline" {
  name                  = "outline"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_admin_username" { value = var.admin_username }

output "postgres_fqdn" { value = azurerm_postgresql_flexible_server.pg.fqdn }
output "postgres_database" { value = azurerm_postgresql_flexible_server_database.db.name }
output "postgres_username" { value = "${azurerm_postgresql_flexible_server.pg.administrator_login}@${azurerm_postgresql_flexible_server.pg.name}" }
output "postgres_password" { value = random_password.pg.result  sensitive = true }

output "storage_account_name" { value = azurerm_storage_account.sa.name }
output "storage_account_primary_key" {
  value     = azurerm_storage_account.sa.primary_access_key
  sensitive = true
}

output "domain_name" { value = var.domain_name }
output "tenant_id" { value = var.tenant_id }
output "certbot_email" { value = var.certbot_email }
output "resource_group" { value = azurerm_resource_group.rg.name }
