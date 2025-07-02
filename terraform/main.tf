provider "digitalocean" {
  token = var.do_token
}

# Recherche du VPC existant par son ID
data "digitalocean_vpc" "existing_nfs_vpc" {
  id = var.vpc_id
}

# Récupération de la clé SSH déjà importée
data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

# Déploiement du serveur NFS
resource "digitalocean_droplet" "nfs_server" {
  name       = "nfs-server"
  region     = var.region
  size       = var.droplet_size
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = data.digitalocean_vpc.existing_nfs_vpc.id
  tags       = ["nfs", "server"]
}

# Configuration automatique du serveur NFS
resource "null_resource" "nfs_provisioner" {
  depends_on = [digitalocean_droplet.nfs_server]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.nfs_server.ipv4_address
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y nfs-kernel-server",
      "mkdir -p /srv/nfs_share",
      "chmod 777 /srv/nfs_share",
      "echo '/srv/nfs_share *(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports",
      "ufw allow from any to any port nfs",
      "systemctl enable nfs-server",
      "systemctl restart nfs-server"
    ]
  }
}

# Déploiement du client NFS
resource "digitalocean_droplet" "nfs_client" {
  name       = "nfs-client"
  region     = var.region
  size       = var.droplet_size
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = data.digitalocean_vpc.existing_nfs_vpc.id
  tags       = ["nfs", "client"]
}

# Configuration automatique du client NFS
resource "null_resource" "nfs_client_setup" {
  depends_on = [digitalocean_droplet.nfs_client, null_resource.nfs_provisioner]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.nfs_client.ipv4_address
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y nfs-common",
      "mkdir -p /mnt/nfs_test",
      # Montage persistant via fstab
      "echo '${digitalocean_droplet.nfs_server.ipv4_address_private}:/srv/nfs_share /mnt/nfs_test nfs defaults 0 0' >> /etc/fstab",
      "mount -a",
      "echo 'Hello depuis le client (persistant)' > /mnt/nfs_test/hello_from_client.txt"
    ]
  }
}

# Déploiement de la VM monitoring (Prometheus + Grafana en Docker)
resource "digitalocean_droplet" "monitoring" {
  name       = "monitoring"
  region     = var.region
  size       = var.droplet_size
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = data.digitalocean_vpc.existing_nfs_vpc.id
  tags       = ["monitoring"]
}

# Installation Docker + lancement Prometheus et Grafana sur la VM monitoring
resource "null_resource" "monitoring_setup" {
  depends_on = [digitalocean_droplet.monitoring]

  connection {
    type        = "ssh"
    host        = digitalocean_droplet.monitoring.ipv4_address
    user        = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
  inline = [
    # Installation Docker (idem)
    "apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common",
    "curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -",
    "add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable\"",
    "apt update && apt install -y docker-ce",
    "systemctl enable docker --now",

    "docker network create monitoring-net || true",

    # Lancement Prometheus
    "docker run -d --name prometheus --network monitoring-net -p 9090:9090 -v /root/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus",

    # Lancement Grafana
    "docker run -d --name grafana --network monitoring-net -p 3000:3000 grafana/grafana"
  ]
}
}