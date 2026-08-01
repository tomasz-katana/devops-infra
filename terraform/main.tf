# ============================================================
# NETWORKS
# Two separate networks isolate application traffic from
# monitoring traffic. Containers on the same network reach each
# other by name, so no ports need to be published to the host.
# ============================================================

resource "docker_network" "app" {
  name   = "app-net"
  driver = "bridge"
}

resource "docker_network" "monitoring" {
  name   = "monitoring-net"
  driver = "bridge"
}

# ============================================================
# VOLUMES
# Named volumes hold data that must survive container recreation:
# the metrics database and dashboards. Without them every
# redeployment would wipe monitoring history.
# ============================================================

resource "docker_volume" "prometheus_data" {
  name = "prom-data"
}

resource "docker_volume" "grafana_data" {
  name = "grafana-data"
}

# ============================================================
# APPLICATION
# Created through the reusable service module.
# ============================================================

module "app" {
  source = "./modules/service"

  name  = "app"
  image = "${var.app_image}:${var.app_image_tag}"

  # Attached to both networks: app-net carries user traffic, while
  # monitoring-net lets Prometheus reach the app without publishing
  # extra ports to the outside world.
  networks = [
    docker_network.app.name,
    docker_network.monitoring.name,
  ]

  ports = [
    { internal = var.app_port, external = var.app_port }
  ]

  env = [
    "APP_ADDR=:${var.app_port}"
  ]
}
