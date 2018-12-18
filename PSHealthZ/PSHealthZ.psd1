@{
    RootModule        = 'PSHealthZ.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'd4027060-825a-4746-a9f6-5b6e537e2897'
    Author            = 'Brandon Olin'
    CompanyName       = 'Community'
    Copyright         = '(c) 2018 Brandon Olin. All rights reserved.'
    Description       = 'Basic HTTP listener written in PowerShell that executes Operation Validation Framework (OVF) tests and returns results using a simple REST API'
    PowerShellVersion = '3.0'
    RequiredModules   = @('Pester', 'OperationValidation')
    FunctionsToExport = @(
        'Get-HealthZListener',
        'New-HealthZListener',
        'New-HealthZToken',
        'Start-HealthZListener',
        'Stop-HealthZListener'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Pester', 'OVF', 'Operation', 'Validation', 'Infrastructure', 'Testing', 'REST', 'HealthZ', 'Health', 'Endpoint', 'PSEdition_Desktop', 'PSEdition_Core')
            LicenseUri   = 'https://raw.githubusercontent.com/devblackops/pshealthz/master/LICENSE'
            ProjectUri   = 'https://github.com/devblackops/pshealthz'
            IconUri      = ''
            ReleaseNotes = 'https://raw.githubusercontent.com/devblackops/pshealthz/master/CHANGELOG.md'
        }
    }
}

