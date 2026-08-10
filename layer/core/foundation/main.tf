terraform {
  required_version = ">= 1.11"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
  # SEM backend remoto — state fica local nesta pasta (é o único layer assim)
}

provider "oci" {
  region = var.region
}

# Bucket para guardar os tfstate de todos os layers seguintes
resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.tenancy_ocid   # direto no compartment raiz, por enquanto
  namespace      = var.object_storage_namespace
  name           = var.state_bucket_name
  versioning     = "Enabled"

  freeform_tags = {
    ManagedBy = "tofu"
    Stack     = "foundation"
  }
}

# Grupo de automação
resource "oci_identity_group" "automation" {
  compartment_id = var.tenancy_ocid
  name           = "grp-automation"
  description    = "Grupo para automação via GitHub Actions"
}

# Usuário de serviço usado pelo CI/CD
resource "oci_identity_user" "automation" {
  compartment_id = var.tenancy_ocid
  name           = "svc-github-actions"
  description    = "Usuário de serviço para OpenTofu via GitHub Actions"
  email          = "svc-github-actions@SEUDOMINIO.com"
}

resource "oci_identity_user_group_membership" "automation" {
  user_id  = oci_identity_user.automation.id
  group_id = oci_identity_group.automation.id
}

# Policy: o grupo pode gerenciar tudo no tenancy (vamos restringir por compartment mais pra frente)
resource "oci_identity_policy" "automation" {
  compartment_id = var.tenancy_ocid
  name           = "policy-automation"
  description    = "Permissões de automação para o grupo grp-automation"
  statements = [
    "Allow group grp-automation to manage all-resources in tenancy"
  ]
}