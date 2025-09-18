@{
    RootModule = 'vmware-cis-run-checks.ps1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'uldyssian-sh'
    CompanyName = 'Community'
    Copyright = '(c) 2024 uldyssian-sh. All rights reserved.'
    Description = 'Read-only CIS compliance checks for VMware vSphere 8 environments'
    PowerShellVersion = '5.1'
    
    RequiredModules = @(
        @{
            ModuleName = 'VMware.PowerCLI'
            ModuleVersion = '13.0.0'
        }
    )
    
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('VMware', 'vSphere', 'CIS', 'Security', 'Compliance', 'Audit')
            LicenseUri = 'https://github.com/uldyssian-sh/vmware-cis-run-checks/blob/main/LICENSE'
            ProjectUri = 'https://github.com/uldyssian-sh/vmware-cis-run-checks'
            IconUri = ''
            ReleaseNotes = 'Initial release of VMware CIS Run Checks'
            Prerelease = ''
            RequireLicenseAcceptance = $false
            ExternalModuleDependencies = @('VMware.PowerCLI')
        }
    }
}