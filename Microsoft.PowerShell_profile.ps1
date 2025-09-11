# --- PowerShell Profile ---

# 1. Set PSReadLine options for a better command-line experience.
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# 2. Check for and install required modules if they are missing.
$requiredModules = @('Terminal-Icons', 'PSAISUITE') # PowerShellAI contains Invoke-ChatCompletion
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
        # We specify the local, user-specific path for installation.
        Install-Module -Name $module -Scope CurrentUser -Force
    }
}

# 3. Import modules for use in the session.
Import-Module -Name Terminal-Icons
Import-Module -Name PSAISUITE

# 4. Define the path for the custom module file.
$customModuleFile = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Modules\Custom\Custom.psm1'

# 5. Check if the 'Custom' module is already loaded in the current session.
if (Get-Module -Name Custom -ErrorAction SilentlyContinue) {
    # If the module is already loaded, do nothing.
    # We can add a subtle message for clarity when debugging profiles.
    Write-Host "Custom module already loaded." -ForegroundColor DarkGray
}
else {
    # If the module is NOT loaded, then proceed to download and import it.
    Write-Host "Custom module not found, attempting to download and import..." -ForegroundColor Yellow

    try {
    # Ensure the parent directory exists before downloading.
    $parentDir = Split-Path -Path $customModuleFile -Parent
    if (-not (Test-Path -Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    
    # Download the latest version of the module from GitHub.
    Invoke-WebRequest -Uri 'https://www.tinyurl.com/Wirelore' -AllowInsecureRedirect -OutFile $customModuleFile -ErrorAction Stop
}
catch [System.Net.WebException] {
    Write-Warning "Network error downloading custom module. Check your internet connection. A local version will be used if available."
}
catch [System.UnauthorizedAccessException] {
    Write-Warning "Permission error accessing module path '$customModuleFile'. A local version will be used if available."
}
catch [System.IO.DirectoryNotFoundException] {
    Write-Warning "Could not create or access the module directory. A local version will be used if available."
}
catch {
    # Fallback for any other unexpected errors
    Write-Warning "Failed to download custom module: $($_.Exception.Message). A local version will be used if available."
}

    # Finally, import the module. This will only run if the module wasn't loaded initially.
    # We check if the file exists in case the download failed and there's no local copy.
    if (Test-Path -Path $customModuleFile) {
        Import-Module -Name $customModuleFile
    }
    else {
        Write-Error "Could not import 'Custom' module. The file was not found at $customModuleFile and could not be downloaded."
    }
}
Write-Host "Profile loaded. Custom commands are available." -ForegroundColor Green




