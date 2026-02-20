@echo off
TITLE TBOK Provisioned APP DEPROVISIONING Script
cls
:: Automatically check & get admin rights ::
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
ECHO Brought to you by The Beard of Knowledge
ECHO Based on Video "How to remove Windows 11 Junk for Good! by CyberCPU Tech
::Enabling option to remove co-pilot
 REG ADD "HKLM\SOFTWARE\Microsoft\Windows\WindowsCopilot" /v /t REG_DWORD /d 00000001 /f	>nul 2>&1
 :MENU

echo.
echo ====================================================================
echo  Windows Provisioned APP DEPROVISIONING Script
echo ====================================================================
echo.
echo  --- Please select an option ---
echo.
echo    [1] List and remove provisioned packages
echo    [2] Exit
echo.
echo ====================================================================
echo.

set /p choice="Enter your choice [1-2]: "

if "%choice%"=="1" goto GETLIST
if "%choice%"=="2" goto EXIT
echo Invalid choice. Please try again.
pause
goto MENU

:getlist
ECHO Below are all the Provisioned APPS in this system:
::Get UWP (Universal Windows Platform) names
ECHO ============================================================

setlocal EnableExtensions EnableDelayedExpansion

::Optional: ensure UTF-8 to preserve special characters
::chcp 65001 >nul

::Collect PowerShell results into an in-memory array in batch ---
set "count=0"
for /f "usebackq delims= eol=" %%A in (`powershell -NoProfile -Command ^
 "Get-AppxProvisionedPackage -Online | Format-Table PackageName"`) do (
	set /a count+=1
	rem Remove ALL spaces from the line
	set "line=%%~A"
	set "line=!line: =!"
	set "item[!count!]=!line!"
	)

if not defined count (
	echo No items returned from PowerShell.
	exit /b 1
	)

::Render a numbered menu for use with selection
	echo.
	echo Showing Provisioned Packages and numbering for easier selection:
	for /l %%I in (1,1,%count%) do (
	echo   %%I^) !item[%%I]!
	)

::Get user input and validate ---
	set "choice="
	set /p "choice=Enter the number on the left of the item to remove (1-%count%): "

::numeric validation
	for /f "delims=0123456789" %%Z in ("%choice%") do set "choice="
	if not defined choice goto ask
	if %choice% LSS 1 goto ask
	if %choice% GTR %count% goto ask

		set "selected=!item[%choice%]!"
		echo You selected: "%selected%"
		echo.

::action to perform on selection
	echo Attempting to remove selected package:
	powershell -NoProfile -Command "Remove-AppxProvisionedPackage -Online -PackageName '%selected%'"

		endlocal
PAUSE
goto MENU
:exit
exit /b 0

