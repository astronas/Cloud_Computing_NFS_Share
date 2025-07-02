provider "digitalocean" { 
  token = var.do_token
}

resource "digitalocean_vpc" "nfs_vpc" {
  name        = "nfs-vpc2"
  region      = "fra1"
  ip_range    = "10.10.0.0/16"
  description = "VPC privé pour le partage NFS"
}

data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "nfs_server" {
  name       = "nfs-server"
  region     = "fra1"
  size       = "s-1vcpu-1gb"
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = digitalocean_vpc.nfs_vpc.id
  tags       = ["nfs", "server"]
}

resource "null_resource" "nfs_provisioner" {
  depends_on = [digitalocean_droplet.nfs_server]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.nfs_server.ipv4_address_private
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y nfs-kernel-server wget curl",
      "mkdir -p /srv/nfs_share",
      "chmod 777 /srv/nfs_share",
      "echo '/srv/nfs_share 10.10.0.0/16(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports",
      "exportfs -a",
      "ufw allow from 10.10.0.0/16 to any port 2049 proto tcp",
      "ufw allow from 10.10.0.0/16 to any port 2049 proto udp",
      "systemctl enable nfs-kernel-server",
      "systemctl restart nfs-kernel-server",

      # --- Installation et lancement node_exporter pour metrics ---
      "useradd -m -s /bin/false node_exporter",
      "cd /tmp",
      "curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz",
      "tar xzf node_exporter-1.5.0.linux-amd64.tar.gz",
      "cp node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/",
      "chown node_exporter:node_exporter /usr/local/bin/node_exporter",
      "rm -rf node_exporter-1.5.0.linux-amd64*",
      "echo '[Unit]\nDescription=Node Exporter\nAfter=network.target\n\n[Service]\nUser=node_exporter\nExecStart=/usr/local/bin/node_exporter\n\n[Install]\nWantedBy=default.target' > /etc/systemd/system/node_exporter.service",
      "systemctl daemon-reload",
      "systemctl enable node_exporter",
      "systemctl start node_exporter"
    ]
  }
}

resource "digitalocean_droplet" "nfs_client" {
  name       = "nfs-client"
  region     = "fra1"
  size       = "s-1vcpu-1gb"
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = digitalocean_vpc.nfs_vpc.id
  tags       = ["nfs", "client"]
}

resource "null_resource" "nfs_client_setup" {
  depends_on = [
    digitalocean_droplet.nfs_client,
    null_resource.nfs_provisioner
  ]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.nfs_client.ipv4_address_private
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y nfs-common",
      "mkdir -p /mnt/nfs_test",
      "echo '${digitalocean_droplet.nfs_server.ipv4_address_private}:/srv/nfs_share /mnt/nfs_test nfs defaults 0 0' >> /etc/fstab",
      "mount -a",
      "echo 'Hello depuis le client (persistant)' > /mnt/nfs_test/hello_from_client.txt"
    ]
  }
}

# --- VM Monitoring ---
resource "digitalocean_droplet" "monitoring" {
  name       = "monitoring"
  region     = "fra1"
  size       = "s-1vcpu-2gb"
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = digitalocean_vpc.nfs_vpc.id
  tags       = ["monitoring"]
}

resource "null_resource" "monitoring_setup" {
  depends_on = [digitalocean_droplet.monitoring]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.monitoring.ipv4_address_private
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Installation Docker
      "apt update",
      "apt install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt update",
      "apt install -y docker-ce docker-ce-cli containerd.io",

      # Installation docker-compose
      "curl -L \"https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "chmod +x /usr/local/bin/docker-compose",

      # Création des dossiers pour les configs Prometheus et Grafana
      "mkdir -p /opt/monitoring/prometheus",
      "mkdir -p /opt/monitoring/grafana",

      # Création fichier config Prometheus (scraping node_exporter sur nfs-server)
      "echo 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: \"node_exporter\"\n    static_configs:\n      - targets: [\"${digitalocean_droplet.nfs_server.ipv4_address_private}:9100\"]' > /opt/monitoring/prometheus/prometheus.yml",

      # Lancement Prometheus et Grafana via docker-compose
      "echo 'version: \"3\"\nservices:\n  prometheus:\n    image: prom/prometheus:latest\n    volumes:\n      - /opt/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml\n    ports:\n      - \"9090:9090\"\n  grafana:\n    image: grafana/grafana:latest\n    ports:\n      - \"3000:3000\"\n' > /opt/monitoring/docker-compose.yml",

      "cd /opt/monitoring && docker-compose up -d"
    ]
  }
}
