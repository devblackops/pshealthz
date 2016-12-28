
function Get-HealthZListener {
    <#
    .SYNOPSIS
        Gets running PSHealthZ listeners
    .DESCRIPTION
        Gets all currently running PSHealthZ listeners.
    .PARAMETER Id
        The Id of the listener to get.
    .EXAMPLE
        Get-HealthZListener

        Gets all currently running PSHealthZ listeners.

    .EXAMPLE
        Get-HealthZListener -Id 101

        Gets the PSHealthZ listener with Id 101.
    #>
    [OutputType([pscustomobject])]
    [cmdletbinding()]
    param(
        [int]$Id
    )

    $script:httpListeners.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{
            Id = $_.Name
            State = (Get-Job -Id $_.Name).State
            Uri = $_.Value.Uri
            Port = $_.Value.port
            Path = $_.Value.path
            Auth = $_.Value.auth
            SSL = $_.Value.ssl
            CertificateThumbprint = $_.Value.certificateThumbprint
            Token = $_.Value.token
            Log = $_.Value.log
            InstanceId = $_.Value.instanceId
        }
    }
}
