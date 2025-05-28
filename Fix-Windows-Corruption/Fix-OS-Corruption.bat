:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
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

chkdsk /scan /perf c:

sfc /scannow

dism /online /cleanup-image /scanhealth

dism /online /cleanup-image /restorehealth

Dism.exe /online /Cleanup-Image /StartComponentCleanup

Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
::Powershell
Get-AppxPackage Microsoft.Windows.ShellExperienceHost | foreach {Add-AppxPackage -register "$($_. InstallLocation)\appxmanifest.xml" -DisableDevelopmentMode}

Get-AppXPackage | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_. InstallLocation)\AppXManifest.xml"}
popd
