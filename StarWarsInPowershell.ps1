$Host.UI.RawUI.WindowTitle = 'StarWarsInPowershell!'
#=======================================================================================================================
#runs powershell as admin and also preserves working directory
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
    exit;
}

# Your script here

#testing
Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient
Telnet "towel.blinkenlights.nl"
$port = 23
$telnet = New-Object System.Net.Sockets.TcpClient
$telnet.Connect($remoteHost, $port)
$stream = $telnet.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)






#Ending to prevent powershell from exiting
Read-Host - Prompt "Press Enter to EXIT"
