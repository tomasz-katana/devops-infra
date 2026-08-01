# Version constraints. Pinning them makes builds reproducible:
# a provider update cannot silently change behaviour.

terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
