# --- One-Time Local Environment Setup (Bootstrapper) ---
# Filename: up.ps1
# Hosted at: https://tools.wirelore.com/up.ps1

# 1. Define Local Paths
# We use standard environment variables for maximum compatibility.
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
# This ensures your custom modules persist across sessions.
$currentUserModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$pathParts = $currentUserModulePath -split ';' | Where-Object { $_ }

if ($localModulesDir -notin $pathParts) {
    Write-Host "Adding '$localModulesDir' to your permanent PSModulePath." -ForegroundColor Green
    # Prepend local path so your overrides take precedence over system modules
    $newPath = ($localModulesDir, $pathParts) -join ';'
    [Environment]::SetEnvironmentVariable('PSModulePath', $newPath, 'User')
} else {
    Write-Host "'$localModulesDir' is already in your PSModulePath." -ForegroundColor DarkGray
}

# 4. Profile Shim (The "Bypass")
# We modify the default $PROFILE to simply load our custom local profile.
# This works around Group Policy or OneDrive redirection issues.
$defaultProfileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $defaultProfileDir)) {
    New-Item -Path $defaultProfileDir -ItemType Directory -Force | Out-Null
}

try {
    $loaderContent = "# Bootstrap Loader `n. `"$localProfileFile`""
    Set-Content -Path $PROFILE -Value $loaderContent -Force -ErrorAction Stop
    Write-Host "Loader profile created at: $PROFILE" -ForegroundColor Green
}
catch {
    Write-Warning "Could not write to default profile path ($PROFILE). GPO might be blocking it."
    Write-Warning "You may need to manually add `. `"$localProfileFile`"` to your profile."
}

# 5. Payload Delivery (Downloading the Real Profile)
Write-Host "`nDownloading latest profile configuration..." -ForegroundColor Cyan

# UPDATED: Using your new custom domain
$profileUrl = "https://tools.wirelore.com/profile.ps1"

try {
    # We use -UseBasicParsing for compatibility and 0 for logic checks
    Invoke-WebRequest -Uri $profileUrl -OutFile $localProfileFile -ErrorAction Stop
    Write-Host "Profile successfully downloaded to: $localProfileFile" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download profile from $profileUrl"
    Write-Error "Error: $($_.Exception.Message)"
    # Fallback instruction
    Write-Host "Please ensure 'profile.ps1' exists in your repo root." -ForegroundColor Red
    return
}

# 6. Final Instructions
Write-Host "`nSetup complete!" -ForegroundColor Cyan
Write-Host "Your environment is ready. Reloading profile now..." -ForegroundColor Yellow

# Generate the reload command for the user
$reloadCommand = '. $PROFILE'
Set-Clipboard -Value $reloadCommand

Write-Host "`n--- EXECUTION ---" -ForegroundColor Yellow
Write-Host "I have copied the reload command to your clipboard."
Write-Host "Paste it (Ctrl+V) and hit Enter to start."
Write-Host "-------------------"
