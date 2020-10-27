#!/bin/bash -x

# extract command-line options into variables.
Endpoint=$1
Port=$2
DBName=$3
Maximos3location=$4
DeployModules=$5
WASAdminUsername=$6
WASAdminPassword=$7
WASSSMParameter=$8



# Install aws cli
yum -y install  unzip telnet

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

mkdir /work
cd /work

REGION=$(curl -sq http://169.254.169.254/latest/meta-data/placement/availability-zone/)
#ex: us-east-1a => us-east-1
REGION=${REGION: :-1}
export AWS_DEFAULT_REGION=${REGION}

# Download the installer files from S3
/usr/local/bin/aws s3 cp s3://$Maximos3location/IED_V1.8.8_Wins_Linux_86.zip .
/usr/local/bin/aws s3 cp s3://$Maximos3location/WAS_ND_V9.0_MP_ML.zip .
/usr/local/bin/aws s3 cp s3://$Maximos3location/was.repo.9000.java8_part1.zip .
/usr/local/bin/aws s3 cp s3://$Maximos3location/was.repo.9000.java8_part2.zip .
/usr/local/bin/aws s3 cp s3://$Maximos3location/was.repo.9000.java8_part3.zip .


# Install IBM Installation manager
unzip -q IED_V1.8.8_Wins_Linux_86.zip
./EnterpriseDVD/Linux_x86_64/EnterpriseCD-Linux-x86_64/InstallationManager/installc -log /tmp/IM_Install_Unix.xml -acceptLicense

# Extract java8 repositories
cd /work
mkdir java8
unzip -q was.repo.9000.java8_part1.zip -d java8
unzip -q was.repo.9000.java8_part2.zip -d java8
unzip -q was.repo.9000.java8_part3.zip -d java8


# Install the Websphere 9.0 and IBM java sdk 8

/opt/IBM/InstallationManager/eclipse/tools/imcl -acceptLicense install com.ibm.websphere.ND.v90 com.ibm.java.jdk.v8 -repositories WAS_ND_V9.0_MP_ML.zip,java8 -installationDirectory /opt/IBM/WebSphere/AppServer -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false

export WAS_HOME=/opt/IBM/WebSphere/AppServer




# Download  and install the maximo
mkdir /Launchpad
cd /Launchpad
/usr/local/bin/aws s3 cp s3://$Maximos3location/MAM_7.6.1.0_LINUX64.tar.gz .
tar -xf MAM_7.6.1.0_LINUX64.tar.gz
export BYPASS_PRS=True # Bypass the prechecks
/opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/SilentResponseFiles/Unix/ResponseFile_MAM_Install_Unix.xml -log /tmp/MAM_Install_log.xml -acceptLicense

if [ $DeployModules = "Utilities" ];
then
  mkdir /Launchpad/utilities
  cd /Launchpad/utilities
  /usr/local/bin/aws s3 cp s3://$Maximos3location/MAXIMO_UTILITIES_7.6_MP_ML.zip .
  unzip -q MAXIMO_UTILITIES_7.6_MP_ML.zip
  sed -i 's/c:\\Launchpad\\UtilitiesInstallerRepository.zip/\/Launchpad\/utilities\/UtilitiesInstallerRepository.zip/g' Utilities_Silent_ResponseFile.xml
  /opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/utilities/Utilities_Silent_ResponseFile.xml -log /tmp/ModulesInstall_log.xml -acceptLicense
elif [ $DeployModules = "Nuclear"  ]; then
  mkdir /Launchpad/nuclear
  cd /Launchpad/nuclear
  /usr/local/bin/aws s3 cp s3://$Maximos3location/MAX_NUCLEAR_POWER_7.6.1.zip .
  unzip -q MAX_NUCLEAR_POWER_7.6.1.zip
  sed -i 's/c:\\Launchpad\\NuclearInstallerRepository.zip/\/Launchpad\/nuclear\/NuclearInstallerRepository.zip/g' Nuclear_Silent_ResponseFile.xml
  /opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/nuclear/Nuclear_Silent_ResponseFile.xml -log /tmp/ModulesInstall_log.xml -acceptLicense
elif [ $DeployModules = "Scheduler"  ]; then
  mkdir /Launchpad/scheduler
  cd /Launchpad/scheduler
  /usr/local/bin/aws s3 cp s3://$Maximos3location/MAM_Scheduler_7.6.7.zip .
  unzip -q MAM_Scheduler_7.6.7.zip
  sed -i 's/c:\\Launchpad\\SchedulerInstallerRepository.zip/\/Launchpad\/scheduler\/SchedulerInstallerRepository.zip/g' Scheduler_Silent_ResponseFile.xml
  /opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/scheduler/Scheduler_Silent_ResponseFile.xml -log /tmp/ModulesInstall_log.xml -acceptLicense
elif [ $DeployModules = "Transportation"  ]; then
  mkdir /Launchpad/transportation
  cd /Launchpad/transportation
  /usr/local/bin/aws s3 cp s3://$Maximos3location/Max_Transportation_762IFR3.zip .
  unzip -q Max_Transportation_762IFR3.zip
  sed -i 's/c:\\Launchpad\\TransportationInstallerRepository.zip/\/Launchpad\/transportation\/TransportationInstallerRepository.zip/g' Transportation_Silent_ResponseFile.xml
  /opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/Transportation/Transportation_Silent_ResponseFile.xml -log /tmp/ModulesInstall_log.xml -acceptLicense
elif [ $DeployModules = "HSE"  ]; then
  mkdir /Launchpad/hse
  cd /Launchpad/hse
  /usr/local/bin/aws s3 cp s3://$Maximos3location/Max_HSEM_V761.zip .
  unzip -q Max_HSEM_V761.zip
  unzip -q hse_7.6.1_launchpad.zip
  sed -i 's/c:\\Launchpad\\HSEInstallerRepository.zip/\/Launchpad\/hse\/HSEInstallerRepository.zip/g' HSE_Silent_ResponseFile.xml
  /opt/IBM/InstallationManager/eclipse/tools/imcl input /Launchpad/hse/HSE_Silent_ResponseFile.xml -log /tmp/ModulesInstall_log.xml -acceptLicense
fi

cp /opt/IBM/SMP/maximo/applications/maximo/properties/maximo.properties.orig/maximo.properties /opt/IBM/SMP/maximo/applications/maximo/properties/
sed -i "s/^[[:blank:]]*mxe.db.url=jdbc:oracle:thin:/mxe.db.url=jdbc:oracle:thin:@$Endpoint:$Port:$DBName/" /opt/IBM/SMP/maximo/applications/maximo/properties/maximo.properties


ssmParameterValue=`/usr/local/bin/aws ssm get-parameter --name "${WASSSMParameter}" --query Parameter.Value --output text`
echo $ssmParameterValue

if [ $ssmParameterValue != "Installed" ];
then
  # Deploy the empty database schema and tables
  cd /opt/IBM/SMP/maximo/tools/maximo
  ./maxinst.sh -sMAXINDEX -tMAXDATA -imaximo
  /usr/local/bin/aws ssm put-parameter --name "${WASSSMParameter}" --type "String" --value "Installed" --overwrite
fi

# Generate the maximo ear files
cd /opt/IBM/SMP/maximo/deployment
dos2unix *
#sed -i '/xercesImpl-2.7.1.jar/d' buildmaximoui-war.xml
sh buildmaximoear.sh
sh buildmaximo-xwar.sh


#/usr/local/bin/aws s3 cp /opt/IBM/SMP/maximo/deployment/default/maximo.ear s3://$Maximos3location/qs-files/maximo.ear
#/usr/local/bin/aws s3 cp /opt/IBM/SMP/maximo/deployment/default/maximo-x.war s3://$Maximos3location/qs-files/maximo-x.war


# Create the DMGR profile and start the deployment manager
sh $WAS_HOME/bin/manageprofiles.sh -create -templatePath $WAS_HOME/profileTemplates/management -hostName `hostname -f` -profileName mxDmgr01  -profilePath $WAS_HOME/profiles/mxDmgr01 -cellName mxCell01 -nodeName mxCellManager01 -enableAdminSecurity  "true" -adminUserName "${WASAdminUsername}" -adminPassword "${WASAdminPassword}"

sh $WAS_HOME/profiles/mxDmgr01/bin/startManager.sh

sh $WAS_HOME/profiles/mxDmgr01/bin/wsadmin.sh -lang jython -username "${WASAdminUsername}" -password "${WASAdminPassword}" -f /home/ec2-user/DeployApplications.py

echo "Compelted admin config"


