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

rem Optional: ensure UTF-8 to preserve special characters
	chcp 65001 >nul

rem --- 1) Collect PowerShell results into an in-memory array in batch ---
set "count=0"
for /f "usebackq delims= eol=" %%A in (`powershell -NoProfile -Command "Get-AppxProvisionedPackage -Online | Format-Table DisplayName, PackageName" do (
  set /a count+=1
  set "item[!count!]=%%~A"
)

if not defined count (
  echo No items returned from PowerShell.
  exit /b 1
)

rem --- 2) Render a numbered menu ---
echo.
echo Select a Provisioned Package to remove:
for /l %%I in (1,1,%count%) do (
  echo   %%I^) !item[%%I]!
)

rem --- 3) Get user input and validate ---
:ask
set "choice="
set /p "choice=Enter number (1-%count%): "

rem numeric validation
for /f "delims=0123456789" %%Z in ("%choice%") do set "choice="
if not defined choice goto ask
if %choice% LSS 1 goto ask
if %choice% GTR %count% goto ask

set "selected=!item[%choice%]!"
echo You selected: "%selected%"
echo.

rem --- 4) Do something with the selection (example: show details) ---
powershell -NoProfile -Command "Get-Service -Name '%selected%' | Format-List -Property *"

endlocal
exit /b 0

============================================================= 
::powershell -command "Get-AppxProvisionedPackage -Online | Format-Table DisplayName, PackageName"

set /p removeapp="Enter the EXACT name of the app above you wish to uninstall: "
::Deprovision UWP app. 
powershell -command "Remove-AppxProvisionedPackage -Online -DisplayName "%removeapp%""
PAUSE
goto MENU
::Registry key to verify deprovisioning
::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\

::co-pilot
HKLM\SOFTWARE\Microsoft\Windows\WindowsCopilot\ -dword TurnOffWindowsCopilot 1
::allows you to uninstall co-pilot
