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
.NOTES
    Ensure you have an active internet connection and the correct URL for the Custom.psm1 module.
    Run this script with administrative privileges if profile creation requires elevated access.
#>
# --- Initialize ---
Write-Host "Starting Wirelore's PowerShell profile setup..." -ForegroundColor Cyan
Write-Host "WARNING: This will overwrite your existing PowerShell profile." -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (Y/N)"
if ($confirmation -notmatch '^[Yy]$') {
    Write-Host "Setup aborted by user." -ForegroundColor Red
    return
}

# --- 1. Define Paths and URLs ---
$moduleSourceUrl = "http://www.tinyurl.com/Wirelore"
$localModulePath = Join-Path -Path $env:USERPROFILE -ChildPath "PowerShell\Modules"
$customModuleFullPath = Join-Path -Path $localModulePath -ChildPath "Custom"
$moduleFilePath = Join-Path -Path $customModuleFullPath -ChildPath "Custom.psm1"

# --- 2. Create Directory and Download Module ---
Write-Host "Ensuring local module directory exists at '$customModuleFullPath'..."
try {
    New-Item -ItemType Directory -Path $customModuleFullPath -Force -ErrorAction Stop | Out-Null
    Write-Host "Module directory created successfully." -ForegroundColor Green
}
catch {
    Write-Error "FATAL: Failed to create directory '$customModuleFullPath'. Error: $($_.Exception.Message)"
    return
}

Write-Host "Downloading custom module from '$moduleSourceUrl'..."
try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($moduleSourceUrl, $moduleFilePath)
    Write-Host "Successfully downloaded and saved Custom.psm1 module." -ForegroundColor Green
}
catch {
    Write-Error "FATAL: Failed to download module from '$moduleSourceUrl'. Error: $($_.Exception.Message)"
    return
}

# Validate the downloaded module file
if (-not (Test-Path -Path $moduleFilePath)) {
    Write-Error "FATAL: Module file was not created at '$moduleFilePath'. Setup cannot continue."
    return
}

# --- 3. Create the PowerShell $PROFILE Script ---
# Use a here-string with proper escaping for UNC paths and special characters
$profileContent = @"
# Wirelore's PowerShell Profile (Generated on $(Get-Date))
# --- Correct PSModulePath for Domain Environments ---
# This ensures local modules are prioritized over redirected network paths.
`$LocalModulePath = '$($localModulePath.Replace('\', '\\'))'
if (`$env:PSModulePath -notlike \"*`$LocalModulePath;*\") {
    `$env:PSModulePath = \"`$LocalModulePath;`$(`$env:PSModulePath)\"
}

# --- Load Customizations ---
# Import the custom module with all personal functions and aliases.
try {
    Import-Module -Name Custom -Force -ErrorAction Stop
}
catch {
    Write-Warning \"Failed to import Custom module: `$(`$_.Exception.Message)\"
}
"@

# Validate profile content syntax before writing
Write-Host "Validating profile content syntax..."
try {
    $null = [ScriptBlock]::Create($profileContent)
    Write-Host "Profile content syntax is valid." -ForegroundColor Green
}
catch {
    Write-Error "FATAL: Profile content contains syntax errors: $($_.Exception.Message)"
    return
}

# Write the profile content
Write-Host "Creating/overwriting PowerShell profile at '$PROFILE'..."
try {
    $profileDir = Split-Path -Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop | Out-Null
    }
    $profileContent | Out-File -FilePath $PROFILE -Encoding utf8 -Force -ErrorAction Stop
    Write-Host "PowerShell profile created successfully." -ForegroundColor Green
}
catch {
    Write-Error "FATAL: Failed to create profile at '$PROFILE'. Error: $($_.Exception.Message)"
    return
}

# --- 4. Final Instructions ---
Write-Host "----------------------------------------------------------------" -ForegroundColor Green
Write-Host "SUCCESS: Profile setup is complete." -ForegroundColor Green
Write-Host "Please close and reopen your PowerShell terminal to apply the changes."
Write-Host "To verify, check that the 'Custom' module loads in a new session."
Write-Host "If the error persists, check the profile file at '$PROFILE' for syntax issues."
Write-Host "----------------------------------------------------------------" -ForegroundColor Green

