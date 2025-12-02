
# BeardSweeper - ***The Ultimate Windows Disk Cleanup Script***

<p align="center">
<img src="https://github.com/TheBeardofKnowledge/Scripts-from-my-videos/blob/main/BeardSweeper%20Disk%20Cleanup/BeardSweeperCharacter.png" />
</p>

## Why did I make this, and why you should you use it?
Because there were no disk cleanup utilities or scripts that covered removing everything I was finding hoarding space in Windows related to cache or temporary files for all users of a pc.  Many free utilities only clean the current user's cache, and want **PAYMENT** to clean **ALL USERS... RIDICULOUS!**
### Using or making a script like this also let's you be less dependent on third-party utilities and reduce the number of external resources you need to perform repeditive tasks.
Aren't you tired of Windows and programs leaving everything old all over your drive and taking up unnecessary space? 
  Yeah, me too, so I started doing something about it... this script.

  ***The target use for this is home and work computers running Windows 10, and 11 (home, pro, ltsc, iot)***

This has been made as an accumulation of a lot of testing, and adding to the script until 
it covered as much "safe to delete" temporary files as possible for the most commonly seen situations.
This is solely based on my experience over 25 years in IT, so if perhaps you know of something else that I missed
and you would like to see covered or added in here, send me some info here or on social media.
The idea is to only remove what won't negatively affect a Windows Workstations while reclaiming as much free space as possible.
When it comes to web browser files, I opted to only delete cache, as many users depend on cookies and autofill data.


You can find all my socials and contact info on my profile page.

## How do you use it?
* Simply download it to your pc.
* open the folder where you saved it
* right-click on it and go to properties
* uncheck the bottom right option that says "unblock" (if you don't have this option, its ok, skip to the next step).
* click ok
* now just double-click the file to run it.
                                      

## |SCRIPT WALKTHROUGH |
					
The script itself is commented in each section, indicated by :: at the beginning, but here's the "full monty" explanation...

@echo off ::disables the commands from being shown on screen (minimize clutter)

color f0 sets the command window to use a white background

:checkPriveleges - Checks for running with admin rights (required), and if the script is unelevated, moves to elevation

:getPrivileges - elevates the rights using powershell command in order to clean properly 

cls - clears the screen for a fresh start
:StartIntro - 
Simple display of text on screen providing some information and credits to those who help improve the script.  
A "shout out" if you will, with a 10 second timeout before it continues.

:hibernation
This disables or enables Windows hibernation, also known as "Fast Startup" and deletes the hibernation file. 
This Windows feature dumps ram to disk for restarts and also "deep sleep" modes, however, the feature was created when all computers had spinning disks. 

When you warm boot your computer, everything in the hibernation file is restored to RAM and your system is presumably "ready faster".  
Issue here, is files are only replaced with "fresh copies" when you cold boot a system, and if a program has bad code or includes minor memory leaks, 
this can accumulate and use up all your ram, which can cause issues. Disabling this will ensure only fresh copies are loaded when you start your system.
For desktops this will stay disabled at the end of the script, for laptops it will re-enable it due to peoples habits of letting the laptop 
battery drain without shutting down their laptop first.
The :detectchassis section queries windows to see what the manufacturer labeled your device as and if your device has a battery it moves on to :laptop, if not :desktop.
For laptops/tablets hibernation is enabled because it is required if your battery drops below a critical % while in sleep mode.

:badprintjobs - 
exactly what it sounds like... leftover unprinted jobs that stay in your system because windows doesn't remove them, ever! This clears out all print jobs.

:fontcache - 
Clears out the windows font cache so that all fonts are loaded from their perspective font file when used... clears graphical issues.

:WindowsUpdatesCleanup - 
Let's face it, Microsoft thinks we have unlimited disk space and is a hoarder when it comes to Windows Updates, 
it will store them in your system in case any other computers on your network need them, so that they can be shared over your network vs downloading from microsoft... 
a resource saver for Microsoft, a storage eater for end users. 
While this is an OK idea, we are clearing that out from their respective folders.  
It stops all windows updates and related services, clears the files, then starts up the same windows update services so it can be ready to update your computer.

:WindowsTempFilesCleanup - 
Deletes all known temp files used by windows temporary directories and files.  
These files really never get expunged on their own, but Windows starts new ones when deleted, so don't worry.

:WindowsLogs - 
tons of logging that microsoft keeps, which rarely ever gets cleaned out.

:userprofilecleanup - 
Many of the things you run, install and use when logged into windows also use a temp directory in your profile folder or file to work from,
but same as the above, it's never cleaned. 
This removes them and allows fresh copies to be rebuilt automatically when you actually need them.  These are all the commmon directories I know of.

:therecyclebinisnotafolder - 
Tongue in cheek on the name there because yes... you would be surprised how many people dont clear our their recycle bin. 
This clears it so windows immediately recreates it, but empty.

:userprogramscachecleanup - 
Beginning of the section dedicated to clearing out common program cache from often use software that ends up glitching because of bad/outdated cache.
More will be added as requests come up... for now it does itunes, microsoft teams, outlook, and for corporate pc's; SCCM cache.

:itunes - 
Deletes the stored update downloads that are used to update itunes... because they don't get deleted, EVER.
:iOSbackups
Prompts to delete all the iphone backups that have been made on that system.  If you've ever used it, the folder is HUGE.

:freakenmicrosoftteams - 
Yes, the worldwide program, that is both hated and loved, very often suffers from cache problems... 
things like not showing messages, showing you offline when you're actively using it, etc.  
This clears out the folders recommended by Microsoft to have teams perform a full refresh of the session.

:outlookcache - 
Not often, but it happens that outlook operations stay stuck in limbo due to a cache sync problem.  This will clear the cache. 

:onedrive - 
runs through all users to clear out cache and temp files

:WebBrowsers - 
Clears all from common web browsers (IE,Edge,Chrome,Firefox).  Internet explorer (yes, your system still has it for "IE compatibility mode") for Microsoft Edge Chromium, 
I only have it deleting cache, as I found too many people depended on cookies, history, and autofill data to do a full clear. 
Because the web browsers save cache data per user, the script runs a for each loop on each user directory.  
Firefox is also now included and surprisingly easier to clean out.

:CleanMgr - 
This configures optimal settings for Microsofts built-in disk cleanup tool with all available options enabled (including some you can't enable in the UI).  
First it creates a "SageSet" Registry entries are added to the system to ensure all options enabled, then the ulitity is run with those enabled with "sagerun".  
This is a more in depth cleanup than what you can run manually even covering system files.

:restorepointscleanup - 
section commented out because on some aggressive AV tools it would detect deleting restore points as malicious. 
This is not bad, but 10% of your drive is usually reserved for restore points.

:PreviousWindowsInstalls - 
Runs throughwhy did I leave a confirmation prompt?  
Because you should have a choice on these in case you're unsure about the stability of a recent update or upgrade.

:END - 
The powershell command will show your remaining free space now that the script is complete.
Color 0A changes the terminal window to black background with green text to show completion.

scroll up and compare your free space now to when the script started and please drop me a comment on social media for any videos on this script.
I would like to add some math into the script to simply show how much free space the script made, but thats a WIP.


