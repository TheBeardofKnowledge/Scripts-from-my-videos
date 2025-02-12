@ECHO OFF

:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
CLS 
ECHO.
ECHO =============================
ECHO Running Admin shell
ECHO =============================
::batch file elevation notes
::method 1 - using powershell
@echo off
:: Check for elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Not elevated, so re-run with elevation
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0 %*' -Verb RunAs"
    exit /b
)
 
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
