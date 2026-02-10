location                = "eastus2"
compute_gallery_rg_name = "qa-eastus2-avd-compute-rg"
compute_gallery_name    = "ibavdcomputegallery"
managed_identity_name   = "mgmid-aib-image-builder-qa"
staging_rg_name         = "qa-eastus2-avd-compute-rg" 
image_definition_name   = "prod-win11-avd-25h2"
source_publisher        = "microsoftwindowsdesktop"
source_offer            = "office-365"
source_sku              = "win11-25h2-avd-m365"
aib_vm_size             = "Standard_D4as_v5"
build_timeout_in_minutes = 280
environment             = "qa"
replication_regions     = ["eastus2"]
force_rebuild_id        = "2026020501"
network_rg_name         = "qa-eastus2-avd-vnet-rg"
vnet_name               = "qa-eastus2-avd-vnet"
subnet_name             = "qa-eastus2-avd-aib-pool-snet"

tags = {
  AVD_IMAGE_TEMPLATE = "AVD_IMAGE_TEMPLATE"
  Environment        = "QA"
}