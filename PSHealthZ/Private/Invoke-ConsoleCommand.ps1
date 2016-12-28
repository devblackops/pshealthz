# From Carbon module (get-carbon.org)
# https://bitbucket.org/splatteredbits/carbon/src/05b30be36ba4105147c8a9cbcad815a366e9f553/Carbon/Functions/Invoke-ConsoleCommand.ps1?at=default&fileviewer=file-view-default

function Invoke-ConsoleCommand {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    Set-StrictMode -Version 'Latest'

    if(-not $PSCmdlet.ShouldProcess($Target, $Action)){
        return
    }

    $output = Invoke-Command -ScriptBlock $ScriptBlock
    if ($LASTEXITCODE) {
        $output = $output -join [Environment]::NewLine
        Write-Error ('Failed action ''{0}'' on target ''{1}'' (exit code {2}): {3}' -f $Action,$Target,$LASTEXITCODE,$output)
    } else {
        $output | Where-Object { $_ -ne $null } | Write-Verbose
    }
}
