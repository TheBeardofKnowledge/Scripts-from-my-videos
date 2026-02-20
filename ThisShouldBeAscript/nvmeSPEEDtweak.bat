@echo off
color f0
ECHO Running Admin shell
:checkPrivileges 
	NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges ) 
:getPrivileges
:: Not elevated, so re-run with elevation
    	powershell -Command "Start-Process cmd -ArgumentList '/c %~s0 %*' -Verb RunAs"
    	exit /b
:gotPrivileges 
	cls
::=========================================================================
@echo off
setlocal EnableExtensions
chcp 65001 >nul
:menu
cls
echo ================================
echo        NVMe Driver Menu
echo ================================
echo 1. Check system for NVMe compatibility
echo 2. Enable Microsoft NVMe optimized storage driver
echo 3. Undo "reverse" Microsoft NVMe optimized storage driver changes
echo 4. Exit
echo ================================
choice /c 1234 /n /m "Select 1-4: "
if errorlevel 4 goto :eof
if errorlevel 3 goto :undo
if errorlevel 2 goto :tweaks
if errorlevel 1 goto :checksystem

:checksystem
::Windows 24H2 build 26100+
ECHO Checking Installed Windows Build
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber ^| find /I "CurrentBuildNumber"') do set "BUILD=%%B"
if %BUILD% LSS 26100 (
    echo This Windows Build is not compatible with this change
    pause
    goto :menu
)


::NVMe controller present-international
:: Look for any SCSI-RAID controller PCI InstanceId containing NVMe class code CC_010802
set "NVME_CONTROLLER="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
  "$class='{4d36e97b-e325-11ce-bfc1-08002be10318}';" ^
  "Get-PnpDevice -Class $class -PresentOnly | Where-Object { $_.InstanceId -match 'PCI\\\\.*CC_010802' } | Select-Object -First 1 | ForEach-Object { 'NVME_OK' }"`) do (
  set "NVME_CONTROLLER=%%I"
)

if /I not "%NVME_CONTROLLER%"=="NVME_OK" (
  echo This system Storage Controller is not compatible with this change
  pause
  goto :menu
)


::StorNVMe.sys bound to any disk-international
set "FOUNDSTORNVME="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
  "Get-PnpDevice -Class 'DiskDrive' -PresentOnly | ForEach-Object {" ^
  "  $svc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service').Data;" ^
  "  if ($svc -eq 'stornvme') { 'STORNVME_FOUND' } } | Select-Object -First 1"`) do (
  set "FOUNDSTORNVME=%%I"
)

if /I not "%FOUNDSTORNVME%"=="STORNVME_FOUND" (
  echo This system drives are not compatible with this change
  pause
  goto :menu
)
::BypassIO status-international
	set "BYPASSIO_OK="
	for /f "usebackq tokens=1,* delims=:" %%A in (`
  fsutil bypassIo state %SystemDrive% /v 2^>nul ^| findstr /irc:"^\s*Status:\s*0\b" 
`) do (
  set "BYPASSIO_OK=1"
)

if not defined BYPASSIO_OK (
  echo This system supports bypassIo and should NOT use the new NVMe driver
  pause
  goto :menu
)

if not defined BYPASSIO_SUPPORTED (
    echo This system supports bypassIo and therefore should NOT use the new NVMe driver
    pause
    goto :menu
)

echo System Requirements Verified.
goto :menu

:tweaks
::Disclaimer
echo ================================
ECHO 	*Known compatibility issues*
echo ================================
ECHO Not all SSDs switch to nvmedisk.sys. Some vendors’ firmware and drivers
ECHO such as Samsung WD Intel AMD Crucial SKhynix Physon among other manufacturers providing their own NVMe drivers 
ECHO will continue to use their vendor stack and won't flip to the Microsoft native driver
ECHO Community reports and forum threads show some models do not change driver even after the registry keys are set
ECHO Systems using Intel/AMD VMD, RAID layers or vendor controllers can behave unpredictably
ECHO If your system uses VMD, Intel RST or hardware RAID the native toggle may not apply
echo or it may break access in recovery modes
ECHO That’s especially true for systems where the NVMe device is behind a chipset RAID or special controller
ECHO.
ECHO BitLocker and boot time behavior
ECHO Because the change affects how the OS accesses block devices, encrypted systems or those with preboot security 
ECHO may see boot failures or require reconfiguration. Multiple community posts report inaccessible boot device or 
ECHO inability to enter Safe Mode after making unsupported driver changes
echo NotebookCheck and several forum threads specifically warn that enabling the native stack can break 
ECHO Windows boot on incompatible systems - Back up everything
ECHO.
ECHO Safe Mode and recovery
echo Some users have documented that after flipping the driver - Safe Mode fails to mount the Windows volume 
ECHO producing INACCESSIBLE_BOOT_DEVICE errors
ECHO That makes recovery from Safe Mode or offline repair more complicated unless you have 
ECHO a complete system image or external rescue media. The known safemode changes are included in this script
ECHO.
ECHO Do not enable this if you are running deduplication on your drives - there are known issues*
ECHO IF THE SCRIPT SAYS YOUR SYSTEM IS NOT COMPATIBLE THEN IT IS NOT COMPATIBLE.
ECHO If your system supports DIRECTSTORAGE - DO NOT ENABLE THIS
ECHO If your system supports BYPASSIO for storage - DO NOT ENABLE THIS
	set /p q=Are you sure you wish to continue? [Y/N]?
	if /I "%q%" EQU "Y" goto enable
	if /I "%q%" EQU "N" goto menu



:enable
echo Enabling Microsoft NVMe optimized storage driver...
echo.
echo Temporarily disabling bitlocker if enabled - else continue
::BitLocker - Temporarily suspend protection on the OS drive for 1 reboot
for /f "usebackq delims=" %%S in (`
  powershell -NoProfile -Command "(Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus"
`) do set "BL_PROT=%%S"

if "%BL_PROT%"=="1" (
  powershell -NoProfile -Command "Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1"
  if errorlevel 1 (
    echo [WARN] Failed to suspend BitLocker on %SystemDrive%. You may be prompted for a recovery key after reboot.
  ) else (
    echo BitLocker protection suspended for one reboot on %SystemDrive%.
  )
)
echo.
echo Attempting to create a system restore point

::Save current SystemRestorePointCreationFrequency (if present)
set "SRPF_KEY=HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore"
set "SRPF_VAL=SystemRestorePointCreationFrequency"
set "SRPF_BACKUP="
for /f "tokens=1,2,*" %%A in ('reg query "%SRPF_KEY%" /v %SRPF_VAL% 2^>nul ^| find /i "%SRPF_VAL%"') do set "SRPF_BACKUP=%%C"

::Temporarily set throttle to 0 (allow immediate RP)
reg add "%SRPF_KEY%" /v %SRPF_VAL% /t REG_DWORD /d 0 /f >nul

::Make sure System Protection is enabled on the system drive
powershell -NoProfile -NoLogo -NonInteractive -Command ^
  "Enable-ComputerRestore -Drive $env:SystemDrive" ^
  1>nul 2>nul

::Create the restore point
powershell -NoProfile -NoLogo -NonInteractive -Command ^
  "Checkpoint-Computer -Description 'NVME tweak change' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop"
if errorlevel 1 (
    echo Failed to create a restore point. Aborting changes.
    goto :menu
)

::Restore the throttle value to previous state
if defined SRPF_BACKUP (
    for /f "tokens=3" %%X in ("%SRPF_BACKUP%") do reg add "%SRPF_KEY%" /v %SRPF_VAL% /t REG_DWORD /d %%X /f >nul
) else (
    reg delete "%SRPF_KEY%" /v %SRPF_VAL% /f >nul 2>nul
)

ECHO Enabling NVME storage features
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 1 /f
::safemode fallback
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
ECHO. 
	set /p q=A system restart is required for the changes, reboot? [Y/N]?
	if /I "%q%" EQU "Y" goto reboot
	if /I "%q%" EQU "N" goto eof
:reboot
	shutdown -r -t 0
	
:Undo
echo Temporarily disabling bitlocker if enabled - else continue
::BitLocker - Temporarily suspend protection on the OS drive for 1 reboot
for /f "usebackq delims=" %%S in (`
  powershell -NoProfile -Command "(Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus"
`) do set "BL_PROT=%%S"

if "%BL_PROT%"=="1" (
  powershell -NoProfile -Command "Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1"
  if errorlevel 1 (
    echo [WARN] Failed to suspend BitLocker on %SystemDrive%. You may be prompted for a recovery key after reboot.
  ) else (
    echo BitLocker protection suspended for one reboot on %SystemDrive%.
  )
)
echo.
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 0 /f
goto reboot
::=========================================================================
PAUSE

EXIT




