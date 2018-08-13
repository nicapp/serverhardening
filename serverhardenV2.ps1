###################################################################################
# ____                             _   _               _            _
#/ ___|  ___ _ ____   _____ _ __  | | | | __ _ _ __ __| | ___ _ __ (_)_ __   __ _
#\___ \ / _ \ '__\ \ / / _ \ '__| | |_| |/ _` | '__/ _` |/ _ \ '_ \| | '_ \ / _` |
# ___) |  __/ |   \ V /  __/ |    |  _  | (_| | | | (_| |  __/ | | | | | | | (_| |
#|____/ \___|_|    \_/ \___|_|    |_| |_|\__,_|_|  \__,_|\___|_| |_|_|_| |_|\__, |
#                                                                          |___/
# Nick Abbott | 7/3/2018
# Freeit Data Solutions, Inc | nick@freeitdata.com
# Description: This script disables unnecessary services and task from a freshly
#              installed Windows 2016 Server. The tasks and services removed are
#              as specified by the Capital Metro IT staff.
###################################################################################

#Disabled services ServicesList
$ServicesList = "XblGameSave", "XblAuthManager", "icssvc", "FrameServer", "WbioSrvc",
                "WalletService", "TabletInputService", "TapiSrv", "lfsvc", "MapsBroker"
#Services to be modified via registry
$RegSvcList = "OneSyncSvc", "CDPUserSvc", "UserDataSvc", "UniStoreSvc", "PimIndexMaintenanceSvc"
#Installer registry key parameters
$RegKeyParentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
$RegKeyName = "Installer"
$RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
$KeyPropertyType = "DWord"
$KeyPropertyName = "DisableRollback"
#Disable scheduled tasks
$ScheduledTasks = "Proxy", "UninstallDeviceTask", "CreateObjectTask",
                  "Consolidator", "KernelCeipTask","UsbCeip", "ScheduledDefrag", "Microsoft-Windows-DiskDiagnosticDataCollector",
                  "WindowsActionDialog", "Notifications", "MNO Metadata Parser",
                  "MobilityManager", "SpeechModelDownloadTask"
$UnregisterTasks = "MapsToastTask", "MapsUpdateTask", "XblGameSaveTask", "XblGameSaveTaskLogon"
#Prompt user for machine name
#Assign to computer name
$ServerName = Read-Host -Prompt 'Enter your new desired server name'
#Enable remote desktop
set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0 -erroraction silentlycontinue
if (-not $?) {new-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0 -PropertyType dword }
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
#disable firewall
netsh advfirewall set allprofiles state off
#Set local password to never expire
Set-LocalUser -Name "Administrator" -PasswordNeverExpires:$true


#Check if key exists; if not create it.
If(Test-Path -Path $RegKeyPath){
  Write-Host "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer key exists"
} Else {
  Write-Host "Creating HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer"
  New-Item -Path $RegKeyParentPath -Name $RegKeyName
}

#Check the value of the property and set it to 0 if needed; if the property doesn't
#exists create it.
$Value = (Get-ItemProperty -Path $RegKeypath -Name $KeyPropertyName -ErrorAction SilentlyContinue).$KeyPropertyName
If($Value -eq $null){
  New-ItemProperty -Path $RegKeypath -Name $KeyPropertyName -PropertyType $KeyPropertyType -Value 0
} ElseIf ($Value -ne 0){
    Set-ItemProperty -Path $RegKeyPath -Name $KeyPropertyName -Value 0
}

#Disable services stored in $ServiceList
Foreach($svc in $ServicesList){
  Set-Service $svc -StartupType Disabled
  Stop-Service $svc
}

#Set Start property in registry to 4 for specified tasks stored in $RegSvcList
Foreach($i in $RegSvcList){
  $var = Get-Item -Path ("HKLM:\System\CurrentControlSet\Services\" + $i + "*")
  foreach($j in $var){
    Set-ItemProperty -Path ("Registry::" + $j.Name) -Name "Start" -Value 4
  }
}

#Disable scheduled tasks stored in $ScheduledTasks
Foreach($i in $ScheduledTasks){
  Get-ScheduledTask $i | Disable-ScheduledTask
}

#Delete specified Scheduled Tasks
Foreach($i in $UnregisterTasks){
  Get-ScheduledTask $i | Unregister-ScheduledTask -Confirm:$False
}

#Delete folders
Remove-Item "C:\Windows\System32\Tasks\Microsoft\XblGameSave"
Remove-Item "C:\Windows\System32\Tasks\Microsoft\Windows\Maps"

#Setting time zone
Write-Host "Setting time zone to Central Standard Time"
Set-TimeZone "Central Standard Time"

#Applying name change and restarting
Write-Host "Renaming server to $ServerName and restarting..."
Rename-Computer -NewName $ServerName -Force -Restart
