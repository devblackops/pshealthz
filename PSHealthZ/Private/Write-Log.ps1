
# function Write-Log {
#     [cmdletbinding()]
#     param(
#         [string]$Message
#     )

#     $logFile = Join-Path -Path $LogDir -ChildPath "$((Get-Date).ToString('yyyyMMdd')).log"
#     Write-Verbose -Message $Message
#     $Message | Out-File -FilePath $logFile -Encoding utf8 -Append -Force

#     # Remove old logs
#     $purgeDate = (Get-Date).AddDays(-1 * $LogFilesToKeep)
#     Get-ChildItem -Path $LogDir -File | where { $_.CreationTime -lt $purgeDate }
# }
