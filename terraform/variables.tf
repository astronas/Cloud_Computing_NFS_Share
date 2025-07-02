# Token API DigitalOcean pour l'authentification
variable "do_token" {
  description = "Token d'accès API DigitalOcean"
  type        = string
  sensitive   = true
}

# Nom de la clé SSH déjà importée dans DigitalOcean
variable "ssh_key_name" {
  description = "Nom de la clé SSH importée sur DigitalOcean utilisée pour accéder aux droplets"
  type        = string
}

# Chemin local vers la clé privée SSH correspondante à la clé publique DigitalOcean
variable "private_key_path" {
  description = "Chemin vers la clé privée SSH utilisée pour la connexion SSH"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Nom du VPC DigitalOcean existant à utiliser
variable "vpc_name" {
  description = "Nom du VPC DigitalOcean existant à utiliser pour les droplets"
  type        = string
  default     = "nfs-vpc"
}

# Région du VPC et des droplets
variable "region" {
  description = "Région DigitalOcean pour le déploiement"
  type        = string
  default     = "fra1"
}

# Taille des droplets à déployer
variable "droplet_size" {
  description = "Taille des droplets :"
  type        = string
  default     = "s-1vcpu-1gb"
}
