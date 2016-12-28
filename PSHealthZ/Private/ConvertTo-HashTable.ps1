
# function ConvertTo-HashTable {
#     <#
#     .Synopsis
#         Convert an object to a HashTable
#     .Description
#         Convert an object to a HashTable excluding certain types.  For example, ListDictionaryInternal doesn't support serialization therefore
#         can't be converted to JSON.
#     .Parameter InputObject
#         Object to convert
#     .Parameter ExcludeTypeName
#         Array of types to skip adding to resulting HashTable.  Default is to skip ListDictionaryInternal and Object arrays.
#     .Parameter MaxDepth
#         Maximum depth of embedded objects to convert.  Default is 4.
#     .Example
#         $bios = get-ciminstance win32_bios
#         $bios | ConvertTo-HashTable
#     #>
#     [cmdletbinding()]
#     Param (
#         [Parameter(Mandatory, ValueFromPipeline)]
#         [object]$InputObject,

#         [string[]]$ExcludeTypeName = @('ListDictionaryInternal', 'Object[]'),

#         [ValidateRange(1,10)]
#         [int]$MaxDepth = 4
#     )

#     process {
#         Write-Verbose -Message "Converting to hashtable $($InputObject.GetType())"
#         #$propNames = Get-Member -MemberType Properties -InputObject $InputObject | Select-Object -ExpandProperty Name
#         $propNames = $InputObject.psobject.Properties | Select-Object -ExpandProperty Name
#         $hash = @{}
#         $propNames | foreach {
#             if ($InputObject.$_ -ne $null) {
#                 if ($InputObject.$_ -is [string] -or (Get-Member -MemberType Properties -InputObject ($InputObject.$_) ).Count -eq 0) {
#                     $hash.Add($_,$InputObject.$_)
#                 } else {
#                     if ($InputObject.$_.GetType().Name -in $ExcludeTypeName) {
#                         Write-Verbose "Skipped $_"
#                     } elseif ($MaxDepth -gt 1) {
#                         $hash.Add($_,(ConvertTo-HashTable -InputObject $InputObject.$_ -MaxDepth ($MaxDepth - 1)))
#                     }
#                 }
#             }
#         }
#         $hash
#     }
# }
