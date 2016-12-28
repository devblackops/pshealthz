# Implementation of the Health Endpoint Monitoring Pattern using PowerShell
# https://msdn.microsoft.com/en-us/library/dn589789.aspx

#requires -RunAsAdministrator

$script:httpListeners = @{}

# Dot source public/private functions
$public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )
foreach($file in @($public + $private)) {
    . $file.FullName
}

# Export functions
Export-ModuleMember -Function $public.Basename
