# --- Custom PowerShell Module ---
# Filename: Custom.psm1

# --- Aliases ---
Set-Alias -Name .. -Value cd..
Set-Alias -Name np -Value "C:\Program Files\Notepad++\notepad++.exe" -ErrorAction SilentlyContinue
Set-Alias -Name clr -Value Clear-Host
Set-Alias -Name ral -Value Remove-Alias
Set-Alias -Name home -Value Set-HomeLocation
Set-Alias -Name def -Value Get-FunctionDefinition
Set-Alias -Name clearall -Value Clear-PSReadLineHistory
Set-Alias -Name findps -Value Scan-PSReadLineHistory
Set-Alias -Name list-commands -Value Get-CustomCommands
Set-Alias -Name askg -Value Ask-Gemini

# --- Functions ---

function edit {
    <# .SYNOPSIS Opens the local user profile in Notepad++. #>
    $localProfile = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell\Microsoft.PowerShell_profile.ps1'
    np $localProfile
}

Function Set-HomeLocation {
    <# .SYNOPSIS Navigates to a predefined 'home' directory. #>
    Set-Location C:\Tools
}

function mkcd {
    <# .SYNOPSIS Creates a directory and immediately changes into it. #>
    param([string]$Path)
    mkdir $Path
    cd $Path
}

function Ask-Gemini {
    <# .SYNOPSIS Sends a prompt to the Gemini API. #>
    [CmdletBinding(DefaultParameterSetName='Typed')]
    param(
        [Parameter(ParameterSetName='Typed', ValueFromRemainingArguments=$true)]
        [string[]] $PromptWords,

        [Parameter(ParameterSetName='Pipeline', Mandatory=$true, ValueFromPipeline=$true)]
        [string] $InputObject
    )

    begin {
        if (-not $env:GeminiKey) {
            throw "Gemini API key not found in `$env:GeminiKey. Please set it using `[Environment]::SetEnvironmentVariable('GeminiKey', 'YOUR_KEY', 'User')` and restart PowerShell."
        }
        $script:prompt = if ($PSCmdlet.ParameterSetName -eq 'Typed') { $PromptWords -join ' ' } else { '' }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            $script:prompt = $script:prompt + $InputObject + "`n"
        }
    }
    end {
        if (-not [string]::IsNullOrWhiteSpace($script:prompt)) {
            try {
                $response = Invoke-ChatCompletion -Model 'google:gemini-1.5-flash' -ApiKey $env:GeminiKey -Messages $script:prompt.Trim()
                Write-Host $response -ForegroundColor Cyan
            }
            catch {
                Write-Error "Failed to get response from Gemini API. Error: $($_.Exception.Message)"
            }
        }
    }
}

function Get-FunctionDefinition {
    <#
    .SYNOPSIS
        Displays the definition (code) of a specified PowerShell function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$FunctionName
    )
    process {
        try {
            $command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
            Write-Output $command.Definition
        }
        catch {
            Write-Error "Function '$FunctionName' not found or is not a PowerShell function."
        }
    }
}

function Clear-PSReadLineHistory {
    <# .SYNOPSIS Clears the PSReadLine history for the current user. #>
    $historyFile = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path -Path $historyFile) {
        Remove-Item -Path $historyFile -Force
        Write-Host "PSReadLine history file has been cleared." -ForegroundColor Green
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    Write-Host "In-memory PSReadLine history has been cleared." -ForegroundColor Green
}

function Scan-PSReadLineHistory {
    <#
    .SYNOPSIS
        Scans all user profiles for PSReadLine history logs. Requires admin privileges for other users.
    #>
    # Implementation from your original code...
    $historyRelativePath = "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    $foundUsers = @()
    Write-Host "Scanning for PSReadLine history logs..." -ForegroundColor Yellow
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $historyPath = Join-Path -Path $profile.FullName -ChildPath $historyRelativePath
        if (Test-Path -Path $historyPath) {
            $foundUsers += @{ UserName = $profile.Name; Path = $historyPath }
        }
    }
    if ($foundUsers.Count -eq 0) {
        Write-Host "No PSReadLine history logs were found." -ForegroundColor Red; return
    }
    $selection = Read-Host "`nFound logs for $($foundUsers.UserName -join ', '). Enter user name to view history (or press Enter to exit)"
    if (-not $selection) { return }
    $selectedLog = $foundUsers | Where-Object { $_.UserName -eq $selection }
    if ($selectedLog) {
        Get-Content -Path $selectedLog.Path
    } else {
        Write-Error "User '$selection' not found."
    }
}

function Get-CustomCommands {
    <#
    .SYNOPSIS
        Lists all aliases and functions from this module.
    #>
    $moduleName = $MyInvocation.MyCommand.Module.Name
    Write-Host "--- Functions from '$moduleName' ---" -ForegroundColor Cyan
    Get-Command -Module $moduleName | Where-Object { $_.CommandType -in 'Function', 'Cmdlet' }

    Write-Host "`n--- Aliases from '$moduleName' ---" -ForegroundColor Cyan
    Get-Alias | Where-Object { $_.Source -eq $moduleName }
}

# Export all the functions and aliases to make them available when the module is imported.
Export-ModuleMember -Function *-* -Alias *
