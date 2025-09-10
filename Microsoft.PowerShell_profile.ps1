<#
.SYNOPSIS
    One-time setup script for Wirelore's PowerShell Profile.
.DESCRIPTION
    This script performs the following actions:
    1. Defines a local, non-redirected path for user modules.
    2. Creates the local 'Custom' module directory.
    3. Downloads the latest 'Custom.psm1' module from its source URL.
    4. Creates/overwrites the PowerShell $PROFILE file, embedding logic
       to fix the PSModulePath on startup for domain-joined machines.
#>

Write-Host "Starting Wirelore's PowerShell profile setup..." -ForegroundColor Cyan
Write-Host "This will overwrite your existing PowerShell profile."

# --- 1. DEFINE PATHS AND URLS ---

# IMPORTANT: This URL must point to YOUR 'Custom.psm1' module file from File 1.
$moduleSourceUrl = "http://www.tinyurl.com/Wirelore" 

# Define the local, non-redirected path for modules.
$localModulePath = Join-Path -Path $env:USERPROFILE -ChildPath "PowerShell\Modules"
$customModuleFullPath = Join-Path -Path $localModulePath -ChildPath "Custom"
$moduleFilePath = Join-Path -Path $customModuleFullPath -ChildPath "Custom.psm1"


# --- 2. CREATE DIRECTORY AND DOWNLOAD MODULE ---

Write-Host "Ensuring local module directory exists at '$customModuleFullPath'..."
New-Item -ItemType Directory -Path $customModuleFullPath -Force | Out-Null

Write-Host "Downloading custom module from '$moduleSourceUrl'..."
try {
    Invoke-RestMethod -Uri $moduleSourceUrl -OutFile $moduleFilePath
    Write-Host "Successfully saved Custom.psm1 module." -ForegroundColor Green
}
catch {
    Write-Error "FATAL: Failed to download module from '$moduleSourceUrl'. Please check the URL and your internet connection."
    return
}


# --- 3. CREATE THE ACTUAL $PROFILE SCRIPT ---

# This is the content that will be written to the user's Microsoft.PowerShell_profile.ps1 file.
# It includes the CRITICAL fix for folder-redirection environments.
$profileContent = @"
# Wirelore's PowerShell Profile (Generated on $(Get-Date))

# --- Correct PSModulePath for Domain Environments ---
# This ensures local modules are prioritized over redirected network paths.
\$LocalModulePath = Join-Path -Path \$env:USERPROFILE -ChildPath "PowerShell\Modules"
if (\$env:PSModulePath -notlike "\$ (\$LocalModulePath);*") {
    \$env:PSModulePath = "\$ (\$LocalModulePath);\$ (\$env:PSModulePath)"
}

# --- Load Customizations ---
# Import the custom module with all personal functions and aliases.
# The -Force flag ensures the latest version is loaded in your session.
Import-Module -Name Custom -Force
"@

Write-Host "Creating/overwriting PowerShell profile at '$PROFILE'..."

# Ensure the profile's parent directory exists
$profileDir = Split-Path -Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Use Out-File to set the profile content, overwriting any existing file.
$profileContent | Out-File -FilePath $PROFILE -Encoding utf8 -Force


# --- 4. FINAL INSTRUCTIONS ---
Write-Host "----------------------------------------------------------------" -ForegroundColor Green
Write-Host "SUCCESS: Profile setup is complete." -ForegroundColor Green
Write-Host "Please close and reopen your PowerShell terminal to see the changes."
Write-Host "----------------------------------------------------------------"
