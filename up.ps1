# --- One-Time Local Environment Setup (Bootstrapper) ---
# Filename: up.ps1
# Hosted at: https://tools.wirelore.com/up.ps1

# 1. Define Local Paths
$localPowerShellDir = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell'
$localModulesDir    = Join-Path -Path $localPowerShellDir -ChildPath 'Modules'
$localProfileFile   = Join-Path -Path $localPowerShellDir -ChildPath 'Microsoft.PowerShell_profile.ps1'

# 2. Infrastructure Checks & Creation
$directoriesToCreate = @($localPowerShellDir, $localModulesDir)

foreach ($dir in $directoriesToCreate) {
    if (-not (Test-Path -Path $dir)) {
        Write-Host "Creating directory: $dir" -ForegroundColor Green
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# 3. PSModulePath Injection
$currentUserModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$pathParts = $currentUserModulePath -split ';' | Where-Object { $_ }

if ($localModulesDir -notin $pathParts) {
    Write-Host "Adding '$localModulesDir' to your permanent PSModulePath." -ForegroundColor Green
    $newPath = ($localModulesDir, $pathParts) -join ';'
    [Environment]::SetEnvironmentVariable('PSModulePath', $newPath, 'User')
} else {
    Write-Host "'$localModulesDir' is already in your PSModulePath." -ForegroundColor DarkGray
}

# 4. Payload Delivery (download BEFORE writing the shim)
Write-Host "`nDownloading latest profile configuration..." -ForegroundColor Cyan
$profileUrl = "https://tools.wirelore.com/profile.ps1"

try {
    Invoke-WebRequest -Uri $profileUrl -OutFile $localProfileFile -ErrorAction Stop
    Write-Host "Profile successfully downloaded to: $localProfileFile" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download profile from $profileUrl"
    Write-Error "Error: $($_.Exception.Message)"
    Write-Host "Aborting setup — no changes were made to `$PROFILE." -ForegroundColor Red
    return
}

# 5. Profile Shim (The "Bypass")
# Only written AFTER a successful download so we never point at a missing file.
# Backs up any existing profile content that isn't already our shim.
$defaultProfileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $defaultProfileDir)) {
    New-Item -Path $defaultProfileDir -ItemType Directory -Force | Out-Null
}

if ((Test-Path $PROFILE) -and (Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue) -notmatch 'Bootstrap Loader') {
    Copy-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force
    Write-Host "Existing profile backed up to: $PROFILE.bak" -ForegroundColor Yellow
}

try {
    $loaderContent = "# Bootstrap Loader `n. `"$localProfileFile`""
    Set-Content -Path $PROFILE -Value $loaderContent -Force -ErrorAction Stop
    Write-Host "Loader shim created at: $PROFILE" -ForegroundColor Green
}
catch {
    Write-Warning "Could not write to default profile path ($PROFILE). GPO might be blocking it."
    Write-Warning "You may need to manually add `. `"$localProfileFile`"` to your profile."
}

# 6. Reload
Write-Host "`nSetup complete! Reloading profile..." -ForegroundColor Cyan
. $PROFILE
