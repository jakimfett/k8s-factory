# Metrics infrastructure configuration

# Prometheus image
resource "docker_image" "prometheus" {
  name = "prometheus:local"
  build {
    context    = "../../services/metrics/prometheus"
    dockerfile = "../../services/metrics/prometheus/Dockerfile"
  }
}

# Grafana image
resource "docker_image" "grafana" {
  name = "grafana:local"
  build {
    context    = "../../services/metrics/grafana"
    dockerfile = "../../services/metrics/grafana/Dockerfile"
  }
}

# Prometheus container - always deployed for metrics collection
resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = docker_image.prometheus.name
  
  # Mount Docker socket for service discovery
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  
  networks_advanced {
    name = docker_network.echo_net.name
  }
  
  ports {
    internal = 9090
    external = 9090
  }
  
  depends_on = [docker_container.aggregator]
}

# Grafana container - only deployed when visualization is requested
resource "docker_container" "grafana" {
  count = var.enable_visualization ? 1 : 0
  
  name  = "grafana"
  image = docker_image.grafana.name
  
  networks_advanced {
    name = docker_network.echo_net.name
  }
  
  ports {
    internal = 3000
    external = 3001  # Use 3001 to avoid conflict with aggregator
  }
  
  depends_on = [docker_container.prometheus]
}
