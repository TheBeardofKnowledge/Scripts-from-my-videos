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
::CD /d %~dp0
REM color fc
echo *******************************************************************************
ECHO Current free space of hard drive:
fsutil volume diskfree c:
echo *******************************************************************************
REM color f0
echo .
ECHO disabling hibernation & deleting the hibernation file
powercfg -h off
echo .
ECHO Deleting all temporary files
DEL /S /Q /F "%TMP%\*.*"
DEL /S /Q /F "%TEMP%\*.*"
DEL /S /Q /F "%WINDIR%\Temp\*.*"
DEL /S /Q /F "%USERPROFILE%\Local Settings\Temp\*.*"
DEL /S /Q /F "%LOCALAPPDATA%\Temp\*.*"
DEL /S /Q /F "%username%\AppData\Local\Temp\*.*"
del /S /Q /F c:\users\%username%\AppData\Local\Temp\*.*
del /S /Q /F c:\Windows\Prefetch\*.* 
del /S /Q /F c:\Windows\Temp\*.* 
del /S /Q /F c:\windows\Logs\CBS\*.* 
del /S /Q /F c:\users\%username%\AppData\Roaming\Microsoft\Windows\Recent Items\*.* 



net stop wuauserv

del /S /Q /F c:\windows\SoftwareDistribution\Download\*.* 
del /F /S /Q %Windir%\SoftwareDistribution\Download\*.*

net start wuauserv

cleanmgr /verylowdisk /autoclean /tuneup:5

REM ECHO Reenabling hibernation
REM powercfg -h on
color f2
echo *******************************************************************************
ECHO New free space of hard drive:
fsutil volume diskfree c:
echo *******************************************************************************
ECHO All cleaned up, have a nice day!
PAUSE


