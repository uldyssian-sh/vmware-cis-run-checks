# VMware CIS Run Checks Documentation

## Overview

This tool performs comprehensive CIS (Center for Internet Security) compliance checks for VMware vSphere 8 environments. All checks are read-only and do not modify any configuration.

## Supported Checks

### 1. Install (ESXi Host Software/Patching)
- ESXi patch level verification
- VIB acceptance level validation
- Unauthorized module detection
- Default salt configuration

### 2. Communication (ESXi Host Network Services)
- NTP time synchronization
- Host firewall configuration
- MOB (Managed Object Browser) status
- Certificate validation
- SNMP configuration
- dvfilter settings
- VDS health check status

### 3. Logging (ESXi Host Logging/Syslog)
- Centralized host dumps
- Persistent logging configuration
- Remote logging setup

### 4. Access (ESXi Authentication & User Management)
- Non-root admin accounts
- Password complexity requirements
- Login attempt limits
- Account lockout policies
- Active Directory integration

### 5. Console (ESXi Console & Shell Services)
- DCUI timeout settings
- ESXi Shell status
- SSH service status
- CIM access limitations
- Lockdown mode configuration
- Shell timeout settings

### 6. Storage (ESXi Storage/iSCSI/SAN)
- Bidirectional CHAP authentication
- CHAP secret uniqueness
- SAN resource segregation

### 7. Network (vSwitch/vDS Networking Policies)
- Forged transmits policy
- MAC address change policy
- Promiscuous mode policy
- VLAN configuration
- Netflow configuration
- Port-level overrides

### 8. Virtual Machines (Guest VM Configuration)
- Remote connection limits
- Unnecessary device removal
- Device modification restrictions
- Console operation controls
- VM limits and resource allocation
- Logging configuration

## Usage Examples

### Basic Compliance Check
```powershell
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.example.com"
```

### Detailed Output
```powershell
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.example.com" -ShowDetails
```

## Output Interpretation

### Status Codes
- **PASS**: Configuration meets CIS recommendations
- **FAIL**: Configuration requires remediation
- **INFO**: Informational finding, review recommended
- **NotImplemented**: Manual verification required

### Report Sections
1. **Detailed Results**: Individual check results by category
2. **Category Summary**: Results grouped by security domain
3. **Overall Summary**: Total counts by status

## Security Considerations

- Script requires only read-only access to vCenter
- No configuration changes are performed
- Credentials are not stored or logged
- All connections use secure protocols
- Comprehensive audit trail generated

## Troubleshooting

### Common Issues
1. **PowerCLI Module Missing**: Install VMware.PowerCLI module
2. **Connection Failures**: Verify vCenter connectivity and credentials
3. **Permission Errors**: Ensure read-only access to vCenter
4. **Certificate Errors**: Configure PowerCLI certificate handling

### Support
- Create issues on GitHub repository
- Review existing documentation
- Check PowerCLI compatibility# Updated 20251109_123812
# Updated Sun Nov  9 12:49:56 CET 2025
# Updated Sun Nov  9 12:52:24 CET 2025
