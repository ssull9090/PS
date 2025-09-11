# --- One-Time Local Environment Setup ---

# 1. Define the local paths you want to use.
$localPowerShellDir = Join-Path -Path $env:USERPROFILE -ChildPath 'PowerShell'
$localModulesDir = Join-Path -Path $localPowerShellDir -ChildPath 'Modules'
$localProfileFile = Join-Path -Path $localPowerShellDir -ChildPath 'Microsoft.PowerShell_profile.ps1'

# 2. Create these directories if they don't already exist.
if (-not (Test-Path -Path $localPowerShellDir)) {
    Write-Host "Creating directory: $localPowerShellDir" -ForegroundColor Green
    New-Item -Path $localPowerShellDir -ItemType Directory | Out-Null
}
if (-not (Test-Path -Path $localModulesDir)) {
    Write-Host "Creating directory: $localModulesDir" -ForegroundColor Green
    New-Item -Path $localModulesDir -ItemType Directory | Out-Null
}

# 3. Add your new local modules path to the PSModulePath environment variable.
# This makes the change permanent for your user account.
$currentUserModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$pathParts = $currentUserModulePath -split ';' | Where-Object { $_ }
if ($localModulesDir -notin $pathParts) {
    Write-Host "Adding '$localModulesDir' to your permanent PSModulePath." -ForegroundColor Green
    $newPath = ($localModulesDir, $pathParts) -join ';'
    [Environment]::SetEnvironmentVariable('PSModulePath', $newPath, 'User')
} else {
    Write-Host "'$localModulesDir' is already in your PSModulePath." -ForegroundColor Yellow
}

# 4. Create a "loader" in the default profile location.
# This tells the standard, network-redirected profile to simply load your LOCAL profile.
# This is the key to bypassing the Group Policy redirection for your profile script.
if (-not (Test-Path (Split-Path $PROFILE -Parent))) {
    New-Item -Path (Split-Path $PROFILE -Parent) -ItemType Directory -Force | Out-Null
}
$loaderContent = "# This profile loads the local user profile from a non-redirected folder. `n. `"$localProfileFile`""
Set-Content -Path $PROFILE -Value $loaderContent -Force

Write-Host "`nSetup complete! Please restart your PowerShell session." -ForegroundColor Cyan
Write-Host "After restarting, run the final command to download your profile."
Write-Host "The final commands to run are:"
Write-Host '$localProfileFile = Join-Path -Path $env:USERPROFILE -ChildPath "PowerShell\Microsoft.PowerShell_profile.ps1"' -ForegroundColor Green
Write-Host 'Invoke-WebRequest -Uri "https://www.tinyurl.com/WireloreProfile" -AllowInsecureRedirect -OutFile $localProfileFile' -ForegroundColor Green
$Command1 = '$localProfileFile = Join-Path -Path $env:USERPROFILE -ChildPath "PowerShell\Microsoft.PowerShell_profile.ps1"'
$Command2 = 'Invoke-WebRequest -Uri "https://www.tinyurl.com/WireloreProfile" -AllowInsecureRedirect -OutFile $localProfileFile'
$Command3 = '.$Profile'
$ClipboardCommands = "$command1`r`n$command2`r`n$command3"
Set-Clipboard -Value $clipboardcommands
Write-Host 'The commands have been copied to clipboard, plus a profile reload command. Paste them after opening a new shell.'
