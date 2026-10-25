output "dynamic_group_id" {
  description = "OCID do grupo dinamico da VM da aplicacao"
  value       = oci_identity_dynamic_group.app_vm.id
}

output "dynamic_group_name" {
  description = "Nome do grupo dinamico (usado nas politicas)"
  value       = oci_identity_dynamic_group.app_vm.name
}

output "policy_id" {
  description = "OCID da politica que permite a VM ler os segredos do app"
  value       = oci_identity_policy.app_vm_secrets.id
}
output "instance_id" {
  description = "OCID da instancia da VM da aplicacao"
  value       = oci_core_instance.app.id
}

output "private_ip" {
  description = "IP privado da instancia da VM da aplicacao"
  value       = oci_core_instance.app.private_ip
}

output "vm_private_ip" {
  description = "IP privado da instancia da VM da aplicacao"
  value       = oci_core_instance.app.private_ip
}