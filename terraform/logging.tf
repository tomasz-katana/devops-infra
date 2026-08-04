# ============================================================
# LOG AGGREGATION
# Loki stores logs, Promtail collects them from every container.
# Both are created through the same reusable service module.
# ============================================================

resource "docker_volume" "loki_data" {
  name = "loki-data"
}

# ------------------------------------------------------------
# Loki - log storage and query engine.
# No published port: Grafana queries it inside the monitoring network.
# ------------------------------------------------------------
module "loki" {
  source = "./modules/service"

  name     = "loki"
  image    = var.image_loki
  networks = [docker_network.monitoring.name]

  volumes = [
    { volume_name = docker_volume.loki_data.name, mount_path = "/loki" }
  ]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/loki.yml"
      container_path = "/etc/loki/config.yml"
      read_only      = true
    },
  ]

  command = ["-config.file=/etc/loki/config.yml"]
}

# ------------------------------------------------------------
# Promtail - reads container logs through the Docker socket and
# forwards them to Loki. The socket is mounted read-only.
# ------------------------------------------------------------
module "promtail" {
  source = "./modules/service"

  name     = "promtail"
  image    = var.image_promtail
  networks = [docker_network.monitoring.name]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/promtail.yml"
      container_path = "/etc/promtail/config.yml"
      read_only      = true
    },
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
      read_only      = true
    },
  ]

  command = ["-config.file=/etc/promtail/config.yml"]
}
