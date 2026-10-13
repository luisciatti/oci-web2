terraform {
  required_version = ">= 1.11"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }

  backend "s3" {
    bucket                      = "oci-testhub-tfstate"
    key                         = "database/sa-saopaulo-1.tfstate"
    region                      = "sa-saopaulo-1"
    endpoint                    = "https://gr3fdhs5ybbf.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    skip_s3_checksum            = true
  }
}

provider "oci" {
  region = var.region
}

variable "region" {
  description = "Regiao OCI"
  type        = string
  default     = "sa-saopaulo-1"
}

# ---------- Leitura das outras layers ----------
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket                      = "oci-testhub-tfstate"
    key                         = "core/global/sa-saopaulo-1.tfstate"
    region                      = "sa-saopaulo-1"
    endpoint                    = "https://gr3fdhs5ybbf.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    skip_s3_checksum            = true
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket                      = "oci-testhub-tfstate"
    key                         = "core/network/sa-saopaulo-1.tfstate"
    region                      = "sa-saopaulo-1"
    endpoint                    = "https://gr3fdhs5ybbf.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    skip_s3_checksum            = true
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket                      = "oci-testhub-tfstate"
    key                         = "core/security/sa-saopaulo-1.tfstate"
    region                      = "sa-saopaulo-1"
    endpoint                    = "https://gr3fdhs5ybbf.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    skip_s3_checksum            = true
  }
}

# ---------- Atalhos e dados auxiliares ----------
locals {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  subnet_id      = data.terraform_remote_state.network.outputs.private_subnet_id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
}

# Senha de admin guardada no Vault (layer security), decodificada de base64
data "oci_secrets_secretbundle" "db_admin" {
  secret_id = data.terraform_remote_state.security.outputs.db_admin_secret_id
}

locals {
  db_admin_password = sensitive(base64decode(data.oci_secrets_secretbundle.db_admin.secret_bundle_content[0].content))
}

# ---------- Banco: HeatWave MySQL Always Free ----------
resource "oci_mysql_mysql_db_system" "main" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_id
  subnet_id           = local.subnet_id
  # Pontos de custo: nao altere sem conferir
  shape_name              = "MySQL.Free"
  data_storage_size_in_gb = 50
  is_highly_available     = false

  display_name   = "mysql-app"
  admin_username = "dbadmin"
  admin_password = local.db_admin_password

  freeform_tags = {
    ManagedBy = "tofu"
    Stack     = "database"
  }
}