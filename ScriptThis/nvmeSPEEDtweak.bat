::template
:: Automatically check and get admin rights ::
::@ECHO OFF
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
::SCRIPT TO TEST GOES BETWEEN THE ::==
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
echo 3. Exit
echo ================================
choice /c 123 /n /m "Select 1-3: "
if errorlevel 3 goto :eof
if errorlevel 2 goto :tweaks
if errorlevel 1 goto :checksystem

:checksystem
:: ---------- 1. Windows 24H2 build 26100+ ----------
ECHO Checking Installed Windows Build
for /f "tokens=4-5 delims=. " %%A in ('ver') do set /a BUILD=%%B
if %BUILD% LSS 26100 (
    echo This Windows Build is not compatible with this change
    pause
    goto :menu
)
:: ---------- 2. Standard NVM Express Controller present ----------
driverquery /fo csv | find /I "Standard NVM Express Controller" >nul || (
    echo This system Storage Controller is not compatible with this change
    pause
    goto :menu
)

:: ---------- 3. StorNVMe.sys bound to any disk ----------
set "FOUNDSTORNVME="
wmic diskdrive get PNPDeviceID /value | find "=" >"%temp%\disks.txt"
for /f "tokens=2 delims==" %%D in (%temp%\disks.txt) do (
    pnputil /enum-devices /bus PCI /class DiskDrive /instanceid "%%D" 2>nul | find /I "StorNVMe" >nul && set "FOUNDSTORNVME=1"
)
del "%temp%\disks.txt" 2>nul
if not defined FOUNDSTORNVME (
    echo This system drives are not compatible with this change
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
ECHO Not all SSDs switch to nvmedisk.sys. Some vendors’ firmware/drivers — Samsung, WD and other manufacturers providing their own NVMe drivers — 
ECHO will continue to use their vendor stack and won't flip to the Microsoft native driver. 
ECHO Community reports and forum threads show some models do not change driver even after the registry keys are set.
ECHO Systems using Intel/AMD VMD, RAID layers or vendor controllers can behave unpredictably. If your system uses VMD, Intel RST or hardware RAID, 
ECHO the native toggle may not apply, or it may break access in recovery modes. 
ECHO That’s especially true for systems where the NVMe device is behind a chipset RAID or special controller.
ECHO BitLocker and boot‑time behavior. 
ECHO Because the change affects how the OS accesses block devices, encrypted systems or those with preboot security 
ECHO may see boot failures or require reconfiguration. Multiple community posts report inaccessible boot device or 
ECHO inability to enter Safe Mode after making unsupported driver changes. NotebookCheck and several forum threads specifically warn that 
ECHO enabling the native stack can break Windows boot on incompatible systems. Back up everything.
ECHO Safe Mode and recovery. Some users have documented that after flipping the driver, Safe Mode fails to mount the Windows volume, 
ECHO producing INACCESSIBLE_BOOT_DEVICE errors. That makes recovery from Safe Mode or offline repair more complicated unless you have 
ECHO a complete system image or external rescue media.
	set /p q=Are you sure you wish to continue? [Y/N]?
	if /I "%q%" EQU "Y" goto enable
	if /I "%q%" EQU "N" goto menu
echo Enabling Microsoft NVMe optimized storage driver...

:enable
::create a system restore point
echo Creating a system restore point
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "NVME tweak change", 100, 7 >nul 2>&1

ECHO Enabling NVME storage features
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 1 /f
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 1 /f
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 1 /f
::safemode fallback
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
ECHO 
	set /p q=A system restart is required for the changes, reboot? [Y/N]?
	if /I "%q%" EQU "Y" goto reboot
	if /I "%q%" EQU "N" goto eof
	:reboot
	shutdown -r -t 0
::=========================================================================
PAUSE
EXIT