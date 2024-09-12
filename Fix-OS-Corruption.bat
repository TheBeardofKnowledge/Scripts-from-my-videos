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

::chkdsk /f c:

sfc /scannow

dism /online /cleanup-image /scanhealth

dism /online /cleanup-image /restorehealth

Dism.exe /online /Cleanup-Image /StartComponentCleanup

Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
::Powershell
Get-AppxPackage Microsoft.Windows.ShellExperienceHost | foreach {Add-AppxPackage -register "$($_. InstallLocation)\appxmanifest.xml" -DisableDevelopmentMode}

Get-AppXPackage | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_. InstallLocation)\AppXManifest.xml"}
popd
