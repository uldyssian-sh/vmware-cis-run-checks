# vmware-cis-run-checks.ps1

**Name**: vmware-cis-run-checks.ps1  
**Purpose**: Read-only CIS / Hardening style checks for VMware vSphere 8.  
**Author**: LT  
**Version**: 1.0  

---

## Overview

This script runs **read-only compliance checks** against VMware vSphere 8.  
It is based on common **CIS Benchmarks** and VMware’s **Hardening Guide** recommendations.  

- ✅ **No configuration changes** are made.  
- ✅ **All results are printed to the console**.  
- ✅ Provides **per-check results** and **summaries**.  
- ✅ Marks items as `PASS`, `FAIL`, `INFO`, or `NotImplemented`.  

---

## Disclaimer

This script is provided "as is", without any warranty of any kind.  
Use it at your own risk. You are solely responsible for reviewing, testing, and implementing it in your own environment.  

---

## Requirements

- PowerShell 7+ (or Windows PowerShell 5.1)  
- [VMware.PowerCLI](https://developer.vmware.com/powercli) module version 13+  

Install PowerCLI if not already installed:  

```powershell
Install-Module -Name VMware.PowerCLI -Scope CurrentUser

---

Usage

Run the script directly from PowerShell:
.\vmware-cis-run-checks.ps1 -vCenter "vcsa.lab.local"

Parameters:
- vCenter (mandatory): vCenter Server FQDN or IP.
- ShowDetails (optional): also display detailed failed and not implemented checks.

Example

Run full compliance check:
.\vmware-cis-run-checks.ps1 -vCenter "vcsa.lab.local"

Run with detailed failed/not-implemented results:
.\vmware-cis-run-checks.ps1 -vCenter "vcsa.lab.local" -ShowDetails

---

Example Output
Compliance Results (per check)

Category  Check                                    Object    Status Details
--------  -----                                    ------    ------ -------
5.Console Ensure-SSHIsDisabled                     esxi01    FAIL   Running=True
7.Network Ensure-vSwitchPromiscuousModeIsReject    vSwitch0  PASS   AllowPromiscuous=False
8.Virtual Machines Ensure-VMConsoleCopyOperations… test-vm1  FAIL   isolation.tools.copy.disable=False


Summary by Category and Status
=== Summary by Category and Status ===

Category                                      Status Count
--------                                      ------ -----
1.Install (ESXi host software / patching)     INFO       5
1.Install (ESXi host software / patching)     FAIL       2
2.Communication (ESXi host network services)  PASS      18
3.Logging (ESXi host logging/syslog)          PASS       8
5.Console (ESXi console & shell services)     FAIL       4
7.Network (vSwitch / vDS networking policies) PASS      67
8.Virtual Machines (Guest VM configuration)   FAIL     134
8.Virtual Machines (Guest VM configuration)   PASS     420


Overall Summary
=== Overall Summary ===

Status                                Count
------                                -----
PASS (compliant)                       530
FAIL (requires remediation)            140
INFO (informational only)               10
NotImplemented (manual check required)  35

---

Category Mapping
The script groups checks into 8 categories matching VMware vSphere 8 hardening areas:

| Category                | Component / Scope                 | Description                                                                  |
| ----------------------- | --------------------------------- | ---------------------------------------------------------------------------- |
| **1. Install**          | ESXi host software                | Patch levels, VIB acceptance levels, unauthorized modules                    |
| **2. Communication**    | ESXi host network services        | NTP, firewall, MOB, SNMP, certificates, VDS health checks                    |
| **3. Logging**          | ESXi host logging                 | Syslog persistence, remote logging, core dump                                |
| **4. Access**           | ESXi authentication & user mgmt   | Local accounts, password complexity, AD integration                          |
| **5. Console**          | ESXi console & shell services     | DCUI, ESXi Shell, SSH, CIM, Lockdown mode, session timeouts                  |
| **6. Storage**          | ESXi storage / iSCSI / SAN        | iSCSI CHAP authentication, SAN zoning/masking                                |
| **7. Network**          | vSwitch / vDS networking policies | Security policies (promiscuous, forged transmits, MAC changes), VLAN usage   |
| **8. Virtual Machines** | Guest VM configuration            | Device connections, console copy/paste/drag\&drop, advanced isolation, disks |

---

Notes
* PASS → compliant
* FAIL → remediation required
* INFO → informational only
* NotImplemented → not currently implemented in script, or requires manual verification (e.g., AD policy, SAN zoning)
