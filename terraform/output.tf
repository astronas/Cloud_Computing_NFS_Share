output "nfs_server_public_ip" {
  value       = digitalocean_droplet.nfs_server.ipv4_address
  description = "Adresse IP publique du serveur NFS"
}

output "nfs_server_private_ip" {
  value       = digitalocean_droplet.nfs_server.ipv4_address_private
  description = "Adresse IP privée du serveur NFS"
}

output "nfs_client_public_ip" {
  value       = digitalocean_droplet.nfs_client.ipv4_address
  description = "Adresse IP publique du client NFS"
}
output "nfs_client_private_ip" {
  value       = digitalocean_droplet.nfs_client.ipv4_address_private
  description = "Adresse IP privée du client NFS"
}