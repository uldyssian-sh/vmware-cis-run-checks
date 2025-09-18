# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by creating a private security advisory on GitHub:

1. Go to the [Security tab](https://github.com/uldyssian-sh/vmware-cis-run-checks/security)
2. Click "Report a vulnerability"
3. Provide detailed information about the vulnerability

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Within 30 days (depending on complexity)

## Security Best Practices

When using this tool:

1. **Credentials**: Never hardcode credentials in scripts
2. **Network**: Use secure connections (HTTPS/TLS)
3. **Permissions**: Run with minimal required privileges
4. **Updates**: Keep PowerCLI and dependencies updated
5. **Logging**: Secure log files containing sensitive information

## Security Features

- Read-only operations by design
- No credential storage
- Secure PowerCLI configuration
- Input validation and sanitization
- Comprehensive audit logging

## Compliance

This tool supports security compliance frameworks:

- CIS Controls
- NIST Cybersecurity Framework
- VMware Security Hardening Guides
- Enterprise Security Standards