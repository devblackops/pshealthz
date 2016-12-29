function Start-HealthZListener {
    <#
    .SYNOPSIS
        Starts a PSHealthZ listener instance.
    .DESCRIPTION
        Starts a PSHealthZ listener instance.
    .PARAMETER Port
        The port the listener will listen on.
    .PARAMETER Path
        The URl path to listen on (e.g., '/health').
    .PARAMETER Auth
        The authentication scheme to use. Defaults to anonymous.
    .PARAMETER AuthToken
        The authentication token to secure the endpoint with.
        If specified, the authentication scheme will be set to anonymous.
    .PARAMETER LogDir
        The log directory the listener will write to. A file with the listener instance Id will be created.
    .PARAMETER UseSSL
        Switch to indicate that a SSL certificate will be used. If specified the certificate thumbprint MUST be provided via the CertificateThumbprint parameter.
    .PARAMETER CertificateThumbprint
        The thumbprint of the certificate to use when using SSL. This parameter MUST be provided if using SSL. The certificate MUST be in the LocalMachine\My certificate store.
    .PARAMETER PassThru
        Return the newly created listener object.
    .EXAMPLE
        Start-HealthZListener

        Start a new PSHealthZ listener will default values.
    .EXAMPLE
        Start-HealthZListener -Port 8888 -Path myhealthendpoint

        Start a new PSHealthZ listener on a custom port and path.
    .EXAMPLE
        $token = New-HealthZToken
        $listener = Start-HealthZListener -AuthToken $token -PassThru
        $testResults = Invoke-RestMethod -Uri "http://localhost:1938/health?token=$token?module=*"

        Setup the listener with token authentication and execute all available tests.
    .EXAMPLE
        $thumbprint = '7D85481FE7D35AC4306AF2C4281879B73701D001'
        $listener = Start-HealthZListener -Port 8443 -UseSSL -CertificateThumbprint $thumbprint -PassThru

        Start a new PSHealthZ listener using SSL on port 8443.
    #>
    [OutputType([pscustomobject])]
    [cmdletbinding(SupportsShouldProcess,DefaultParameterSetName = 'auth')]
    param(
        [int]$Port = 1938,

        [string]$Path = 'health/',

        [parameter(ParameterSetName = 'auth')]
        [System.Net.AuthenticationSchemes]$Auth = [System.Net.AuthenticationSchemes]::Anonymous,

        [parameter(ParameterSetName = 'token')]
        [string]$AuthToken,

        [string]$LogDir = (Join-Path -Path $env:temp -ChildPath 'PSHealthZ'),

        [switch]$UseSSL,

        [ValidatePattern("^[0-9a-f]{40}$")]
        [string]$CertificateThumbprint,

        [switch]$PassThru
    )

    begin {
        # Validate that desired port is not already in use
        if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
            throw "Port $Port is already in use!"
            return
        }
    }

    process {
        # If using token-based authentication, set HTTP authentication to anonymous
        if ($PSCmdlet.ParameterSetName -eq 'token') {
            $Auth = [System.Net.AuthenticationSchemes]::Anonymous
        }

        # Make sure path always ends with '/'
        if (($Path.Length -gt 0) -and (-not $Path.EndsWith('/'))) {
            $Path += '/'
        }

        # HTTP or HTTPS
        $protocol = 'http'
        if ($PSBoundParameters.ContainsKey('UseSSL')) {
            if (-not $PSBoundParameters.ContainsKey('CertificateThumbprint')) {
                throw 'A certificate thumbprint MUST be provided when using SSL.'
            }
            $protocol = 'https'
        }

        # Determine final endpoint URL
        if ($Path -eq '/') {
            $endpoint = "$($protocol)://*:$Port/"
        } else {
            $endpoint = "$($protocol)://*:$Port/$Path"
        }

        if ($PSCmdlet.ShouldProcess($endpoint, 'Start PSHealthZ listener')) {

            # Create log directory
            if (-not (Test-Path -Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force -Verbose:$false | Out-Null
            }

            $listenerScript = {
                #[cmdletbinding(DefaultParameterSetName = 'auth')]
                [cmdletbinding()]
                param(
                    [parameter(Mandatory)]
                    [int]$Port,

                    [parameter(Mandatory)]
                    [string]$Path,

                    [parameter(Mandatory)]
                    [string]$Endpoint,

                    [System.Net.AuthenticationSchemes]$Auth,

                    [string]$AuthToken,

                    [bool]$UseSSL,

                    [string]$CertificateThumbprint,

                    [parameter(Mandatory)]
                    [string]$LogDir,

                    [parameter(Mandatory)]
                    [guid]$InstanceId
                )

                $VerbosePreference = 'Continue'

                $listener = New-Object System.Net.HttpListener

                $requestListener = {
                    [cmdletbinding()]
                    param($result)

                    [System.Net.HttpListener]$listener = $result.AsyncState;

                    # Call EndGetContext to complete the asynchronous operation.
                    $context = $listener.EndGetContext($result);

                    # Hand off the Context to the handler, it is in charge of responding.
                    & $requestProcessor $context

                    $listener.BeginGetContext((New-ScriptBlockCallback -Callback $requestListener), $listener)
                }

                $requestProcessor = {
                    [cmdletbinding()]
                    param(
                        $Context
                    )

                    $request = $Context.Request
                    Write-Log -Message "[Listener] Received request from $($context.Request.RemoteEndPoint)"
                    Write-Log -Message "Request details:`n$($request | Format-List -Property * | Out-String)"

                    $buffer = $null
                    $cmdResponse = [string]::Empty
                    $response = $context.Response
                    $statusCode = [System.Net.HttpStatusCode]::OK
                    $continue = $false

                    # Authorize request if using tokens
                    if ($null -ne $AuthToken -and $AuthToken -ne [string]::Empty) {
                        Write-Log -Message 'Inspecting token...'

                        # Check for token in headers or query string
                        if ($request.Headers['token'] -or ($request.QueryString.HasKeys() -and $request.QueryString.Item('token'))) {

                            # Validate token
                            if (Validate-Token -Request $request -AuthToken $AuthToken) {
                                Write-Log -Message 'Token matches'
                                $continue = $true
                            } else {
                                $msg = 'Token provided does not match server'
                                Write-Log -Message $msg
                                $cmdResponse = $msg
                                $statusCode = [System.Net.HttpStatusCode]::Unauthorized
                            }
                        } else {
                            $msg = 'Authorization token not provided in request. Sending 403.'
                            Write-Log -Message $msg
                            $cmdResponse = $msg
                            $statusCode = [System.Net.HttpStatusCode]::Unauthorized
                        }
                    } else {
                        $statusCode = [System.Net.HttpStatusCode]::OK
                        $continue = $true
                    }

                    # Requested test to execute
                    if ($continue) {
                        $test = $null
                        $module = $null
                        if ($request.QueryString.HasKeys()) {
                            $test = $request.QueryString.Item('test')
                            $module = $request.QueryString.Item('module')
                        }
                        try {
                            $invokeOVFParams = @{}
                            if ($test) {
                                $invokeOVFParams.Test = $test
                            }
                            if ($module) {
                                $invokeOVFParams.Module = $module
                            }
                            if ($test -or $Module) {
                                Write-Log -Message "Requesting test [$test] in module [$Module]"
                            } else {
                                Write-Log -Message 'No specific test requested. Listing all available tests.'
                            }
                            $commandOutput = Invoke-Ovf @invokeOVFParams
                        } catch {
                            $commandOutput = $_ | ConvertTo-Json
                            $statusCode = [System.Net.HttpStatusCode]::InternalServerError
                        }
                        $cmdResponse = $commandOutput | ConvertTo-Json
                    }

                    # Setup response
                    $response.StatusCode = $statusCode
                    $response.ContentType = 'application/json'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($cmdResponse)
                    $response.ContentLength64 = $buffer.Length
                    Write-Log -Message "Response: $($response | Format-List -Property * | Out-String)"

                    # Return response
                    $output = $response.OutputStream
                    $output.Write($buffer,0,$buffer.Length)
                    $output.Close()
                    $response.Close()
                }

                # Run a scriptblock from an .NET async callback via events
                # Thanks to http://poshcode.org/1382
                function New-ScriptBlockCallback {
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
                    param(
                        [parameter(Mandatory)]
                        [ValidateNotNullOrEmpty()]
                        [scriptblock]$Callback
                    )

                    # Is this type already defined?
                    if (-not ( 'CallbackEventBridge' -as [type])) {
                        Add-Type @'
                            using System;

                            public sealed class CallbackEventBridge {
                                public event AsyncCallback CallbackComplete = delegate { };

                                private CallbackEventBridge() {}

                                private void CallbackInternal(IAsyncResult result) {
                                    CallbackComplete(result);
                                }

                                public AsyncCallback Callback {
                                    get { return new AsyncCallback(CallbackInternal); }
                                }

                                public static CallbackEventBridge Create() {
                                    return new CallbackEventBridge();
                                }
                            }
'@
                    }
                    $bridge = [callbackeventbridge]::create()
                    Register-ObjectEvent -InputObject $bridge -EventName callbackcomplete -Action $Callback -MessageData $args > $null
                    $bridge.Callback
                }

                # Start HTTP(s) listener
                function Start-Server {
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
                    [cmdletbinding()]
                    param()

                    try {
                        Write-Log -Message "Prefix: $Endpoint"
                        $listener.Prefixes.Add($Endpoint)

                        if ($null -ne $AuthToken) {
                            Write-Log -Message "Starting HTTP(s) server listening at [$Endpoint] with [token-based] authentication..."
                            $listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous
                        } else {
                            Write-Log -Message "Starting HTTP(s) server listening at ]$Endpoint] with [$Auth] authentication..."
                            $listener.AuthenticationSchemes = $Auth
                        }
                        $listener.Start()

                        if ($UseSSL) {
                            Register-SSL
                        }

                        # Register the request listener scriptblock as the async callback
                        $listener.BeginGetContext((New-ScriptBlockCallback -Callback $requestListener), $listener) | Out-Null
                    } catch {
                        throw 'There were problems setting up the HTTP(s) listener.'
                        Stop-Server
                    }
                }

                # Stop HTTP(s) listener
                function Stop-Server {
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
                    [cmdletbinding()]
                    param()

                    Write-Log -Message 'Finished listening for requests. Shutting down HTTP server.'

                    # Remove SSL Binding
                    if ($UseSSL) {
                        $ipPort = "0.0.0.0:$Port"
                        Invoke-ConsoleCommand -Target $ipPort -Action 'removing SSL certificate binding' -ScriptBlock {
                            netsh http delete sslcert ipPort="$ipPort"
                        }
                        #netsh http delete sslcert ipport="0.0.0.0:$Port"
                    }

                    $listener.Close()
                    exit 0
                }

                # Bind SSL cert to listener port
                function Register-SSL {
                    [cmdletbinding()]
                    param()

                    begin {
                        $cert = Get-ChildItem -Path 'Cert:\LocalMachine\My' -Recurse  | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
                        if (-not $cert) {
                            throw "Unable to find certificate with thumbprint [$CertificateThumbprint]"
                        }
                    }

                    process {
                        try {
                            $ipPort = "0.0.0.0:$Port"

                            # Remove Previous SSL Bindings
                            Invoke-ConsoleCommand -Target $ipPort -Action 'removing SSL certificate binding' -ScriptBlock {
                                netsh http delete sslcert ipPort="$ipPort"
                            }
                            #netsh http delete sslcert ipport="$ipPort"

                            # Add SSL Certificate
                            Invoke-ConsoleCommand -Target $ipPort -Action 'creating SSL certificate binding' -ScriptBlock {
                                netsh http add sslcert ipport="$ipPort" certhash="$CertificateThumbprint" appid="{$InstanceId}"
                            }
                            #netsh http add sslcert ipport="$ipPort" certhash="$CertificateThumbprint" appid="{$InstanceId}"
                        } catch {
                            $msg = "Unable to bind SSL Certificate to port [$Port]. $($_.Exception.Message)"
                            Write-Log -Message $msg
                            throw $msg
                        }
                    }
                }

                # Invoke a console command and capture exit code
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

                # Execute specified OVF tests and return results
                function Invoke-Ovf {
                    [cmdletbinding()]
                    param(
                        [string]$Test = '*',
                        [string]$Module = '*'
                    )

                    $ovfModuleNames = @('OperationValidation', 'Microsoft.PowerShell.Operation.Validation')

                    # Track duration of testing
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()

                    Import-Module -Name Microsoft.PowerShell.Operation.Validation -Verbose:$false -ErrorAction Stop

                    $resp = [ordered]@{
                        success = $true
                        time = (get-date).ToUniversalTime().ToString('u')
                        timeElapsedMS = $null
                        message = ''
                        availableTests = @()
                        testResults = @()
                        failedTests = @()
                    }

                    try {
                        # Get OVF tests on the system
                        $filter = {
                            $leaf = Split-Path -Path $_.ModuleName -Leaf
                            if ($leaf -as [Version]) {
                                $moduleName = Split-Path -Path (Split-Path -Path $_.ModuleName -Parent) -Leaf
                            } else {
                                $moduleName = $leaf
                            }
                            $moduleName -notin $ovfModuleNames
                        }
                        $ovfTests = OperationValidation\Get-OperationValidation -ModuleName $Module -Verbose:$false -ErrorAction SilentlyContinue |
                            Where-Object $filter |
                            Where-Object {$_.Name -like $Test}
                        $resp.availableTests = $ovfTests | ForEach-Object {
                            $r = [ordered]@{
                                name = $_.Name
                            }
                            $leaf = Split-Path -Path $_.ModuleName -Leaf
                            if ($leaf -as [Version]) {
                                $r.module = Split-Path -Path (Split-Path -Path $_.ModuleName -Parent) -Leaf
                            } else {
                                $r.module = $leaf
                            }
                            [pscustomobject]$r
                        }

                        if ($PSBoundParameters.ContainsKey('Test') -or $PSBoundParameters.ContainsKey('Module')) {

                            # Execute the Pester/OVF tests
                            Import-Module -Name Pester -Verbose:$false -ErrorAction Stop
                            Write-Log -Message "Executing tests: `n$($ovfTests.Name)"
                            $ovfResults = $ovfTests | Where-Object Name -like $Test | OperationValidation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
                            $resp.success = @($ovfResults | Where-Object Result -like 'Failed').Count -eq 0

                            # All test results
                            $resp.testResults = $ovfResults | ForEach-Object {
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

                            # Only failed test results
                            $resp.failedTests = $ovfResults | Where-Object {$_.RawResult.Passed -eq $false } | ForEach-Object {
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
                            $resp.message = "PSHealthZ responds but does not execute tests without being told to. Add query parameter '?test=<testname>' and/or '?module=<modulename>' to execute a specific tests. Available tests are listed in the 'availableTests' property of this response. Use '?test=*' or '?module=*' to execute all available tests regardless of module. Specific tests can be executed by filtering with the 'test' and 'module' query parameters."
                            $resp.success = $true
                        }
                    } catch {
                        $resp.success = $false
                        $resp.message = $_
                    }

                    # Add time it took to execute test(s)
                    $sw.Stop()
                    $resp.timeElapsedMS = $sw.Elapsed.TotalMilliseconds

                    $o = [pscustomobject]$resp
                    Write-Log -Message "Test results:`n$($o | Format-List -Property * | Out-String)"
                    return $o
                }

                # Validate provided token from HTTP request against what
                # is configured in the listener
                function Validate-Token {
                    param(
                        $Request,
                        $AuthToken
                    )

                    # Token could be in headers or query string
                    if ($Request.Headers['token']) {
                        $providedToken = $Request.Headers['token']
                    } else {
                        $providedToken = $Request.QueryString.Item('token')
                    }

                    return ($providedToken -ceq $AuthToken)
                }

                function Write-Log {
                    [cmdletbinding()]
                    param(
                        [object]$Message
                    )

                    $now = (Get-Date).ToString('yyyy-MM-dd hh:mm:ss')
                    $log = Join-Path -Path $LogDir -ChildPath "$($InstanceId).log"
                    Write-Verbose -Message $Message
                    "[$now] $Message" | Out-File -FilePath $log -Encoding utf8 -Append -Force
                }

                Start-Server
                while($true) {
                    Start-Sleep -Milliseconds 100
                }
            }

            # Start the listener
            $instanceId = New-Guid
            $jobParams = @{
                Name = "PSHealthZHTTPListerner_$InstanceId"
                ScriptBlock = $listenerScript
                ArgumentList = @($Port, $Path, $endpoint, $Auth, $AuthToken, $PSBoundParameters.ContainsKey('UseSSL'), $CertificateThumbprint, $LogDir, $instanceId)
            }
            $job = Start-Job @jobParams

            Write-Verbose -Message "PSHealthZ HTTP listener starting at [$endpoint] with [$Auth] authentication"
            Write-Verbose -Message "Job Id: $($job.Id)"
            Write-Verbose -Message "To stop the listener run: Stop-HealthZListener -Id $($job.Id)"

            # Track the listener
            $listenerTracker = @{
                jobId = $job.Id
                port = $Port
                path = $Path
                uri = $endpoint
                ssl = $PSBoundParameters.ContainsKey('UseSSL')
                certificateThumbprint = $CertificateThumbprint
                auth = $Auth
                log = (Join-Path -Path $LogDir -ChildPath "$($instanceId).log")
                instanceId = $instanceId
            }
            if ($PSBoundParameters.ContainsKey('AuthToken')) {
                $listenerTracker.token = $AuthToken
            }
            $script:httpListeners.Add($job.Id, $listenerTracker)

            # Return listener object if told to
            if ($PSBoundParameters.ContainsKey('PassThru')) {
                return Get-HealthZListener -Id $job.Id
            }
        }
    }
}
