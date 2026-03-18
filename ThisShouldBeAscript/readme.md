Have you ever watched a tech tips video with a bunch of steps and though... "that should just be a script".  I did, and now you can use them as well.

 Please subscribe to my YouTube channel, I would greatly appreciate it!
 https://www.youtube.com/@thebeardofknowledge


1. nvmeSPEEDtweak.bat is to check for and enable the newly released Microsoft NVMe driver that allows faster speeds with your NVMe drive.  The script will first validate your system compatibility to ensure it matches the requirements (minimum Windows 11 24h2 build 26100+), default Standard NVM express controller is in use, and your NVMe drive is tied to the driver.  If your manufacturer provides their own drivers like some but not all (Samsung,WD,Intel,AMD,Crucial,SKhynix,Phison) then it will not apply as they use their own driver.
Original Youtube video covering this by TECHBASED: https://www.youtube.com/watch?v=OC4_oI04-rk

Original Microsoft article
https://techcommunity.microsoft.com/blog/windowsservernewsandbestpractices/announcing-native-nvme-in-windows-server-2025-ushering-in-a-new-era-of-storage-p/4477353


2. APPdeprovisioningCyberCPU.bat Multiple user account Windows PC's are a pain to debloat because Microsoft has moved apps to a per-user install.  This is a script to help you deprovision UWP apps in Windows, which fully uninstalls and prevents them from being added back to new users that sign in to the pc.  Because uninstalling apps under the admin account is apparently not good enough any more.  Many apps are part of the "baseline" packaged user apps that get installed to every user account.
 Inspired by the video by CyberCPU - Permanently Remove Windows 11 Junk
 https://www.youtube.com/watch?v=qIGf73KiPZI


