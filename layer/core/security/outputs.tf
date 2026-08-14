output "vault_id" {
  value = oci_kms_vault.main.id
}

output "vault_management_endpoint" {
  value = oci_kms_vault.main.management_endpoint
}

output "key_id" {
  value = oci_kms_key.app.id
}