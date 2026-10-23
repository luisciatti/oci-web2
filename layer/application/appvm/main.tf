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

provider "oci" {
  region = var.region
}

variable "region" {
  type    = string
  default = "sa-saopaulo-1"
}

variable "tenancy_ocid" {
  type = string
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

locals {
  compartment_id   = data.terraform_remote_state.global.outputs.app_compartment_id
  jwt_secret_id    = data.terraform_remote_state.security.outputs.jwt_secret_id
  db_app_secret_id = data.terraform_remote_state.security.outputs.db_app_secret_id
}

resource "oci_identity_dynamic_group" "app_vm" {
  compartment_id = var.tenancy_ocid        
  name           = "dg-app-vm"
  description    = "Instancias da aplicacao no cmp-app"
  matching_rule  = "ALL {instance.compartment.id = '${local.compartment_id}'}"   
}

resource "oci_identity_policy" "app_vm_secrets" {
  compartment_id = var.tenancy_ocid          
  name           = "policy-app-vm-secrets"
  description    = "A VM da aplicacao le somente os segredos do app"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.app_vm.name} to read secret-bundles in compartment id ${local.compartment_id} where any {target.secret.id = '${local.jwt_secret_id}', target.secret.id = '${local.db_app_secret_id}'}"  
  ]
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
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

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
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

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  image_tag      = "sha-53c8ca4" 
  ssh_public_key = file("~/.ssh/bastion_key.pub")
}

resource "oci_core_instance" "app" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_id
  display_name        = "vm-app"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = data.terraform_remote_state.network.outputs.private_subnet_id
    assign_public_ip = false
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
      db_host       = data.terraform_remote_state.database.outputs.db_private_ip
      db_secret_id  = local.db_app_secret_id
      jwt_secret_id = local.jwt_secret_id
      image         = "ghcr.io/luisciatti/web2-backend:${local.image_tag}"
    }))
  }

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  freeform_tags = {
    ManagedBy = "tofu"
    Stack     = "appvm"
  }
}