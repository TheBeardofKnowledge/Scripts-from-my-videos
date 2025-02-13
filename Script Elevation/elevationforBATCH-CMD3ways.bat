::batch file elevation notes
::======================method 1 - using powershell====================================
@echo off
:: Check for elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Not elevated, so re-run with elevation
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0 %*' -Verb RunAs"
    exit /b
)
:: Your elevated commands go here
echo This batch file is running with administrative privileges.
pause

::======================method 2 - using scheduled tasks================================
@echo off
:: Check for elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Not elevated, so create a scheduled task to run with elevation
    schtasks /create /tn "ElevateBatch" /tr "%~s0 %*" /sc once /st 00:00 /rl highest /f
    schtasks /run /tn "ElevateBatch"
    schtasks /delete /tn "ElevateBatch" /f
    exit /b
)
:: Your elevated commands go here
echo This batch file is running with administrative privileges.
pause

:========================method 3 - asks for password===========================
@echo off
:: Check for elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Not elevated, so re-run with elevation
    runas /user:Administrator "%~s0 %*"
    exit /b
)
:: Your elevated commands go here
echo This batch file is running with administrative privileges.
pause