#requires -modules OperationValidation

[cmdletbinding()]
param(
    [string]$Name
)

Import-Module -Name OperationValidation -ErrorAction Stop

$resp = [ordered]@{
    success = $true
    time = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
    checks = @()
    message = ''
}

$progPref = $ProgressPreference 
$ProgressPreference = 'SilentlyContinue'
try {
    $ovfChecks = OperationValidation\Get-OperationValidation -ModuleName OVF* -Verbose:$false -ErrorAction SilentlyContinue
    $ovfResults = $ovfChecks | OperationValidation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
    $resp.success = @($ovfResults | where Result -like 'Failed').Count -eq 0
    $resp.checks = $ovfResults
} catch {
    $resp.success = $false
    $resp.message = $_
}

$ProgressPreference = $progPref

$json = [pscustomobject]$resp | ConvertTo-Json
Write-Output -InputObject $json
