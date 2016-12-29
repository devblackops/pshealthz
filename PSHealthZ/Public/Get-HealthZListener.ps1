
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
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int[]]$Id = @()
    )

    process {
        if ($Id.Count -gt 0) {
            foreach ($item in $Id) {
                if ($l = $script:httpListeners.$item) {
                    [pscustomobject][ordered]@{
                        Id = $l.jobId
                        State = (Get-Job -Id $l.jobId).State
                        Uri = $l.Uri
                        Port = $l.port
                        Path = $l.path
                        Auth = $l.auth
                        SSL = $l.ssl
                        CertificateThumbprint = $l.certificateThumbprint
                        Token = $l.token
                        Log = $l.log
                        InstanceId = $l.instanceId
                    }
                }
            }
        } else {
            $script:httpListeners.GetEnumerator() | ForEach-Object {
                [pscustomobject][ordered]@{
                    Id = $_.Value.jobId
                    State = (Get-Job -Id $_.Value.jobId).State
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
    }
}
