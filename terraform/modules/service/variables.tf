# Parameters accepted by this module.
# Every container in the project is created through here.

variable "name" {
  description = "Container name"
  type        = string
}

variable "image" {
  description = "Image reference including tag"
  type        = string
}

variable "networks" {
  description = "Names of Docker networks the container joins"
  type        = list(string)
}

variable "ports" {
  description = "Port mappings exposed on the host"
  type = list(object({
    internal = number
    external = number
  }))
  default = []
}

variable "env" {
  description = "Environment variables in KEY=value form"
  type        = list(string)
  default     = []
}

variable "volumes" {
  description = "Named Docker volumes mounted into the container"
  type = list(object({
    volume_name = string
    mount_path  = string
  }))
  default = []
}

variable "host_mounts" {
  description = "Files or directories bind-mounted from the host, used for configuration"
  type = list(object({
    host_path      = string
    container_path = string
    read_only      = bool
  }))
  default = []
}

variable "command" {
  description = "Optional command overriding the image default"
  type        = list(string)
  default     = null
}

variable "restart_policy" {
  description = "Restart behaviour of the container"
  type        = string
  default     = "unless-stopped"
}
