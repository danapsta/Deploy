Script to Automatically Baseline a Windows PC and Install basic applications. 

# deployment
Automatic PC Deployment Script for use when baselining new client PC.  The goal of this script is to automate the entire baseline process.  

Currently, our scripts are broken out and require user intervention to complete.  This script will take in all the needed information up-front and automatically make necessary changes, install applications, and reboot. 

# Pre-requisites

1. Download the relevant Agent from NCentral and place in the **Applications\Agent** folder. 
2. Have the client's local admin password ready (script will prompt for this before running)
3. Have the client's NetExtender connection information ready (if needing to remotely connect). 
4. Have the client's Domain Administration credentials ready (if joining to the domain during the baselining process)
5. Know, in general, what applications and specific baseline considerations are needed for the specific client (NetExtender, Office 365, Etc...)
6. Make sure you don't set a user password during OOB setup.  This won't "break" the script, but you will have to enter the user password each time the machine automatically reboots (5 times).  The script will automatically apply the local admin password when it is completely finished. 

# How to Use

1. Run **dl.bat** to download the most recent version of the script to the desktop
2. Run **deploy.bat**
3. Check the relevant task boxes to tell the script what to do. 
4. Click **Start Script**
5. Fill out any pop-ups requesting information (PC Name, local admin password, etc...)
6. Wait.  The script will do its thing and reboot up to 5 times before completing.  

**Note:** You shouldn't, but you may get a prompt during deployment to accept or run a certain part of the script.  Make note of which part of the process this happens and let me know.

# Typical Options

For workstation deployments, the following options are typically selected for a baseline.  The rest of the options depend on the client's specific needs.  

1. Basic Computer Configuration
2. NTP Configuration
3. Enable RDP
4. Install Adobe Reader
5. Install Agent (Unless already installed)
6. Install Chrome
7. Windows Patching

For Server deployments, the following options are typically selected for baseline.

1. Basic Computer Configuration
2. NTP Configuration
3. Enable RDP
4. Install Agent (Unless already installed)
5. Install Chrome
6. Windows Patching
7. Add to Domain
8. Install BGInfo 

# General Script Flow

If you're curious, below is the detailed information for what each step and/or script does. 

Basically, one file runs another, which runs another...which runs another... until everything is done.  Definitely has more steps than necessary, but below is the main flow of files. 

1. dl.bat > downloads and arranges script files
2. Deploy.bat > Starts the process by launching Menu.bat as Administrator
3. Menu.bat > Does some cleanup, unblocks script files, and runs Menu.ps1
4. Menu.ps1 > Displays the selection menu and presents the "Begin Script" button.  Modifies *variables.bat* according to the selections, then runs *Stepstart.bat* to kick off the automated deployment. 
5. variables.bat > holds information for which selections were made in *Menu.ps1*.  Will be referenced by each stage of the script. 
6. Stepstart.bat > Simply begins the process by running *Step1.bat* as Administrator.
7. Step1.bat > Runs any selected processes for this phase, cleans up folders, places Admin2.bat in startup folder, and reboots
7.  Admin2.bat > Simply runs Step2.bat as Administrator upon startup. 
8. Step2.bat > Runs any selected processes for this phase, cleans up folders, places Admin3.bat in startup folder, and reboots
9. Admin3.bat > Simply runs Step3.bat as Administrator upon startup
10. Step3.bat > Runs any selected processes for this phase, cleans up folders, places Admin4.bat in startup folder, and reboots
11. Admin4.bat > Simply runs Step4.bat as Administrator upon startup
12. Step4.bat > Runs any selected processes for this phase, cleans up folders, places Admin5.bat in startup folder, and reboots. 
13. Admin5.bat > Simply runs Step5.bat as Administrator upon startup. 
14. Step5.bat > Runs any selected processes for this phase, cleans up all folders and initial files, and reboots for the final time. 

# Detailed Information

### ***dl.bat***
1. Downloads a .zip file containing the latest script information from https://github.com/danapsta/Deploy.  
2. Extracts the contents to the Desktop in a format the script can work with (1x Folder: Applications and 2x Files: Deploy.bat and Readme.md (This file))

### ***Deploy.bat***
1.  Runs **Menu.bat** as Administrator. 

### ***Menu.bat***
1. Deletes **variables.bat** if it already exists, and creates a new, blank, file. 
2. Unblocks powershell scripts which will be run later so they are not prompted each time they run. 
3. Runs **Menu.ps1** as Administrator

### ***Menu.ps1***
1. Launches the interface where task selection occurs.  
2. When **Start Script** is pressed, it writes a line to **variables.bat** according to which tasks were selected. 
3. Prompts for additional input for sections which require it. 
4. Runs **Stepstart.bat**

### ***Stepstart.bat****
1. Runs **Step1.bat** as Administrator to kick off the process. 

### ***Step1.bat***
1. References **variables.bat** to determine which sections execute using if statements.  
2. Disables IE Enhanced Security mode (Errors on workstations)
3. Runs **Configure Workstation.ps1** which re-names the computer, enables the built-in firewall and Windows Defender, and removes built-in bloatware.
4. Sets NTP server to **time.windows.com** and **time.google.com** and configures computer to sync. 
5. Enables RDP for the workstation
6. Installs Adobe Reader by downloading and executing the install file. 
7. Copies **Admin2.bat** to the PC's startup folder (to continue script upon reboot)
8. Installs NetExtender by downloading and executing the install file. 
9. Reboots the PC if any of the above sections were executed (will skip if nothing from this file was selected during the menu process)

### ***Admin2.bat***
1. Runs **Step2.bat** as Administrator to continue the process after a reboot. 

### ***Step2.bat***
1. References **variables.bat** to determine which sections execute using if statements
2. Looks in the **Applications\Agent** folder for an installer and executes silently i fpresent. 
3. Installs Google Chrome by running the install launcher located in the **Applications\Chrome** folder. 
4. Deletes any previous script files from the startup folder and copies **Admin3.bat** to startup folder. 
5. Runs **Install Windows Patches.ps1** which looks for and downloads any available Windows Update.  This script will trigger a reboot automatically when it is complete. l
6. Reboots the PC if any of the above sections were executed (will skip if nothing from this file was selected during the menu process)

### ***Admin3.bat***
1. Runs **Step3.bat** as Administrator to continue the process after a reboot. 

### ***Step3.bat***
1. References **variables.bat** to determine which sections execute using if statements
2. Looks in the **Applications\Teams** directory for an installer and executes if present (*currently Broken*)
3. Installs Firefox by looking in the **Aplications\Firefox** directory and executing the installer, if present. 
4. Installs Office 365 by running the setup file located in **Applications\O365** and referencing the O365-specific configuration file (Also located in **Applications\O365**). 
5. Installs BGInfo by calling the **BGInfo_Automated_Windows_Server_2023_R2.ps1** script. 
6. Begins the Office 2019 setup process by running **OFFICE_SETUP.BAT** (*Currently Broken* and calls for user input, if selected)
7. Installs various other deprecated programs, if selected.  These will be removed in future versions and replaced with newer software.
8. Removes pre-installed McAfee antivirus from Lenovo systems, if selected.
9. Deletes any previous script files from the startup folder and copies **Admin4.bat** to startup folder.
10. Reboots the PC (Regardless if any section was executed)

### ***Admin4.bat***
1. Runs **Step4.bat** as Administrator to continue th eprocess after a reboot

### ***Step4.bat***
1. References **variables.bat** to determine which sections execute using if statements
2. Deletes any previous script files in the startup folder. 
4. Calls on **SetuserFTA** scripts to change program defaults for the local admin user (.pdf to Adobe Acrobat, http,https,html,and htm to Google Chrome. ) (Only works for the currently logged in user which won't be used by the client.)
5. Adds registry keys to change Windows visual settings for more performance (Currently Broken)
6. Copies **Admin5.bat** to startup folder
7. Reboots the PC (Regardless if any section was executed)

### ***Admin5.bat***
1. Runs **Step5.bat** as Administrator to continue the process after a reboot

### ***Step5.bat***
1. References ***variables.bat*** to determine which sections execute using if statements
2. Deltes any previous script files in the startup folder
3. Sets the password of the local admin user to the pre-determined value. 
4. Prompts for domain admin credentials to add PC to the pre-determined domain. 
5. Will reboot PC for a final time if domain join is successful. 
6. Deletes all script files from the Desktop. 
