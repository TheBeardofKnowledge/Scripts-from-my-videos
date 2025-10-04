TITLE
:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
@ECHO OFF
	color f0
ECHO =============================
ECHO This Script Needs Admin rights to perform repairs -Checking Admin shell
ECHO =============================
 
:checkPrivileges 
NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges ) 
:getPrivileges
    :: Not elevated, so re-run with elevation
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0 %*' -Verb RunAs"
    exit /b
)
:gotPrivileges 
::::::::::::::::::::::::::::
:STARTINTRO
::::::::::::::::::::::::::::
::cls
@ECHO OFF
color
TITLE The Beard of Knowledge automagic workstation repair script.
ECHO The Beard of Knowledge automagic workstation repair script. Follow on Youtube!
::TheBeardofKnowledge https://thebeardofknowledge.bio.link/
::
ECHO Checking your Windows Drive for Errors
	chkdsk /scan /perf /sdcleanup /forceofflinefix c:
ECHO Running Windows System Files Checker to check and repair errors
	sfc /scannow
ECHO Checking Windows Image Health
	dism /online /cleanup-image /scanhealth
ECHO Restoring Image Health
	dism /online /cleanup-image /restorehealth
ECHO Cleaning Image Components
	Dism.exe /online /Cleanup-Image /StartComponentCleanup
ECHO Reset Base Image
	Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
 
::WMIcorruptionfix
ECHO Repairing Windows Management Instrumentation

echo This is an aggressive repair. It will stop the WMI service,
echo re-register all WMI-related DLLs, and recompile all standard
echo MOF files in the WBEM directory except uninstallers.
echo Disabling and stopping the WMI service...
	sc config winmgmt start= disabled
	net stop winmgmt /y

echo registering all provider DLLs
	cd /d %windir%\system32\wbem
	for /f %%s in ('dir /b *.dll') do (
	    echo Registering %%s...
	    regsvr32 /s %%s
	)
echo DLL registration complete.

echo Recompiling MOF and MFL files (excluding uninstallers)...
:: This command creates a list of MOF/MFL files, filters out any
:: containing "uninstall", and then compiles the files from that list.
	dir /b *.mof *.mfl | findstr /v /i "uninstall" > exclude.txt
	for /f %%s in (exclude.txt) do (
	    echo Compiling %%s...
	    mofcomp %%s
	)
	del exclude.txt
echo MOF compilation complete.

echo Re-enabling and starting the WMI service...
	sc config winmgmt start= auto
	net start winmgmt

::Powershell
ECHO Registering AppXPackages to Fix Windows APP and Store Problems
::Powershell
::Fix Windows Store Apps
PowerShell -ExecutionPolicy Unrestricted -C "& {Add-AppxPackage -DisableDevelopmentMode -Register ((Get-AppxPackage *Microsoft.WindowsStore*).InstallLocation + '\AppxManifest.xml')}"

PowerShell -ExecutionPolicy Unrestricted -c "Get-AppXPackage | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_. InstallLocation + '\appxmanifest.xml')}"

PowerShell -ExecutionPolicy Unrestricted -c "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | foreach {Add-AppxPackage -register "$($_. InstallLocation + '\appxmanifest.xml') -DisableDevelopmentMode}"

::end of script
exit
ECHO Service is complete, please restart the pc for the changes to take effect.
echo ?
set /P c=A reboot might be required to complete the settings, do you wish to reboot now[Y/N]?
if /I "%c%" EQU "Y" goto :REBOOT
if /I "%c%" EQU "N" goto :END

:REBOOT
shutdown -r -t 0

:END
exit




