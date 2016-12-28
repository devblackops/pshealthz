[cmdletbinding(DefaultParameterSetName = 'task')]
param(
    [parameter(ParameterSetName = 'task')]
    [string[]]$Task = 'default',

    [parameter(ParameterSetName = 'help')]
    [switch]$Help
)

function Resolve-Module {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Name
    )

    Process {
        foreach ($ModuleName in $Name) {
            $Module = Get-Module -Name $ModuleName -ListAvailable -Verbose:$false | Sort-Object -Property Version -Descending | Select -First 1
            Write-Verbose -Message "Resolving Module [$($ModuleName)]"
            
            if ($Module) {
                $Version = $Module | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
                $GalleryVersion = Find-Module -Name $ModuleName -Repository PSGallery -Verbose:$false | 
                    Measure-Object -Property Version -Maximum | 
                    Select-Object -ExpandProperty Maximum

                if ($Version -lt $GalleryVersion) {                                        
                    Write-Verbose -Message "$($ModuleName) Installed Version [$($Version.tostring())] is outdated. Installing Gallery Version [$($GalleryVersion.tostring())]"
                    
                    Install-Module -Name $ModuleName -Verbose:$false -Force
                    Import-Module -Name $ModuleName -Verbose:$false -Force -RequiredVersion $GalleryVersion
                }
                else {
                    Write-Verbose -Message "Module Installed, Importing [$($ModuleName)]"
                    Import-Module -Name $ModuleName -Verbose:$false -Force -RequiredVersion $Version
                }
            }
            else {
                Write-Verbose -Message "[$($ModuleName)] Missing, installing Module"
                Install-Module -Name $ModuleName -Verbose:$false -Force
                Import-Module -Name $ModuleName -Verbose:$false -Force -RequiredVersion $Version
            }
        }
    }
}

Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

'BuildHelpers', 'psake' | Resolve-Module

$psakeScript = "$PSScriptRoot\psake.ps1"

if ($PSCmdlet.ParameterSetName -eq 'task') {
    Set-BuildEnvironment -Verbose:$false

    Invoke-psake -buildFile $psakeScript  -taskList $Task -nologo -Verbose:$VerbosePreference
    exit ( [int]( -not $psake.build_success ) )
} else {
    Get-PSakeScriptTasks -buildFile $psakeScript | Select -Property Name, Description, Alias, DependsOn | Format-Table
}
