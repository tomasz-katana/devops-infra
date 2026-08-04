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

variable "monitoring_dir" {
  description = "Directory on the server holding monitoring configuration"
  type        = string
  default     = "/opt/devops/monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password. Supplied via TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
}

# Image versions are pinned so redeployment always produces
# an identical environment.
variable "image_prometheus" {
  type    = string
  default = "prom/prometheus:v2.53.0"
}

variable "image_grafana" {
  type    = string
  default = "grafana/grafana:11.1.0"
}

variable "image_alertmanager" {
  type    = string
  default = "prom/alertmanager:v0.27.0"
}

variable "image_node_exporter" {
  type    = string
  default = "prom/node-exporter:v1.8.2"
}

variable "image_cadvisor" {
  type    = string
  default = "gcr.io/cadvisor/cadvisor:latest"
}

variable "image_blackbox" {
  type    = string
  default = "prom/blackbox-exporter:v0.25.0"
}

variable "image_loki" {
  type    = string
  default = "grafana/loki:2.9.8"
}

variable "image_promtail" {
  type    = string
  default = "grafana/promtail:2.9.8"
}
