output "state_bucket_name" {
  value = oci_objectstorage_bucket.tfstate.name
}

output "object_storage_namespace" {
  value = var.object_storage_namespace
}

output "automation_user_ocid" {
  value = oci_identity_user.automation.id
}