@echo Off

MKDIR C:\ODT

:CREATE_NEW
set file=c:\odt\test.txt
set source=c:\odt\test.txt
set target=c:\odt\test1.txt
set dest=c:\odt\configuration.xml
set PRD1_EDTN=0
set PRD2_EDTN=0
set PRD3_EDTN=0
set PRD4_EDTN=0
set /a PRD_1=0
set /a PRD_2=0
set /a PRD_3=0
set /a PRD_4=0
set /a PRD_5=0
set PRVS_INST=0


:PFORM
echo ************************************************
echo PLEASE CHOOSE PLATFORM (RECOMMENDED IS 32BIT)
set PFORM=64
		GOTO :LCNS_TYPE

:LCNS_TYPE
echo ************************************************
echo PLEASE CHOOSE LICENSE TYPE
set LCNS_TYPE=Retail
		set CHNL=BROAD
		GOTO :PRD_SEL

:PRD_SEL
echo ************************************************
echo PLEASE CHOOCE A THE PRODUCT
set PRD_5=1
			set LCNS_TYPE=Retail
			GOTO :PRD5_EDTN
			
:PRD5_EDTN
	echo ************************************************
	echo PLEASE CHOOSE YOUR OFFICE 365  EDITION
	set PRD5_EDTN=O365BusinessRetail
		GOTO :END

:END
	if %PRD_5%==1 (GOTO :CONT) else (GOTO :CONT)

:CONT
	echo ^<Configuration^> > %file%
	echo ^<Add OfficeClientEdition^="PFORM" Channel^="CHNL"^> >> %file%

:PRD5
	if %PRD_5%==1 (GOTO :PRDNO5) else (GOTO :PRD4)
	:PRDNO5
	echo ^<Product ID^="PRODUCT5" PIDKEY^="PRD5_KEY"^> >> %file%
	echo ^<Language ID^="en-us" /^> >> %file%
	echo ^</Product^> >> %file%


:PRD_END
	echo ^</Add^> >> %file%
	echo ^<Display Level^="Full" AcceptEULA^="TRUE" /^> >> %file%
	echo ^<Property Name^="AUTOACTIVATE" Value^="1" /^> >> %file%
	echo ^</Configuration^> >> %file%

:UPDT_CONFG
setlocal enableDelayedExpansion

::PLATFORM
set PFORM_old=PFORM
set PFORM_new=%PFORM%
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" %source%') do (
      set "line=%%b"
      if defined line set "line=!line:%PFORM_old%=%PFORM_new%!"
      echo(!line!
   )
) > %target%

)

::LICENSE TYPE
set LCNS_old=CHNL
set LCNS_new=%CHNL%
(
   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" %target%') do (
      set "line=%%b"
      if defined line set "line=!line:%LCNS_old%=%LCNS_new%!"
      echo(!line!
   )
) > %source%

)

::PRODUCT 5
:PRD5_REP
	if %PRD_5%==1 (GOTO :REP_PRD5) else (GOTO :PRD4_REP)
	:REP_PRD5
		set EDTN1a=PRODUCT5
		set EDTN1b=%PRD5_EDTN%%LCNS_TYPE%
		(
		   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" %source%') do (
			  set "line=%%b"
			  if defined line set "line=!line:%EDTN1a%=%EDTN1b%!"
			  echo(!line!
		   )
		) > %target%

		)
		set EDTN1a=PRD5_KEY
		set EDTN1b=%PRD5_KEY%
		(
		   for /F "tokens=1* delims=:" %%a in ('findstr /N "^" %target%') do (
			  set "line=%%b"
			  if defined line set "line=!line:%EDTN1a%=%EDTN1b%!"
			  echo(!line!
		   )
		) > %source%

		)

:CREATE_CONFIGXML
		
		1>"%dest%" (
		  for /f "delims=" %%e in ('findstr /n "^" "%source%"') do (
			set "line=%%e"
			setlocal enabledelayedexpansion
			set "line=!line:*:=!"

			if not "!line!" == "" (
			  echo(!line!
			)
			endlocal
		  )
		  )



:PWRSHL
powershell.exe -command "Invoke-WebRequest https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117 -OutFile C:\odt\odt.exe"
if %errorlevel%==0 (GOTO :INSTYPE) else (GOTO :SHOW_ERROR)

:SHOW_ERROR
echo There is an issue encountered when trying to download the ODT program!
echo Please try downloading it manually and extract it to the ODT folder found in your C Drive.
echo %errorlevel%
pause

:INSTYPE
	Start /d C:\odt /b /wait odt.exe /extract:C:\ODT 
	:CREAT_AUTORUN
	set autorun=c:\odt\autorun.bat
	set value=start /d "C:\ODT" /b /wait setup.exe /configure C:\ODT\configuration.xml
	echo %value% > %autorun%

echo ************************************************
echo Choose the TYPE of INSTALLATION.
GOTO :DWN_INST

:DWN_INST
start /d "C:\odt" /b /wait setup.exe /download configuration.xml

:EOC
exit
