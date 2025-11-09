# Testing Framework

## Overview

This directory contains tests for the VMware CIS Run Checks script to ensure reliability and correctness.

## Test Categories

### 1. Unit Tests
- Function validation
- Parameter handling
- Error conditions
- Output formatting

### 2. Integration Tests
- vCenter connectivity
- PowerCLI module compatibility
- End-to-end workflow

### 3. Security Tests
- Input validation
- Credential handling
- Output sanitization

## Running Tests

### Prerequisites
```powershell
# Install Pester testing framework
Install-Module -Name Pester -Force -SkipPublisherCheck
```

### Execute Tests
```powershell
# Run all tests
Invoke-Pester -Path .\tests\

# Run specific test file
Invoke-Pester -Path .\tests\Unit.Tests.ps1

# Generate coverage report
Invoke-Pester -Path .\tests\ -CodeCoverage .\vmware-cis-run-checks.ps1
```

## Test Structure

```
tests/
├── Unit.Tests.ps1          # Unit tests for individual functions
├── Integration.Tests.ps1   # Integration tests with mock vCenter
├── Security.Tests.ps1      # Security validation tests
└── Performance.Tests.ps1   # Performance and load tests
```

## Mock Data

Tests use mock vCenter data to simulate various environment configurations:
- Different ESXi versions
- Various security configurations
- Network topologies
- VM configurations

## Continuous Testing

Tests are automatically executed in CI/CD pipeline:
- On every pull request
- Before releases
- Scheduled weekly runs

## Test Coverage Goals

- **Unit Tests**: >90% code coverage
- **Integration Tests**: All major workflows
- **Security Tests**: All input vectors
- **Performance Tests**: Baseline metrics# Updated 20251109_123812
# Updated Sun Nov  9 12:49:56 CET 2025
