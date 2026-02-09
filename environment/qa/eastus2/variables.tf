variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
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
variable "subnet_id" { type = string }
variable "replication_regions" { type = list(string) }
variable "force_rebuild_id" { type = string }
variable "tags" { type = map(string) }

subscription_id = "ce2696e6-e6a1-4ef4-8c4c-b5136fd91316"
tenant_id       = "7abd04ef-837d-48e6-9ba8-69d84f65a110"
location        = "eastus2"
compute_gallery_rg_name = "qa-eastus2-avd-compute-rg"
compute_gallery_name    = "ibavdcomputegallery"
managed_identity_name   = "mgmid-aib-image-builder-qa"
staging_rg_name         = "qa2-eastus2-avd-compute-rg" 
image_definition_name   = "prod-win11-avd-25h2"

source_publisher = "microsoftwindowsdesktop"
source_offer     = "office-365"
source_sku       = "win11-25h2-avd-m365"

aib_vm_size              = "Standard_D4as_v5"
build_timeout_in_minutes = 280

subnet_id = "/subscriptions/ce2696e6-e6a1-4ef4-8c4c-b5136fd91316/resourceGroups/qa-eastus2-avd-vnet-rg/providers/Microsoft.Network/virtualNetworks/qa-eastus2-avd-vnet/subnets/qa-eastus2-avd-aib-pool-snet"

replication_regions = ["eastus2"]
force_rebuild_id    = "2026020501"

tags = {
  AVD_IMAGE_TEMPLATE = "AVD_IMAGE_TEMPLATE"
  Environment        = "QA"
}

