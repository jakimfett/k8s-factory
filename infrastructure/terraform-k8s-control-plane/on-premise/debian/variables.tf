variable "server_ip" {
  description = "IP address of the Debian server for staging environment"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for connecting to the remote server"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file for authentication"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to install (e.g., 1.26.1)"
  type        = string
  default     = "1.26.1"
}

variable "pod_cidr" {
  description = "CIDR range for pod networking"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes service networking"
  type        = string
  default     = "10.96.0.0/12"
}

variable "kubeconfig_path" {
  description = "Local path to store the retrieved kubeconfig file"
  type        = string
  default     = "~/.kube"
}

variable "enable_dashboard" {
  description = "Whether to deploy the Kubernetes dashboard"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Whether to deploy the metrics server for monitoring"
  type        = bool
  default     = true
}
