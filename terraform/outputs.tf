output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.infraforge.id
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.infraforge.endpoint
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = digitalocean_kubernetes_cluster.infraforge.kube_config[0].raw_config
  sensitive   = true
}

output "registry_endpoint" {
  description = "Container registry endpoint"
  value       = digitalocean_container_registry.infraforge.endpoint
}
