# Input variables. Keeping values out of the code makes the same
# configuration usable in different environments.

variable "server_ip" {
  description = "IP address of the target server"
  type        = string
}

variable "server_user" {
  description = "SSH user used to reach the Docker daemon"
  type        = string
  default     = "devops"
}

variable "app_image" {
  description = "Application image reference without the tag"
  type        = string
}

variable "app_image_tag" {
  description = "Application image tag. Overridden by the CI/CD pipeline on every deployment."
  type        = string
  default     = "v1"
}

variable "app_port" {
  description = "Port the application listens on, inside and outside the container"
  type        = number
  default     = 8080
}
