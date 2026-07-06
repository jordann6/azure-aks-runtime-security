variable "project_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "aks-runtime-sec"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-runtime-security"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (use a version on standard support; 1.30 and earlier are LTS-only)"
  type        = string
  default     = "1.34"
}

variable "node_count" {
  description = "Node count for the default pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for the default pool"
  type        = string
  default     = "Standard_B2s"
}

variable "enable_defender_for_containers" {
  description = "Enable the Microsoft Defender for Containers subscription plan. This is a subscription-level setting; leave off if another workload already manages it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "azure-aks-runtime-security"
    environment = "lab"
    managed_by  = "terraform"
  }
}
