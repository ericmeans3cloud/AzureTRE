variable "tre_id" {
  type        = string
  description = "Unique TRE ID"
}

variable "tre_resource_id" {
  type        = string
  description = "Resource ID"
}

variable "enable_cmk_encryption" {
  type        = bool
  default     = false
  description = "Enable CMK encryption for the workspace"
}

variable "key_store_id" {
  type        = string
  description = "ID of the Key Vault to store CMKs in (only used if enable_cmk_encryption is true)"
}

variable "use_external_identity" {
  type        = bool
  default     = false
  description = "Whether to use a pre-created external user-assigned managed identity (true) or automatically create a user-defined managed identity for the data factory (false). Defaults to false."
}

variable "user_assigned_identity_rg" {
  type        = string
  description = "If use_external_identity is true, the name of the resource group the external user-defined managed identity was created in."
}

variable "user_assigned_identity_name" {
  type        = string
  description = "If use_external_identity is true, the name of the external user-defined managed identity to use."
}