variable "echo_count" {
  description = "Number of hashicorp/http-echo containers to run"
  type        = number
  default     = 2
}

variable "enable_visualization" {
  description = "Whether to enable Grafana for metrics visualization"
  type        = bool
  default     = false
}

