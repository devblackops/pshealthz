# Implementation of the Health Endpoint Monitoring Pattern using PowerShell 
# https://msdn.microsoft.com/en-us/library/dn589789.aspx

#requires -RunAsAdministrator

<#
.Synopsis
    Creates a new HTTP listener that executes Operation Validation Framework (OVF) tests and returns results using a simple REST API
.Description
    Creates a new HTTP listener that executes Operation Validation Framework (OVF) tests and returns results using a simple REST API
    This script must be run from an elevated administrator prompt.    

    Use Ctrl-C to stop the listener.  You'll need to send another web request to allow the listener to stop since
    it will be blocked waiting for a request.
.Parameter Port
    Port to listen on
.Parameter Path
    Path to listen on
.Parameter Auth
    Authentication Schemes to use, default is Anonymous
.Example
    Start-HealthzListener -Port 1938 -Path 'health' -Auth Anonymous    
.Example
    Start-HealthzListener -Port 8888 -Path 'endpointhealth' -Auth IntegratedWindowsAuthentication
#>
[cmdletbinding()]
param(
    [int]$Port = 1938,
    
    [string]$Path = 'health',

    [System.Net.AuthenticationSchemes]$Auth = [System.Net.AuthenticationSchemes]::Anonymous,

    [string]$LogDir = (Join-Path -Path $env:temp -ChildPath 'PSHealthZ'),

    [int]$LogFilesToKeep = 7
)

function New-HealthzToken {
    [System.Convert]::ToBase64String((New-guid).ToByteArray())
}

function Start-HTTPListener {    
    [cmdletbinding()]
    param (
        [int]$Port = 1938,

        [string]$Path = 'health',

        [System.Net.AuthenticationSchemes]$Auth = [System.Net.AuthenticationSchemes]::Anonymous,

        [string]$LogDir = (Join-Path -Path $env:temp -ChildPath 'PSHealthZ'),

        [int]$LogFilesToKeep = 7
    )

    process {

        $serverThreadCode = {
            $VerbosePreference = 'Continue'
            $Port = $args[0]
            $Path = $args[1]
            $Auth = $args[2]
            $LogDir = $args[3]
            $LogFilesToKeep = $args[4]

            if (-not (Test-Path -Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force
            }

            function Log {
                [cmdletbinding()]
                param(
                    [string]$Message
                )
                
                $logFile = Join-Path -Path $LogDir -ChildPath "$((Get-Date).ToString('yyyyMMdd')).log"
                Write-Verbose -Message $Message
                $Message | Out-File -FilePath $logFile -Encoding utf8 -Append -Force

                # Remove old logs
                $purgeDate = (Get-Date).AddDays(-1 * $LogFilesToKeep)
                Get-ChildItem -Path $LogDir -File | where { $_.CreationTime -lt $purgeDate }
            }

            function ConvertTo-HashTable {
                <#
                .Synopsis
                    Convert an object to a HashTable
                .Description
                    Convert an object to a HashTable excluding certain types.  For example, ListDictionaryInternal doesn't support serialization therefore
                    can't be converted to JSON.
                .Parameter InputObject
                    Object to convert
                .Parameter ExcludeTypeName
                    Array of types to skip adding to resulting HashTable.  Default is to skip ListDictionaryInternal and Object arrays.
                .Parameter MaxDepth
                    Maximum depth of embedded objects to convert.  Default is 4.
                .Example
                    $bios = get-ciminstance win32_bios
                    $bios | ConvertTo-HashTable
                #>
                [cmdletbinding()]
                Param (
                    [Parameter(Mandatory, ValueFromPipeline)]
                    [object]$InputObject,

                    [string[]]$ExcludeTypeName = @('ListDictionaryInternal', 'Object[]'),

                    [ValidateRange(1,10)]
                    [int]$MaxDepth = 4
                )

                process {
                    Write-Verbose -Message "Converting to hashtable $($InputObject.GetType())"
                    #$propNames = Get-Member -MemberType Properties -InputObject $InputObject | Select-Object -ExpandProperty Name
                    $propNames = $InputObject.psobject.Properties | Select-Object -ExpandProperty Name
                    $hash = @{}
                    $propNames | % {
                        if ($InputObject.$_ -ne $null) {
                            if ($InputObject.$_ -is [string] -or (Get-Member -MemberType Properties -InputObject ($InputObject.$_) ).Count -eq 0) {
                                $hash.Add($_,$InputObject.$_)
                            } else {
                                if ($InputObject.$_.GetType().Name -in $ExcludeTypeName) {
                                    Write-Verbose "Skipped $_"
                                } elseif ($MaxDepth -gt 1) {
                                    $hash.Add($_,(ConvertTo-HashTable -InputObject $InputObject.$_ -MaxDepth ($MaxDepth - 1)))
                                }
                            }
                        }
                    }
                    $hash
                }
            }

            function Compress-GZip {
                [cmdletbinding()]
                param (
                    [parameter(mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
                    [string]$InputObject
                )

                process {
                    $ms = New-Object System.IO.MemoryStream
                    $cs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
                    $sw = New-Object System.IO.StreamWriter($cs)
                    $sw.Write($InputObject)
                    $sw.Close();
                    $s = [System.Convert]::ToBase64String($ms.ToArray())
                    $s
                }
            }

            function Invoke-OVF {
                [cmdletbinding()]
                param(
                    [string]$Name
                )

                $sw = [System.Diagnostics.Stopwatch]::StartNew()

                Import-Module -Name Microsoft.PowerShell.Operation.Validation -Verbose:$false -ErrorAction Stop

                $resp = [ordered]@{
                    success = $true
                    time = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
                    timeElapsedMS = $null
                    message = ''
                    availableTests = @()
                    testResults = @()        
                }

                try {
                    $ovfTests = Microsoft.PowerShell.Operation.Validation\Get-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
                    $resp.availableTests = $ovfTests | foreach { $_.Name }

                    if ($PSBoundParameters.ContainsKey('Name')) {
                        if ($Name -eq 'all' -or $Name -eq '*') {
                            $ovfResults = $ovfTests | Microsoft.PowerShell.Operation.Validation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
                        } else {
                            $ovfResults = $ovfTests | where Name -eq $Name | Microsoft.PowerShell.Operation.Validation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
                        }
                        $resp.success = @($ovfResults | where Result -like 'Failed').Count -eq 0
                        $resp.testResults = $ovfResults | foreach {
                            [pscustomobject]@{
                                test = $_.RawResult.Name
                                module = $_.Module
                                passed = $_.RawResult.Passed
                                result = $_.Result                    
                                describe = $_.RawResult.Describe
                                context = $_.RawResult.Context
                                file = $_.FileName                                    
                                message = $_.RawResult.FailureMessage
                                duration = $_.RawResult.Time.ToString()
                            }
                        }
                    } else {
                        $resp.message = "PSHealthZ responds. Add query parameter '?test=<testname>' to execute specific test. Use '?test=*' or '?test=all' to execute all available tests."
                        $resp.success = $true
                    }
                } catch {
                    $resp.success = $false
                    $resp.message = $_
                }

                $ProgressPreference = $progPref

                # Add time take to execute test(s)
                $sw.Stop() 
                $resp.timeElapsedMS = $sw.Elapsed.TotalMilliseconds

                return [pscustomobject]$resp
            }
            
            $ErrorActionPreference = 'Stop'
            $progPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'

            if (($Path.Length -gt 0) -and (-not $Path.EndsWith('/'))) {
                $Path += '/'
            }

            $listener = New-Object System.Net.HttpListener
            $prefix = "http://*:$Port/$Path"
            $listener.Prefixes.Add($prefix)
            #$listener.AuthenticationSchemes = $Auth
            try {
                $listener.Start()
                #Write-Verbose -Message "Listening at $prefix with [$Auth] authentication..."
                Log -Message "Listening at $prefix with [$Auth] authentication..."
                while ($listener.IsListening) {
                    Write-Warning -Message 'Note that thread is blocked waiting for a request.  After using Ctrl-C to stop listening, you need to send a valid HTTP request to stop the listener cleanly.'
                    Write-Warning -Message "Sending 'exit' command will cause listener to stop immediately"

                    $context = $listener.GetContext()
                    $request = $context.Request

                    Log -Message "Received request from $($context.Request.RemoteEndPoint):"
                    Log -Message "Request`n$($request | Format-List -Property * | Out-String)"
                    #Write-Verbose -Message "Received request from $($context.Request.RemoteEndPoint):"
                    #Write-Verbose -Message "Request`n$($request | Format-List -Property * | Out-String)"

                    $command = $request.QueryString.Item('command')
                    if ($command -eq 'exit') {
                        Log -Message 'Received command to exit listener'
                        #Write-Verbose -Message 'Received command to exit listener'
                        return
                    }

                    $test = $null
                    if ($request.QueryString.HasKeys()) {

                        # Set content type if requested
                        if ($request.QueryString.Item('format') -eq 'application/xml') {
                            $format = 'application/xml'
                        } else {
                            $format = 'application/json'
                        }

                        # Requested test to execute
                        $test = $request.QueryString.Item('test')
                    }

                    # Execute requested test
                    $statusCode = 200
                    try {                    
                        if ($test) {
                            Log -Message "Requested test: $test"    
                            #Write-Verbose -Message "Requested test: $test"                        
                            $commandOutput = Invoke-OVF -Name $test
                        } else {
                            Log -Message 'No requested test. Listing available tests'
                            #Write-Verbose -Message 'No requested test. Listing available tests'
                            $commandOutput = Invoke-OVF
                        }
                    } catch {
                        $commandOutput = $_ | ConvertTo-HashTable
                        $statusCode = 500
                    }                
                    $cmdResponse = $commandOutput | ConvertTo-Json

                    # Setup response                
                    $response = $context.Response
                    $response.StatusCode = $statusCode
                    $response.ContentType = 'application/json'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($cmdResponse)
                    $response.ContentLength64 = $buffer.Length
                    #Write-Verbose 'Response:'
                    Log -Message 'Response:'
                    Log -Message ($response | Format-List -Property * | Out-String)
                    #Write-Verbose ($response | Format-List -Property * | Out-String)

                    # Return respons
                    $output = $response.OutputStream
                    $output.Write($buffer,0,$buffer.Length)
                    $output.Close()
                }
                $listener.Stop()
            } finally {
                $listener.Stop()
                $ProgressPreference = $progPref
            }
        }

        $job = Start-Job $serverThreadCode -ArgumentList ($Port, $Path, $Auth, $LogDir, $LogFilesToKeep)
        Write-Verbose -Message 'Listening...'
        Write-Verbose -Message 'Press Ctrl+C to terminate'

        [console]::TreatControlCAsInput = $true

        # Wait for it all to complete
        while ($job.HasMoreData -or $Job.State -eq 'Running') {
            if ([console]::KeyAvailable) {
                $key = [system.console]::readkey($true)
                if (($key.modifiers -band [consolemodifiers]'control') -and ($key.key -eq 'C')) {
                    Write-Verbose -Message 'Terminating...'
                    $job | Stop-Job
                    Remove-Job $job
                    break
                }
            }
            
            Start-Sleep -Seconds 1
        }
        
        # Getting the information back from the jobs
        Get-Job | Receive-Job
    }
}

Start-HTTPListener -Port $Port -Path $Path -Auth $Auth
