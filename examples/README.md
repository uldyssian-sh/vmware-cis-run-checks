# Usage Examples

## Basic Usage

### Simple CIS Check
```powershell
# Connect to vCenter and run all CIS checks
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
```

### Detailed Output
```powershell
# Show all findings including FAIL and NotImplemented items
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com" -ShowDetails
```

## Advanced Usage

### Automated Reporting
```powershell
# Run checks and save output to file
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com" | Tee-Object -FilePath "cis-report-$(Get-Date -Format 'yyyy-MM-dd').txt"
```

### Scheduled Execution
```powershell
# Create scheduled task for weekly CIS checks
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\vmware-cis-run-checks.ps1 -vCenter vcenter.company.com"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6AM
Register-ScheduledTask -TaskName "VMware CIS Checks" -Action $action -Trigger $trigger
```

### Multiple vCenter Environments
```powershell
# Check multiple vCenter servers
$vCenters = @("vcenter1.company.com", "vcenter2.company.com", "vcenter3.company.com")

foreach ($vCenter in $vCenters) {
    Write-Host "Checking $vCenter..." -ForegroundColor Green
    .\vmware-cis-run-checks.ps1 -vCenter $vCenter -ShowDetails | 
        Out-File -FilePath "cis-report-$($vCenter.Split('.')[0])-$(Get-Date -Format 'yyyy-MM-dd').txt"
}
```

## Integration Examples

### PowerShell Module Usage
```powershell
# Import as module
Import-Module .\VMware-CIS-Run-Checks.psd1

# Use with custom parameters
$results = .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
```

### CI/CD Pipeline Integration
```yaml
# Azure DevOps Pipeline example
- task: PowerShell@2
  displayName: 'Run VMware CIS Checks'
  inputs:
    targetType: 'filePath'
    filePath: 'vmware-cis-run-checks.ps1'
    arguments: '-vCenter $(vCenterServer)'
    pwsh: true
```

### JSON Output Processing
```powershell
# Convert results to JSON for further processing
$results = .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
$jsonResults = $results | ConvertTo-Json -Depth 3
$jsonResults | Out-File "cis-results.json"
```

## Filtering and Analysis

### Filter by Status
```powershell
# Show only failed checks
$results = .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
$results | Where-Object Status -eq "FAIL" | Format-Table
```

### Category-specific Analysis
```powershell
# Analyze only network-related checks
$results = .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
$results | Where-Object Category -like "*Network*" | Format-Table
```

### Export to CSV
```powershell
# Export results to CSV for spreadsheet analysis
$results = .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
$results | Export-Csv -Path "cis-results.csv" -NoTypeInformation
```

## Error Handling

### Connection Error Handling
```powershell
try {
    .\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
} catch {
    Write-Error "CIS check failed: $($_.Exception.Message)"
    # Send notification or log error
}
```

### Credential Management
```powershell
# Use stored credentials
$credential = Get-Credential
Connect-VIServer -Server "vcenter.company.com" -Credential $credential
.\vmware-cis-run-checks.ps1 -vCenter "vcenter.company.com"
```