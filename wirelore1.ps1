# =====================================================================================
# Windows Optimization and Configuration Script
#
# INSTRUCTIONS:
# Run this script as a local administrator. Right-click the .ps1 file and
# choose "Run with PowerShell as Administrator".
#
# This script modifies system and user settings. Review carefully before execution.
# =====================================================================================

Write-Host "Starting Windows configuration script..." -ForegroundColor Yellow

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit
}

Write-Host "Administrator privileges confirmed." -ForegroundColor Green

# Check Windows version
$OSVersion = [System.Environment]::OSVersion.Version
$isWindows11 = ($OSVersion.Major -eq 10 -and $OSVersion.Build -ge 22000)
Write-Host "Detected OS: Windows $($OSVersion.Major).$($OSVersion.Build), IsWindows11: $isWindows11"

# --- 1. Turn on Dark Theme Mode (for current user) ---
Write-Host "Setting Dark Theme for Apps and System..."
$ThemePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
try {
    Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value 0 -Force -ErrorAction Stop
    Set-ItemProperty -Path $ThemePath -Name "SystemUsesLightTheme" -Value 0 -Force -ErrorAction Stop
    Write-Host "Dark theme set successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to set dark theme: $_" -ForegroundColor Red
}

# --- 2. Turn off Widgets ---
if ($isWindows11) {
    Write-Host "Uninstalling Widgets (Windows Web Experience Pack)..."
    try {
        Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" | Remove-AppxPackage -ErrorAction Stop
        Write-Host "Widgets uninstalled successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to uninstall Widgets: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "Widgets feature not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
}

# --- 3. Move Windows Icon/Start Menu to the Left ---
if ($isWindows11) {
    Write-Host "Aligning Taskbar to the Left..."
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Host "Taskbar aligned to the left successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to align taskbar: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Taskbar alignment not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
}

# --- 4. Disable Windows Telemetry ---
Write-Host "Disabling Telemetry Services and Tasks..."
$DataCollectionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
try {
    New-Item -Path $DataCollectionPath -Force -ErrorAction Stop
    Set-ItemProperty -Path $DataCollectionPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction Stop
    Write-Host "Telemetry registry settings applied." -ForegroundColor Green
} catch {
    Write-Host "Failed to set telemetry registry: $_" -ForegroundColor Red
}
try {
    Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction Stop
    Write-Host "DiagTrack service disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to disable DiagTrack service: $_" -ForegroundColor Yellow
}
try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" | Disable-ScheduledTask -ErrorAction Stop
    Write-Host "CEIP scheduled tasks disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to disable CEIP tasks: $_" -ForegroundColor Yellow
}

# --- 5. Disable Wi-Fi Sense ---
Write-Host "Disabling Wi-Fi Sense..."
$WifiSensePath = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
try {
    New-Item -Path $WifiSensePath -Force -ErrorAction Stop
    Set-ItemProperty -Path $WifiSensePath -Name "AllowWiFiHotSpotReporting" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $WifiSensePath -Name "AllowAutoConnectToWiFiSenseHotspots" -Value 0 -Type DWord -Force -ErrorAction Stop
    Write-Host "Wi-Fi Sense disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to disable Wi-Fi Sense: $_" -ForegroundColor Yellow
}

# --- 6. Add and Activate "Ultimate Performance" Power Plan ---
Write-Host "Adding and activating 'Ultimate Performance' power plan..."
$UltimatePlanGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
try {
    $ExistingPlans = powercfg /LIST
    if ($ExistingPlans -notmatch "Ultimate Performance") {
        powercfg -duplicatescheme $UltimatePlanGuid
        Write-Host "Ultimate Performance plan imported." -ForegroundColor Green
    }
    $UltimatePlan = powercfg /LIST | Select-String "Ultimate Performance"
    if ($UltimatePlan) {
        $PlanGuid = ($UltimatePlan -split 'GUID: ')[1].Split(' ')[0]
        powercfg /SETACTIVE $PlanGuid
        Write-Host "Ultimate Performance plan activated (GUID: $PlanGuid)." -ForegroundColor Green
    } else {
        Write-Host "Ultimate Performance plan not found after import." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to configure power plan: $_" -ForegroundColor Red
}

# --- 7. Turn off all File Explorer History ---
Write-Host "Clearing and disabling File Explorer history..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Type DWord -Force -ErrorAction Stop
    Clear-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Name "*" -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "File Explorer history cleared and disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to clear File Explorer history: $_" -ForegroundColor Red
}

# --- 8. Check and Install winget if not present ---
Write-Host "Checking for winget availability..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Attempting to install..." -ForegroundColor Yellow
    try {
        # Download and install Microsoft.AppInstaller (winget) from Microsoft Store
        $wingetUrl = "https://aka.ms/getwinget"
        $tempPath = "$env:TEMP\Microsoft.AppInstaller.appxbundle"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $tempPath -ErrorAction Stop
        Add-AppxPackage -Path $tempPath -ErrorAction Stop
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        Write-Host "winget installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install winget: $_" -ForegroundColor Red
        Write-Host "Skipping Notepad++ and PowerShell 7 installation." -ForegroundColor Yellow
        $wingetAvailable = $false
    }
} else {
    Write-Host "winget is available." -ForegroundColor Green
    $wingetAvailable = $true
}

# --- 9. Check and Install Notepad++ (using winget) ---
if ($wingetAvailable) {
    Write-Host "Checking for Notepad++ installation..."
    try {
        if (-not (winget list --id Notepad++.Notepad++ --accept-source-agreements | Select-String "Notepad++")) {
            Write-Host "Notepad++ not found. Installing..."
            winget install --id Notepad++.Notepad++ --silent --accept-source-agreements --accept-package-agreements
            Write-Host "Notepad++ installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Notepad++ is already installed." -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to install Notepad++: $_" -ForegroundColor Red
    }
}

# --- 10. Install PowerShell 7 ---
if ($wingetAvailable) {
    Write-Host "Installing PowerShell 7 (x64)..."
    try {
        winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
        Write-Host "PowerShell 7 installed. To make it the default terminal:" -ForegroundColor Green
        Write-Host " 1. Open Windows Terminal." -ForegroundColor Green
        Write-Host " 2. Go to Settings (Ctrl + ,)." -ForegroundColor Green
        Write-Host " 3. On the 'Startup' page, set 'Default profile' to 'PowerShell'." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install PowerShell 7: $_" -ForegroundColor Red
    }
}

# --- 11. Disable PowerShell 7 Telemetry ---
Write-Host "Disabling PowerShell 7 telemetry system-wide..."
try {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
    Write-Host "PowerShell 7 telemetry disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to disable PowerShell 7 telemetry: $_" -ForegroundColor Red
}

# --- 12. Enable Windows 10/Classic Right-Click Context Menu ---
if ($isWindows11) {
    Write-Host "Enabling classic right-click context menu..."
    $ClassicContextPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    try {
        New-Item -Path $ClassicContextPath -Force -ErrorAction Stop
        Set-ItemProperty -Path $ClassicContextPath -Name "(Default)" -Value "" -Force -ErrorAction Stop
        Write-Host "Classic context menu enabled." -ForegroundColor Green
    } catch {
        Write-Host "Failed to enable classic context menu: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Classic context menu not applicable (Windows 10 or earlier)." -ForegroundColor Yellow
}

# --- 13. Apply Performance and Menu Optimizations ---
Write-Host "Applying advanced performance tweaks from registry data..."
try {
    # Define registry settings as an array of hashtables to avoid JSON parsing issues
    $registrySettings = @(
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "DragFullWindows"; Value = "0"; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = "200"; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = "0"; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Keyboard"; Name = "KeyboardDelay"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewAlphaSelect"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewShadow"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = "3"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "EnableAeroPeek"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowTaskViewButton"; Value = "0"; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Value = "0"; Type = "DWord" }
    )
    foreach ($reg in $registrySettings) {
        Write-Host " Applying registry key: $($reg.Path)\$($reg.Name)"
        if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force -ErrorAction Stop }
        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force -ErrorAction Stop
    }
    # Set UserPreferencesMask directly to avoid escape character issues
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0)) -Force -ErrorAction Stop
    Write-Host "Performance tweaks applied successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to apply performance tweaks: $_" -ForegroundColor Red
}

# --- 14. Disable Bing Search in Start Menu ---
Write-Host "Disabling Bing search in the Start Menu..."
$SearchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Search"
try {
    New-Item -Path $SearchPolicyPath -Force -ErrorAction Stop
    Set-ItemProperty -Path $SearchPolicyPath -Name "DisableBingSearch" -Value 1 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $SearchPolicyPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -Force -ErrorAction Stop
    Write-Host "Bing search disabled." -ForegroundColor Green
} catch {
    Write-Host "Failed to disable Bing search: $_" -ForegroundColor Red
}

# --- 15. Additional Start Menu and Taskbar Configurations ---
Write-Host "Applying additional Start menu and Taskbar configurations..."
try {
    # Turn off Task View (already in registrySettings, but ensuring explicitly)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force -ErrorAction Stop
    # Turn off/hide Search bar in Taskbar (already in registrySettings, but ensuring explicitly)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force -ErrorAction Stop
    # Turn off "Show recently added apps"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "Start_TrackProgs" -Value 0 -Type DWord -Force -ErrorAction Stop
    # Turn off "Show recommended files in Start, recent files in Explorer, and items in jump lists"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "Start_TrackDocs" -Value 0 -Type DWord -Force -ErrorAction Stop
    # Turn off "Show recommendations for tips, shortcuts, new apps, and more"
    $StartPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $StartPolicyPath)) { New-Item -Path $StartPolicyPath -Force -ErrorAction Stop }
    Set-ItemProperty -Path $StartPolicyPath -Name "HideRecommendedSection" -Value 1 -Type DWord -Force -ErrorAction Stop
    # Switch Start menu layout to "More Pins" (0 = Default, 1 = More Pins, 2 = More Recommendations)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Additional Start menu and Taskbar configurations applied." -ForegroundColor Green
} catch {
    Write-Host "Failed to apply Start menu/Taskbar configurations: $_" -ForegroundColor Red
}

# --- Finalization ---
Write-Host "Configuration complete. Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
try {
    Stop-Process -Name explorer -Force -ErrorAction Stop
    Write-Host "Windows Explorer restarted successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to restart Windows Explorer: $_" -ForegroundColor Red
}

Write-Host "Done." -ForegroundColor Green
