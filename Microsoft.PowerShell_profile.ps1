Import-Module -Name Terminal-Icons
Set-PSReadLineOption -PredictionSource History
Import-Module -Name Custom.psm1 -Force
function edit { np $PROFILE }