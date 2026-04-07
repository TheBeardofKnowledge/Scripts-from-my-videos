:: Automatically check and get admin rights ::
@ECHO OFF
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
::@ECHO OFF
color
TITLE TBOK NVMe Windows Driver Enabler Release 04-07-2026
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cls
:menu
ECHO TBOK NVMe Windows Driver Enabler Release 04-07-2026
::Disclaimer
ECHO ******************************************
ECHO  *PLEASE READ-Known compatibility issues*
ECHO ******************************************
ECHO Not all SSDs switch to StorNVMe.sys. Some vendors firmware and drivers such as
ECHO Samsung-WD-Intel-AMD-Crucial"Micron"-SKhynix-Physon provide their own NVMe drivers
ECHO and will continue to use their vendor driver stack-so this script will read it incompatible
ECHO Some models do not change driver even after the registry keys are set
ECHO Systems using Intel RST or AMD VMD RAID layers or vendor controllers can behave unpredictably
ECHO If your system uses VMD, Intel RST or hardware RAID the native toggle will NOT apply
ECHO.
ECHO Because the change affects how the OS accesses block devices, encrypted systems or those with preboot security 
ECHO Bitlocker will be suspended for a single boot to avoid this.
ECHO Safe Mode and recovery
ECHO When this was first tested on Windows 11 some users had issues booting to recovery -  
ECHO The known safemode changes required to fix that are included in this script
ECHO.
ECHO Do not enable this if you are running deduplication on your drives-there are known issues
ECHO IF THE SCRIPT SAYS YOUR SYSTEM IS NOT COMPATIBLE -  THEN IT IS NOT COMPATIBLE.
ECHO If your system supports DIRECTSTORAGE - DO NOT USE THIS
ECHO If your system supports BYPASSIO for storage - DO NOT USE THIS
ECHO ================================
ECHO        NVMe Driver Menu
ECHO ================================
ECHO 1. Check system for compatibility and enable new NVMe driver if applicable
ECHO 2. I know what I am doing so just apply the changes for the new NVME driver
ECHO 3. Undo "reverse" Microsoft NVMe optimized storage driver registry changes
ECHO 4. Exit
ECHO ================================
choice /c 1234 /n /m "Select 1-4: "
if errorlevel 4 goto :eof
if errorlevel 3 goto :undo
if errorlevel 2 goto :tweaks
if errorlevel 1 goto :checksystem

:checksystem
:: Windows 24H2 build 26100+
ECHO Checking Installed Windows Build
set "BUILD="
for /f "tokens=2,*" %%A in ('
  reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber ^| find /I "CurrentBuildNumber"
') do set "BUILD=%%B"
if not defined BUILD (
	ECHO ***********************************
    ECHO Unable to determine Windows build
	ECHO ***********************************
    pause
    goto :menu
)
if %BUILD% LSS 26100 (
	ECHO ************************************************
    ECHO This Windows Build is not compatible
	ECHO Windows 11 24H2 build 2600 or newer is required
	ECHO ************************************************
    pause
    goto menu
)
ECHO.
ECHO 	Installed Windows Build Meets Requirements
ECHO.
::NVMe controller present_region-free
ECHO.
ECHO Checking Active Storage Controller is Microsoft Standard NVM Express Controller
ECHO.
set "NVME_CONTROLLER="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
  "$dev = Get-PnpDevice -PresentOnly -Class 'SCSIAdapter' |" ^
  "  Where-Object { (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data -eq 'stornvme' } |" ^
  "  Select-Object -First 1;" ^
  "if ($dev) { 'NVME_OK' }"`) do (
  set "NVME_CONTROLLER=%%I"
)
if /I not "%NVME_CONTROLLER%"=="NVME_OK" (
	ECHO *************************************************************************************
	ECHO This system Storage Controller is either not compatible or using proprietary drivers
	ECHO This is a hard requirement - Please check device manager to verify if the 
	ECHO storage controller is Microsoft NVM express Controller - You might be on IntelRST
	ECHO However - if you are NOT running RAID then you need to change it in bios to AHCI
	ECHO Changing it in bios means you also need to boot into safe mode 1 time after.
	ECHO *************************************************************************************
  pause
  goto menu
)
ECHO.
ECHO 	Microsoft Standard NVM Express Controller found active
ECHO.
:drives
ECHO Ensuring installed drives are using the Microsoft StorNVMe driver and not proprietary
::StorNVMe.sys bound to disk (locale-independent)
set "FOUNDSTORNVME="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
  "Get-PnpDevice -Class 'DiskDrive' -PresentOnly | ForEach-Object {" ^
  "  $svc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service').Data;" ^
  "  if ($svc -eq 'stornvme') { 'STORNVME_FOUND' } } | Select-Object -First 1"`) do (
  set "FOUNDSTORNVME=%%I"
)
if /I not "%FOUNDSTORNVME%"=="STORNVME_FOUND" (
	ECHO. 
	ECHO *****************************************************************************************
	ECHO This system drives are not bound to Microsoft stornvme or are using proprietary drivers
	ECHO This is listed as a dependency of the new Microsoft NVMe driver for activation - However
	ECHO testing has found some drives and systems that dont have this pairing will still work
	ECHO with the new NVMe driver regardless of this - continuing
	ECHO *****************************************************************************************
	ECHO. 
  goto bypassio
)
ECHO.
ECHO 	Disks found active with Microsoft StorNVMe
ECHO.

:bypassio
::BypassIO status (not language dependent - fsutil returned language results)
ECHO Checking for BypassIO use as it is not yet fully compatible

set KEY=HKLM\SYSTEM\CurrentControlSet\Services\storport\Parameters
set VALUE=EnableBypassIO

::Query registry WITHOUT parsing localized text
reg query "%KEY%" /v %VALUE% >nul 2>&1
if errorlevel 1 (
    echo 	BypassIO is NOT enabled - registry value not present
    goto bypassiosystemdrive
)

for /f "tokens=3" %%A in (
    'reg query "%KEY%" /v %VALUE% ^| findstr /R /C:"REG_DWORD"'
) do set DATA=%%A

if /i "%DATA%"=="0x1" (
    echo BypassIO is ENABLED
	goto bypassiostop
) else (
    echo BypassIO is NOT enabled
	goto bypassiosystemdrive
)

:bypassiosystemdrive
::DRIVE SUPPORT check
ECHO System Drive Status Check
set DRIVE=C:

rem Query BypassIO capability
fsutil bypassio query %DRIVE% >nul 2>&1

set ERR=%ERRORLEVEL%

if %ERR%==0 (
	echo 	Drive %DRIVE% SUPPORTS BypassIO.
	goto bypassiostop
) else if %ERR%==1 (
	echo 	Drive %DRIVE% does NOT support BypassIO.
	goto systemverifiedcompatible
) else if %ERR%==5 (
    echo 	Access denied.
	goto menu
) else (
    echo 	Unknown result - Error code: %ERR%
	pause
	goto menu
)

:bypassioSTOP
	ECHO *************************************************************************
	ECHO This system supports BypassIO Support- DO NOT enable the new NVMe driver
  	ECHO *************************************************************************
  pause
  goto :menu
) else (
  ECHO 		BypassIO-compatible storage not detected- continuing...
)
:systemverifiedcompatible
  	ECHO ************************************************************
	ECHO Congratulations - all system requirements Verified.
	ECHO The changes for enabling the new NVMe driver will now apply
	ECHO ************************************************************
pause
goto :enable

:tweaks
	set /p q=Are you sure you wish to continue? [Y/N]?
	if /I "%q%" EQU "Y" goto enable
	if /I "%q%" EQU "N" goto menu

:enable
echo Enabling Microsoft NVMe optimized storage driver...
echo.
echo Temporarily suspending BitLocker for one reboot - if enabled...
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
ECHO.
ECHO Attempting to create a system restore point
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
  "Checkpoint-Computer -Description 'NVME tweak change' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue"
if errorlevel 1 (
    ECHO Failed to create a restore point.
)
::Restore the throttle value to previous state in order to avoid excessive restore points
if defined SRPF_BACKUP (
    for /f "tokens=3" %%X in ("%SRPF_BACKUP%") do reg add "%SRPF_KEY%" /v %SRPF_VAL% /t REG_DWORD /d %%X /f >nul
) else (
    reg delete "%SRPF_KEY%" /v %SRPF_VAL% /f >nul 2>nul
)
endlocal
:registry
ECHO.
ECHO 	Enabling NVME storage features in registry
ECHO.

::Feature Flag 156965516  (Standalone_Future - Performance optimizations)
ECHO 	Enabling Performance Optimizations
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 1 /f
:: Feature Flag 1853569164 UxAccOptimization 
ECHO 	Enabling UxAccOptimization
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 1 /f
:: Feature Flag 735209102  -NativeNVMeStackForGeClient
ECHO 	Enabling NVMe Stack for GeClient
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 1 /f
:: OptionalFeature Flag 1176759950 -Microsoft Official Server 2025 key
ECHO 	Alternate optional key for Server 2025
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1176759950 /t REG_DWORD /d 1 /f

::new workarounds
ECHO Enabling additional feature sets that Microsoft moved the feature enablement to
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 60786016 /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 48433719 /t REG_DWORD /d 1 /f

::safemode fallback
ECHO Enabling SafeMode fallback registry entries
::SafeBoot Minimal
ECHO 	Enabling SafeMode Minimal Fallback registry change
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
::SafeBoot Network
ECHO 	Enabling SafeMode with Networking Fallback registry change
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
ECHO. 
	set /p q=A system restart is required for the changes, reboot? [Y/N]?
	if /I "%q%" EQU "Y" goto reboot
	if /I "%q%" EQU "N" goto eof
:reboot
	shutdown -r -t 0
	
:Undo
ECHO Temporarily disabling bitlocker if enabled - else continue
::BitLocker - Temporarily suspend protection on the OS drive for 1 reboot
for /f "usebackq delims=" %%S in (`
  powershell -NoProfile -Command "(Get-BitLockerVolume -MountPoint $env:SystemDrive).ProtectionStatus"
`) do set "BL_PROT=%%S"

if "%BL_PROT%"=="1" (
  powershell -NoProfile -Command "Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1"
  if errorlevel 1 (
    ECHO [WARN] Failed to suspend BitLocker on %SystemDrive%. You may be prompted for a recovery key after reboot.
  ) else (
    ECHO BitLocker protection suspended for one reboot on %SystemDrive%.
  )
)
ECHO.
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 60786016 /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 48433719 /t REG_DWORD /d 0 /f
goto reboot
::=========================================================================
PAUSE

EXIT
