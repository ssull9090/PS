# --- PowerShell Profile ---

# 1. Set PSReadLine options for a better command-line experience.
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# 2. Check for and install required modules if they are missing.
$requiredModules = @('Terminal-Icons', 'PowerShellAI') # PowerShellAI contains Invoke-ChatCompletion
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
        # We specify the local, user-specific path for installation.
        Install-Module -Name $module -Scope CurrentUser -Force
    }
}

# 3. Import modules for use in the session.
Import-Module -Name Terminal-Icons
Import-Module -Name PowerShellAI

# 4. Define the location for the custom module and download it.
# This ensures your module is always up-to-date from your GitHub source.
$customModulePath = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Modules\Custom'
$customModuleFile = Join-Path -Path $customModulePath -ChildPath 'Custom.psm1'

# Ensure the directory exists
if (-not (Test-Path -Path $customModulePath)) {
    New-Item -Path $customModulePath -ItemType Directory -Force | Out-Null
}

# Download the latest version of the module from GitHub
try {
    Write-Host "Checking for latest custom module..." -ForegroundColor Gray
    Invoke-WebRequest -Uri 'https://www.tinyurl.com/Wirelore' -OutFile $customModuleFile -ErrorAction Stop
}
catch {
    Write-Warning "Failed to download custom module from GitHub. A local version may be used if available."
}

# 5. Import the custom module. Using -Force ensures the latest version is loaded.
Import-Module -Name $customModuleFile -Force

Write-Host "Profile loaded. Custom commands are available." -ForegroundColor Green
