
function Stop-HealthZListener {
    <#
    .SYNOPSIS
        Stop a currently running PSHealthZ listener.
    .DESCRIPTION
        Stop a currently running PSHealthZ listener.
    .PARAMETER Id
        The Id of the listener to stop.
    .EXAMPLE
        Stop-HealthZListener -Id 101

        Stop the listener with Id 101.

    .EXAMPLE
        Get-HealthZListener | Stop-HealthZListener

        Gets all running listeners and stops them.
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int[]]$Id
    )

    begin {
        $remove = @()
    }

    process {
        foreach ($jobId in $Id) {
            if ($PSCmdlet.ShouldProcess($jobId, 'Stop listener')) {
                $listener = $script:httpListeners.$jobId
                if ($listener) {

                    # Remove Previous SSL Bindings
                    if ($listener.SSL) {
                        Write-Verbose -Message "Removing SSL binding for port [$($listener.Port)] and certificate [$($listener.CertificateThumbprint)]"
                        $ipPort = "0.0.0.0:$($listener.Port)"
                        Invoke-ConsoleCommand -Target $ipPort -Action 'removing SSL certificate binding' -ScriptBlock {
                            netsh http delete sslcert ipPort="$ipPort"
                        } -Verbose:$false
                    }

                    Write-Verbose -Message "Stopping listener Id: $jobId"
                    Stop-Job -Id $jobId -Verbose:$false
                    Remove-Job -Id $JobId -Verbose:$false
                    $remove += $jobId
                } else {
                    throw "Unable to find listener instance with Id [$Id]"
                }
            }
        }
    }

    end {
        # Remove this job from tracking
        $remove | ForEach-Object {
            $script:httpListeners.Remove($_)
        }
    }
}
