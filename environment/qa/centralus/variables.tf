subscription_id = "ce2696e6-e6a1-4ef4-8c4c-b5136fd91316"
tenant_id       = "7abd04ef-837d-48e6-9ba8-69d84f65a110"
location        = "centralus"
compute_gallery_rg_name = "qa-centralus-avd-compute-rg"
compute_gallery_name    = "IBAVDCENTRALUSCOMPUTEGALLERY"
managed_identity_name   = "mgmid-aib-image-builder-qa"
staging_rg_name         = "qa-centralus-avd-compute-rg" 
image_definition_name   = "PROD-CENTRAL-WIN11-AVD-25H2"

source_publisher = "microsoftwindowsdesktop"
source_offer     = "office-365"
source_sku       = "win11-25h2-avd-m365"

aib_vm_size              = "Standard_D4as_v5"
build_timeout_in_minutes = 280

subnet_id = "/subscriptions/ce2696e6-e6a1-4ef4-8c4c-b5136fd91316/resourceGroups/qa-centralus-avd-vnet-rg/providers/Microsoft.Network/virtualNetworks/qa-centralus-avd-vnet/subnets/qa-centralus-avd-aib-pool-snet"
environment = "qa"
replication_regions = ["centralus"]
force_rebuild_id    = "2026020501"

tags = {
  AVD_IMAGE_TEMPLATE = "AVD_IMAGE_TEMPLATE"
  Environment        = "QA"
}

