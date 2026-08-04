# devops-infra — Infrastructure as Code

Infrastructure and configuration for the DevOps diploma project. Provisions a
server, deploys the application from
**[golang-helloworld](https://github.com/tomasz-katana/golang-helloworld)**
and runs a full monitoring stack.

## Architecture

```
  git push
     |
     v
+------------------------------------------+
|  GitHub Actions (hosted runners)          |
|  tests -> image build -> Docker Hub       |
+----------------+-------------------------+
                 |  self-hosted runner
                 |  (master branch only)
                 v
+------------------------------------------+
|  Deployment host (WSL)                    |
|  ansible-playbook  ->  terraform apply    |
+----------------+-------------------------+
                 |  SSH
                 v
+------------------------------------------+
|  Target server - Ubuntu on VirtualBox     |
|  UFW firewall, key-only SSH               |
|                                           |
|  network app-net                          |
|    +- app                        :8080    |
|                                           |
|  network monitoring-net                   |
|    +- prometheus                 :9090    |
|    +- grafana                    :3000    |
|    +- alertmanager               :9093    |
|    +- node-exporter          internal     |
|    +- cadvisor               internal     |
|    +- blackbox-exporter      internal     |
+----------------+-------------------------+
                 |
                 v
          email notifications
```

## Division of responsibility

Two tools with distinct roles, which is the standard separation between
configuration management and resource management:

| Tool | Manages |
|---|---|
| **Ansible** | operating system: packages, Docker Engine, firewall, SSH hardening, time synchronisation, configuration files |
| **Terraform** | Docker resources: networks, volumes, containers |

## Repository layout

```
ansible/
  ansible.cfg              defaults, so no flags are needed on the CLI
  inventory.ini            target host, SSH user and key
  playbook.yml             operating system configuration
  monitoring.yml           monitoring configuration files
  site.yml                 entry point importing both playbooks
  files/monitoring/        Prometheus, Alertmanager, blackbox, Loki, Promtail configs
  files/monitoring/grafana/dashboards/   dashboard definitions kept as code

terraform/
  versions.tf              pinned Terraform and provider versions
  providers.tf             Docker provider over an SSH tunnel
  variables.tf             input variables
  terraform.tfvars         values for this environment
  main.tf                  networks, volumes, application container
  monitoring.tf            monitoring containers
  logging.tf               log aggregation containers
  outputs.tf               service URLs
  modules/service/         reusable container module
```

## Prerequisites

On the deployment host:

- Ansible 2.18 or newer, with the `community.general` collection
- Terraform 1.5 or newer
- SSH key-based access to the target server
- Git

On the target server:

- Ubuntu 24.04 or newer, minimum 2 GB RAM and 20 GB disk
- OpenSSH server
- a user named `devops` with sudo rights

## Bootstrap (one-time manual steps)

Three things cannot be automated, because the automation itself depends on
them. They are performed once, on a freshly installed server.

**1. Non-interactive sudo.** The pipeline runs unattended, so sudo must not
prompt for a password:

```bash
ssh -t devops@192.168.56.50 \
  'echo "devops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-devops && sudo chmod 440 /etc/sudoers.d/90-devops'
```

**2. DNS resolution.** The NAT interface does not always supply working name
servers, and without DNS nothing can be downloaded:

```bash
ssh devops@192.168.56.50 'sudo tee /etc/netplan/99-dns.yaml > /dev/null << "YAML"
network:
  version: 2
  ethernets:
    enp0s3:
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
YAML
sudo chmod 600 /etc/netplan/99-dns.yaml && sudo netplan apply'
```

**3. Initial clock synchronisation.** Virtual machines drift, and a skewed clock
breaks TLS validation and repository metadata checks:

```bash
ssh devops@192.168.56.50 "sudo date -s '$(date -u +'%Y-%m-%d %H:%M:%S')' && sudo hwclock --systohc"
```

Ongoing synchronisation is handled by the playbook, which installs and enables
`chrony`.

## Deployment

Both stages are idempotent and safe to repeat.

### Required environment variables

```bash
export SMTP_USER="you@gmail.com"
export SMTP_PASSWORD="gmail-app-password"
export ALERT_EMAIL_TO="you@gmail.com"
export TF_VAR_grafana_admin_password="grafana-admin-password"
```

No secret is stored in this repository. In the pipeline these values come from
GitHub Secrets.

### Configure the operating system

```bash
cd ansible
ansible-playbook site.yml
```

Installs Docker from the vendor repository, configures the UFW firewall,
disables SSH password authentication, and uploads monitoring configuration.

### Deploy containers

```bash
cd ../terraform
terraform init
terraform apply -var="app_image_tag=master-d3447db"
```

The image tag is supplied by the pipeline on every deployment. Omitting it uses
the default from `terraform.tfvars`.

## Verification

```bash
curl http://192.168.56.50:8080
curl http://192.168.56.50:8080/health
ssh devops@192.168.56.50 'docker ps'
ssh devops@192.168.56.50 'sudo ufw status verbose'
ssh devops@192.168.56.50 'sudo sshd -T | grep passwordauthentication'
```

### Web interfaces

| Service | Address |
|---|---|
| Application | http://192.168.56.50:8080 |
| Grafana | http://192.168.56.50:3000 |
| Prometheus | http://192.168.56.50:9090 |
| Alertmanager | http://192.168.56.50:9093 |

Grafana logs in as `admin` with the password supplied through
`TF_VAR_grafana_admin_password`.

## Idempotence

Both tools report no changes when the actual state already matches the code:

```bash
ansible-playbook site.yml     # PLAY RECAP ... changed=0
terraform apply               # No changes. Your infrastructure matches ...
```

## Monitoring

Two layers are monitored, as a healthy server does not imply a working
application:

| Layer | Source | Measures |
|---|---|---|
| Infrastructure | node-exporter | CPU, memory, disk, network |
| Infrastructure | cAdvisor | per-container resource usage |
| Application | blackbox-exporter | HTTP availability and response time |
| Logs | Promtail into Loki | log lines from every container, labelled by container name |

Prometheus scrapes every 15 seconds and evaluates five alert rules. Alerts are
delivered by email through Alertmanager, including a resolution message once
the condition clears.

Exporters publish no host ports. Prometheus reaches them by container name
inside `monitoring-net`, which keeps the exposed surface minimal.

## Security

- SSH password authentication and direct root login are disabled
- UFW denies all inbound traffic except SSH, the application and the three
  monitoring interfaces
- containers run unprivileged, with the single exception of cAdvisor, which
  needs host access to read container runtime data
- host paths are mounted read-only
- Terraform reaches the Docker daemon through an SSH tunnel rather than an
  exposed Docker API
- secrets are supplied through environment variables and GitHub Secrets
- the Alertmanager configuration file, which contains SMTP credentials, is
  readable only by the container's own user (mode 0400)

### Dashboards as code

Grafana data sources and the project dashboard are provisioned from files in
this repository, so a freshly created Grafana container is immediately usable
with no manual configuration. Community dashboards for node-exporter and
blackbox-exporter are imported separately by ID, as there is no value in
recreating well-maintained work.

## Known limitations

**Per-container metrics from cAdvisor are unavailable.** Docker 29 introduced a
storage driver based on the containerd snapshotter, while cAdvisor looks for
layer metadata in the legacy `overlay2` layout. Its logs show repeated attempts
to open paths that no longer exist, and a newer cAdvisor release behaves the
same. Switching Docker back to `overlay2` would fix it but discards all local
images, which was not justified at this stage of the project.

The impact is limited: infrastructure metrics come from node-exporter and
application availability from blackbox-exporter, so no monitoring requirement
depends on cAdvisor.

## Rollback

Redeploy an earlier image tag; previous images remain in the registry:

```bash
cd terraform
terraform apply -var="app_image_tag=master-<earlier-sha>"
```

## State management

Terraform state is kept on the deployment host and managed exclusively by the
pipeline. In a team environment a remote backend with locking would be used
instead, so that state is shared and concurrent runs cannot corrupt it.
