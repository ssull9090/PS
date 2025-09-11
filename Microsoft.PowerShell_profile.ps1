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
    Write-Host "Custom module already loaded." -ForegroundColor DarkGray
}
else {
    # Module is not loaded - first try to import from local file if it exists
    if (Test-Path -Path $customModuleFile) {
        Write-Host "Custom module found locally, importing..." -ForegroundColor Green
        try {
            Import-Module -Name $customModuleFile -ErrorAction Stop
            Write-Host "Custom module imported successfully." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to import existing Custom module: $($_.Exception.Message). Will attempt to re-download."
            # If import fails, we'll fall through to the download logic below
            $importFailed = $true
        }
    }
    
    # Only download if the module file doesn't exist OR if the import failed
    if (-not (Test-Path -Path $customModuleFile) -or $importFailed) {
        Write-Host "Custom module not found locally, attempting to download..." -ForegroundColor Yellow
        try {
            # Ensure the parent directory exists before downloading.
            $parentDir = Split-Path -Path $customModuleFile -Parent
            if (-not (Test-Path -Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            
            # Download the latest version of the module from GitHub.
            Invoke-WebRequest -Uri 'https://www.tinyurl.com/Wirelore' -AllowInsecureRedirect -OutFile $customModuleFile -ErrorAction Stop
            Write-Host "Custom module downloaded successfully." -ForegroundColor Green
            
            # Now try to import the freshly downloaded module
            Import-Module -Name $customModuleFile -ErrorAction Stop
            Write-Host "Custom module imported successfully." -ForegroundColor Green
        }
        catch [System.Net.WebException] {
            Write-Warning "Network error downloading custom module. Check your internet connection."
        }
        catch [System.UnauthorizedAccessException] {
            Write-Warning "Permission error accessing module path '$customModuleFile'."
        }
        catch [System.IO.DirectoryNotFoundException] {
            Write-Warning "Could not create or access the module directory."
        }
        catch {
            # Fallback for any other unexpected errors
            Write-Warning "Failed to download or import custom module: $($_.Exception.Message)"
        }
    }
}
Write-Host "Profile loaded. Custom commands are available." -ForegroundColor Green





