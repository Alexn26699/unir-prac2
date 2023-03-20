output "aks_id" {
  value = azurerm_kubernetes_cluster.aks-unir.id
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.aks-unir.fqdn
}

output "aks_node_rg" {
  value = azurerm_kubernetes_cluster.aks-unir.node_resource_group
}

