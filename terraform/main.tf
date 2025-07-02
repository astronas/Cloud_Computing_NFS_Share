provider "digitalocean" {
  token = var.do_token
}

# Récupération du VPC existant par son nom et sa région
data "digitalocean_vpc" "existing_nfs_vpc" {
  name   = "nfs-vpc"
  region = "fra1"
}

# Récupération de la clé SSH déjà importée
data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

# Déploiement du serveur NFS
resource "digitalocean_droplet" "nfs_server" {
  name       = "nfs-server"
  region     = "fra1"
  size       = "s-1vcpu-1gb"
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
  region     = "fra1"
  size       = "s-1vcpu-1gb"
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

# Déploiement de la VM Monitoring (Grafana + Prometheus en Docker)
resource "digitalocean_droplet" "monitoring" {
  name       = "monitoring"
  region     = "fra1"
  size       = "s-1vcpu-1gb"
  image      = "debian-12-x64"
  ssh_keys   = [data.digitalocean_ssh_key.default.id]
  vpc_uuid   = data.digitalocean_vpc.existing_nfs_vpc.id
  tags       = ["monitoring"]
}

# Installation Docker et lancement de Grafana + Prometheus
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
      # Installation Docker
      "apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list",
      "apt update && apt install -y docker-ce docker-ce-cli containerd.io",
      "systemctl enable docker",
      "systemctl start docker",

      # Création du fichier de configuration Prometheus (exemple basique)
      "mkdir -p /opt/prometheus",
      "cat <<EOF > /opt/prometheus/prometheus.yml\n" +
      "global:\n" +
      "  scrape_interval: 15s\n" +
      "scrape_configs:\n" +
      "  - job_name: 'nfs'\n" +
      "    static_configs:\n" +
      "      - targets: ['${digitalocean_droplet.nfs_server.ipv4_address}:9100']\n" +
      "EOF",

      # Lancement Prometheus en Docker
      "docker run -d --name prometheus -p 9090:9090 -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus",

      # Lancement Grafana en Docker
      "docker run -d --name grafana -p 3000:3000 grafana/grafana"
    ]
  }
}
