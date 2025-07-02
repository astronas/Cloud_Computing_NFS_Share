variable "do_token" {
  description = "Token API DigitalOcean"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Nom de la clé SSH importée sur DigitalOcean"
  type        = string
}

variable "private_key_path" {
  description = "Chemin local vers la clé privée SSH"
  type        = string
}