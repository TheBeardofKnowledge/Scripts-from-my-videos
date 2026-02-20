
@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Optional: ensure UTF-8 to preserve special characters
rem chcp 65001 >nul

rem --- 1) Collect PowerShell results into an in-memory array in batch ---
set "count=0"
for /f "usebackq delims= eol=" %%A in (`powershell -NoProfile -Command ^
  "Get-Service | Where-Object {$_.Status -eq 'Running'} | Select-Object -ExpandProperty Name"`) do (
  set /a count+=1
  set "item[!count!]=%%~A"
)

if not defined count (
  echo No items returned from PowerShell.
  exit /b 1
)

rem --- 2) Render a numbered menu ---
echo.
echo Select a running service:
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
