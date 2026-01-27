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
set LOGFILE=%~dp0TBOKfix-OS-corruption.log
set PHASEFLAG=%~dp0RepairPhase.flag

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
TITLE The Beard of Knowledge automagic Windows repair script version 01-27-2026.
ECHO The Beard of Knowledge automagic Windows repair script version 01-27-2026. 
ECHO Follow on Youtube! TheBeardofKnowledge https://thebeardofknowledge.bio.link/
ECHO.
ECHO THIS SCRIPT REQUIRES INTERNET ACCESS TO MICROSOFT WINDOWS UPDATE SERVERS TO RUN REPAIRS
ECHO IF LAPTOP OR TABLET PLEASE ENSURE IT IS CONNECTED TO POWER
	if "%RESUME_MODE%"=="1" (
		echo RESUMING REPAIR AFTER RESTART
		echo.
		echo The following phases have been completed:
		echo  [X] DISM - Windows Image Health Check and Repair
		echo  [X] CHKDSK - Disk Error Check - ran during boot^)
		echo  [X] System Restart
		echo.
		echo Continuing with remaining repairs:
		echo  [ ] SFC  - System File Check and Repair
		echo  [ ] Component Store Cleanup
		echo  [ ] WMI Repository Repair - optional^)
		echo.
	) else (
		echo This script will perform the following repairs:
		echo  [1] DISM - Windows Image Health Check and Repair
		echo  [2] CHKDSK - Disk Error Check - scheduled at next boot^)
		echo  [3] System Restart - runs CHKDSK + prepares for SFC^)
		echo  [4] SFC  - System File Check and Repair
		echo  [5] Component Store Cleanup
		echo  [6] WMI Repository Repair - optional^)
		echo  [7] RE-Register Windows Apps - optional^)
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
ping -n 1 aka.ms >nul 2>&1
	if !errorlevel! neq 0 (
		echo WARNING: Could not connect to Microsoft Servers.
		echo DISM RestoreHealth requires Windows Update access.
		pause
	)

echo Checking if System Restore is enabled...
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval >nul 2>&1
	if !errorlevel! equ 0 (
		echo System Restore is enabled - creating restore point...
    
    :: Allow creating restore points more frequently than 24 hours
    reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1
    
    PowerShell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before TBOK System Repair' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction SilentlyContinue"
    if !errorlevel! equ 0 (
        echo Restore point created successfully.
        echo Restore point created successfully >> "%LOGFILE%"
    ) else (
        echo WARNING: Could not create restore point.
        echo WARNING: Restore point creation failed >> "%LOGFILE%"
    )
	) else (
		echo System Restore is disabled - skipping restore point creation
		echo System Restore disabled - restore point skipped >> "%LOGFILE%"
	)
echo [Phase 1 of 6] Running DISM operations
echo [Phase 1 of 6] Running DISM operations... >> "%LOGFILE%"
ECHO Stopping Windows Search
net stop "Windows Search" >> "%LOGFILE%" 2>&1

ECHO [step 1/3] Quick Check Windows Image Health
echo [Step 1/3] Checking Windows Image Health >> "%LOGFILE%"
	dism /online /cleanup-image /checkhealth >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
		echo WARNING: CheckHealth reported issues or errors >> "%LOGFILE%"
		)
		echo CheckHealth completed.
echo.
	
ECHO [step 2/3] Deep Scanning Windows Image Health
echo [Step 2/3] Scanning Windows Image... >> "%LOGFILE%"
	dism /online /cleanup-image /scanhealth >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
		echo WARNING: ScanHealth detected corruption >> "%LOGFILE%"
		)
		echo ScanHealth completed.
echo.
	
ECHO [step 3/3] Restoring-Repair Image Health
echo [Step 3/3] Repairing Windows Image... >> "%LOGFILE%"
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
echo [PHASE 2 of 6] Scheduling Disk Check for next boot...
echo [PHASE 2 of 6] Scheduling Disk Check... >> "%LOGFILE%"
echo.

echo Y | chkdsk %systemdrive% /f /r >> "%LOGFILE%" 2>&1
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
    
    if %errorlevel% equ 0 (
        echo Auto-resume task created successfully.
        echo Auto-resume task created successfully >> "%LOGFILE%"
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
        echo Logging restart timestamp... >> "%LOGFILE%"
        echo System restart initiated: %date% %time% >> "%LOGFILE%"
        shutdown /r /t 5 /c "Restarting for CHKDSK and DISM completion. Repair script will auto-resume after login."
        exit
	) else (
        echo WARNING: Failed to create auto-resume task.
        echo You will need to re-run this script manually after restart.
        pause
    )
)

echo.
echo ============================================
echo WARNING: Restart Declined
echo ============================================
echo You chose to continue without restarting.
echo.
echo This means:
echo  - CHKDSK will NOT run (disk errors may remain^)
echo  - SFC may be less effective (no fresh boot state^)
echo  - DISM repairs not fully applied yet
echo.
echo The script will continue, but repairs may not work.
echo Consider restarting manually and re-running this script.
echo ============================================
echo.
echo User chose to continue without restart >> "%LOGFILE%"
pause

:PHASE3_RESUME
REM PHASE 3: System File Checker
echo.
echo [Phase 3 of 6] Running System File Checker...
echo [Phase 3 of 6] Running System File Checker... >> "%LOGFILE%"
echo This may take 10-20 minutes...
echo.

	sfc /scannow >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
			echo WARNING: SFC found issues or encountered errors >> "%LOGFILE%"
			echo WARNING: SFC found issues. Check CBS.log for details.
		) else (
		echo SFC scan completed successfully.
	)

echo.
echo [PHASE 4 of 6] Cleaning up Component Store...
echo [PHASE 4 of 6] Component Store Cleanup... >> "%LOGFILE%"
echo This may take several minutes...
echo.

	dism /online /cleanup-image /startcomponentcleanup /resetbase >> "%LOGFILE%" 2>&1
		if %errorlevel% neq 0 (
			echo WARNING: Component cleanup encountered errors >> "%LOGFILE%"
			echo WARNING: Component cleanup encountered errors.
		) else (
		echo Component cleanup completed successfully.
	)
echo.

	
::WMIcorruptionfix
::(WMI corruption fix with delayed expansion)
echo.
echo [PHASE 5 of 6] WMI Repository Check and Repair...
echo [PHASE 5 of 6] WMI Repository Check and Repair... >> "%LOGFILE%"
echo.
ECHO Repairing Windows Management Instrumentation
ECHO This is an aggressive repair. It will stop the WMI service,
ECHO re-register all WMI-related DLLs, and recompile all standard
ECHO MOF files in the WBEM directory, except uninstallers.
ECHO. 

set /p REPAIR_WMI="Do you want to check and repair WMI? (Y/N): "
setlocal enabledelayedexpansion
if /i "%REPAIR_WMI%"=="Y" (
    echo.
    echo [PHASE 5 of 6] WMI Repository Repair... >> "%LOGFILE%"
    echo Checking WMI Repository consistency...
    winmgmt /verifyrepository >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 (
        echo WMI Repository is consistent - no repair needed.
        echo WMI Repository is consistent >> "%LOGFILE%"
    ) else (
        echo WMI Repository is inconsistent - attempting repair...
        echo WMI Repository is inconsistent - repairing... >> "%LOGFILE%"
        echo Disabling and stopping the WMI service...
        echo Disabling and stopping WMI service... >> "%LOGFILE%"
        sc config winmgmt start= disabled >> "%LOGFILE%" 2>&1
        net stop winmgmt /y >> "%LOGFILE%" 2>&1
        
        echo [1/3] Registering all WMI provider DLLs...
        echo [1/3] Registering WMI provider DLLs... >> "%LOGFILE%"
        cd /d %windir%\system32\wbem
        for /f %%s in ('dir /b *.dll') do (
            echo Registering %%s... >> "%LOGFILE%"
            regsvr32 /s %%s >> "%LOGFILE%" 2>&1
        )
        echo Registering WMI Provider Host and WMI Service...
        wmiprvse /regserver >> "%LOGFILE%" 2>&1
        winmgmt /regserver >> "%LOGFILE%" 2>&1
        echo DLL registration complete.
        
        echo [2/3] Recompiling MOF and MFL files (excluding uninstallers^)...
        echo [2/3] Recompiling MOF/MFL files... >> "%LOGFILE%"
        dir /b *.mof *.mfl | findstr /v /i "uninstall" > mof_exclude.txt
        for /f %%s in (mof_exclude.txt) do (
            echo Compiling %%s... >> "%LOGFILE%"
            mofcomp %%s >> "%LOGFILE%" 2>&1
        )
        if exist mof_exclude.txt del mof_exclude.txt
        echo MOF compilation complete.
        
        echo [3/3] Re-enabling and starting the WMI service...
        echo [3/3] Re-enabling and starting WMI service... >> "%LOGFILE%"
        sc config winmgmt start= auto >> "%LOGFILE%" 2>&1
        net start winmgmt >> "%LOGFILE%" 2>&1
        timeout /t 5 /nobreak >nul       
		
        echo Verifying WMI repository after repair...
        winmgmt /verifyrepository >> "%LOGFILE%" 2>&1
        if !errorlevel! equ 0 (
            echo WMI Repository repair completed successfully.
            echo WMI Repository repair SUCCESSFUL >> "%LOGFILE%"
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
endlocal
echo [PHASE 6 of 6] Windows Store Apps Re-registration...
echo.
	set /p REPAIR_APPX="Do you want to re-register Windows Store Apps? (Y/N): "
	if /i "%REPAIR_APPX%"=="Y" (
		echo.
		echo Re-registering Windows Store Apps...
		echo Re-registering AppX Packages... >> "%LOGFILE%"
    
		PowerShell -ExecutionPolicy Bypass -Command "Get-AppXPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register \"$($_.InstallLocation)\AppXManifest.xml\" -ErrorAction SilentlyContinue}" >> "%LOGFILE%" 2>&1
    
		echo AppX re-registration completed.
		echo.
	) else (
		echo AppX re-registration skipped by user.
		echo AppX re-registration skipped by user. >> "%LOGFILE%"
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
echo  - WMI Repository: %REPAIR_WMI%
echo  - AppX Re-registration: %REPAIR_APPX%
echo.
echo Log file location: %LOGFILE%
echo.
echo NEXT STEPS:
echo  1. Review the log file for any errors or warnings
echo  2. No additional restart required (unless issues found^)
echo  3. Your system repairs are complete
echo.
echo For detailed results, check these log files:
echo  - This script's log: %LOGFILE%
echo  - DISM log: C:\Windows\Logs\DISM\dism.log
echo  - SFC log: C:\Windows\Logs\CBS\CBS.log
echo  - CHKDSK log: Run 'chkdsk' to view results
echo.
echo ================================================================
echo.

echo ============================================ >> "%LOGFILE%"
echo Repair Script Completed: %date% %time% >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"

::after cleanup
if exist "%PHASEFLAG%" (
    echo Cleaning up auto-resume task...
    echo Cleaning up auto-resume task... >> "%LOGFILE%"
    
    schtasks /delete /tn "TBOKWindowsRepairResume" /f >nul 2>&1
    if %errorlevel% equ 0 (
        echo Auto-resume task deleted successfully.
        echo Auto-resume task deleted successfully >> "%LOGFILE%"
    )
    
    del "%PHASEFLAG%" >nul 2>&1
    if exist "%PHASEFLAG%" (
        echo WARNING: Could not delete phase flag file: %PHASEFLAG%
    ) else (
        echo Phase flag file cleaned up >> "%LOGFILE%"
    )
)
endlocal
pause
exit /b 0


