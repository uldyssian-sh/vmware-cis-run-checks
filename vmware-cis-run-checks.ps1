<#
================================================================================
 Name     : vmware-cis-run-checks.ps1
 Purpose  : Read-only CIS / Hardening style checks for VMware vSphere 8.
            Prints results to console and a final summary.
 Author   : Paladin alias LT
 Version  : 1.0
 Target   : VMware vSphere 8

 DISCLAIMER
 ----------
 This script is provided "as is", without any warranty of any kind.
 Use it at your own risk. You are solely responsible for reviewing,
 testing, and implementing it in your own environment.

 NOTES
 -----
 - Read-only: no configuration changes are performed.
 - Some checks are marked NotImplemented where precise verification
   is not reliably available via PowerCLI alone.
================================================================================
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$vCenter,
  [switch]$ShowDetails       # also list all FAIL/NotImplemented items
)

# --- Setup ----------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
  throw "VMware.PowerCLI module is required. Install-Module VMware.PowerCLI"
}
Import-Module VMware.PowerCLI -ErrorAction Stop | Out-Null
Import-Module VMware.VimAutomation.Vds -ErrorAction SilentlyContinue | Out-Null
Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

Write-Host "Connecting to $vCenter ..." -ForegroundColor Cyan
$null = Connect-VIServer -Server $vCenter

# --- Result collector -----------------------------------------------------
$global:Results = New-Object System.Collections.Generic.List[object]
function Add-CheckResult {
  param(
    [string]$Category,
    [string]$Check,
    [string]$Object,
    [ValidateSet('PASS','FAIL','NotImplemented','INFO')][string]$Status,
    [string]$Details
  )
  $global:Results.Add([PSCustomObject]@{
    Category = $Category
    Check    = $Check
    Object   = $Object
    Status   = $Status
    Details  = $Details
  })
}

# Helper to convert bool -> PASS/FAIL (PS 5.1 compatible)
function To-Status([bool]$ok) { if ($ok) { 'PASS' } else { 'FAIL' } }

# --- Utility helpers ------------------------------------------------------
function Get-AdvValue {
  param($Entity, [string]$Name)
  try { (Get-AdvancedSetting -Entity $Entity -Name $Name -ErrorAction Stop).Value } catch { $null }
}

function BoolVal([object]$v) { try { return [bool]$v } catch { return $false } }

# ESXCLI acceptance level (portable)
function Get-HostAcceptanceLevel {
  param([VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost)
  try {
    $e2 = Get-EsxCli -VMHost $VMHost -V2
    ($e2.software.acceptance.get.Invoke()).AcceptanceLevel
  } catch {
    try { (Get-EsxCli -VMHost $VMHost).software.acceptance.get() } catch { $null }
  }
}

# ==========================================================================#
#                               1. INSTALL                                  #
# ==========================================================================#
function Ensure-ESXiIsProperlyPatched {
  $cat='1.Install'
  foreach($h in Get-VMHost){
    $ver = "$($h.Version) build $($h.Build)"
    Add-CheckResult $cat 'Ensure-ESXiIsProperlyPatched' $h.Name 'INFO' "Reported: $ver"
  }
}

function Ensure-VIBAcceptanceLevelIsConfiguredProperly {
  $cat='1.Install'
  foreach($h in Get-VMHost){
    $acc = Get-HostAcceptanceLevel -VMHost $h
    $ok  = $acc -in @('PartnerSupported','VMwareAccepted')
    Add-CheckResult $cat 'Ensure-VIBAcceptanceLevelIsConfiguredProperly' $h.Name (To-Status $ok) "AcceptanceLevel=$acc"
  }
}

function Ensure-UnauthorizedModulesNotLoaded {
  $cat='1.Install'
  foreach($h in Get-VMHost){
    Add-CheckResult $cat 'Ensure-UnauthorizedModulesNotLoaded' $h.Name 'NotImplemented' 'Requires defined forbidden module list'
  }
}

function Ensure-DefaultSaultIsConfiguredProperly {
  $cat='1.Install'
  foreach($h in Get-VMHost){
    Add-CheckResult $cat 'Ensure-DefaultSaultIsConfiguredProperly' $h.Name 'NotImplemented' 'Setting not exposed via PowerCLI'
  }
}

# ==========================================================================#
#                            2. COMMUNICATION                               #
# ==========================================================================#
function Ensure-NTPTimeSynchronizationIsConfiguredProperly {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    $servers = Get-VMHostNtpServer -VMHost $h -ErrorAction SilentlyContinue
    $svcNtp  = Get-VMHostService -VMHost $h | Where-Object { $_.Key -eq 'ntpd' }
    $ok = ($servers -and $servers.Count -gt 0 -and $svcNtp -and $svcNtp.Running)
    Add-CheckResult $cat 'Ensure-NTPTimeSynchronizationIsConfiguredProperly' $h.Name (To-Status $ok) "Servers=$($servers -join ','); Running=$($svcNtp.Running)"
  }
}

function Ensure-ESXiHostFirewallIsProperlyConfigured {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    try {
      $pol = Get-VMHostFirewallDefaultPolicy -VMHost $h
      $ok = (-not $pol.AllowIncoming)   # inbound should not be allowed by default
      Add-CheckResult $cat 'Ensure-ESXiHostFirewallIsProperlyConfigured' $h.Name (To-Status $ok) "AllowIncoming=$($pol.AllowIncoming); AllowOutgoing=$($pol.AllowOutgoing)"
    } catch {
      Add-CheckResult $cat 'Ensure-ESXiHostFirewallIsProperlyConfigured' $h.Name 'NotImplemented' 'Could not read default policy'
    }
  }
}

function Ensure-MOBIsDisabled {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    $v = Get-AdvValue $h 'Config.HostAgent.plugins.solo.enableMob'
    $ok = -not (BoolVal $v)
    Add-CheckResult $cat 'Ensure-MOBIsDisabled' $h.Name (To-Status $ok) "Config.HostAgent.plugins.solo.enableMob=$v"
  }
}

function Ensure-DefaultSelfSignedCertificateIsNotUsed {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    Add-CheckResult $cat 'Ensure-DefaultSelfSignedCertificateIsNotUsed' $h.Name 'NotImplemented' 'Certificate issuer/age not evaluated'
  }
}

function Ensure-SNMPIsConfiguredProperly {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    try {
      $snmp = Get-VMHostSnmp -VMHost $h
      $ok = $snmp.Enabled -and ($snmp.Community -and ($snmp.Community -ne 'public'))
      Add-CheckResult $cat 'Ensure-SNMPIsConfiguredProperly' $h.Name (To-Status $ok) "Enabled=$($snmp.Enabled); Community=$($snmp.Community)"
    } catch {
      Add-CheckResult $cat 'Ensure-SNMPIsConfiguredProperly' $h.Name 'NotImplemented' 'SNMP state unavailable'
    }
  }
}

function Ensure-dvfilterIsDisabled {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    $val = Get-AdvValue $h 'Net.DVFilterBindIpAddress'
    $ok  = [string]::IsNullOrEmpty($val)
    Add-CheckResult $cat 'Ensure-dvfilterIsDisabled' $h.Name (To-Status $ok) "Net.DVFilterBindIpAddress='$val'"
  }
}

function Ensure-DefaultExpiredOrRevokedCertificateIsNotUsed {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    Add-CheckResult $cat 'Ensure-DefaultExpiredOrRevokedCertificateIsNotUsed' $h.Name 'NotImplemented' 'CRL/expiry validation not implemented'
  }
}

function Ensure-vSphereAuthenticationProxyIsUsedWithAD {
  $cat='2.Communication'
  foreach($h in Get-VMHost){
    Add-CheckResult $cat 'Ensure-vSphereAuthenticationProxyIsUsedWithAD' $h.Name 'NotImplemented' 'Auth Proxy detection not implemented'
  }
}

function Ensure-VDSHealthCheckIsDisabled {
  $cat='2.Communication'
  $vdss = Get-VDSwitch -ErrorAction SilentlyContinue
  if ($vdss) {
    foreach($vds in $vdss){
      try {
        $hc = $vds.ExtensionData.Config.HealthCheckConfig
        $teaming = ($hc | Where-Object {$_.Enable -and $_.HealthCheckType -eq 'teamingHealthCheck'})
        $mtu     = ($hc | Where-Object {$_.Enable -and $_.HealthCheckType -eq 'mtuHealthCheck'})
        $ok = -not $teaming -and -not $mtu
        Add-CheckResult $cat 'Ensure-VDSHealthCheckIsDisabled' $vds.Name (To-Status $ok) "TeamingHC=$([bool]$teaming); MTUHC=$([bool]$mtu)"
      } catch {
        Add-CheckResult $cat 'Ensure-VDSHealthCheckIsDisabled' $vds.Name 'NotImplemented' 'Cannot read HealthCheckConfig'
      }
    }
  } else {
    Add-CheckResult $cat 'Ensure-VDSHealthCheckIsDisabled' 'No-VDS' 'INFO' 'No VDSwitches found'
  }
}

# ==========================================================================#
#                               3. LOGGING                                  #
# ==========================================================================#
function Ensure-CentralizedESXiHostDumps {
  $cat='3.Logging'
  foreach($h in Get-VMHost){
    try {
      $cd = Get-VMHostNetworkCoreDump -VMHost $h
      $ok = ($cd.Enabled -and $cd.NetworkCoreDumpEnabled)
      Add-CheckResult $cat 'Ensure-CentralizedESXiHostDumps' $h.Name (To-Status $ok) "Enabled=$($cd.Enabled); NetEnabled=$($cd.NetworkCoreDumpEnabled); Server=$($cd.NetworkServerIpAddress)"
    } catch {
      Add-CheckResult $cat 'Ensure-CentralizedESXiHostDumps' $h.Name 'NotImplemented' 'Core dump state not available'
    }
  }
}

function Ensure-PersistentLoggingIsConfigured {
  $cat='3.Logging'
  foreach($h in Get-VMHost){
    $dir = Get-AdvValue $h 'Syslog.global.logDir'
    $ok  = -not [string]::IsNullOrWhiteSpace($dir)
    Add-CheckResult $cat 'Ensure-PersistentLoggingIsConfigured' $h.Name (To-Status $ok) "Syslog.global.logDir='$dir'"
  }
}

function Ensure-RemoteLoggingIsConfigured {
  $cat='3.Logging'
  foreach($h in Get-VMHost){
    $logHost = Get-AdvValue $h 'Syslog.global.logHost'
    $ok   = -not [string]::IsNullOrWhiteSpace($logHost)
    Add-CheckResult $cat 'Ensure-RemoteLoggingIsConfigured' $h.Name (To-Status $ok) "Syslog.global.logHost='$logHost'"
  }
}

# ==========================================================================#
#                                4. ACCESS                                  #
# ==========================================================================#
function Ensure-NonRootExistsForLocalAdmin {
  $cat='4.Access'
  foreach($h in Get-VMHost){
    try {
      $accts = Get-VMHostAccount -VMHost $h -Id * -ErrorAction Stop
      $nonRootAdmins = $accts | Where-Object { $_.Id -ne 'root' -and $_.Role -match 'Admin' }
      Add-CheckResult $cat 'Ensure-NonRootExistsForLocalAdmin' $h.Name (To-Status ($null -ne $nonRootAdmins -and $nonRootAdmins.Count -gt 0)) "Non-root admin accounts: $(@($nonRootAdmins.Id) -join ',')"
    } catch {
      Add-CheckResult $cat 'Ensure-NonRootExistsForLocalAdmin' $h.Name 'NotImplemented' 'Cannot read local accounts'
    }
  }
}

function Ensure-PasswordsAreRequiredToBeComplex                 { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-PasswordsAreRequiredToBeComplex'                 $h.Name 'NotImplemented' 'ESXi PAM policy check not implemented' } }
function Ensure-LoginAttemptsIsSetTo5                           { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-LoginAttemptsIsSetTo5'                           $h.Name 'NotImplemented' 'Lockout threshold (PAM) not implemented' } }
function Ensure-AccountLockoutIsSetTo15Minutes                  { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-AccountLockoutIsSetTo15Minutes'                  $h.Name 'NotImplemented' 'Lockout duration (PAM) not implemented' } }
function Ensure-Previous5PasswordsAreProhibited                 { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-Previous5PasswordsAreProhibited'                 $h.Name 'NotImplemented' 'Password history (PAM) not implemented' } }
function Ensure-ADIsUsedForAuthentication                       { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-ADIsUsedForAuthentication'                       $h.Name 'NotImplemented' 'ESXi AD join state not implemented' } }
function Ensure-OnlyAuthorizedUsersBelongToEsxAdminsGroup       { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-OnlyAuthorizedUsersBelongToEsxAdminsGroup'       $h.Name 'NotImplemented' 'Requires directory query' } }
function Ensure-ExceptionUsersIsConfiguredManually              { $cat='4.Access'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-ExceptionUsersIsConfiguredManually'              $h.Name 'NotImplemented' 'Policy-specific' } }

# ==========================================================================#
#                               5. CONSOLE                                  #
# ==========================================================================#
function Ensure-DCUITimeOutIs600 {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $v = [int](Get-AdvValue $h 'UserVars.DcuiTimeOut')
    $ok = ($v -ge 600)
    Add-CheckResult $cat 'Ensure-DCUITimeOutIs600' $h.Name (To-Status $ok) "UserVars.DcuiTimeOut=$v"
  }
}

function Ensure-ESXiShellIsDisabled {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $svcTSM = Get-VMHostService -VMHost $h | Where-Object { $_.Key -eq 'TSM' }
    $ok = ($svcTSM -and -not $svcTSM.Running)
    Add-CheckResult $cat 'Ensure-ESXiShellIsDisabled' $h.Name (To-Status $ok) "Running=$($svcTSM.Running)"
  }
}

function Ensure-SSHIsDisabled {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $svcSSH = Get-VMHostService -VMHost $h | Where-Object { $_.Key -eq 'TSM-SSH' }
    $ok = ($svcSSH -and -not $svcSSH.Running)
    Add-CheckResult $cat 'Ensure-SSHIsDisabled' $h.Name (To-Status $ok) "Running=$($svcSSH.Running)"
  }
}

function Ensure-CIMAccessIsLimited {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $svcCim = Get-VMHostService -VMHost $h | Where-Object { $_.Key -eq 'sfcbd-watchdog' }
    $ok = ($svcCim -and -not $svcCim.Running) -or (-not $svcCim)
    Add-CheckResult $cat 'Ensure-CIMAccessIsLimited' $h.Name (To-Status $ok) "sfcbd-watchdog Running=$($svcCim.Running)"
  }
}

function Ensure-NormalLockDownIsEnabled {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $mode = $h.ExtensionData.Config.LockdownMode
    $ok = ($mode -eq 'lockdownNormal' -or $mode -eq 'lockdownStrict')
    Add-CheckResult $cat 'Ensure-NormalLockDownIsEnabled' $h.Name (To-Status $ok) "LockdownMode=$mode"
  }
}

function Ensure-StrickLockdownIsEnabled {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $mode = $h.ExtensionData.Config.LockdownMode
    $ok = ($mode -eq 'lockdownStrict')
    Add-CheckResult $cat 'Ensure-StrickLockdownIsEnabled' $h.Name (To-Status $ok) "LockdownMode=$mode"
  }
}

function Ensure-SSHAuthorisedKeysFileIsEmpty                    { $cat='5.Console'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-SSHAuthorisedKeysFileIsEmpty' $h.Name 'NotImplemented' '/etc/ssh/keys check not available via PowerCLI' } }
function Ensure-IdleESXiShellAndSSHTimeout {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $sshTo  = [int](Get-AdvValue $h 'UserVars.SshClientAliveInterval')
    $esxiTo = [int](Get-AdvValue $h 'UserVars.ESXiShellInteractiveTimeOut')
    $ok = ($esxiTo -ge 600)
    Add-CheckResult $cat 'Ensure-IdleESXiShellAndSSHTimeout' $h.Name (To-Status $ok) "ESXiShellInteractiveTimeOut=$esxiTo; SshClientAliveInterval=$sshTo"
  }
}
function Ensure-ShellServicesTimeoutIsProperlyConfigured {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $v = [int](Get-AdvValue $h 'UserVars.ESXiShellTimeOut')
    $ok = ($v -ge 600)
    Add-CheckResult $cat 'Ensure-ShellServicesTimeoutIsProperlyConfigured' $h.Name (To-Status $ok) "ESXiShellTimeOut=$v"
  }
}
function Ensure-DCUIHasTrustedUsersForLockDownMode {
  $cat='5.Console'
  foreach($h in Get-VMHost){
    $dcui = Get-AdvValue $h 'DCUI.Access'
    $ok = -not [string]::IsNullOrWhiteSpace($dcui)
    Add-CheckResult $cat 'Ensure-DCUIHasTrustedUsersForLockDownMode' $h.Name (To-Status $ok) "DCUI.Access='$dcui'"
  }
}
function Ensure-ContentsOfExposedConfigurationsNotModified       { $cat='5.Console'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-ContentsOfExposedConfigurationsNotModified' $h.Name 'NotImplemented' 'Manual review required' } }

# ==========================================================================#
#                               6. STORAGE                                  #
# ==========================================================================#
function Ensure-BidirectionalCHAPAuthIsEnabled                   { $cat='6.Storage'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-BidirectionalCHAPAuthIsEnabled' $h.Name 'NotImplemented' 'iSCSI CHAP inspection not implemented' } }
function Ensure-UniquenessOfCHAPAuthSecretsForiSCSI              { $cat='6.Storage'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-UniquenessOfCHAPAuthSecretsForiSCSI' $h.Name 'NotImplemented' 'Requires secret inventory' } }
function Ensure-SANResourcesAreSegregatedProperly                { $cat='6.Storage'; foreach($h in Get-VMHost){ Add-CheckResult $cat 'Ensure-SANResourcesAreSegregatedProperly' $h.Name 'NotImplemented' 'Zoning/masking cannot be verified from PowerCLI alone' } }

# ==========================================================================#
#                               7. NETWORK                                  #
# ==========================================================================#
function Ensure-vSwitchForgedTransmitsIsReject {
  $cat='7.Network'
  foreach($pg in Get-VirtualPortGroup -Standard -ErrorAction SilentlyContinue){
    $sp = $pg.ExtensionData.SecurityPolicy
    $ok = (-not $sp.ForgedTransmits)
    Add-CheckResult $cat 'Ensure-vSwitchForgedTransmitsIsReject' "$($pg.VirtualSwitch.Name)/$($pg.Name)" (To-Status $ok) "ForgedTransmits=$($sp.ForgedTransmits)"
  }
  foreach($pg in Get-VDPortgroup -ErrorAction SilentlyContinue){
    $sec = $pg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy
    $ok = (-not $sec.ForgedTransmits.Value)
    Add-CheckResult $cat 'Ensure-vSwitchForgedTransmitsIsReject' "$($pg.VDSwitch.Name)/$($pg.Name)" (To-Status $ok) "ForgedTransmits=$($sec.ForgedTransmits.Value)"
  }
}
function Ensure-vSwitchMACAdressChangeIsReject {
  $cat='7.Network'
  foreach($pg in Get-VirtualPortGroup -Standard -ErrorAction SilentlyContinue){
    $sp = $pg.ExtensionData.SecurityPolicy
    $ok = (-not $sp.MacChanges)
    Add-CheckResult $cat 'Ensure-vSwitchMACAdressChangeIsReject' "$($pg.VirtualSwitch.Name)/$($pg.Name)" (To-Status $ok) "MacChanges=$($sp.MacChanges)"
  }
  foreach($pg in Get-VDPortgroup -ErrorAction SilentlyContinue){
    $sec = $pg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy
    $ok = (-not $sec.MacChanges.Value)
    Add-CheckResult $cat 'Ensure-vSwitchMACAdressChangeIsReject' "$($pg.VDSwitch.Name)/$($pg.Name)" (To-Status $ok) "MacChanges=$($sec.MacChanges.Value)"
  }
}
function Ensure-vSwitchPromiscuousModeIsReject {
  $cat='7.Network'
  foreach($pg in Get-VirtualPortGroup -Standard -ErrorAction SilentlyContinue){
    $sp = $pg.ExtensionData.SecurityPolicy
    $ok = (-not $sp.AllowPromiscuous)
    Add-CheckResult $cat 'Ensure-vSwitchPromiscuousModeIsReject' "$($pg.VirtualSwitch.Name)/$($pg.Name)" (To-Status $ok) "AllowPromiscuous=$($sp.AllowPromiscuous)"
  }
  foreach($pg in Get-VDPortgroup -ErrorAction SilentlyContinue){
    $sec = $pg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy
    $ok = (-not $sec.AllowPromiscuous.Value)
    Add-CheckResult $cat 'Ensure-vSwitchPromiscuousModeIsReject' "$($pg.VDSwitch.Name)/$($pg.Name)" (To-Status $ok) "AllowPromiscuous=$($sec.AllowPromiscuous.Value)"
  }
}
function Ensure-PortGroupsNotNativeVLAN                          { $cat='7.Network'; foreach($pg in Get-VirtualPortGroup -Standard -ErrorAction SilentlyContinue){ Add-CheckResult $cat 'Ensure-PortGroupsNotNativeVLAN' "$($pg.VirtualSwitch.Name)/$($pg.Name)" 'NotImplemented' 'Native VLAN determination is external' } foreach($pg in Get-VDPortgroup -ErrorAction SilentlyContinue){ Add-CheckResult $cat 'Ensure-PortGroupsNotNativeVLAN' "$($pg.VDSwitch.Name)/$($pg.Name)" 'NotImplemented' 'Native VLAN determination is external' } }
function Ensure-PortGroupsNotUpstreamPhysicalSwitches            { $cat='7.Network'; Add-CheckResult $cat 'Ensure-PortGroupsNotUpstreamPhysicalSwitches' 'All' 'NotImplemented' 'Requires switch-side validation' }
function Ensure-PortGroupsAreNotConfiguredToVLAN0and4095 {
  $cat='7.Network'
  foreach($pg in Get-VirtualPortGroup -Standard -ErrorAction SilentlyContinue){
    $vid = $pg.VlanId
    $ok = ($vid -ne 0 -and $vid -ne 4095)
    Add-CheckResult $cat 'Ensure-PortGroupsAreNotConfiguredToVLAN0and4095' "$($pg.VirtualSwitch.Name)/$($pg.Name)" (To-Status $ok) "VLAN=$vid"
  }
  foreach($pg in Get-VDPortgroup -ErrorAction SilentlyContinue){
    $vlan = $pg.ExtensionData.Config.DefaultPortConfig.Vlan
    $vid  = $vlan.VlanId
    $ok = ($vid -ne 0 -and $vid -ne 4095)
    Add-CheckResult $cat 'Ensure-PortGroupsAreNotConfiguredToVLAN0and4095' "$($pg.VDSwitch.Name)/$($pg.Name)" (To-Status $ok) "VLAN=$vid"
  }
}
function Ensure-VirtualDistributedSwitchNetflowTrafficSentToAuthorizedCollector {
  $cat='7.Network'
  foreach($vds in Get-VDSwitch -ErrorAction SilentlyContinue){
    $nf = $vds.ExtensionData.Config.IpfixConfig
    $enabled = ($nf -and $nf.IpfixEnabled)
    Add-CheckResult $cat 'Ensure-VirtualDistributedSwitchNetflowTrafficSentToAuthorizedCollector' $vds.Name $(if($enabled){'PASS'}else{'INFO'}) "IpfixEnabled=$($nf.IpfixEnabled); Collector=$($nf.CollectorIpAddress)"
  }
}
function Ensure-PortLevelConfigurationOverridesAreDisabled       { $cat='7.Network'; foreach($vds in Get-VDSwitch -ErrorAction SilentlyContinue){ Add-CheckResult $cat 'Ensure-PortLevelConfigurationOverridesAreDisabled' $vds.Name 'NotImplemented' 'Port override scan not implemented' } }

# ==========================================================================#
#                           8. VIRTUAL MACHINES                             #
# ==========================================================================#
function VM-List { if ($script:VMs) { $script:VMs } else { $script:VMs = Get-VM; $script:VMs } }

function Ensure-InformationalMessagesFromVMToVMXLimited          { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-InformationalMessagesFromVMToVMXLimited' $vm.Name 'NotImplemented' '' } }
function Ensure-OnlyOneRemoteConnectionIsPermittedToVMAtAnyTime  {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'RemoteDisplay.maxConnections' -ErrorAction SilentlyContinue
    $ok = ($as -and $as.Value -eq '1')
    Add-CheckResult $cat 'Ensure-OnlyOneRemoteConnectionIsPermittedToVMAtAnyTime' $vm.Name (To-Status $ok) "RemoteDisplay.maxConnections=$($as.Value)"
  }
}
function Ensure-UnnecessaryFloppyDevicesAreDisconnected {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $has = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualFloppy] }
    Add-CheckResult $cat 'Ensure-UnnecessaryFloppyDevicesAreDisconnected' $vm.Name (To-Status (-not $has)) "FloppyPresent=$([bool]$has)"
  }
}
function Ensure-UnnecessaryCdDvdDevicesAreDisconnected {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $cds = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualCdrom] }
    $bad = $false
    foreach($cd in $cds){
      $now = [bool]$cd.ConnectionState.Connected
      $on  = [bool]($cd.Connectable.Connected -or $cd.Connectable.StartConnected)
      if ($now -or $on) { $bad = $true; break }
    }
    Add-CheckResult $cat 'Ensure-UnnecessaryCdDvdDevicesAreDisconnected' $vm.Name (To-Status (-not $bad)) "AnyConnectedOrOnBoot=$bad"
  }
}
function Ensure-UnnecessaryParallelPortsAreDisconnected {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $has = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualParallelPort] }
    Add-CheckResult $cat 'Ensure-UnnecessaryParallelPortsAreDisconnected' $vm.Name (To-Status (-not $has)) "ParallelPresent=$([bool]$has)"
  }
}
function Ensure-UnnecessarySerialPortsAreDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $has = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualSerialPort] }
    Add-CheckResult $cat 'Ensure-UnnecessarySerialPortsAreDisabled' $vm.Name (To-Status (-not $has)) "SerialPresent=$([bool]$has)"
  }
}
function Ensure-UnnecessaryUsbDevicesAreDisconnected             { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnnecessaryUsbDevicesAreDisconnected' $vm.Name 'NotImplemented' '' } }
function Ensure-UnauthorizedModificationOrDisconnectionOfDevicesIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.device.edit.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-UnauthorizedModificationOrDisconnectionOfDevicesIsDisabled' $vm.Name (To-Status $ok) "isolation.device.edit.disable=$($as.Value)"
  }
}
function Ensure-UnauthorizedConnectionOfDevicesIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.device.connectable.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-UnauthorizedConnectionOfDevicesIsDisabled' $vm.Name (To-Status $ok) "isolation.device.connectable.disable=$($as.Value)"
  }
}
function Ensure-PciPcieDevicePassthroughIsDisabled               { $cat='8.Virtual Machines'; foreach($vm in VM-List){ $has = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualPCIPassthrough] }; Add-CheckResult $cat 'Ensure-PciPcieDevicePassthroughIsDisabled' $vm.Name (To-Status (-not $has)) "PCIPassthroughPresent=$([bool]$has)" } }
function Ensure-UnnecessaryFunctionsInsideVMsAreDisabled         { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnnecessaryFunctionsInsideVMsAreDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UseOfTheVMConsoleIsLimited                       { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UseOfTheVMConsoleIsLimited' $vm.Name 'NotImplemented' 'Operational control/policy' } }
function Ensure-SecureProtocolsAreUsedForVirtualSerialPortAccess { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-SecureProtocolsAreUsedForVirtualSerialPortAccess' $vm.Name 'NotImplemented' '' } }
function Ensure-StandardProcessesAreUsedForVMDeployment          { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-StandardProcessesAreUsedForVMDeployment' $vm.Name 'NotImplemented' '' } }
function Ensure-AccessToVMsThroughDvFilterNetworkAPIsIsConfiguredCorrectly { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-AccessToVMsThroughDvFilterNetworkAPIsIsConfiguredCorrectly' $vm.Name 'NotImplemented' '' } }
function Ensure-AutologonIsDisabled                              { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-AutologonIsDisabled' $vm.Name 'NotImplemented' 'Guest OS policy' } }
function Ensure-BIOSBBSIsDisabled                                { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-BIOSBBSIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-GuestHostInteractionProtocolIsDisabled           { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-GuestHostInteractionProtocolIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityTaskBarIsDisabled                           { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityTaskBarIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityActiveIsDisabled                            { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityActiveIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityWindowContentsIsDisabled                    { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityWindowContentsIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityPushUpdateIsDisabled                        { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityPushUpdateIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-DragAndDropVersionGetIsDisabled                  { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-DragAndDropVersionGetIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-DragAndDropVersionSetIsDisabled                  { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-DragAndDropVersionSetIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-ShellActionIsDisabled                            { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-ShellActionIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-DiskRequestTopologyIsDisabled                    { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-DiskRequestTopologyIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-TrashFolderStateIsDisabled                       { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-TrashFolderStateIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-GuestHostInterationTrayIconIsDisabled            { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-GuestHostInterationTrayIconIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityIsDisabled                                  { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-UnityInterlockIsDisabled                         { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-UnityInterlockIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-GetCredsIsDisabled                               { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-GetCredsIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-HostGuestFileSystemServerIsDisabled              { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-HostGuestFileSystemServerIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-GuestHostInteractionLaunchMenuIsDisabled         { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-GuestHostInteractionLaunchMenuIsDisabled' $vm.Name 'NotImplemented' '' } }
function Ensure-memSchedFakeSampleStatsIsDisabled                { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-memSchedFakeSampleStatsIsDisabled' $vm.Name 'NotImplemented' '' } }

function Ensure-VMConsoleCopyOperationsAreDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.copy.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VMConsoleCopyOperationsAreDisabled' $vm.Name (To-Status $ok) "isolation.tools.copy.disable=$($as.Value)"
  }
}
function Ensure-VMConsoleDragAndDropOprerationsIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.dnd.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VMConsoleDragAndDropOprerationsIsDisabled' $vm.Name (To-Status $ok) "isolation.tools.dnd.disable=$($as.Value)"
  }
}
function Ensure-VMConsoleGUIOptionsIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.setGUIOptions.enable' -ErrorAction SilentlyContinue
    $ok = (-not $as) -or (-not (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VMConsoleGUIOptionsIsDisabled' $vm.Name (To-Status $ok) "isolation.tools.setGUIOptions.enable=$($as.Value)"
  }
}
function Ensure-VMConsolePasteOperationsAreDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.paste.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VMConsolePasteOperationsAreDisabled' $vm.Name (To-Status $ok) "isolation.tools.paste.disable=$($as.Value)"
  }
}

function Ensure-VMLimitsAreConfiguredCorrectly                   { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-VMLimitsAreConfiguredCorrectly' $vm.Name 'NotImplemented' 'Depends on policy' } }
function Ensure-HardwareBased3DAccelerationIsDisabled            { $cat='8.Virtual Machines'; foreach($vm in VM-List){ $svga = Get-AdvancedSetting -Entity $vm -Name 'mks.enable3d' -ErrorAction SilentlyContinue; $ok = (-not $svga) -or (-not (BoolVal $svga.Value)); Add-CheckResult $cat 'Ensure-HardwareBased3DAccelerationIsDisabled' $vm.Name (To-Status $ok) "mks.enable3d=$($svga.Value)" } }
function Ensure-NonPersistentDisksAreLimited                     { $cat='8.Virtual Machines'; foreach($vm in VM-List){ Add-CheckResult $cat 'Ensure-NonPersistentDisksAreLimited' $vm.Name 'NotImplemented' '' } }
function Ensure-VirtualDiskShrinkingIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.diskShrink.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VirtualDiskShrinkingIsDisabled' $vm.Name (To-Status $ok) "isolation.tools.diskShrink.disable=$($as.Value)"
  }
}
function Ensure-VirtualDiskWipingIsDisabled {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.diskWiper.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-VirtualDiskWipingIsDisabled' $vm.Name (To-Status $ok) "isolation.tools.diskWiper.disable=$($as.Value)"
  }
}
function Ensure-TheNumberOfVMLogFilesIsConfiguredProperly {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'log.keepOld' -ErrorAction SilentlyContinue
    $ok = ($as -and [int]$as.Value -ge 10)  # example threshold
    Add-CheckResult $cat 'Ensure-TheNumberOfVMLogFilesIsConfiguredProperly' $vm.Name $(if($ok){'PASS'}else{'INFO'}) "log.keepOld=$($as.Value)"
  }
}
function Ensure-HostInformationIsNotSentToGuests {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'isolation.tools.getHostInfo.disable' -ErrorAction SilentlyContinue
    $ok = ($as -and (BoolVal $as.Value))
    Add-CheckResult $cat 'Ensure-HostInformationIsNotSentToGuests' $vm.Name (To-Status $ok) "isolation.tools.getHostInfo.disable=$($as.Value)"
  }
}
function Ensure-VMLogFileSizeIsLimited {
  $cat='8.Virtual Machines'
  foreach($vm in VM-List){
    $as = Get-AdvancedSetting -Entity $vm -Name 'log.rotateSize' -ErrorAction SilentlyContinue
    $ok = ($as -and [int]$as.Value -le 1048576)  # <= 1 MiB example
    Add-CheckResult $cat 'Ensure-VMLogFileSizeIsLimited' $vm.Name $(if($ok){'PASS'}else{'INFO'}) "log.rotateSize=$($as.Value)"
  }
}

# ==========================================================================#
#                         EXECUTE ALL REQUESTED CHECKS                      #
# ==========================================================================#

# 1. Install
Ensure-ESXiIsProperlyPatched
Ensure-VIBAcceptanceLevelIsConfiguredProperly
Ensure-UnauthorizedModulesNotLoaded
Ensure-DefaultSaultIsConfiguredProperly

# 2. Communication
Ensure-NTPTimeSynchronizationIsConfiguredProperly
Ensure-ESXiHostFirewallIsProperlyConfigured
Ensure-MOBIsDisabled
Ensure-DefaultSelfSignedCertificateIsNotUsed
Ensure-SNMPIsConfiguredProperly
Ensure-dvfilterIsDisabled
Ensure-DefaultExpiredOrRevokedCertificateIsNotUsed
Ensure-vSphereAuthenticationProxyIsUsedWithAD
Ensure-VDSHealthCheckIsDisabled

# 3. Logging
Ensure-CentralizedESXiHostDumps
Ensure-PersistentLoggingIsConfigured
Ensure-RemoteLoggingIsConfigured

# 4. Access
Ensure-NonRootExistsForLocalAdmin
Ensure-PasswordsAreRequiredToBeComplex
Ensure-LoginAttemptsIsSetTo5
Ensure-AccountLockoutIsSetTo15Minutes
Ensure-Previous5PasswordsAreProhibited
Ensure-ADIsUsedForAuthentication
Ensure-OnlyAuthorizedUsersBelongToEsxAdminsGroup
Ensure-ExceptionUsersIsConfiguredManually

# 5. Console
Ensure-DCUITimeOutIs600
Ensure-ESXiShellIsDisabled
Ensure-SSHIsDisabled
Ensure-CIMAccessIsLimited
Ensure-NormalLockDownIsEnabled
Ensure-StrickLockdownIsEnabled
Ensure-SSHAuthorisedKeysFileIsEmpty
Ensure-IdleESXiShellAndSSHTimeout
Ensure-ShellServicesTimeoutIsProperlyConfigured
Ensure-DCUIHasTrustedUsersForLockDownMode
Ensure-ContentsOfExposedConfigurationsNotModified

# 6. Storage
Ensure-BidirectionalCHAPAuthIsEnabled
Ensure-UniquenessOfCHAPAuthSecretsForiSCSI
Ensure-SANResourcesAreSegregatedProperly

# 7. Network
Ensure-vSwitchForgedTransmitsIsReject
Ensure-vSwitchMACAdressChangeIsReject
Ensure-vSwitchPromiscuousModeIsReject
Ensure-PortGroupsNotNativeVLAN
Ensure-PortGroupsNotUpstreamPhysicalSwitches
Ensure-PortGroupsAreNotConfiguredToVLAN0and4095
Ensure-VirtualDistributedSwitchNetflowTrafficSentToAuthorizedCollector
Ensure-PortLevelConfigurationOverridesAreDisabled

# 8. Virtual Machines
Ensure-InformationalMessagesFromVMToVMXLimited
Ensure-OnlyOneRemoteConnectionIsPermittedToVMAtAnyTime
Ensure-UnnecessaryFloppyDevicesAreDisconnected
Ensure-UnnecessaryCdDvdDevicesAreDisconnected
Ensure-UnnecessaryParallelPortsAreDisconnected
Ensure-UnnecessarySerialPortsAreDisabled
Ensure-UnnecessaryUsbDevicesAreDisconnected
Ensure-UnauthorizedModificationOrDisconnectionOfDevicesIsDisabled
Ensure-UnauthorizedConnectionOfDevicesIsDisabled
Ensure-PciPcieDevicePassthroughIsDisabled
Ensure-UnnecessaryFunctionsInsideVMsAreDisabled
Ensure-UseOfTheVMConsoleIsLimited
Ensure-SecureProtocolsAreUsedForVirtualSerialPortAccess
Ensure-StandardProcessesAreUsedForVMDeployment
Ensure-AccessToVMsThroughDvFilterNetworkAPIsIsConfiguredCorrectly
Ensure-AutologonIsDisabled
Ensure-BIOSBBSIsDisabled
Ensure-GuestHostInteractionProtocolIsDisabled
Ensure-UnityTaskBarIsDisabled
Ensure-UnityActiveIsDisabled
Ensure-UnityWindowContentsIsDisabled
Ensure-UnityPushUpdateIsDisabled
Ensure-DragAndDropVersionGetIsDisabled
Ensure-DragAndDropVersionSetIsDisabled
Ensure-ShellActionIsDisabled
Ensure-DiskRequestTopologyIsDisabled
Ensure-TrashFolderStateIsDisabled
Ensure-GuestHostInterationTrayIconIsDisabled
Ensure-UnityIsDisabled
Ensure-UnityInterlockIsDisabled
Ensure-GetCredsIsDisabled
Ensure-HostGuestFileSystemServerIsDisabled
Ensure-GuestHostInteractionLaunchMenuIsDisabled
Ensure-memSchedFakeSampleStatsIsDisabled
Ensure-VMConsoleCopyOperationsAreDisabled
Ensure-VMConsoleDragAndDropOprerationsIsDisabled
Ensure-VMConsoleGUIOptionsIsDisabled
Ensure-VMConsolePasteOperationsAreDisabled
Ensure-VMLimitsAreConfiguredCorrectly
Ensure-HardwareBased3DAccelerationIsDisabled
Ensure-NonPersistentDisksAreLimited
Ensure-VirtualDiskShrinkingIsDisabled
Ensure-VirtualDiskWipingIsDisabled
Ensure-TheNumberOfVMLogFilesIsConfiguredProperly
Ensure-HostInformationIsNotSentToGuests
Ensure-VMLogFileSizeIsLimited

# ------------------------- OUTPUT & SUMMARY -------------------------------

# Print all results
$global:Results | Sort-Object Category, Check, Object |
  Format-Table -AutoSize Category, Check, Object, Status, Details

# Summary by Category and Status
$summary = $global:Results | Group-Object Category, Status | ForEach-Object {
  [PSCustomObject]@{
    Category = $_.Group[0].Category
    Status   = $_.Group[0].Status
    Count    = $_.Count
  }
} | Sort-Object Category, Status

# Category labels for readability
$categoryMap = @{
  '1.Install'           = '1.Install (ESXi host software / patching)'
  '2.Communication'     = '2.Communication (ESXi host network services)'
  '3.Logging'           = '3.Logging (ESXi host logging/syslog)'
  '4.Access'            = '4.Access (ESXi authentication & user mgmt)'
  '5.Console'           = '5.Console (ESXi console & shell services)'
  '6.Storage'           = '6.Storage (ESXi storage / iSCSI / SAN)'
  '7.Network'           = '7.Network (vSwitch / vDS networking policies)'
  '8.Virtual Machines'  = '8.Virtual Machines (Guest VM configuration)'
}

$summaryLabeled = $summary | ForEach-Object {
  [PSCustomObject]@{
    Category = $categoryMap[$_.Category]
    Status   = $_.Status
    Count    = $_.Count
  }
}

Write-Host ""
Write-Host "=== Summary by Category and Status ===" -ForegroundColor Yellow
$summaryLabeled | Format-Table -AutoSize

# Overall counts
$overall = $global:Results | Group-Object Status | ForEach-Object {
  [PSCustomObject]@{ Status = $_.Name; Count = $_.Count }
} | Sort-Object Status

# Status labels for readability
$statusMap = @{
  'PASS'            = 'PASS (compliant)'
  'FAIL'            = 'FAIL (requires remediation)'
  'INFO'            = 'INFO (informational only)'
  'NotImplemented'  = 'NotImplemented (manual check required)'
}

$overallLabeled = $overall | ForEach-Object {
  [PSCustomObject]@{
    Status = $statusMap[$_.Status]
    Count  = $_.Count
  }
}

Write-Host ""
Write-Host "=== Overall Summary ===" -ForegroundColor Yellow
$overallLabeled | Format-Table -AutoSize
