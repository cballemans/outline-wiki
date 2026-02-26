
variable "project_name" {
  description = "Project prefix for resource names"
  type        = string
  default     = "mccoy-outline"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Resource group name (optional; default computed)"
  type        = string
  default     = null
}

variable "vnet_cidr" {
  description = "VNet address space"
  type        = string
  default     = "10.90.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet address prefix for VM"
  type        = string
  default     = "10.90.1.0/24"
}

variable "pg_subnet_cidr" {
  description = "Delegated subnet for Azure PostgreSQL Flexible Server"
  type        = string
  default     = "10.90.2.0/24"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "outlineadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the admin user"
  type        = string
}

variable "ssh_source_address_prefixes" {
  description = "CIDRs allowed to SSH to the VM"
  type        = list(string)
  default     = ["*"]
}

variable "domain_name" {
  description = "FQDN for Outline (e.g., wiki.example.com)"
  type        = string
}

variable "certbot_email" {
  description = "Email for Let's Encrypt registration"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID used for OAuth endpoints"
  type        = string
}

variable "storage_account_tier" {
  description = "Azure Storage Account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Azure Storage replication type"
  type        = string
  default     = "LRS"
}
