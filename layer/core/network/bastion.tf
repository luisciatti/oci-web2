variable "bastion_allowed_cidrs" {
  description = "CIDRs autorizados a abrir sessões no Bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

resource "oci_bastion_bastion" "main" {
  bastion_type     = "STANDARD"
  compartment_id   = data.terraform_remote_state.global.outputs.app_compartment_id
  target_subnet_id = oci_core_subnet.brazil_subnet_private.id
  name             = "bastionapp"

  client_cidr_block_allow_list = var.bastion_allowed_cidrs
  max_session_ttl_in_seconds   = 10800
}