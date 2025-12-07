#!/bin/bash

date="$(date +%s)"
rg="aro-rg"
location="swedencentral"

#ARO
aro="aro$date"
version="4.18.26"
serviceCidr=10.0.248.0/22
masterSku="Standard_D8s_v3"
workerSku="Standard_D4s_v3"
nodeCount=3

#VNET
vnet="aro-vnet$date"
vnetAddr=10.0.0.0/16
masterSubnet="master"
workerSubnet="worker"
masterSubnetAddr=10.0.240.0/23
workerSubnetAddr=10.0.244.0/23

#SP
spName="aro-cluster-SP-$date"

#VM
vm="aksVM"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"


register(){
    az provider register --namespace 'Microsoft.RedHatOpenShift' --wait
    az provider register --namespace 'Microsoft.Compute' --wait
    az provider register --namespace 'Microsoft.Storage' --wait
    az provider register --namespace 'Microsoft.Authorization' --wait
    az feature register --namespace Microsoft.RedHatOpenShift --name preview
}

aro() {
    header
    echo "## 01 - Public Azure Red Hat OpenShift Cluster                    ##"
    echo "## 02 - Private Azure Red Hat OpenShift Cluster                   ##"
    echo "####################################################################"

    while read -p "Option: " opt; do

        case $opt in
        1)
            register
            createPublicAROCluster
            break
            ;;
        2)
            register
            createPrivateAROCluster
            break
            ;;
        esac
    done
}

###############################################
############## Resource Group #################
createRG(){
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

###############################################
############# Virtual Network #################
createVNET(){
    echo "Creating vnet and subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr

    az network vnet subnet create -g $rg -n $masterSubnet --vnet-name  $vnet --address-prefixes $masterSubnetAddr
    az network vnet subnet create  -g $rg -n $workerSubnet --vnet-name  $vnet --address-prefixes $workerSubnetAddr
}

###############################################
########### Azure RedHat Openshift ############

createAROClusterWithRGAndVNET() {
    createRG
    createVNET
    createAROCluster "$1"
}

createAROCluster(){
    echo "Creating ARO cluster"
    az aro create --resource-group $rg --name  $aro --version $version --vnet $vnet --service-cidr $serviceCidr --master-subnet $masterSubnet --worker-subnet $workerSubnet --master-vm-size $masterSku --worker-vm-size $workerSku $1
}

createPublicCluster() {
    createRG
    createVNET

    masterSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $masterSubnet --query id -o tsv)
    workerSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $workerSubnet --query id -o tsv)

    AZ_SUB_ID=$(az account show --query id -o tsv) 

    PASSWORD=$(az ad sp create-for-rbac --name $spName  --role contributor --scopes "/subscriptions/${AZ_SUB_ID}/resourceGroups/${rg}" --query "password" --output tsv)
    appID=$(az ad sp list --display-name $spName --query "[].appId" --output tsv)

    echo "Creating ARO cluster"
    az aro create -g $rg -n $aro --vnet  $vnet --service-cidr $serviceCidr --master-subnet $masterSubnet --worker-subnet $workerSubnet --client-id $appID --client-secret $PASSWORD # --master-vm-size $masterSku --worker-vm-size $workerSku --worker-count $nodeCount 
    
    az aro list-credentials -g $rg -n $aro
    az aro show -g $rg -n $aro --query "consoleProfile.url" -o tsv
  
    apiServer=$(az aro show -g $rg -n $aro --query apiserverProfile.url -o tsv)
    kubeAdminPassword=$( az aro list-credentials -g $rg -n $aro --query kubeadminPassword -o tsv)
    echo "oc login $apiServer -u kubeadmin -p $kubeAdminPassword"
}

createPrivateCluster() {
    createRG
    createVNET

    masterSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $masterSubnet --query id -o tsv)
    workerSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $workerSubnet --query id -o tsv)

    echo "Creating ARO cluster"
    az aro create -g $rg -n $aro --vnet  $vnet --master-subnet $masterSubnet --worker-subnet $workerSubnet --service-cidr $serviceCidr --apiserver-visibility Private --ingress-visibility Private # --master-vm-size $masterSku --worker-vm-size $workerSku --worker-count $nodeCount
   
    createVM
}

createVM(){
    echo "Creating Azure VM in the same vnet"
    az vm create -g $rg -n $vm --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation
}

header() {
    echo "################################################################"
    echo "##                                                            ##"
    echo "##              Azure RedHat Openshift Helper                 ##"
    echo "##                                                            ##"
    echo "################################################################"
}

main() {
    header
    echo "## 01 - Create Azure RedHat Openshift Cluster                  ##"
    echo "## 02 - List Azure RedHat Openshift Clusters                   ##"
    echo "## 03 - Delete Azure RedHat Openshift Cluster                  ##"
    echo "## 04 - Delete resource group (aro-rg)                         ##"
    echo "################################################################"
    while read -p "Option: " opt; do

        case $opt in
        1)
            aro
            break
            ;;
        2)
            mapfile -t clusters < <(az aro list -g $rg --only-show-errors -o tsv --query '[].[name]')

            if [ ${#clusters[@]} -eq 0 ]; then
                echo "No Azure RedHat Openshift Clusters"
            else
                echo "################################################################"
                echo "##                Azure RedHat Openshift Clusters                   ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                      ##\n"
                done
                echo "################################################################"
            fi

            break
            ;;
        3)
            mapfile -t clusters < <(az aro list -g $rg --only-show-errors -o tsv --query '[].[name]')

            size=${#clusters[@]}

            if [ $size -eq 0 ]; then
                echo "No Azure RedHat Openshift Clusters"
            else
                echo "################################################################"
                echo "##                Azure RedHat Openshift Clusters           ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                      ##\n"
                done
                echo "################################################################"

                read -p "Enter the cluster number: " index

                if [[ $index =~ ^[0-9]+$ ]] && (( $index <= size )); then
                  cluster=${clusters[index-1]}
                  echo "Deleting the Azure RedHat Openshift Cluster - $cluster"
                  az aro delete --name $cluster --resource-group $rg --yes
                else
                  echo "$index is NOT a valid index."
                fi                
            fi

            break
            ;;
        4)
            echo "Deleting the aro-rg resource group"
            az group delete -n $rg --no-wait
            break
            ;;
        esac
    done
}

main $@