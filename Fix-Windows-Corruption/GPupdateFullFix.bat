:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: This Script Needs Admin Rights to properly fix the issue
::Automatically check & get admin rights
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@ECHO OFF
color f0
ECHO =============================
ECHO Running Admin shell
ECHO =============================
 
:checkPrivileges 
NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges ) 
:getPrivileges
::method 1 - using powershell
::@echo off
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

ECHO Verify and Display current sync
	w32tm /query /status

ECHO Please verify time server sync displayed above is your correct domain server


:DCTIMESET
ECHO Configuring time sync with DC server
	w32tm /config /syncfromflags:domhier /update
	net stop w32time
	net start w32time
ECHO Updating time service config =============================
	w32tm /config /update

ECHO Synchronizing time with DC ===============================
	w32tm /resync

ECHO Verify and Display current sync ==========================
	w32tm /query /status

:updateGPO
echo Flushing Cached GPO data on local workstation
	RD /S /Q "%WinDir%\System32\GroupPolicyUsers" 
	RD /S /Q "%WinDir%\System32\GroupPolicy"
	RD /S /Q "c:\GroupPolicy"
	RD /S /Q "c:\ProgramData\Microsoft\GroupPolicy"
	RD /S /Q "c:\windows\syswow64\grouppolicy"
	RD /S /Q "c:\windows\syswow64\grouppolicyusers"

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

	echo "Updating Group policy"
	gpupdate /force
	

echo ?
set /P c=A reboot might be required to complete the settings, do you wish to reboot now[Y/N]?
if /I "%c%" EQU "Y" goto :REBOOT
if /I "%c%" EQU "N" goto :END

:REBOOT
shutdown -r -t 0

:END
exit




