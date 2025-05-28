@ECHO OFF

::WMIcorruptionfix
echo Checking / Repairing Windows Management Instrumentation
	cd C:\Windows\System32\Wbem
	for /f %%s in ('dir /b *.mof *.mfl') do mofcomp %%s
	for %%i in (*.dll) do regSvr32 -s %%i)
	net stop winmgmt /y
	net start winmgmt
