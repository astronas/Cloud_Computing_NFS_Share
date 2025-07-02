# 🚀 Infrastructure NFS automatisée avec Terraform sur DigitalOcean

Ce projet Terraform permet de déployer **automatiquement une infrastructure NFS** sur DigitalOcean :

- 🌐 Un **réseau privé (VPC)**
- 🖥️ Un **serveur NFS (Debian 12)**
- 💻 Un **client NFS (Debian 12)** dans le même VPC
- 📦 Configuration automatique du **partage NFS**
- 🔁 Montage **persistant** via `/etc/fstab` sur le client

---

## 📁 Arborescence

nfs_terraform/
├── main.tf # Infrastructure principale
├── variables.tf # Variables réutilisables
├── terraform.tfvars # Valeurs de variables sensibles
├── outputs.tf # IPs de sortie
└── README.md # Documentation

---

## 🔐 Prérequis

- ✅ Compte [DigitalOcean](https://cloud.digitalocean.com/)
- ✅ Clé API DigitalOcean
- ✅ Clé SSH importée dans ton compte
- ✅ Terraform installé (`brew install terraform` ou depuis https://terraform.io)

---

## ⚙️ Configuration

### `terraform.tfvars`

```hcl
do_token         = "votre_token_api"
ssh_key_name     = "nom_de_votre_cle_ssh_importee"
private_key_path = "~/.ssh/id_rsa"
