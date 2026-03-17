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
TITLE TBOK NVMe Windows Driver Enabler Release 03-17-2026
Updated 03-17-2026
setlocal EnableExtensions
chcp 65001 >nul
cls
:menu
::Disclaimer
ECHO ================================
ECHO *PLEASE READ-Known compatibility issues*
ECHO ================================
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
ECHO 3. Undo "reverse" Microsoft NVMe optimized storage driver changes
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
    goto :menu
)
ECHO Windows Build Meets Requirements
::NVMe controller present_region-free
:: Look for any SCSI/RAID controller whose PCI identifiers show NVMe class code CC_010802
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

echo NVME_CONTROLLER=%NVME_CONTROLLER%

if /I not "%NVME_CONTROLLER%"=="NVME_OK" (
	ECHO *************************************************************************************
	ECHO This system Storage Controller is either not compatible or using proprietary drivers
	ECHO *************************************************************************************
  pause
  goto :menu
)
ECHO Microsoft Standard NVM Express Controller found active
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
	ECHO *****************************************************************************************
	ECHO This system drives are not bound to Microsoft stornvme or are using proprietary drivers
	ECHO These are dependencies of the new Microsoft NVMe driver for activation
	ECHO *****************************************************************************************
  pause
  goto :menu
)
ECHO Disks found active with Microsoft StorNVMe

::BypassIO status (improved via FSCTL_MANAGE_BYPASS_IO)
ECHO Checking for BypassIO in use - it is not yet compatible with the new NVMe driver
for /f "usebackq delims=" %%I in (`
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Add-Type -Language CSharp @'
  using System;
  using System.Runtime.InteropServices;
  public static class Bpio {
    const uint FILE_FLAG_BACKUP_SEMANTICS=0x02000000, FILE_SHARE_READ=1, FILE_SHARE_WRITE=2, FILE_SHARE_DELETE=4, OPEN_EXISTING=3, GENERIC_READ=0x80000000;
    const uint FSCTL_MANAGE_BYPASS_IO=0x00090448; // ntifs.h
    [StructLayout(LayoutKind.Sequential)] struct FS_BPIO_INPUT{ public int Operation; public int InFlags; public ulong R1; public ulong R2; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct FS_BPIO_OUTPUT{ public int Operation; public int OutFlags; public int Status; public int Reserved;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DriverName;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Reason; }
    [DllImport(\"kernel32\", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr sa,uint disp,uint flags,IntPtr tpl);
    [DllImport(\"kernel32\", SetLastError=true)]
    static extern bool DeviceIoControl(IntPtr h,uint code,ref FS_BPIO_INPUT inB,int inSz,out FS_BPIO_OUTPUT outB,int outSz,out uint ret,IntPtr ov);
    [DllImport(\"kernel32\")] static extern bool CloseHandle(IntPtr h);
    public static int Query(string root){
      var h=CreateFile(@\"\\\\.\\\"+root.TrimEnd('\\'),GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,IntPtr.Zero,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,IntPtr.Zero);
      if(h==IntPtr.Zero||h.ToInt64()==-1) return 2;
      var input=new FS_BPIO_INPUT{Operation=3/*FS_BPIO_OP_QUERY*/,InFlags=0,R1=0,R2=0}; FS_BPIO_OUTPUT output; uint ret;
      bool ok=DeviceIoControl(h,FSCTL_MANAGE_BYPASS_IO,ref input,Marshal.SizeOf<FS_BPIO_INPUT>(),out output,Marshal.SizeOf<FS_BPIO_OUTPUT>(),out ret,IntPtr.Zero);
      CloseHandle(h); if(!ok) return 3;
      const int FSBPIO_OUTFL_COMPATIBLE_STORAGE_DRIVER=0x00000008;
      return ((output.OutFlags & FSBPIO_OUTFL_COMPATIBLE_STORAGE_DRIVER)!=0)? 0:1;
    }
  }
'@; exit ([Bpio]::Query('%SystemDrive%'))"
`) do set "BPIO_RC=%%I"

if "%BPIO_RC%"=="0" (
	ECHO *************************************************************************
	ECHO This system supports BypassIO Support- DO NOT enable the new NVMe driver
  	ECHO *************************************************************************
  pause
  goto :menu
) else (
  ECHO BypassIO-compatible storage not detected- continuing...
)
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

ECHO Enabling NVME storage features in registry
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 156965516 /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 1853569164 /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides /v 735209102 /t REG_DWORD /d 1 /f
::safemode fallback
ECHO Enabling SafeMode fallback registry entries
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" /ve /d "Storage Disks" /f
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
goto reboot
::=========================================================================
PAUSE

EXIT
