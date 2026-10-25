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
    key                         = "application/edge/sa-saopaulo-1.tfstate"
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
  type    = string
  default = "sa-saopaulo-1"
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

data "terraform_remote_state" "appvm" {
  backend = "s3"
  config = {
    bucket                      = "oci-testhub-tfstate"
    key                         = "application/appvm/sa-saopaulo-1.tfstate"
    region                      = "sa-saopaulo-1"
    endpoint                    = "https://gr3fdhs5ybbf.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    skip_s3_checksum            = true
  }
}

locals {
  portas = {
    http  = 80
    https = 443
  }
}

resource "oci_network_load_balancer_network_load_balancer" "main" {
  compartment_id             = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name               = "nlb-main"
  subnet_id                  = data.terraform_remote_state.network.outputs.public_subnet_id
  is_private                 = false
  network_security_group_ids = [data.terraform_remote_state.network.outputs.nsg_public_id]

  freeform_tags = {
    ManagedBy = "tofu"
    Stack     = "edge"
  }
}

resource "oci_network_load_balancer_backend_set" "web" {
  for_each = local.portas

  name                     = "bs-${each.key}"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol = "TCP"
    port     = each.value
  }
}

resource "oci_network_load_balancer_backend" "vm" {
  for_each = local.portas

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main.id
  backend_set_name         = oci_network_load_balancer_backend_set.web[each.key].name
  port                     = each.value
  ip_address               = data.terraform_remote_state.appvm.outputs.vm_private_ip
}

resource "oci_network_load_balancer_listener" "web" {
  for_each = local.portas

  name                     = "ls-${each.key}"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main.id
  default_backend_set_name = oci_network_load_balancer_backend_set.web[each.key].name
  port                     = each.value
  protocol                 = "TCP"
}

output "nlb_public_ip" {
  description = "IP publico do NLB (registro A no DNS)"
  value       = oci_network_load_balancer_network_load_balancer.main.ip_addresses[0].ip_address
}