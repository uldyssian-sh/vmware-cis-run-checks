# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### Added
- Initial release of VMware CIS Run Checks
- Comprehensive CIS compliance checks for vSphere 8
- Read-only security assessment capabilities
- PowerShell module manifest for PowerShell Gallery
- Automated CI/CD pipeline with GitHub Actions
- Security scanning with Trivy and PSScriptAnalyzer
- Comprehensive documentation and examples
- SECURITY.md with security policy
- CODEOWNERS for code review management

### Security
- All operations are read-only by design
- No credential storage or logging
- Secure PowerCLI configuration
- Input validation and sanitization
- Comprehensive audit logging

### Features
- **Install Checks**: ESXi patching and VIB validation
- **Communication Checks**: Network services and certificates
- **Logging Checks**: Centralized and remote logging
- **Access Checks**: Authentication and user management
- **Console Checks**: Shell and lockdown configuration
- **Storage Checks**: iSCSI and SAN security
- **Network Checks**: vSwitch and vDS policies
- **VM Checks**: Virtual machine security settings

### Documentation
- Complete usage guide with examples
- Security best practices
- Troubleshooting guide
- API reference documentation

### Automation
- GitHub Actions workflows for CI/CD
- Automated security scanning
- PowerShell Gallery publishing
- Release automation with artifacts

## [Unreleased]

### Planned
- Enhanced reporting formats (JSON, XML, HTML)
- Integration with SIEM systems
- Custom compliance frameworks
- Remediation recommendations
- Performance optimizations# Updated 20251109_123812
