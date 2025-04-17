terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  echo_names = [for i in range(1, var.echo_count + 1) : "echo-${i}"]
  echo_urls  = [for name in local.echo_names : "http://${name}:5678"]
  echo_urls_csv = join(",", local.echo_urls)
}

resource "docker_network" "echo_net" {
  name = "echo-net"
}

resource "docker_image" "http_echo" {
  name = "hashicorp/http-echo:latest"
}

resource "docker_image" "aggregator" {
  name         = "aggregator:local"
  build {
    context    = "../../services/aggregator"
    dockerfile = "../../services/aggregator/Dockerfile"
  }
}

resource "docker_container" "http_echo" {
  count = var.echo_count
  name  = "echo-${count.index + 1}"
  image = docker_image.http_echo.name
  command = [
    "-text=Hello from echo-${count.index + 1}!"
  ]
  
  # Ensure the container starts quickly
  restart = "no"
  
  # Add explicit hostname for better DNS resolution
  hostname = "echo-${count.index + 1}"
  
  # Add network alias to ensure the hostname resolves correctly
  networks_advanced {
    name = docker_network.echo_net.name
    aliases = ["echo-${count.index + 1}"]
  }
  
  # Add health check to ensure the echo server is ready
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:5678"]
    interval     = "2s"
    timeout      = "1s"
    start_period = "3s"
    retries      = 3
  }
  
  ports {
    internal = 5678
    external = 8081 + count.index
  }
}

resource "docker_container" "aggregator" {
  name     = "aggregator"
  image    = docker_image.aggregator.name
  hostname = "aggregator"
  env      = [
    "ECHO_URLS=${local.echo_urls_csv}",
    "MAX_RETRIES=10",                    # Increase retry count for echo server connections
    "RETRY_DELAY=5",                    # Longer delay between retries
    "STARTUP_DELAY=5"                   # Add delay before connecting to echo servers
  ]
  
  # Allow for proper restart loop detection within the container
  # while still giving it a chance to recover from temporary issues
  restart     = "on-failure"
  stdin_open  = true
  tty         = true
  
  networks_advanced {
    name    = docker_network.echo_net.name
    aliases = ["aggregator"]  # Explicit network alias
  }
  
  # Health check to monitor the aggregator container
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:3000/health"]
    interval     = "10s"
    timeout      = "5s"
    start_period = "15s"
    retries      = 3
  }
  
  ports {
    internal = 3000
    external = 3000
  }
  
  # Wait for echo servers to be healthy before starting aggregator
  depends_on = [docker_container.http_echo]
}
