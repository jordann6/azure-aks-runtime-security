data "azurerm_subscription" "current" {}

locals {
  tags = var.tags
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}"
  location = var.location
  tags     = local.tags
}

# --- Log Analytics: sink for AKS diagnostics and Defender for Containers -------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.project_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# --- AKS cluster --------------------------------------------------------------
# OIDC issuer + workload identity so in-cluster workloads authenticate to Azure
# with federated tokens and no client secrets. The microsoft_defender block wires
# the Defender for Containers sensor to the Log Analytics workspace, and the
# azure_policy add-on installs the managed Gatekeeper used by Azure Policy — this
# lab layers Kyverno on top for its own admission rules and unit tests.

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true
  role_based_access_control_enabled = true
  local_account_disabled            = false

  default_node_pool {
    name                         = "default"
    node_count                   = var.node_count
    vm_size                      = var.node_vm_size
    os_disk_size_gb              = 30
    only_critical_addons_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  tags = local.tags
}

# --- Microsoft Defender for Containers ----------------------------------------
# Subscription-level plan that adds agentless discovery, runtime threat detection,
# and image-scanning findings on top of the in-cluster Falco/Kyverno controls.
# Gated behind a variable because it is a subscription setting other workloads
# may already own.

resource "azurerm_security_center_subscription_pricing" "containers" {
  count         = var.enable_defender_for_containers ? 1 : 0
  tier          = "Standard"
  resource_type = "Containers"
}

# Route Defender for Cloud security alerts to the workspace for correlation.
resource "azurerm_security_center_workspace" "this" {
  count        = var.enable_defender_for_containers ? 1 : 0
  scope        = data.azurerm_subscription.current.id
  workspace_id = azurerm_log_analytics_workspace.this.id
}
