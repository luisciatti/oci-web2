variable "tenancy_ocid" {
  description = "OCID do tenancy"
  type        = string
}

variable "region" {
  description = "Região OCI"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "object_storage_namespace" {
  description = "Namespace do Object Storage (saída de: oci os ns get)"
  type        = string
}

variable "state_bucket_name" {
  description = "Nome do bucket de tfstate"
  type        = string
  default     = "oci-testhub-tfstate"
}