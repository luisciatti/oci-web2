# ---------- Grupos ----------
resource "oci_core_network_security_group" "public" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  vcn_id         = oci_core_vcn.brazil_vcn.id
  display_name   = "nsg-public"
}

resource "oci_core_network_security_group" "private" {
  compartment_id = data.terraform_remote_state.global.outputs.app_compartment_id
  vcn_id         = oci_core_vcn.brazil_vcn.id
  display_name   = "nsg-private"
}

# ---------- Regras do nsg-public: entrada ----------
locals {
  public_ingress_ports = {
    http  = 80
    https = 443
  }
}

resource "oci_core_network_security_group_security_rule" "public_ingress" {
  for_each = local.public_ingress_ports

  network_security_group_id = oci_core_network_security_group.public.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Entrada TCP ${each.value}"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value
      max = each.value
    }
  }
}

# ---------- Regra do nsg-public: saída ----------
resource "oci_core_network_security_group_security_rule" "public_egress" {
  # direction EGRESS, protocol "all", destination 0.0.0.0/0, destination_type "CIDR_BLOCK"
  network_security_group_id = oci_core_network_security_group.public.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}



# ---------- Regras do nsg-private ----------
# 1) INGRESS, protocol "all", origem = CIDR da VCN (você já usou isso na security list)
# 2) INGRESS TCP 6443 e 10250 (use for_each, como no public)
# 3) EGRESS liberado

# ---------- Regras do nsg-private ----------
locals {
  private_ingress_ports = {
    kube_api = 6443
    kubelet  = 10250
  }
}

# 1) Todo tráfego vindo de dentro da VCN
resource "oci_core_network_security_group_security_rule" "private_ingress_vcn" {
  network_security_group_id = oci_core_network_security_group.private.id
  direction                 = "INGRESS"
  protocol                  = "all"
  description               = "Todo tráfego interno da VCN"
  source                    = oci_core_vcn.brazil_vcn.cidr_block    
  source_type               = "CIDR_BLOCK"
}

# 2) Portas do Kubernetes, só de origem interna
resource "oci_core_network_security_group_security_rule" "private_ingress_k8s" {
  for_each = local.private_ingress_ports
  network_security_group_id = oci_core_network_security_group.private.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Entrada TCP ${each.value}"
  source                    = oci_core_vcn.brazil_vcn.cidr_block
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value
      max = each.value
    }
  }
  # mesmo formato do public_ingress, mas:
  #  - o NSG é o private
  #  - a origem é o CIDR da VCN (não 0.0.0.0/0)
}

# 3) Saída liberada
resource "oci_core_network_security_group_security_rule" "private_egress" {
  network_security_group_id = oci_core_network_security_group.private.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}