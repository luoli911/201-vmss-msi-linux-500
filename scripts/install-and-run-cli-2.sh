#!/bin/bash
startuptime1=$(date +%s%3N)

while getopts ":i:a:c:r:p:" opt; do
  case $opt in
    i) docker_image="$OPTARG"
    ;;
    a) storage_account="$OPTARG"
    ;;
    c) container_name="$OPTARG"
    ;;
    r) resource_group="$OPTARG"
    ;;
    p) password="$OPTARG"
    ;;
    t) script_file="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z $docker_image ]; then
    docker_image="azuresdk/azure-cli-python:latest"
fi

if [ -z $script_file ]; then
    script_file="writeblob.sh"
fi

for var in storage_account resource_group
do

    if [ -z ${!var} ]; then
        echo "Argument $var is not set" >&2
        exit 1
    fi 

done


#Install Azure CLI
sudo apt-get -y update
sudo apt-get -y install linux-image-extra-$(uname -r) linux-image-extra-virtual
sudo apt-get -y update
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -y update
sudo apt-get -y install docker-ce

#Install Docker CLI
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
sudo apt-get install -y apt-transport-https
sudo apt-get -y update && sudo apt-get install -y azure-cli

#Install cifs utils for mount file share
sudo apt-get -y update
sudo apt-get install -y cifs-utils

#Install git tool
sudo apt-get -y update
sudo apt install -y git-all

today=$(date +%Y-%m-%d)
currenttime=$(date +%s)
machineName=$(hostname)
sudo mkdir /mnt/azurefiles
sudo mount -t cifs //acrtestlogs.file.core.windows.net/logshare /mnt/azurefiles -o vers=3.0,username=acrtestlogs,password=ZIisPCN0UrjLfhv6Njiz0Q8w9YizeQgIm6+DIfMtjak4RJrRlzJFn4EcwDUhNvXmmDv5Axw9yGePh3vn1ak8cg==,dir_mode=0777,file_mode=0777,sec=ntlmssp
sudo mkdir /mnt/azurefiles/$today
sudo mkdir /mnt/azurefiles/$today/Scenario1-500
sudo mkdir /mnt/azurefiles/$today/Scenario1-500/$machineName$currenttime

function loadTest()
{
ACR_NAME="ACRLoadTestBuildCR500eus2euap3"
#sudo git clone https://github.com/SteveLasker/node-helloworld.git
#cd node-helloworld
sudo git clone https://github.com/SteveLasker/aspnetcore-helloworld.git
cd aspnetcore-helloworld/HelloWorld
echo "+ az login -u azcrci@microsoft.com -p $password"
az login -u azcrci@microsoft.com -p $password

echo "+ az account set --subscription c451bd61-44a6-4b44-890c-ef4c903b7b12"
az account set --subscription "c451bd61-44a6-4b44-890c-ef4c903b7b12"

echo "+ az extension remove -n acrbuildext"
az extension remove -n acrbuildext

echo  "+ az extension add --source https://acrbuild.blob.core.windows.net/cli/acrbuildext-0.0.4-py2.py3-none-any.whl -y"
az extension add --source https://acrbuild.blob.core.windows.net/cli/acrbuildext-0.0.4-py2.py3-none-any.whl -y

echo "+ az acr login -n $ACR_NAME"
az acr login -n $ACR_NAME

echo "---ACR Build Test---"
pullbegin=$(date +%s%3N)
PullStartTime=$(date +%H:%M:%S)
for i in {1..1} 
  do    
   echo "+ az acr build -t helloworld$i:v1 --context . -r $ACR_NAME"
   az acr build -t helloworld$i:v1 --context . -r $ACR_NAME 
   echo "BuildTask$i Done!" 
  done
# echo "+ az acr build -t helloworld1:v1 --context . -r $ACR_NAME"
# az acr build -t helloworld1:v1 --context . -r $ACR_NAME 
# echo "BuildTask1 Done!" 
pullend=$(date +%s%3N)
PullEndTime=$(date +%H:%M:%S)
pulltime=$((pullend-pullbegin))
echo machineName,starttime,endtime,pulltime:$machineName,$PullStartTime,$PullEndTime,$pulltime >> /mnt/azurefiles/$today/Scenario1-500/acr-buid-output-time.log

}

loadTest >> /mnt/azurefiles/$today/Scenario1-500/$machineName$currenttime/acr-buid-output.log
