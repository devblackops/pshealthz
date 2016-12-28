
# function Compress-GZip {
#     [cmdletbinding()]
#     param (
#         [parameter(mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
#         [string]$InputObject
#     )

#     process {
#         $ms = New-Object System.IO.MemoryStream
#         $cs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
#         $sw = New-Object System.IO.StreamWriter($cs)
#         $sw.Write($InputObject)
#         $sw.Close();
#         $s = [System.Convert]::ToBase64String($ms.ToArray())
#         $s
#     }
# }
