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
ECHO Repairing Windows Management Instrumentation 
ECHO Checking / Repairing Windows Management Instrumentation
	net stop winmgmt /y
	cd C:\Windows\System32\Wbem
	for /f %%s in ('dir /b *.mof *.mfl') do mofcomp %%s
	for %%i in (*.dll) do regSvr32 -s %%i)
	sc config winmgmt start= disabled
	Winmgmt /salvagerepository %windir%\System32\wbem
	Winmgmt /resetrepository %windir%\System32\wbem
	sc config winmgmt start= auto
	net start winmgmt
::Powershell
ECHO Registering AppXPackages to Fix Windows APP and Store Problems
::Powershell
::Fix Windows Store
PowerShell -ExecutionPolicy Unrestricted -C "& {Add-AppxPackage -DisableDevelopmentMode -Register ((Get-AppxPackage *Microsoft.WindowsStore*).InstallLocation + '\AppxManifest.xml')}"

PowerShell -ExecutionPolicy Unrestricted -c "Get-AppXPackage | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_. InstallLocation + '\appxmanifest.xml')}"

PowerShell -ExecutionPolicy Unrestricted -c "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | foreach {Add-AppxPackage -register "$($_. InstallLocation + '\appxmanifest.xml') -DisableDevelopmentMode}"

::end of script
ECHO Service is complete, please restart the pc for the changes to take effect.
PAUSE

