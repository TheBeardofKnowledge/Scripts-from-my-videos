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
@ECHO OFF
:: set batch file script path as default working path
CD /d %~dp0
ECHO ===================================================================================

	ECHO Installing Everything in current folder...

:: The following command executes all files in folders and subfolders silently, one at a time and in order
	FOR /r "." %%a in (*.exe) do "%%~fa" -s

	ECHO Complete. 
	ECHO Remember to reboot if needed
	ECHO Monitor Task Manager Processes to ensure installations complete
	TIMEOUT 120
