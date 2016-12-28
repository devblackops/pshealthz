
# function Invoke-Ovf {
#     [cmdletbinding()]
#     param(
#         [string]$Name
#     )

#     $sw = [System.Diagnostics.Stopwatch]::StartNew()

#     Import-Module -Name Microsoft.PowerShell.Operation.Validation -Verbose:$false -ErrorAction Stop

#     $resp = [ordered]@{
#         success = $true
#         time = (get-date).ToString('yyyy-MM-dd hh:mm:ss')
#         timeElapsedMS = $null
#         message = ''
#         availableTests = @()
#         testResults = @()
#         failedTests = @()
#     }

#     try {
#         $ovfTests = Microsoft.PowerShell.Operation.Validation\Get-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
#         $resp.availableTests = $ovfTests | foreach { $_.Name }

#         if ($PSBoundParameters.ContainsKey('Name')) {
#             Import-Module -Name Pester -Verbose:$false -ErrorAction Stop
#             if ($Name -eq 'all' -or $Name -eq '*') {                        
#                 $ovfResults = $ovfTests | Microsoft.PowerShell.Operation.Validation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
#             } else {
#                 $ovfResults = $ovfTests | where Name -eq $Name | Microsoft.PowerShell.Operation.Validation\Invoke-OperationValidation -Verbose:$false -ErrorAction SilentlyContinue
#             }
#             $resp.success = @($ovfResults | where Result -like 'Failed').Count -eq 0
#             $resp.testResults = $ovfResults | foreach {
#                 [pscustomobject]@{
#                     test = $_.RawResult.Name
#                     module = $_.Module
#                     passed = $_.RawResult.Passed
#                     result = $_.Result
#                     describe = $_.RawResult.Describe
#                     context = $_.RawResult.Context
#                     file = $_.FileName
#                     message = $_.RawResult.FailureMessage
#                     duration = $_.RawResult.Time.ToString()
#                 }
#             }
#             $resp.failedTests = $ovfResults | where {$_.RawResult.Passed -eq $false } | foreach {
#                 [pscustomobject]@{
#                     test = $_.RawResult.Name
#                     module = $_.Module
#                     passed = $_.RawResult.Passed
#                     result = $_.Result
#                     describe = $_.RawResult.Describe
#                     context = $_.RawResult.Context
#                     file = $_.FileName
#                     message = $_.RawResult.FailureMessage
#                     duration = $_.RawResult.Time.ToString()
#                 }
#             }
#         } else {
#             $resp.message = "PSHealthZ responds. Add query parameter '?test=<testname>' to execute specific test. Use '?test=*' or '?test=all' to execute all available tests."
#             $resp.success = $true
#         }
#     } catch {
#         $resp.success = $false
#         $resp.message = $_
#     }

#     # Add time take to execute test(s)
#     $sw.Stop()
#     $resp.timeElapsedMS = $sw.Elapsed.TotalMilliseconds

#     return [pscustomobject]$resp
# }