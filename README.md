# VMware CIS Run Checks

[![CI](https://github.com/uldyssian-sh/vmware-cis-run-checks/workflows/CI/badge.svg)](https://github.com/uldyssian-sh/vmware-cis-run-checks/actions)
[![Security](https://github.com/uldyssian-sh/vmware-cis-run-checks/workflows/Security%20Scan/badge.svg)](https://github.com/uldyssian-sh/vmware-cis-run-checks/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)

## Overview

Enterprise-grade PowerShell script for performing comprehensive CIS (Center for Internet Security) compliance assessments on VMware vSphere 8 environments. All operations are read-only and designed for production use.

**Technology Stack:** PowerShell, VMware PowerCLI, vSphere API  
**Compliance Framework:** CIS Controls v8, VMware Security Hardening Guidelines  
**Target Platform:** VMware vSphere 8.0+

## Features

- **Comprehensive Security Assessment** - 100+ CIS compliance checks across 8 security domains
- **Read-Only Operations** - No configuration changes, safe for production environments
- **Enterprise Ready** - Optimized for large-scale VMware infrastructures
- **Detailed Reporting** - Structured output with remediation guidance
- **Automated Execution** - CI/CD pipeline integration support

## Quick Start

### Prerequisites

```powershell
# Required PowerShell version
$PSVersionTable.PSVersion  # Must be 5.1 or higher

# Install VMware PowerCLI
Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Installation

```bash
git clone https://github.com/uldyssian-sh/vmware-cis-run-checks.git
cd vmware-cis-run-checks
```

### Basic Usage

```powershell
# Standard CIS compliance check
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"

# Detailed output with all findings
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com" -ShowDetails
```

## Security Domains

| Domain | Checks | Description |
|--------|--------|-------------|
| **Install** | 4 | ESXi host software and patching validation |
| **Communication** | 9 | Network services and certificate security |
| **Logging** | 3 | Centralized logging and audit configuration |
| **Access** | 8 | Authentication and user management controls |
| **Console** | 11 | Shell access and lockdown mode settings |
| **Storage** | 3 | iSCSI and SAN security configurations |
| **Network** | 8 | vSwitch and distributed switch policies |
| **Virtual Machines** | 50+ | Guest VM security and isolation controls |

## Output Interpretation

### Status Codes
- **PASS** - Configuration meets CIS recommendations
- **FAIL** - Remediation required for compliance
- **INFO** - Informational finding, review recommended
- **NotImplemented** - Manual verification required

### Sample Output
```
Category                Check                                    Object          Status  Details
--------                -----                                    ------          ------  -------
1.Install              Ensure-ESXiIsProperlyPatched             esxi01.lab.com  INFO    Reported: 8.0.2 build 22380479
2.Communication        Ensure-NTPTimeSynchronizationIsConfigured esxi01.lab.com  PASS    Servers=pool.ntp.org; Running=True
5.Console              Ensure-SSHIsDisabled                     esxi01.lab.com  FAIL    Running=True
```

## Advanced Usage

### Automated Reporting
```powershell
# Generate timestamped report
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com" | 
    Out-File "CIS-Report_$timestamp.txt"
```

### Multiple vCenter Assessment
```powershell
$vCenters = @("vc01.company.com", "vc02.company.com")
foreach ($vc in $vCenters) {
    .\vmware-cis-run-checks.ps1 -vCenter $vc -ShowDetails |
        Out-File "CIS-Report_$($vc.Split('.')[0])_$(Get-Date -Format 'yyyy-MM-dd').txt"
}
```

### CI/CD Integration
```yaml
# Azure DevOps Pipeline
- task: PowerShell@2
  displayName: 'VMware CIS Compliance Check'
  inputs:
    targetType: 'filePath'
    filePath: 'vmware-cis-run-checks.ps1'
    arguments: '-vCenter $(vCenterFQDN)'
```

## Security Considerations

- **Credentials**: Use service accounts with read-only permissions
- **Network**: Ensure secure connectivity to vCenter Server
- **Logging**: Review output for sensitive information before sharing
- **Compliance**: Regular execution recommended (weekly/monthly)

## Troubleshooting

### Common Issues

**PowerCLI Connection Errors**
```powershell
# Configure certificate handling
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
```

**Permission Denied**
```powershell
# Verify read-only access to vCenter
Get-VIPermission -Principal "domain\serviceaccount"
```

**Module Not Found**
```powershell
# Install required modules
Install-Module VMware.PowerCLI -Force -AllowClobber
Import-Module VMware.PowerCLI
```

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/enhancement`
3. Commit changes: `git commit -m 'Add enhancement'`
4. Push branch: `git push origin feature/enhancement`
5. Submit Pull Request

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/uldyssian-sh/vmware-cis-run-checks/issues)
- **Documentation**: [Wiki](https://github.com/uldyssian-sh/vmware-cis-run-checks/wiki)
- **Security**: [Security Policy](SECURITY.md)

---

**Enterprise VMware Security Assessment Tool**  
*Developed by [uldyssian-sh](https://github.com/uldyssian-sh)*