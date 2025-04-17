output "kubernetes_api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${var.server_ip}:6443"
}

output "kubeconfig_path" {
  description = "Path to the retrieved kubeconfig file"
  value       = "${var.kubeconfig_path}/config-debian"
}

output "connection_command" {
  description = "Command to set the KUBECONFIG environment variable"
  value       = "export KUBECONFIG=${var.kubeconfig_path}/config-debian"
}

output "namespace" {
  description = "The namespace created for the k8s-factory project"
  value       = "k8s-factory"
}

output "metrics_endpoint" {
  description = "Where to find Prometheus metrics (once your services are deployed)"
  value       = "http://${var.server_ip}:<NodePort>/metrics"
  # Note: The actual NodePort will be determined when you deploy your services
}
