variable "location" { type = string }
variable "compute_gallery_rg_name" { type = string }
variable "compute_gallery_name" { type = string }
variable "image_definition_name" { type = string }
variable "managed_identity_name" { type = string }
variable "staging_rg_name" { type = string }
variable "source_publisher" { type = string }
variable "source_offer" { type = string }
variable "source_sku" { type = string }
variable "aib_vm_size" { type = string }
variable "build_timeout_in_minutes" { type = number }
variable "replication_regions" { type = list(string) }
variable "force_rebuild_id" { type = string }
variable "tags" { type = map(string) }
variable "environment" { type = string }

# New variables for dynamic lookup
variable "network_rg_name" { type = string }
variable "vnet_name" { type = string }
variable "subnet_name" { type = string }