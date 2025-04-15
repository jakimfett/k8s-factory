terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "echo_count" {
  description = "Number of hashicorp/http-echo containers to run"
  type        = number
  default     = 3
}

resource "docker_image" "http_echo" {
  name = "hashicorp/http-echo:latest"
}

resource "docker_container" "http_echo" {
  count = var.echo_count
  name  = "echo-${count.index + 1}"
  image = docker_image.http_echo.latest
  command = [
    "-text=Hello from echo-${count.index + 1}!"
  ]
  ports {
    internal = 5678
    external = 808${count.index + 1}
  }
}
