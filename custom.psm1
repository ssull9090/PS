# --- Custom PowerShell Module ---
# Filename: custom.psm1
# Version: 2026-04-01

# --- System Aliases ---
Set-Alias -Name .. -Value cd..
Set-Alias -Name np -Value "C:\Program Files\Notepad++\notepad++.exe" -ErrorAction SilentlyContinue
Set-Alias -Name clr -Value Clear-Host
Set-Alias -Name ral -Value Remove-Alias
Set-Alias -Name home -Value Set-HomeLocation
Set-Alias -Name def -Value Get-FunctionDefinition
Set-Alias -Name clearall -Value Clear-PSReadLineHistory
Set-Alias -Name findps -Value Scan-PSReadLineHistory
Set-Alias -Name list -Value Get-CustomCommands
Set-Alias -Name askg -Value Ask-Gemini
Set-Alias -Name flush -Value Clear-MemoryStandby
Set-Alias -Name killbloat -Value Stop-BloatwareProcess
Set-Alias -Name update -Value Update-Wirelore

# --- Functions ---

function Update-Wirelore {
    <# .SYNOPSIS Force-downloads the latest profile and custom module from the server. #>
    $baseUrl          = "https://tools.wirelore.com"
    $localProfileFile = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Microsoft.PowerShell_profile.ps1'
    $customModuleDir  = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Modules\Custom'
    $customModuleFile = Join-Path -Path $customModuleDir -ChildPath 'Custom.psm1'

    # --- Update profile.ps1 ---
    Write-Host "Checking profile.ps1..." -ForegroundColor Cyan
    try {
        $remoteProfile = (Invoke-RestMethod -Uri "$baseUrl/profile.ps1" -ErrorAction Stop) -split "`n"
        $localVersion  = $null
        $remoteVersion = $null
        if (Test-Path $localProfileFile) {
            $localVersion = (Get-Content $localProfileFile | Select-String '^# Version:\s*(.+)$').Matches.Groups[1].Value
        }
        $remoteVersion = ($remoteProfile | Select-String '^# Version:\s*(.+)$').Matches.Groups[1].Value

        if ($localVersion -ne $remoteVersion) {
            $remoteProfile -join "`n" | Set-Content -Path $localProfileFile -Encoding utf8 -Force
            Write-Host "profile.ps1 updated ($localVersion -> $remoteVersion)." -ForegroundColor Green
        } else {
            Write-Host "profile.ps1 is current ($localVersion)." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning "Failed to update profile.ps1: $($_.Exception.Message)"
    }

    # --- Update custom.psm1 ---
    Write-Host "Checking custom.psm1..." -ForegroundColor Cyan
    try {
        $remoteModule = (Invoke-RestMethod -Uri "$baseUrl/custom.psm1" -ErrorAction Stop) -split "`n"
        $localModVersion  = $null
        $remoteModVersion = $null
        if (Test-Path $customModuleFile) {
            $localModVersion = (Get-Content $customModuleFile | Select-String '^# Version:\s*(.+)$').Matches.Groups[1].Value
        }
        $remoteModVersion = ($remoteModule | Select-String '^# Version:\s*(.+)$').Matches.Groups[1].Value

        if ($localModVersion -ne $remoteModVersion) {
            if (-not (Test-Path $customModuleDir)) { New-Item -Path $customModuleDir -ItemType Directory -Force | Out-Null }
            $remoteModule -join "`n" | Set-Content -Path $customModuleFile -Encoding utf8 -Force
            Import-Module -Name $customModuleFile -Force -DisableNameChecking
            Write-Host "custom.psm1 updated ($localModVersion -> $remoteModVersion)." -ForegroundColor Green
        } else {
            Write-Host "custom.psm1 is current ($localModVersion)." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning "Failed to update custom.psm1: $($_.Exception.Message)"
    }
}

function edit {
    <# .SYNOPSIS Opens the local user profile. #>
    $localProfile = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Microsoft.PowerShell_profile.ps1'
    if (Get-Command np -ErrorAction SilentlyContinue) {
        np $localProfile
    } else {
        notepad $localProfile
    }
}

Function Set-HomeLocation {
    $toolsPath = "C:\Tools"
    if (Test-Path $toolsPath) { Set-Location $toolsPath } else { Write-Warning "'$toolsPath' not found." }
}

function mkcd {
    <# .SYNOPSIS Creates a directory and enters it. #>
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    Set-Location $Path
}

function Ask-Gemini {
    <# .SYNOPSIS Interactive AI via PSAISUITE. #>
    [CmdletBinding(DefaultParameterSetName='Typed')]
    param(
        [Parameter(ParameterSetName='Typed', ValueFromRemainingArguments=$true)]
        [string[]] $PromptWords,
        [Parameter(ParameterSetName='Pipeline', Mandatory=$true, ValueFromPipeline=$true)]
        [string] $InputObject
    )
    begin {
        if (-not $env:GeminiKey) { throw "GeminiKey env variable missing." }
        $script:AccumulatedPrompt = ""
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') { $script:AccumulatedPrompt += $InputObject + "`n" }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Typed') { $script:AccumulatedPrompt = $PromptWords -join ' ' }
        if (-not [string]::IsNullOrWhiteSpace($script:AccumulatedPrompt)) {
            try {
                $response = Invoke-ChatCompletion -Model 'google:gemini-1.5-flash' -ApiKey $env:GeminiKey -Messages $script:AccumulatedPrompt.Trim()
                if ($response.Content) { Write-Host $response.Content -ForegroundColor Cyan } 
                else { Write-Host $response -ForegroundColor Cyan }
            }
            catch { Write-Error "Gemini Error: $($_.Exception.Message)" }
        }
    }
}

function Get-FunctionDefinition {
    <# .SYNOPSIS Prints function source code. #>
    [CmdletBinding()]
    param ([Parameter(Mandatory=$true, Position=0)]$FunctionName)
    try {
        (Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop).Definition
    } catch { Write-Error "Function '$FunctionName' not found." }
}

function Clear-PSReadLineHistory {
    $historyFile = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path $historyFile) { Remove-Item $historyFile -Force; Write-Host "History file deleted." -ForegroundColor Green }
    [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    Write-Host "Memory history cleared." -ForegroundColor Green
}

function Scan-PSReadLineHistory {
    <# .SYNOPSIS Scans user profiles for shell history files. #>
    $historyRelativePath = "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    $foundUsers = @()
    Write-Host "Scanning users..." -ForegroundColor Yellow
    
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $historyPath = Join-Path -Path $profile.FullName -ChildPath $historyRelativePath
        if (Test-Path -Path $historyPath) {
            $foundUsers += [PSCustomObject]@{ UserName = $profile.Name; Path = $historyPath }
        }
    }

    if ($foundUsers.Count -eq 0) { Write-Host "No history logs found." -ForegroundColor Red; return }
    
    $selection = Read-Host "`nFound logs: $($foundUsers.UserName -join ', '). Enter user to view"
    if (-not $selection) { return }
    $selectedLog = $foundUsers | Where-Object { $_.UserName -eq $selection }
    if ($selectedLog) { Get-Content -Path $selectedLog.Path } else { Write-Error "User not found." }
}

function Clear-MemoryStandby {
    <# .SYNOPSIS Purges Standby List via P/Invoke. #>
    [CmdletBinding()]
    param()
    process {
        $Source = @"
using System;
using System.Runtime.InteropServices;
public class MemoryCleaner {
    [DllImport("ntdll.dll")]
    public static extern int NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength);
    public static void ClearStandbyList() {
        int SystemMemoryListInformation = 80;
        int Command = 4; 
        GCHandle handle = GCHandle.Alloc(Command, GCHandleType.Pinned);
        try { NtSetSystemInformation(SystemMemoryListInformation, handle.AddrOfPinnedObject(), Marshal.SizeOf(Command)); }
        finally { handle.Free(); }
    }
}
"@
        if (-not ("MemoryCleaner" -as [Type])) { Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue }
        try { [MemoryCleaner]::ClearStandbyList(); Write-Host "Standby List Purged." -ForegroundColor Green }
        catch { Write-Error "Failed to purge memory: $_" }
    }
}

function Stop-BloatwareProcess {
    <# .SYNOPSIS Kills defined bloatware. #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    process {
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Warning "Admin privileges required for full effect."
        }
        $targets = @("crossdeviceresume","escsvc64","igfxCUIService","IntelCpHDCPSvc","IntelCpHeciSvc","WorkflowAppControl","PnScWIA2EvtRegSvc","PDFProFiltSrvPP","USBAppControl","Widgets","Widgetservice")
        
        foreach ($proc in $targets) {
            $name = $proc -replace '\.exe$', ''
            if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
                if ($PSCmdlet.ShouldProcess($name, "Stop-Process")) {
                    Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
                    Write-Host "Killed: $name" -ForegroundColor Green
                }
            }
        }
    }
}

function Get-CustomCommands {
    $mod = $MyInvocation.MyCommand.Module.Name; if(-not $mod){$mod="Custom"}
    Write-Host "--- $mod Functions ---" -ForegroundColor Cyan
    Get-Command -Module $mod | Where-Object CommandType -eq Function | Select-Object -ExpandProperty Name
    Write-Host "`n--- $mod Aliases ---" -ForegroundColor Cyan
    Get-Alias | Where-Object Source -eq $mod | Select-Object Name, Definition
}

Export-ModuleMember -Function * -Alias *
