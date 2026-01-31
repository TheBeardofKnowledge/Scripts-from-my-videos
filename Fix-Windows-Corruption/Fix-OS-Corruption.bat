@ECHO OFF
setlocal enableextensions enabledelayedexpansion
	color f0
ECHO Running Admin shell
ECHO ::::::::::::::::::::::::::::::::::::::::::::
ECHO  Automatically check and get admin rights 
ECHO ::::::::::::::::::::::::::::::::::::::::::::
 
:checkPrivileges 
NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges ) 
:getPrivileges
:: Not elevated, so re-run with elevation
	    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    exit /b
:gotPrivileges 

:: Log stored in current script directory
set "LOGFILE=%~dp0TBOKfix-OS-corruption.log"
set "PHASEFLAG=%~dp0RepairPhase.flag"
goto resumecheck

::LOG and echo helper to avoid duplicate lines
::usage call :LOG "message"
:LOG 
echo %~1
echo %~1>>"%LOGFILE%"
exit /b

:resumecheck
:: Check if this is a resume from restart
set RESUME_MODE=0
if /i "%1"=="/resume" (
    if exist "%PHASEFLAG%" (
        set RESUME_MODE=1
        echo ============================================ >> "%LOGFILE%"
        echo Resuming repair after restart >> "%LOGFILE%"
        echo Resumed: %date% %time% >> "%LOGFILE%"
        echo ============================================ >> "%LOGFILE%"
        echo. >> "%LOGFILE%"
        goto PHASE3_RESUME
    ) else (
        echo WARNING: Resume requested but no phase flag found. Starting from beginning.
        echo WARNING: Resume requested but flag missing - starting fresh >> "%LOGFILE%"
    )
)

:: Clean up any stale flag file from previous incomplete runs
if exist "%PHASEFLAG%" (
    echo Cleaning up stale flag file from previous run...
    del "%PHASEFLAG%" >nul 2>&1
)

echo ============================================ >> "%LOGFILE%"
echo Windows System Repair Log >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"
cls
:STARTINTRO
TITLE The Beard of Knowledge automagic Windows repair script version 01-30-2026.
ECHO The Beard of Knowledge automagic Windows repair script version 01-30-2026. 
ECHO Follow on Youtube! TheBeardofKnowledge https://thebeardofknowledge.bio.link/
ECHO.
ECHO THIS SCRIPT REQUIRES INTERNET ACCESS TO MICROSOFT WINDOWS UPDATE SERVERS TO RUN REPAIRS
ECHO IF THIS IS A LAPTOP OR TABLET PLEASE ENSURE IT IS CONNECTED TO POWER
	if "%RESUME_MODE%"=="1" (
		echo RESUMING REPAIR AFTER RESTART
		echo.
		echo The following phases have been completed:
		echo  [X] DISM - Windows Image Health Check and Repair
		echo  [X] CHKDSK - Disk Error Check (ran during boot^)
		echo  [X] System Restart
		echo.
		echo Continuing with remaining repairs:
		echo  [ ] SFC  - System File Check and Repair
		echo  [ ] Component Store Cleanup
		echo  [ ] WMI Repository Repair (optional^)
		echo.
	) else (
		echo This script will perform the following repairs:
		echo  [1] DISM - Windows Image Health Check and Repair
		echo  [2] CHKDSK - Disk Error Check (scheduled at next boot^)
		echo  [3] System Restart (runs CHKDSK and prepares for SFC^)
		echo  [4] SFC  - System File Check and Repair
		echo  [5] Component Store Cleanup
		echo  [6] WMI Repository Repair (optional^)
		echo  [7] RE-Register Windows Apps (optional^)
		echo  Reboot to complete repairs
		echo Log file: %LOGFILE%
		echo.
	)
PAUSE
ECHO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
ECHO Starting Windows System Repair
ECHO This process can take some time depending on your System
ECHO DO NOT CLOSE OR CANCEL THIS PROCESS BEFORE IT COMPLETES
ECHO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
echo.
echo Performing pre-flight checks...
	PowerShell -ExecutionPolicy Bypass -Command "Try { [System.Net.WebClient]::new().DownloadString('http://www.msftconnecttest.com/connecttest.txt') | Out-Null; exit 0 } Catch { exit 1 }" >nul 2>&1
	if !errorlevel! neq 0 (
    echo WARNING: Could not connect to Microsoft test servers.
    echo DISM RestoreHealth requires Windows servers connection.
    pause
	) else (
	echo Basic Internet test to Microsoft confirmed - continue repairs
	)
echo Checking if System Restore is enabled...
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval >nul 2>&1
	if !errorlevel! equ 0 (
    echo System Restore is enabled - checking required services...
    
    :: Check if Volume Shadow Copy service is running
    sc query vss | find "RUNNING" >nul 2>&1
    if !errorlevel! neq 0 (
        echo Starting Volume Shadow Copy service...
        net start vss >nul 2>&1
        timeout /t 2 /nobreak >nul
    )
    :: Allow creating restore points more frequently than 24 hours
    reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
    :: Wait for registry change to take effect
    timeout /t 2 /nobreak >nul
    
    echo Creating restore point...
    PowerShell -ExecutionPolicy Bypass -Command "try { Checkpoint-Computer -Description 'Before TBOK System Repair' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Restore point created successfully.
        call :LOG "Restore point created successfully"
    ) else (
        echo WARNING: Could not create restore point.
        echo This may be due to:
        echo  - A restore point was created in the last 24 hours
        echo  - System Protection is disabled for the system drive
        echo  - Volume Shadow Copy service issues
        echo  - Insufficient disk space
        echo.
        echo The script will continue without a restore point.
        call :LOG "WARNING: Restore point creation failed"
        pause
    )
) else (
    call :LOG "System Restore disabled - restore point skipped"
)
call :LOG "[Phase 1 of 6] Running DISM operations"
ECHO Stopping Windows Search
net stop "Windows Search" >> "%LOGFILE%" 2>&1

call :LOG "[step 1/3] Quick Check Windows Image Health"
	dism /online /cleanup-image /checkhealth >> "%LOGFILE%" 2>&1
		if !errorlevel! neq 0 (
		call :LOG "WARNING: CheckHealth reported issues or errors"
		)
		echo CheckHealth completed.
echo.
	
call :LOG "[step 2/3] Deep Scanning Windows Image Health"
	dism /online /cleanup-image /scanhealth >> "%LOGFILE%" 2>&1
		if !errorlevel! neq 0 (
		call :LOG "WARNING: ScanHealth detected corruption"
		)
		echo ScanHealth completed.
echo.
	
call :LOG "[step 3/3] Restoring-Repair Image Health"
dism /online /cleanup-image /restorehealth >> "%LOGFILE%" 2>&1
	if !errorlevel! neq 0 (
		echo.
		echo ============================================
		echo ERROR: DISM RestoreHealth failed
		echo ============================================
		echo This could indicate:
		echo  - No internet connection to Windows Update
		echo  - Corrupted Windows Update components
		echo  - Severe system corruption
		echo.
		echo Please check:
		echo  1. Internet connectivity
		echo  2. Windows Update service is running
		echo  3. Review log: %LOGFILE%
		echo.
		set /p CONTINUE="Continue anyway? (Y/N): "
		if /i not "!CONTINUE!"=="Y" exit /b 1
	) else (
			echo DISM repairs completed successfully.
	)
echo.

:: PHASE 2: Schedule CHKDSK for Next Boot
REM ============================================================================
echo.
call :LOG "[PHASE 2 of 6] Scheduling Disk Check for next boot..."
echo.

echo Y | chkdsk %systemdrive% /f >> "%LOGFILE%" 2>&1
echo CHKDSK has been scheduled to run during the next system restart.
echo This will check and repair disk errors while Windows is offline.
echo.
echo ================================================================
echo              OPTIMIZED RESTART REQUIRED
echo ================================================================
echo.
echo A restart is now recommended to:
echo  1. Run CHKDSK to fix any disk errors (scheduled above^)
echo  2. Complete DISM repairs and refresh system state
echo  3. Optimize SFC scan performance (less file locks^)
echo.
echo The script will automatically continue after restart to run:
echo  - SFC (System File Checker^)
echo  - Component Store Cleanup
echo  - WMI Repository Repair (optional^)
echo  - AppX Package Re-registration (optional^)
echo.
echo ================================================================
echo.

	set /p RESTART_CHOICE="Restart now and auto-continue with repairs? (Y/N): "
	if /i "%RESTART_CHOICE%"=="Y" (
	echo.
    echo Creating auto-resume task for after restart...
    echo Creating auto-resume task... >> "%LOGFILE%"
    
    :: Create a flag file to mark Phase 2 complete
    echo PHASE2_COMPLETE > "%PHASEFLAG%"
    
    :: Create scheduled task to resume script at next logon
	schtasks /create /tn "TBOKWindowsRepairResume" /tr "'%~dpnx0' /resume" /sc onlogon /rl highest /f >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 (
        call :LOG "Auto-resume task created successfully."
        echo.
        echo ============================================
        echo IMPORTANT: What happens next
        echo ============================================
        echo 1. Computer will restart in 10 seconds
        echo 2. CHKDSK will run automatically during boot
        echo 3. After you log in, this script resumes
        echo 4. Remaining repairs complete automatically
        echo.
        echo Press Ctrl+C now to cancel the restart.
        echo ============================================
        echo.
        timeout /t 10
        call :LOG "Logging restart timestamp..."
        call :LOG "System restart initiated: %date% %time%"
        shutdown -r -t 5 -c "TBOK Restarting for CHKDSK and DISM completion. Repair script will auto-resume after login."
		exit /b
) else (
        echo WARNING: Did not create auto-resume task.
        echo You will need to re-run this script manually after restart.
		echo.
		echo ============================================
		echo Your system has not been checked completely.
		echo ============================================
		echo Process incomplete.
		echo.
		echo This means:
		echo  - CHKDSK will NOT run (disk errors may remain^)
		echo  - SFC will not run (no fresh boot state^)
		echo  - DISM repairs not fully applied yet
		echo  - WMI not checked or repaired for consistency
		echo  - APP-X application problems may still exist
		echo.
		echo The script will now exit.
		echo Consider allowing the script to complete.
		echo ============================================
		echo.
		call :LOG "User chose to continue without restart"
		pause
		exit /b
)

:PHASE3_RESUME
::PHASE 3: After System restart
::System File Checker
TITLE TBOK System Repair Script Continued
echo.
call :LOG "Resuming TBOK System Repair Script"
call :LOG "[Phase 3 of 6] Running System File Checker"
echo This may take 10-20 minutes...
echo.

	sfc /scannow >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
			call :LOG "WARNING: SFC found issues or encountered errors - Check CBS.log for details."
		) else (
		echo SFC scan completed successfully.
	)

echo.
call :LOG "[PHASE 4 of 6] Component Store Cleanup..."
echo This may take several minutes...
echo.

	dism /online /cleanup-image /startcomponentcleanup /resetbase >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
			call :LOG "WARNING: Component cleanup encountered errors"
		) else (
		echo Component cleanup completed successfully.
	)
echo.

	
::WMIcorruptionfix
::(WMI corruption fix with delayed expansion)
echo.
call :LOG "[PHASE 5 of 6] WMI Repository Check and Repair"
echo.
ECHO Repairing Windows Management Instrumentation
ECHO This is an aggressive repair. It will stop the WMI service,
ECHO re-register all WMI-related DLLs, and recompile all standard
ECHO MOF files in the WBEM directory, except uninstallers.
ECHO. 

set /p REPAIR_WMI="Do you want to check and repair WMI? (Y/N): "
if /i "%REPAIR_WMI%"=="Y" (
    echo.
    echo [PHASE 5 of 6] WMI Repository Repair... >> "%LOGFILE%"
    echo Checking WMI Repository consistency...
    winmgmt /verifyrepository >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 (
        call :LOG "WMI Repository is consistent - no repair needed."
    ) else (
        call :LOG "WMI Repository is inconsistent - attempting repair..."
        call :LOG "Disabling and stopping the WMI service..."
        sc config winmgmt start= disabled >> "%LOGFILE%" 2>&1
        net stop winmgmt /y >> "%LOGFILE%" 2>&1
        
        call :LOG "[1/3] Registering all WMI provider DLLs..."
        cd /d %windir%\system32\wbem
        for /f %%s in ('dir /b *.dll') do (
            echo Registering %%s... >> "%LOGFILE%"
            regsvr32 /s %%s >> "%LOGFILE%" 2>&1
        )
        echo Registering WMI Provider Host and WMI Service...
        wmiprvse /regserver >> "%LOGFILE%" 2>&1
        winmgmt /regserver >> "%LOGFILE%" 2>&1
        echo DLL registration complete.
        
        call :LOG "[2/3] Recompiling MOF and MFL files (excluding uninstallers^)..."
        dir /b *.mof *.mfl | findstr /v /i "uninstall" > mof_exclude.txt
        for /f %%s in (mof_exclude.txt) do (
            echo Compiling %%s... >> "%LOGFILE%"
            mofcomp %%s >> "%LOGFILE%" 2>&1
        )
        if exist mof_exclude.txt del mof_exclude.txt
        echo MOF compilation complete.
        
        call :LOG "[3/3] Re-enabling and starting WMI service..."
        sc config winmgmt start= auto >> "%LOGFILE%" 2>&1
        net start winmgmt >> "%LOGFILE%" 2>&1
        timeout /t 5 /nobreak >nul       
		
        echo Verifying WMI repository after repair...
        winmgmt /verifyrepository >> "%LOGFILE%" 2>&1
        if !errorlevel! equ 0 (
            call :LOG "WMI Repository repair completed successfully."
        ) else (
            echo WARNING: WMI Repository may still have issues.
            echo Consider running 'winmgmt /resetrepository' manually if problems persist.
            echo WARNING: WMI Repository verification failed after repair >> "%LOGFILE%"
        )
    )
    echo.
) else (
    echo WMI repair skipped by user.
    echo WMI repair skipped by user. >> "%LOGFILE%"
)
echo.
echo [PHASE 6 of 6] Windows Store Apps Re-registration...
echo.
set /p REPAIR_APPX="Do you want to re-register Windows Store Apps? (Y/N): "
if /i "!REPAIR_APPX!"=="Y" (
    echo.
    call :LOG "Re-registering AppX Packages..."
    
    PowerShell -ExecutionPolicy Bypass -Command "Get-AppXPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register \"$($_.InstallLocation)\AppXManifest.xml\" -ErrorAction SilentlyContinue}"
    
    if !errorlevel! neq 0 (
        call :LOG "WARNING: Some AppX packages may have failed to register."
    ) else (
        echo AppX re-registration completed successfully.
    )
    echo.
) else (
    call :LOG "AppX re-registration skipped by user."
)

:completed
echo.
echo ================================================================
echo                    REPAIR COMPLETED
echo ================================================================
echo.
echo Summary of operations:
echo  - DISM Image Health Check and Repair: Completed
echo  - CHKDSK Disk Error Check: Completed (ran during boot^)
echo  - System File Checker (SFC): Completed
echo  - Component Store Cleanup: Completed
echo  - WMI Repository: !REPAIR_WMI!
echo  - AppX Re-registration: !REPAIR_APPX!
echo.
echo Log file location: !LOGFILE!
echo.
echo NEXT STEPS:
echo  1. Review the log file for any errors or warnings
echo  2. No additional restart required (unless issues found^)
echo  3. Your system repairs are complete
echo.
echo For detailed results, check these log files:
echo  - This script's log: !LOGFILE!
echo  - DISM log: C:\Windows\Logs\DISM\dism.log
echo  - SFC log: C:\Windows\Logs\CBS\CBS.log
echo  - CHKDSK log: Run 'chkdsk' to view results
echo.
echo ================================================================
echo.

echo ============================================ >> "!LOGFILE!"
echo Repair Script Completed: %date% %time% >> "!LOGFILE!"
echo ============================================ >> "!LOGFILE!"

::after cleanup
if exist "%PHASEFLAG%" (
    call :LOG " Cleaning up auto-resume task..."
    schtasks /delete /tn "TBOKWindowsRepairResume" /f >nul 2>&1
    if %errorlevel% equ 0 (
    call :LOG "Auto-resume task deleted successfully."
    )
    del "%PHASEFLAG%" >nul 2>&1
    if exist "%PHASEFLAG%" (
        echo WARNING: Could not delete phase flag file: %PHASEFLAG%
    ) else (
        echo Phase flag file cleaned up >> "!LOGFILE!"
    )
)
endlocal
pause
exit /b 0

