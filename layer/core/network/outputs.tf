//var "region" (mesmo padrão das outras layers)

output "vcn_id" {
  description = "O OCID da VCN"
  value       = oci_core_vcn.brazil_vcn.id
}

output "public_subnet_id" {
  description = "O OCID da sub-rede pública"
  value       = oci_core_subnet.brazil_subnet_public.id
}

output "private_subnet_id" {
  description = "O OCID da sub-rede privada"
  value       = oci_core_subnet.brazil_subnet_private.id
}

output "service_gateway_id" {
  description = "O OCID do Service Gateway"
  value       = oci_core_service_gateway.main.id
}