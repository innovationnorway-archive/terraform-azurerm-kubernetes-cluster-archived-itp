##################################
##-- AZURE KUBERNETES SERVICE --##
##################################

##- AKS cluster -##
resource "azurerm_kubernetes_cluster" "cluster" {
  # Set name, location, resource group and dns prefix
  name                = format("k8s-%s-%s", var.name, data.azurerm_resource_group.cluster.location)
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  dns_prefix          = var.name

  # If kubernetes version is specified, we will attempt to use that
  # If not specified, use the latest non-preview version available in AKS
  # See the local value for more details
  kubernetes_version  = local.kubernetes_version

  # Use the log analytics workspace in West Europe
  addon_profile {
    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = data.azurerm_log_analytics_workspace.westeurope.id
    }
  }

  network_profile {
    network_plugin      = "azure"
    service_cidr        = "10.10.0.0/16"
    dns_service_ip      = "10.10.0.10"
    docker_bridge_cidr  = "172.17.0.1/16"
  }

  role_based_access_control {
    enabled         = var.role_based_access_control
  }

  enable_pod_security_policy = var.enable_pod_security_policy

  default_node_pool {
    name            = var.default_node_pool[0].name
    vnet_subnet_id  = data.azurerm_subnet.cluster.id
    vm_size         = var.default_node_pool[0].vm_size
    node_count      = var.default_node_pool[0].node_count

    enable_auto_scaling = var.default_node_pool[0].enable_auto_scaling
    min_count           = var.default_node_pool[0].min_count
    max_count           = var.default_node_pool[0].max_count

    node_taints = [var.default_node_pool[0].node_taints]
    #node_taints     = var.default_node_pool_system_only == true ? ["CriticalAddonsOnly=true:NoSchedule"] : [""]
  }

  service_principal {
    client_id       = azuread_service_principal.cluster.application_id
    client_secret   = random_password.cluster.result
  }

  tags = var.tags
}
##- Additional nodepools -##
resource "azurerm_kubernetes_cluster_node_pool" "additional_cluster" {
  for_each     = { for np in local.additional_node_pools : np.name => np }

  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  name                  = each.value.name
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  vnet_subnet_id        = each.value.vnet_subnet_id

  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count

  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints

  tags = each.value.tags
}
