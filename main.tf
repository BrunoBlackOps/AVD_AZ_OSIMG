terraform {
  required_version = ">= 1.6.0"
 /* backend "azurerm" {
    resource_group_name  = "qa-eastus2-avd-artifacts-storage-rg"
    storage_account_name = "stquea2avdartifacts"
    container_name       = "avdartifacts-blob-container"
    key                  = "aib.tfstate"
  }*/
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
    azapi   = { source = "azure/azapi"}
    random  = { source = "hashicorp/random"}
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Data Sources
data "azurerm_resource_group" "compute_gallery_rg" {
  name = var.compute_gallery_rg_name
}

data "azurerm_resource_group" "staging_rg" {
  name = var.staging_rg_name
}

data "azurerm_user_assigned_identity" "avd_identity" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.compute_gallery_rg.name
}

data "azurerm_shared_image" "win11_def" {
  name                = var.image_definition_name
  gallery_name        = var.compute_gallery_name
  resource_group_name = data.azurerm_resource_group.compute_gallery_rg.name
}

# Resources
resource "random_id" "aib_run_trigger" {
  byte_length = 2
  keepers     = { key = coalesce(var.force_rebuild_id, "initial") }
}

resource "azapi_resource" "aib_template" {
  type      = "Microsoft.VirtualMachineImages/imageTemplates@2024-02-01"
  name      = "Aib2026v5GitLab"
  # This points to qa2-eastus2-avd-compute-rg via the data source
  parent_id = data.azurerm_resource_group.staging_rg.id 
  location  = var.location
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.avd_identity.id]
  }

  body = {
    properties = {
      buildTimeoutInMinutes = var.build_timeout_in_minutes
      vmProfile = {
        vmSize       = var.aib_vm_size
        osDiskSizeGB = 127
        vnetConfig = {
          subnetId = var.subnet_id
        }
      }
      source = {
        type      = "PlatformImage"
        publisher = var.source_publisher
        offer     = var.source_offer
        sku       = var.source_sku
        version   = "latest"
      }
      customize = [
        {
          type        = "PowerShell"
          name        = "SetupDirectories"
          runElevated = true
          runAsSystem = true
          inline = [
            "$ErrorActionPreference = 'Stop'",
            "New-Item -ItemType Directory -Path C:\\Windows\\admin\\Scripts -Force | Out-Null",
            "New-Item -ItemType Directory -Path C:\\Windows\\admin\\Custom -Force | Out-Null",
            "New-Item -ItemType Directory -Path C:\\Windows\\admin\\Logs -Force | Out-Null"
          ]
        },
        {
          type        = "PowerShell"
          name        = "DownloadAndExtractCustomFiles"
          runElevated = true
          runAsSystem = true
          inline = [
            "Write-Host 'Downloading Custom.zip from Nexus...' -ForegroundColor Cyan",
            "$destDir = 'C:\\windows\\admin\\Custom'",
            "$zipFile = 'C:\\windows\\admin\\Custom\\Custom.zip'",
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/Custom.zip' -OutFile $zipFile -UseBasicParsing",
            "Write-Host 'Extracting files...' -ForegroundColor Cyan",
            "Expand-Archive -Path $zipFile -DestinationPath $destDir -Force",
            "Remove-Item -Path $zipFile -Force"
          ]
        },
        {
          type        = "PowerShell"
          name        = "MasterConfiguration"
          runElevated = true
          runAsSystem = true
          inline = [
            "Write-Host 'Applying Master Image configurations...' -ForegroundColor Cyan",
            "$ErrorActionPreference = 'SilentlyContinue'",
            "Add-LocalGroupMember -Group 'FSLogix Profile Exclude List' -Member 'Administrators', 'S-1-5-113'",
            "Get-ChildItem 'C:\\windows\\admin\\Custom\\*.crt' | ForEach-Object { Import-Certificate -FilePath $_.FullName -CertStoreLocation 'Cert:\\LocalMachine\\Root' }",
            "$reg = @(",
            "  @{ P='SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System'; N='Wallpaper'; V='C:\\windows\\admin\\Custom\\IBKR_Desktop_Black.png'; T='String' },",
            "  @{ P='SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System'; N='WallpaperStyle'; V='10'; T='String' },",
            "  @{ P='SYSTEM\\CurrentControlSet\\Services\\wuauserv'; N='Start'; V=4; T='DWord' }",
            ")",
            "foreach ($S in $reg) { $fp = 'HKLM:\\' + $S.P; if (!(Test-Path $fp)) { New-Item $fp -Force | Out-Null }; Set-ItemProperty -Path $fp -Name $S.N -Value $S.V -Type $S.T -Force }",
            "exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "ImportIntunePolicies"
          runElevated = true
          runAsSystem = true
          inline = [
            "Write-Host 'Importing Intune Registry Policies...' -ForegroundColor Cyan",
            "$regFile = 'C:\\windows\\admin\\Scripts\\EASTINTUNEPolicies.reg'",
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/EASTINTUNEPolicies.reg' -OutFile $regFile -UseBasicParsing",
            "reg import $regFile",
            "exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "FSLogixKerberos"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/FSLogixKerberos.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\FSLogixKerberos.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\FSLogixKerberos.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "MissingConfigs"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/MissingConfigs.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\MissingConfigs.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\MissingConfigs.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "DisableStorageSense"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/DisableStorageSense.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\DisableStorageSense.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\DisableStorageSense.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "TimezoneRedirection"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/TimezoneRedirection.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\TimezoneRedirection.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\TimezoneRedirection.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "RdpShortpath"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/RDPShortpath.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\RDPShortpath.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\RDPShortpath.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "SessionTimeouts"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/ConfigureSessionTimeoutsV2.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\ConfigureSessionTimeouts.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\ConfigureSessionTimeouts.ps1' -ArgumentList '-MaxDisconnectionTime 15 -MaxIdleTime 360 -MaxConnectionTime 960 -RemoteAppLogoffTimeLimit 360'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "EnforceUDPShortPath"
          runElevated = true
          runAsSystem = true
          inline      = ["C:\\windows\\admin\\Custom\\EnforceUDPShortPath.ps1"]
        },
        {
          type        = "PowerShell"
          name        = "WindowsOptimization"
          runElevated = true
          runAsSystem = true
          inline      = ["C:\\windows\\admin\\Custom\\WindowsOptimization.ps1 -Optimizations \"RemoveOneDrive\",\"Edge\",\"DiskCleanup\",\"LGPO\",\"NetworkOptimizations\",\"Services\",\"Autologgers\",\"DefaultUserSettings\",\"ScheduledTasks\""]
        },
        {
          type           = "WindowsRestart"
          name           = "Restart-Main"
          restartTimeout = "5m"
        },
        {
          type        = "PowerShell"
          name        = "DisableAutoUpdates"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/DisableAutoUpdates.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\DisableAutoUpdates.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\DisableAutoUpdates.ps1'; exit 0"
          ]
        },
        {
          type        = "PowerShell"
          name        = "RemoveAppxPackages"
          runElevated = true
          runAsSystem = true
          inline      = ["C:\\windows\\admin\\Custom\\removeAppxPackages.ps1 -AppxPackages \"Clipchamp.Clipchamp\",\"Microsoft.BingNews\",\"Microsoft.BingWeather\",\"Microsoft.GamingApp\",\"Microsoft.GetHelp\",\"Microsoft.MicrosoftSolitaireCollection\",\"Microsoft.Getstarted\",\"Microsoft.MicrosoftOfficeHub\",\"Microsoft.People\",\"Microsoft.SkypeApp\",\"Microsoft.WindowsFeedbackHub\",\"Microsoft.windowscommunicationsapps\",\"Microsoft.WindowsMaps\",\"Microsoft.XboxGameOverlay\",\"Microsoft.XboxGamingOverlay\",\"Microsoft.XboxIdentityProvider\",\"Microsoft.XboxSpeechToTextOverlay\",\"Microsoft.YourPhone\",\"Microsoft.ZuneMusic\",\"Microsoft.ZuneVideo\",\"Microsoft.XboxApp\""]
        },
        {
          type        = "PowerShell"
          name        = "Cleanup"
          runElevated = true
          runAsSystem = true
          inline      = ["Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue; exit 0"]
        },
        {
          type        = "PowerShell"
          name        = "AdminSysPrep"
          runElevated = true
          runAsSystem = true
          inline = [
            "Invoke-WebRequest -Uri 'https://nexus.prod.ibkr-int.com/repository/raw/ibkr/avd/aib/AdminSysPrep.ps1' -OutFile 'C:\\Windows\\admin\\Scripts\\AdminSysPrep.ps1' -UseBasicParsing",
            "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Windows\\admin\\Scripts\\AdminSysPrep.ps1'; exit 0"
          ]
        }
      ]
      distribute = [
        {
          type               = "SharedImage"
          runOutputName      = "aib-qa-run"
          galleryImageId     = data.azurerm_shared_image.win11_def.id
          replicationRegions = ["eastus2"]
          excludeFromLatest  = false  
          artifactTags       = { BuildBy = "AIB", Environment = "QA" }
        }
      ]
    } 
  } 
}

resource "azapi_resource_action" "aib_run" {
  type        = "Microsoft.VirtualMachineImages/imageTemplates@2024-02-01"
  resource_id = azapi_resource.aib_template.id
  action      = "run"
  method      = "POST"
  timeouts {
    create = "${var.build_timeout_in_minutes}m"
  }
  lifecycle {
    replace_triggered_by = [random_id.aib_run_trigger.hex]
  }
}