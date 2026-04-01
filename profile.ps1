# --- PowerShell Profile ---
# Filename: profile.ps1 (Renamed in Repo)
# Local Path: ...\PowerShell\Microsoft.PowerShell_profile.ps1
# Version: 2026-04-01

# 1. UX Configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{
    InlinePrediction = 'DarkGray'
    ListPrediction   = 'DarkGray'
}

# 2. Dependency Management
# We check for these modules but only install if absolutely missing.
$requiredModules = @('Terminal-Icons', 'PSAISUITE') 

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Dependency '$module' missing. Installing..." -ForegroundColor Yellow
        try {
            # Installing to CurrentUser scope avoids Admin requirement
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to install '$module'. Some features may be broken."
        }
    }
}

# 3. Import Standard Modules
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
Import-Module -Name PSAISUITE -ErrorAction SilentlyContinue

# 4. Custom Module Bootstrapping
$customModuleDir  = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Modules\Custom'
$customModuleFile = Join-Path -Path $customModuleDir -ChildPath 'Custom.psm1'

# UPDATED: Pointing to your clean Custom Domain
$customModuleUrl  = "https://tools.wirelore.com/custom.psm1"

# Function to handle the update logic
function Update-CustomModule {
    Write-Host "Updating Custom module..." -ForegroundColor Cyan
    try {
        if (-not (Test-Path $customModuleDir)) { New-Item -Path $customModuleDir -ItemType Directory -Force | Out-Null }
        
        # Download new version
        Invoke-WebRequest -Uri $customModuleUrl -OutFile $customModuleFile -ErrorAction Stop
        
        # Force reload
        Import-Module -Name $customModuleFile -Force -DisableNameChecking -ErrorAction Stop
        Write-Host "Custom module updated and reloaded." -ForegroundColor Green
    }
    catch {
        Write-Warning "Update failed. Server might be unreachable."
        Write-Warning "Error: $($_.Exception.Message)"
    }
}

# Check if module exists locally
if (Test-Path -Path $customModuleFile) {
    # Import local version
    try {
        Import-Module -Name $customModuleFile -DisableNameChecking -ErrorAction Stop
        # Optional: Uncomment the next line if you want to auto-update on EVERY launch (adds latency)
        # Update-CustomModule 
    }
    catch {
        Write-Warning "Local Custom module is corrupt. Re-downloading..."
        Update-CustomModule
    }
}
else {
    # First run download
    Write-Host "Custom module not found. Initializing..." -ForegroundColor Yellow
    Update-CustomModule
}

Write-Host "Wirelore Environment Loaded." -ForegroundColor Green
