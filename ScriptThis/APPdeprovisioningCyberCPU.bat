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
powershell -command "Get-AppxProvisionedPackage -Online | Format-Table DisplayName, PackageName"

set /p removeapp="Enter the EXACT name of the app above you wish to uninstall: "
::Deprovision UWP app. 
powershell -command "Remove-AppxProvisionedPackage -Online -packagename "%removeapp%""
PAUSE
goto MENU
::Registry key to verify deprovisioning
::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\

::co-pilot
HKLM\SOFTWARE\Microsoft\Windows\WindowsCopilot\ -dword TurnOffWindowsCopilot 1
::allows you to uninstall co-pilot
