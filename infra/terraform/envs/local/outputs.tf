output "kubeconfig_path" {
  description = "Use: export KUBECONFIG=<este caminho>"
  value       = kind_cluster.this.kubeconfig_path
}

output "endpoint" {
  description = "Endpoint da API do Kubernetes"
  value       = kind_cluster.this.endpoint
}
