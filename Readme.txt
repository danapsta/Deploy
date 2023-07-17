Below is a breakdown on how to get started and what each file does.

1. Download the relevant agent file from NCentral and drop into the Applications\Agent directory.
2. Look up the client-specific nwadmin password in ITGlue.  Have on-hand and ready for input during step 1.
3. Look up the client-specific netextender username/password and have on hand if necessary (for adding PC to domain remotely in step 5)
4. Look up the client-specific domain administrator password and have on hand for end of deployment (will prompt for domain, username, and password)
5. (Optional) Download the latest version of Adobe Reader and Chrome.  Place in the Applications\Adobe & Applications\Chrome directories.  
6. Once all changes are made.  Copy Applications directory and Deploy.bat to Desktop
7. Run Deploy.bat



Deploy.bat: Runs Step.1.bat as Administrator

Step.1.bat: Initial Configuration
a. Runs initial PC configuration script (requires interaction)
b. Sets NTP server for PC to time.windows.com & time.google.com
c. Enables remote desktop for PC
d. Installs Adobe Reader
e. Installs NetExtender
f. Copies Admin.2.bat to Startup folder

Admin.2.bat: Runs Step.2.bat as Administrator upon system startup

Step.2.bat: Agent & Patching Step
a. Installs Agent
b. Installs Chrome
c. Runs Windows 10 feature update (requires interaction)
d. Runs unattended patching (requires interaction)
f. Copies Admin.3.bat to Startup folder

Admin.3.bat: Runs Step.3.bat as Administrator upon system startup

Step.3.bat: Software Installation (Make changes here for specific applications to be installed)
a. Installs Teams
b. Installs Firefox
c. Installs Office 365 Premium Apps
d. Installs any client-specific software (may require interaction)
e. Copies Admin.4.bat to Startup folder

Admin.4.bat: Runs Step.4.bat as Administrator upon system startup

Step.4.bat: Sets program defaults and optimal settings (work in progres)
a. Sets Adobe Reader as default .pdf viewer
b. Sets Chrome as default browswer
c. Changes Advanced System Settings to Performance Display mode
d. Copies Admin.5.bat to Startup folder

Admin.5.bat: Runs Step.5.bat as Administrator upon system startup

Step.5.bat: Sets nwadmin password and adds PC to domain
a. Cleans up Startup Folder
b. Changes nwadmin password
c. Prompts for Domain credentials to add to domain (must be on the domain network or connected to NetExtender) (requires interaction)
d. Setup is finished

Manual Steps:
a. Set Outlook as default program (will implement later)
b. Update system drivers (auto driver update is broken)
