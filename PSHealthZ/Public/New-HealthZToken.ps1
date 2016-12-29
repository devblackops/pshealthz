
function New-HealthzToken {
    <#
    .SYNOPSIS
        Generates an authentication token to secure a PSHealthZ listener with.
    .DESCRIPTION
        Generates an authentication token to secure a PSHealthZ listener with.
    .EXAMPLE
        $token = New-HealthZToken

        Create a new token
    .EXAMPLE
        $token = New-HealthZToken
        $listener = Start-HealthzListener -Token $token -PassThru

        Start a listener using a token for authentication.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()

    Add-Type -AssemblyName 'System.Web'
    return [System.Web.HttpServerUtility]::UrlTokenEncode((New-guid).ToByteArray())
}
