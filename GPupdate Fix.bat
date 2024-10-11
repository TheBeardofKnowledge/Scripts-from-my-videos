@ECHO OFF
:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
CLS 
ECHO.
ECHO =============================
ECHO Running Admin shell
ECHO =============================
 
:checkPrivileges 
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges ) 
 
:getPrivileges 
if '%1'=='ELEV' (shift & goto gotPrivileges)  
ECHO. 
ECHO **************************************
ECHO Invoking UAC for Privilege Escalation 
ECHO **************************************
 
setlocal DisableDelayedExpansion
set "batchPath=%~0"
setlocal EnableDelayedExpansion
ECHO Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPrivileges.vbs" 
ECHO UAC.ShellExecute "!batchPath!", "ELEV", "", "runas", 1 >> "%temp%\OEgetPrivileges.vbs" 
"%temp%\OEgetPrivileges.vbs" 
exit /B 
 
:gotPrivileges 
::::::::::::::::::::::::::::
:START
::::::::::::::::::::::::::::
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
echo "Flushing Cached GPO data on local workstation"
	RD /S /Q "%WinDir%\System32\GroupPolicyUsers" 
	RD /S /Q "%WinDir%\System32\GroupPolicy"
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

