# deployment
Automatic PC Deployment Script for use when baselining new client PC.  The goal of this script is to automate the entire baseline process.  

Currently, our scripts are broken out and require user intervention to complete.  This script will take in all the needed information up-front and automatically make necessary changes, install applications, and reboot. 

# Pre-requisites

1. Download the relevant Agent from NCentral and place in the **Applications\Agent** folder. 
2. Have the client's nwadmin password ready (script will prompt for this before running)
3. Have the client's NetExtender connection information ready (if needing to remotely connect). 
4. Have the client's Domain Administration credentials ready (if joining to the domain during the baselining process)
5. Know, in general, what applications and specific baseline considerations are needed for the specific client (NetExtender, Office 365, Etc...)
6. Make sure you don't set a user password during OOB setup.  This won't "break" the script, but you will have to enter the user password each time the machine automatically reboots (5 times).  The script will automatically apply the nwadmin password when it is completely finished. 

# How to Use

1. Run **dl.bat** to download the most recent version of the script to the desktop
2. Run **deploy.bat**
3. Check the relevant task boxes to tell the script what to do. 
4. Click **Start Script**
5. Fill out any pop-ups requesting information (PC Name, nwadmin password, etc...)
6. Wait.  The script will do its thing and reboot up to 5 times before completing.  

**Note:** You shouldn't, but you may get a prompt during deployment to accept or run a certain part of the script.  Make note of which part of the process this happens and let me know. 

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

## ***dl.bat***
*dl.bat*: Downloads a .zip file containing the latest script information from https://github.com/danapsta/Deploy.  Then, it automatically extracts the contents to the Desktop in a format the script can work with (1x Folder: Applications and 2x Files: Deploy.bat and Readme.md (This file))

***Deploy.bat***:
1.  

*Menu.bat*:
1. 
e
