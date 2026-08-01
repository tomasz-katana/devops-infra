# The Docker provider talks to the Docker daemon on the target server.
# Instead of exposing the Docker API over the network (a serious security
# risk), we tunnel through SSH using the same key-based authentication
# as Ansible.

provider "docker" {
  host = "ssh://${var.server_user}@${var.server_ip}:22"

  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null"
  ]
}
