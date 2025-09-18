REM *****************************
REM        PACKAGE CREATION   
REM *****************************

REM Package Create Config
SET devHub=
SET packageName=Agentforce File Analyser
SET packageDescription=A POC on how Agentforce can leverage prompt template to query file content, extract tables, processes and more
SET packageType=Unlocked
SET packagePath=force-app
SET definitionFile=config/project-scratch-def.json

REM Package Config
SET packageId=0HoKk000000TN1KKAW
SET packageVersionId=04tKk000000kaahIAA

REM Create package
sf package create --name "%packageName%" --description "%packageDescription%" --package-type "%packageType%" --path "%packagePath%" --target-dev-hub %devHub%

REM Create package version
sf package version create --package "%packageName%"  --target-dev-hub "%devHub%" --code-coverage --installation-key-bypass --wait 30 --definition-file "%definitionFile%"

REM Delete package
sf package:delete -p %packageId% --target-dev-hub %devHub% --no-prompt

REM Delete package version
sf package:version:delete -p %packageVersionId% --target-dev-hub %devHub% --no-prompt

REM Promote package version
sf package:version:promote -p %packageVersionId% --target-dev-hub %devHub% --no-prompt

REM Installation URL
rem /packaging/installPackage.apexp?p0=04tKk000000kaahIAA