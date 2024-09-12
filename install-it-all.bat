@ECHO OFF
:: set batch file script path as default working path
CD /d %~dp0
ECHO ===================================================================================

	ECHO Installing Everything in current folder...

:: The following command executes all files in folders and subfolders silently, one at a time and in order
	FOR /r "." %%a in (*.exe) do "%%~fa" -s

	ECHO Complete. 
	ECHO Remember to reboot if needed
	ECHO Monitor Task Manager Processes to ensure installations complete
	TIMEOUT 120
