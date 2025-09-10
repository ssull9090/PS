if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Write-Host "Module 'Terminal-Icons' not found. Installing..." -ForegroundColor Yellow
    Install-Module Terminal-Icons -Scope CurrentUser -Force -AcceptLicense
}

# --- Module Imports and Configuration ---
Import-Module -Name Terminal-Icons
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionSource History
Set-Alias -Name .. -Value cd..
Set-Alias -Name np -Value "C:\Program Files\Notepad++\notepad++.exe"
Set-Alias -Name clr -value clear
Set-Alias -Name ral -value remove-Alias
function edit {np $profile}

# Function to cd into a "home directory", in this case C:\Tools. Alias:home
Function Set-HomeLocation { Set-Location C:\Tools }
Set-Alias -name home -value Set-HomeLocation

# Function to create a directory and then change into it
function mkcd {
    mkdir $args[0]
    cd $args[0]
}

# Get-FunctionDefinition: Retrieves the definition / code of a specified PowerShell function.
function Get-FunctionDefinition {
    <#
    .SYNOPSIS
        Displays the definition (code) of a specified PowerShell function.
    .DESCRIPTION
        Retrieves and outputs the script block (code) of a named function using Get-Command.
        If the specified name is not a function or does not exist, an error message is displayed.
        This is useful for inspecting the implementation of user-defined or module-provided functions.
    .PARAMETER FunctionName
        The name of the function to inspect. This parameter is mandatory.
    .EXAMPLE
        Get-FunctionDefinition -FunctionName home
        # Displays the definition of the 'home' function, if it exists.
    .EXAMPLE
        "Set-HomeLocation", "Get-FunctionDefinition" | def
        # Using the alias, displays definitions of multiple functions.
    .NOTES
        Author: Wirelore
        Last Updated: September 3, 2025
    .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-command
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$FunctionName
    )
    process {
        try {
            $command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
            if ($command) {
                Write-Output $command.Definition
            }
        }
        catch {
            Write-Error "Function '$FunctionName' not found or is not a PowerShell function."
        }
    }
}

# Set alias 'define' for Get-FunctionDefinition
Set-Alias -Name def -Value Get-FunctionDefinition

function Clear-PSReadLineHistory {
    <#
    .SYNOPSIS
        Clears the PSReadLine history for the current user.

    .DESCRIPTION
        This function removes all entries from the PSReadLine history file,
        effectively clearing the history that is saved between sessions.
        It first checks the location of the history file and then removes it.
        The function also clears the in-memory history of the current session.

    .EXAMPLE
        Clear-PSReadLineHistory

    .NOTES
        The history file location is determined by the PSReadLine module.
        Typically, it's located at C:\Users\<Username>\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
        This function handles the path determination automatically.
    #>

    $historyFile = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path -Path $historyFile) {
        Remove-Item -Path $historyFile -Force
        Write-Host "PSReadLine history file '$historyFile' has been cleared." -ForegroundColor Green
    } else {
        Write-Host "PSReadLine history file not found at '$historyFile'." -ForegroundColor Yellow
    }

    # Clear the in-memory history for the current session
    [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    Write-Host "In-memory PSReadLine history for the current session has been cleared." -ForegroundColor Green
}

function Scan-PSReadLineHistory {
    <#
    .SYNOPSIS
        Scans all user profiles for PSReadLine history logs.

    .DESCRIPTION
        This function iterates through all user profiles on the system,
        identifies those with a PSReadLine history file, and then provides
        an interactive prompt to view the contents of a selected user's history.
        The history file is typically located in the user's AppData directory.

    .NOTES
        This function requires administrative privileges to access other users'
        profile directories. If run without elevated permissions, it may
        only be able to access the current user's history file.
    #>

    # Define the common part of the history file path
    $historyRelativePath = "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    $foundUsers = @()

    Write-Host "Scanning for PSReadLine history logs on this system..." -ForegroundColor Yellow
    Write-Host "This may require elevated privileges to access all user profiles."

    # Get all user profile directories under C:\Users
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue

    foreach ($profile in $userProfiles) {
        $userName = $profile.Name
        $historyPath = Join-Path -Path $profile.FullName -ChildPath $historyRelativePath

        # Check if the history file exists for this user
        if (Test-Path -Path $historyPath) {
            Write-Host "   [+] Found log for user: $userName"
            $foundUsers += @{
                UserName = $userName
                Path     = $historyPath
            }
        }
    }

    # Check if any logs were found
    if ($foundUsers.Count -eq 0) {
        Write-Host "`nNo PSReadLine history logs were found." -ForegroundColor Red
        return
    }

    Write-Host "`nFound logs for the following users:" -ForegroundColor Cyan
    $foundUsers | ForEach-Object {
        Write-Host "  - $($_.UserName)"
    }

    # Prompt the user for which log to view
    $selection = Read-Host "`nEnter the name of the user whose history you want to view (or press Enter to exit)"
    
    if (-not $selection) {
        Write-Host "Exiting."
        return
    }

    # Find the selected user's log path
    $selectedLog = $foundUsers | Where-Object { $_.UserName -eq $selection }

    if (-not $selectedLog) {
        Write-Host "Error: User '$selection' not found in the list." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Displaying history for $($selectedLog.UserName) ---" -ForegroundColor Green
    Get-Content -Path $selectedLog.Path
    Write-Host "`n--- End of history ---" -ForegroundColor Green
}

# A function to list all aliases and functions found within the source module "Custom"
function Get-CustomCommands {
    <#
    .SYNOPSIS
        Lists all aliases and functions from the 'Custom' module.
    .DESCRIPTION
        This function uses Get-Command and Get-Alias to find all commands
        that have the 'Custom' module as their source. It's a quick way
        to see all the custom functions and aliases you've defined.
    .EXAMPLE
        Get-CustomCommands
        # Lists all commands from the 'Custom' module.
    .NOTES
        The 'Custom' module name is assumed based on the file name.
    #>
    Write-Host "--- Custom Functions ---" -ForegroundColor Cyan
    Get-Command -CommandType Function -Module custom
    Write-Host "`n--- Custom Aliases ---" -ForegroundColor Cyan
    get-alias | where-object -property source -eq custom
}

# Alias creation for clear-PSreadlinehistory and Scan-PSReadLineHistory
Set-Alias -name clearall -value clear-PSreadlinehistory
Set-Alias -name findps -value scan-psreadlinehistory
Set-Alias -name list-commands -value Get-CustomCommands



