# Values the module returns to whoever calls it.

output "container_name" {
  description = "Name of the created container"
  value       = docker_container.this.name
}

output "container_id" {
  description = "Docker ID of the created container"
  value       = docker_container.this.id
}
