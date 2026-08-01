# Generic service definition reused by every container in the project.

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# Pull the image onto the server.
resource "docker_image" "this" {
  name = var.image
}

resource "docker_container" "this" {
  name = var.name

  # Referencing image_id, not the tag, is deliberate: when the tag points
  # to a new build, the digest changes and Terraform recreates the
  # container. Using the tag alone would leave the old container running.
  image = docker_image.this.image_id

  restart = var.restart_policy

  # Dynamic blocks generate as many blocks as there are list entries,
  # so one module handles containers with any number of ports or volumes.

  dynamic "networks_advanced" {
    for_each = var.networks
    content {
      name = networks_advanced.value
    }
  }

  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  # Named volumes - persistent data that survives container recreation
  dynamic "volumes" {
    for_each = var.volumes
    content {
      volume_name    = volumes.value.volume_name
      container_path = volumes.value.mount_path
    }
  }

  # Bind mounts - configuration files supplied from the host
  dynamic "volumes" {
    for_each = var.host_mounts
    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
      read_only      = volumes.value.read_only
    }
  }

  env     = var.env
  command = var.command
}
