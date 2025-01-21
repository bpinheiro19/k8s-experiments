#!/bin/bash

date="$(date +%s)"
rg="aro-rg"
location="uksouth"

#ARO
spName="aro-cluster-SP-$date"
aro="aro$date"
serviceCidr=10.0.248.0/22
masterSku="standard_d8s_v3"
workerSku="standard_d4s_v3"
nodeCount=3

#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
masterSubnet="master-subnet$date"
workerSubnet="worker-subnet$date"
masterSubnetAddr=10.0.240.0/23
workerSubnetAddr=10.0.244.0/23

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

    for arg in "$@"; do

        case "$arg" in
        create)
            register
            createPublicCluster
            break
            ;;
            
        private)
            register
            createPrivateCluster
            break
            ;;
            
        delrg)
            echo "Deleting resource group"
            az group delete -n $rg
            ;;
        -h | --help)
            help
            ;;
        *)
            echo "Invalid arguments"
            help
            exit 1
            ;;
        esac
    done
}

help() {
    echo 'Help:'
    echo "Create an ARO cluster"
    echo '$ aroh create'
    echo ""
     echo "Delete the resource group"
    echo "$ aroh delete"
    echo ""
}

createRG(){
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

createVNET(){
    echo "Creating vnet and subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr

    az network vnet subnet create -g $rg -n $masterSubnet --vnet-name  $vnet --address-prefixes $masterSubnetAddr
    az network vnet subnet create  -g $rg -n $workerSubnet --vnet-name  $vnet --address-prefixes $workerSubnetAddr
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

main() {
    if [ -z "$1" ]; then
        echo "No arguments!"
        echo ""
        help
        return 1
    fi

    aro $@
}

main $@