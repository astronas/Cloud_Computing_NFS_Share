provider "digitalocean" {
  token = var.do_token
}

# Réseau privé DigitalOcean (VPC)
resource "digitalocean_vpc" "nfs_vpc" {
  name        = "nfs-vpc"
  region      = "fra1"
  ip_range    = "10.10.0.0/16"
  description = "VPC privé pour le partage NFS"
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
  vpc_uuid   = digitalocean_vpc.nfs_vpc.id
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
      "sudo ufw allow from any ip to any port nfs",
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
  vpc_uuid   = digitalocean_vpc.nfs_vpc.id
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
    # Ajout au fstab pour montage persistant
    "echo '${digitalocean_droplet.nfs_server.ipv4_address_private}:/srv/nfs_share /mnt/nfs_test nfs defaults 0 0' >> /etc/fstab",
    "mount -a",
    "echo 'Hello depuis le client (persistant)' > /mnt/nfs_test/hello_from_client.txt"
  ]
}
}