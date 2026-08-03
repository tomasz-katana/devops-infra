# Values printed after a successful apply - handy during a demo.

output "application_url" {
  description = "Address of the running application"
  value       = "http://${var.server_ip}:${var.app_port}"
}

output "deployed_image" {
  description = "Image reference currently deployed"
  value       = "${var.app_image}:${var.app_image_tag}"
}

output "networks" {
  description = "Docker networks managed by Terraform"
  value       = [docker_network.app.name, docker_network.monitoring.name]
}

output "volumes" {
  description = "Docker volumes managed by Terraform"
  value       = [docker_volume.prometheus_data.name, docker_volume.grafana_data.name]
}

output "grafana_url" {
  description = "Grafana dashboard address"
  value       = "http://${var.server_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus web interface"
  value       = "http://${var.server_ip}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager web interface"
  value       = "http://${var.server_ip}:9093"
}
