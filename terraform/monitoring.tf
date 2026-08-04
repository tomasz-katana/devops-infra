# ============================================================
# MONITORING STACK
# Every container below is created through the same reusable
# service module used for the application.
# ============================================================

resource "docker_volume" "alertmanager_data" {
  name = "alertmanager-data"
}

# ------------------------------------------------------------
# Prometheus - collects metrics and evaluates alert rules
# ------------------------------------------------------------
module "prometheus" {
  source = "./modules/service"

  name     = "prometheus"
  image    = var.image_prometheus
  networks = [docker_network.monitoring.name]

  ports = [
    { internal = 9090, external = 9090 }
  ]

  volumes = [
    { volume_name = docker_volume.prometheus_data.name, mount_path = "/prometheus" }
  ]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/prometheus.yml"
      container_path = "/etc/prometheus/prometheus.yml"
      read_only      = true
    },
    {
      host_path      = "${var.monitoring_dir}/alerts.yml"
      container_path = "/etc/prometheus/alerts.yml"
      read_only      = true
    },
  ]

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=15d", # keep 15 days of history
    "--web.enable-lifecycle",            # allows config reload without restart
  ]
}

# ------------------------------------------------------------
# Alertmanager - delivers notifications by email
# ------------------------------------------------------------
module "alertmanager" {
  source = "./modules/service"

  name     = "alertmanager"
  image    = var.image_alertmanager
  networks = [docker_network.monitoring.name]

  ports = [
    { internal = 9093, external = 9093 }
  ]

  volumes = [
    { volume_name = docker_volume.alertmanager_data.name, mount_path = "/alertmanager" }
  ]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/alertmanager.yml"
      container_path = "/etc/alertmanager/alertmanager.yml"
      read_only      = true
    },
  ]

  command = [
    "--config.file=/etc/alertmanager/alertmanager.yml",
    "--storage.path=/alertmanager",
  ]
}

# ------------------------------------------------------------
# Grafana - dashboards
# ------------------------------------------------------------
module "grafana" {
  source = "./modules/service"

  name     = "grafana"
  image    = var.image_grafana
  networks = [docker_network.monitoring.name]

  ports = [
    { internal = 3000, external = 3000 }
  ]

  volumes = [
    { volume_name = docker_volume.grafana_data.name, mount_path = "/var/lib/grafana" }
  ]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/grafana/datasources.yml"
      container_path = "/etc/grafana/provisioning/datasources/datasources.yml"
      read_only      = true
    },
    {
      host_path      = "${var.monitoring_dir}/grafana/dashboard-provider.yml"
      container_path = "/etc/grafana/provisioning/dashboards/dashboard-provider.yml"
      read_only      = true
    },
    {
      host_path      = "${var.monitoring_dir}/grafana/dashboards"
      container_path = "/etc/grafana/dashboards"
      read_only      = true
    },
  ]

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_USERS_ALLOW_SIGN_UP=false", # no self-registration
    "GF_ANALYTICS_REPORTING_ENABLED=false",
  ]
}

# ------------------------------------------------------------
# node-exporter - host metrics (INFRASTRUCTURE)
# Host directories are mounted read-only so the exporter can read
# kernel statistics from outside the container.
# ------------------------------------------------------------
module "node_exporter" {
  source = "./modules/service"

  name     = "node-exporter"
  image    = var.image_node_exporter
  networks = [docker_network.monitoring.name]

  # No published ports: Prometheus reaches it inside the network

  host_mounts = [
    { host_path = "/proc", container_path = "/host/proc", read_only = true },
    { host_path = "/sys", container_path = "/host/sys", read_only = true },
    { host_path = "/", container_path = "/rootfs", read_only = true },
  ]

  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--path.rootfs=/rootfs",
  ]
}

# ------------------------------------------------------------
# cAdvisor - per-container metrics (INFRASTRUCTURE)
# Needs privileged access to read container runtime information.
# ------------------------------------------------------------
module "cadvisor" {
  source = "./modules/service"

  name       = "cadvisor"
  image      = var.image_cadvisor
  networks   = [docker_network.monitoring.name]
  privileged = true

  host_mounts = [
    { host_path = "/", container_path = "/rootfs", read_only = true },
    { host_path = "/var/run", container_path = "/var/run", read_only = true },
    { host_path = "/sys", container_path = "/sys", read_only = true },
    { host_path = "/var/lib/docker", container_path = "/var/lib/docker", read_only = true },
  ]

  # cAdvisor scans every container once per second by default, which
  # starves a small virtual machine. These flags reduce its footprint:
  # longer housekeeping interval, containers only, and the most
  # expensive metric collectors disabled.
  command = [
    "--housekeeping_interval=30s",
    "--docker_only=true",
    "--disable_metrics=disk,diskIO,tcp,udp,percpu,sched,process,hugetlb,referenced_memory,cpu_topology,resctrl",
  ]
}

# ------------------------------------------------------------
# blackbox-exporter - availability probing (APPLICATION)
# ------------------------------------------------------------
module "blackbox_exporter" {
  source = "./modules/service"

  name     = "blackbox-exporter"
  image    = var.image_blackbox
  networks = [docker_network.monitoring.name]

  host_mounts = [
    {
      host_path      = "${var.monitoring_dir}/blackbox.yml"
      container_path = "/etc/blackbox_exporter/config.yml"
      read_only      = true
    },
  ]

  command = ["--config.file=/etc/blackbox_exporter/config.yml"]
}
