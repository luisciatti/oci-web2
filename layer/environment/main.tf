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
    key                         = "environment/sa-saopaulo-1.tfstate"
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

data "oci_objectstorage_namespace" "ns" {}

resource "oci_objectstorage_bucket" "app_artifacts" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "oci-testhub-app-artifacts"
  access_type    = "NoPublicAccess"

  freeform_tags = {
    ManagedBy = "tofu"
    Stack     = "environment"
  }
}