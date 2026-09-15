//terraform{} + provider + remote_state do global + os resources
terraform {
	required_version = ">= 1.11"
	required_providers {
		oci = {
			source  = "oracle/oci"
			version = "~> 8.0"
		}
		 random = {
     	    source  = "hashicorp/random"
      		version = "~> 3.6"
    	}
		}
	

	backend "s3" {
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

provider "oci" {
  region = var.region
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

resource "oci_core_vcn" "brazil_vcn" {
  cidr_block = "10.0.0.0/16"
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_vcn"
}


resource "oci_core_internet_gateway" "brazil_ig" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_ig"
  vcn_id = oci_core_vcn.brazil_vcn.id
}

resource "oci_core_nat_gateway" "brazil_nat" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_nat"
  vcn_id = oci_core_vcn.brazil_vcn.id
}

resource "oci_core_route_table" "brazil_rt_public" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_rt_public"
  vcn_id = oci_core_vcn.brazil_vcn.id
  route_rules {
    destination = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.brazil_ig.id
  }
}

resource "oci_core_route_table" "brazil_rt_private" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_rt_private"
  vcn_id = oci_core_vcn.brazil_vcn.id
  route_rules {
    destination = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.brazil_nat.id
  }
  route_rules {
  destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
  destination_type  = "SERVICE_CIDR_BLOCK"
  network_entity_id = oci_core_service_gateway.main.id
}
}

resource "oci_core_security_list" "brazil_sl_public" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_sl_public"
  vcn_id = oci_core_vcn.brazil_vcn.id

  ingress_security_rules {
    protocol = "6" # TCP
    source = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  egress_security_rules {
    protocol = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "brazil_sl_private" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_sl_private"
  vcn_id = oci_core_vcn.brazil_vcn.id

  ingress_security_rules {
    protocol = "all"
    source = oci_core_vcn.brazil_vcn.cidr_block
  }
  egress_security_rules {
    protocol = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "brazil_subnet_public" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_subnet_public"
  vcn_id = oci_core_vcn.brazil_vcn.id
  cidr_block = "10.0.1.0/24"
  route_table_id = oci_core_route_table.brazil_rt_public.id
  security_list_ids = [oci_core_security_list.brazil_sl_public.id]
}

resource "oci_core_subnet" "brazil_subnet_private" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  display_name = "brazil_subnet_private"
  vcn_id = oci_core_vcn.brazil_vcn.id
  cidr_block = "10.0.2.0/24"
  route_table_id = oci_core_route_table.brazil_rt_private.id
  security_list_ids = [oci_core_security_list.brazil_sl_private.id]
  prohibit_public_ip_on_vnic = true 
}

data "oci_core_services" "all_oci_services" {}

resource "oci_core_service_gateway" "main" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  vcn_id         = oci_core_vcn.brazil_vcn.id
  display_name   = "sgw-network"

  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
}


