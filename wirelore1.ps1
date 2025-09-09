# =====================================================================================
# Windows Optimization and Configuration Script
#
# INSTRUCTIONS:
# Run this script as a local administrator. Right-click the .ps1 file and
# choose "Run with PowerShell as Administrator".
#
# This script modifies system and user settings. Review carefully before execution.
# =====================================================================================

# Initialize logging
$LogFile = "$env:USERPROFILE\Desktop\OptimizationScript.log"
Add-Content -Path $LogFile -Value "[$(Get-Date)] Starting Windows configuration script..." -Force

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: This script requires administrator privileges."
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit
}

Write-Host "Starting Windows configuration script..." -ForegroundColor Yellow
Add-Content -Path $LogFile -Value "[$(Get-Date)] Administrator privileges confirmed."

# Check Windows version
$OSVersion = [System.Environment]::OSVersion.Version
$isWindows11 = ($OSVersion.Major -eq 10 -and $OSVersion.Build -ge 22000)
Add-Content -Path $LogFile -Value "[$(Get-Date)] Detected OS: Windows $($OSVersion.Major).$($OSVersion.Build), IsWindows11: $isWindows11"

# --- 1. Turn on Dark Theme Mode (for current user) ---
Write-Host "Setting Dark Theme for Apps and System..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Setting Dark Theme for Apps and System..."
$ThemePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
try {
    Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value 0 -Force -ErrorAction Stop
    Set-ItemProperty -Path $ThemePath -Name "SystemUsesLightTheme" -Value 0 -Force -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Dark theme set successfully."
} catch {
    Write-Host "Failed to set dark theme: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to set dark theme: $_"
}

# --- 2. Turn off Widgets ---
if ($isWindows11) {
    Write-Host "Uninstalling Widgets (Windows Web Experience Pack)..."
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Uninstalling Widgets (Windows Web Experience Pack)..."
    try {
        Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" | Remove-AppxPackage -ErrorAction Stop
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Widgets uninstalled successfully."
    } catch {
        Write-Host "Failed to uninstall Widgets: $_" -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Failed to uninstall Widgets: $_"
    }
} else {
    Write-Host "Widgets feature not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Widgets feature not applicable (Windows 10 or earlier)."
}

# --- 3. Move Windows Icon/Start Menu to the Left ---
if ($isWindows11) {
    Write-Host "Aligning Taskbar to the Left..."
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Aligning Taskbar to the Left..."
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord -Force -ErrorAction Stop
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Taskbar aligned to the left successfully."
    } catch {
        Write-Host "Failed to align taskbar: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to align taskbar: $_"
    }
} else {
    Write-Host "Taskbar alignment not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Taskbar alignment not applicable (Windows 10 or earlier)."
}

# --- 4. Disable Windows Telemetry ---
Write-Host "Disabling Telemetry Services and Tasks..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Disabling Telemetry Services and Tasks..."
$DataCollectionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
try {
    New-Item -Path $DataCollectionPath -Force -ErrorAction Stop
    Set-ItemProperty -Path $DataCollectionPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Telemetry registry settings applied."
} catch {
    Write-Host "Failed to set telemetry registry: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to set telemetry registry: $_"
}
try {
    Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] DiagTrack service disabled."
} catch {
    Write-Host "Failed to disable DiagTrack service: $_" -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Failed to disable DiagTrack service: $_"
}
try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" | Disable-ScheduledTask -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] CEIP scheduled tasks disabled."
} catch {
    Write-Host "Failed to disable CEIP tasks: $_" -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Failed to disable CEIP tasks: $_"
}

# --- 5. Disable Wi-Fi Sense ---
Write-Host "Disabling Wi-Fi Sense..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Disabling Wi-Fi Sense..."
$WifiSensePath = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
try {
    New-Item -Path $WifiSensePath -Force -ErrorAction Stop
    Set-ItemProperty -Path $WifiSensePath -Name "AllowWiFiHotSpotReporting" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $WifiSensePath -Name "AllowAutoConnectToWiFiSenseHotspots" -Value 0 -Type DWord -Force -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Wi-Fi Sense disabled."
} catch {
    Write-Host "Failed to disable Wi-Fi Sense: $_" -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Failed to disable Wi-Fi Sense: $_"
}

# --- 6. Add and Activate "Ultimate Performance" Power Plan ---
Write-Host "Adding and activating 'Ultimate Performance' power plan..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Adding and activating Ultimate Performance power plan..."
$UltimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
try {
    $ExistingPlans = powercfg /LIST
    if ($ExistingPlans -notmatch "Ultimate Performance") {
        powercfg -duplicatescheme $UltimatePlanGuid
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Ultimate Performance plan imported."
    }
    $UltimatePlan = powercfg /LIST | Select-String "Ultimate Performance"
    if ($UltimatePlan) {
        $PlanGuid = ($UltimatePlan -split 'GUID: ')[1].Split(' ')[0]
        powercfg /SETACTIVE $PlanGuid
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Ultimate Performance plan activated (GUID: $PlanGuid)."
    } else {
        Write-Host "Ultimate Performance plan not found after import." -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "[$(Get-Date)] WARNING: Ultimate Performance plan not found after import."
    }
} catch {
    Write-Host "Failed to configure power plan: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to configure power plan: $_"
}

# --- 7. Turn off all File Explorer History ---
Write-Host "Clearing and disabling File Explorer history..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Clearing and disabling File Explorer history..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Type DWord -Force -ErrorAction Stop
    Clear-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Name "*" -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -Recurse -ErrorAction SilentlyContinue
    Add-Content -Path $LogFile -Value "[$(Get-Date)] File Explorer history cleared and disabled."
} catch {
    Write-Host "Failed to clear File Explorer history: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to clear File Explorer history: $_"
}

# --- 8. Check and Install winget if not present ---
Write-Host "Checking for winget availability..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Checking for winget availability..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Attempting to install..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] winget not found. Attempting to install..."
    try {
        # Download and install Microsoft.AppInstaller (winget) from Microsoft Store
        $wingetUrl = "https://aka.ms/getwinget"
        $tempPath = "$env:TEMP\Microsoft.AppInstaller.appxbundle"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $tempPath -ErrorAction Stop
        Add-AppxPackage -Path $tempPath -ErrorAction Stop
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        Write-Host "winget installed successfully." -ForegroundColor Green
        Add-Content -Path $LogFile -Value "[$(Get-Date)] winget installed successfully."
    } catch {
        Write-Host "Failed to install winget: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to install winget: $_"
        Write-Host "Skipping Notepad++ and PowerShell 7 installation." -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Skipping Notepad++ and PowerShell 7 installation due to winget absence."
        $wingetAvailable = $false
    }
} else {
    Write-Host "winget is available." -ForegroundColor Green
    Add-Content -Path $LogFile -Value "[$(Get-Date)] winget is available."
    $wingetAvailable = $true
}

# --- 9. Check and Install Notepad++ (using winget) ---
if ($wingetAvailable) {
    Write-Host "Checking for Notepad++ installation..."
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Checking for Notepad++ installation..."
    try {
        if (-not (winget list --id Notepad++.Notepad++ --accept-source-agreements | Select-String "Notepad++")) {
            Write-Host "Notepad++ not found. Installing..."
            Add-Content -Path $LogFile -Value "[$(Get-Date)] Notepad++ not found. Installing..."
            winget install --id Notepad++.Notepad++ --silent --accept-source-agreements --accept-package-agreements
            Add-Content -Path $LogFile -Value "[$(Get-Date)] Notepad++ installed successfully."
        } else {
            Write-Host "Notepad++ is already installed." -ForegroundColor Green
            Add-Content -Path $LogFile -Value "[$(Get-Date)] Notepad++ is already installed."
        }
    } catch {
        Write-Host "Failed to install Notepad++: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to install Notepad++: $_"
    }
}

# --- 10. Install PowerShell 7 ---
if ($wingetAvailable) {
    Write-Host "Installing PowerShell 7 (x64)..."
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Installing PowerShell 7 (x64)..."
    try {
        winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
        Add-Content -Path $LogFile -Value "[$(Get-Date)] PowerShell 7 installed successfully."
        Write-Host "PowerShell 7 installed. To make it the default terminal:" -ForegroundColor Green
        Write-Host " 1. Open Windows Terminal." -ForegroundColor Green
        Write-Host " 2. Go to Settings (Ctrl + ,)." -ForegroundColor Green
        Write-Host " 3. On the 'Startup' page, set 'Default profile' to 'PowerShell'." -ForegroundColor Green
        Add-Content -Path $LogFile -Value "[$(Get-Date)] PowerShell 7 installation instructions provided."
    } catch {
        Write-Host "Failed to install PowerShell 7: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to install PowerShell 7: $_"
    }
}

# --- 11. Disable PowerShell 7 Telemetry ---
Write-Host "Disabling PowerShell 7 telemetry system-wide..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Disabling PowerShell 7 telemetry system-wide..."
try {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
    Add-Content -Path $LogFile -Value "[$(Get-Date)] PowerShell 7 telemetry disabled."
} catch {
    Write-Host "Failed to disable PowerShell 7 telemetry: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to disable PowerShell 7 telemetry: $_"
}

# --- 12. Enable Windows 10/Classic Right-Click Context Menu ---
if ($isWindows11) {
    Write-Host "Enabling classic right-click context menu..."
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Enabling classic right-click context menu..."
    $ClassicContextPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    try {
        New-Item -Path $ClassicContextPath -Force -ErrorAction Stop
        Set-ItemProperty -Path $ClassicContextPath -Name "(Default)" -Value "" -Force -ErrorAction Stop
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Classic context menu enabled."
    } catch {
        Write-Host "Failed to enable classic context menu: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to enable classic context menu: $_"
    }
} else {
    Write-Host "Classic context menu not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Classic context menu not applicable (Windows 10 or earlier)."
}

# --- 13. Apply Performance and Menu Optimizations from JSON ---
Write-Host "Applying advanced performance tweaks from registry data..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Applying advanced performance tweaks from registry data..."
$jsonData = @'
{
    "registry": [
        { "Path": "HKCU:\Control Panel\Desktop", "Name": "DragFullWindows", "Value": "0", "Type": "String" },
        { "Path": "HKCU:\Control Panel\Desktop", "Name": "MenuShowDelay", "Value": "200", "Type": "String" },
        { "Path": "HKCU:\Control Panel\Desktop\WindowMetrics", "Name": "MinAnimate", "Value": "0", "Type": "String" },
        { "Path": "HKCU:\Control Panel\Keyboard", "Name": "KeyboardDelay", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Name": "ListviewAlphaSelect", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Name": "ListviewShadow", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Name": "TaskbarAnimations", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects", "Name": "VisualFXSetting", "Value": "3", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\DWM", "Name": "EnableAeroPeek", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Name": "ShowTaskViewButton", "Value": "0", "Type": "DWord" },
        { "Path": "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search", "Name": "SearchboxTaskbarMode", "Value": "0", "Type": "DWord" }
    ],
    "InvokeScript": [
        "Set-ItemProperty -Path \"HKCU:\Control Panel\Desktop\" -Name \"UserPreferencesMask\" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0))"
    ]
}
'@
try {
    $config = $jsonData | ConvertFrom-Json
    foreach ($reg in $config.registry) {
        Write-Host " Applying registry key: $($reg.Path)\$($reg.Name)"
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Applying registry key: $($reg.Path)\$($reg.Name)"
        if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force -ErrorAction Stop }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force -ErrorAction Stop
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Registry key set: $($reg.Path)\$($reg.Name)"
    }
    foreach ($script in $config.InvokeScript) {
        Write-Host " Invoking script: $script"
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Invoking script: $script"
        Invoke-Expression $script
        Add-Content -Path $LogFile -Value "[$(Get-Date)] Script invoked successfully."
    }
} catch {
    Write-Host "Failed to apply performance tweaks: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to apply performance tweaks: $_"
}

# --- 14. Disable Bing Search in Start Menu ---
Write-Host "Disabling Bing search in the Start Menu..."
Add-Content -Path $LogFile -Value "[$(Get-Date)] Disabling Bing search in the Start Menu..."
$SearchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Search"
try {
    New-Item -Path $SearchPolicyPath -Force -ErrorAction Stop
    Set-ItemProperty -Path $SearchPolicyPath -Name "DisableBingSearch" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $SearchPolicyPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -Force -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Bing search disabled."
} catch {
    Write-Host "Failed to disable Bing search: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to disable Bing search: $_"
}

# --- Finalization ---
Write-Host "Configuration complete. Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
Add-Content -Path $LogFile -Value "[$(Get-Date)] Configuration complete. Restarting Windows Explorer..."
try {
    Stop-Process -Name explorer -Force -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$(Get-Date)] Windows Explorer restarted successfully."
} catch {
    Write-Host "Failed to restart Windows Explorer: $_" -ForegroundColor Red
    Add-Content -Path $LogFile -Value "[$(Get-Date)] ERROR: Failed to restart Windows Explorer: $_"
}

Write-Host "Done." -ForegroundColor Green
Add-Content -Path $LogFile -Value "[$(Get-Date)] Script execution completed."
