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

variable "ssh_key_name_secondary_1" {
  description = "Nom de la deuxième clé SSH importée dans DigitalOcean"
  type        = string
}

variable "ssh_key_name_secondary_2" {
  description = "Nom de la troisième clé SSH importée dans DigitalOcean"
  type        = string
}

# Chemin local vers la clé privée SSH correspondante à la clé publique DigitalOcean
variable "private_key_path" {
  description = "Chemin vers la clé privée SSH utilisée pour la connexion SSH"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "vpc_id" {
  description = "ID du VPC DigitalOcean existant"
  type        = string
}

variable "region" {
  description = "Région DigitalOcean pour le déploiement"
  type        = string
  default     = "fra1"
}

variable "droplet_size" {
  description = "Taille des droplets"
  type        = string
  default     = "s-1vcpu-1gb"
}