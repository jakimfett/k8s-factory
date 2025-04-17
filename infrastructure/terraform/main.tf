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
  networks_advanced {
    name = docker_network.echo_net.name
  }
  ports {
    internal = 5678
    external = 8081 + count.index
  }
}

resource "docker_container" "aggregator" {
  name  = "aggregator"
  image = docker_image.aggregator.name
  env   = ["ECHO_URLS=${local.echo_urls_csv}"]
  
  # Keep container running
  restart = "always"
  stdin_open = true
  tty = true
  
  networks_advanced {
    name = docker_network.echo_net.name
  }
  ports {
    internal = 3000
    external = 3000
  }
  depends_on = [docker_container.http_echo]
}
