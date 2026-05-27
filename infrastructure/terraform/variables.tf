variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "nata-expensy-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "nata-expensy-cluster"
}

variable "dns_prefix" {
  description = "DNS prefix for AKS cluster"
  type        = string
  default     = "nataexpensy"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "availability_zones" {
  description = "Availability zones supported in East US"
  type        = list(string)
  default     = ["3"]
}

variable "acr_name" {
  description = "Azure Container Registry name - no hyphens allowed"
  type        = string
  default     = "nataexpensyacr"
}

variable "dns_zone_name" {
  description = "DNS zone name"
  type        = string
  default     = "azure.ironlabs.online"
}

variable "dns_record_name" {
  description = "DNS record subdomain"
  type        = string
  default     = "nata-expensy"
}
