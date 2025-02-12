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
winget update --all --include-unknown --accept-source-agreements --accept-package-agreements --silent --verbose
PAUSE
::to exclude a package use
::winget pin add --name "Micron Storage Executive" --blocking
::to remove a package from pin use
::winget pin remove --name "Micron Storage Executive"
