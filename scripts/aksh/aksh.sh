#!/bin/bash

date="$(date +%s)"
rg="aks-rg"
location="uksouth"

#AKS
aks="aks$date"
serviceCidr=10.0.242.0/24
dnsIp=10.0.242.10
sku="standard_d2as_v4" #"standard_b2s" Cheaper option
nodeCount=1
networkPlugin="azure"

#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
subnet="subnet$date"
subnetAddr=10.0.240.0/24

#VM
vm="aksVM"
vmImage="UbuntuLTS"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"


aks() {

    for arg in "$@"; do

        case "$arg" in
        create)

            while true; do

                read -p "Do you want to create a private cluster: (y/n)" yn

                case $yn in
                y | yes)
                    createPrivateCluster
                    break
                    ;;
                n | no)
                    createPublicCluster
                    break
                    ;;
                esac

            done
            ;;

        delete)

            mapfile -t clusters < <( az aks list -g $rg -o tsv --query '[].[name]' )

            for i in "${!clusters[@]}"; do
                printf "$i ${clusters[i]} \n"
            done
        
            read -p "Enter the cluster number: " AKS_INDEX
            cluster=${clusters[AKS_INDEX]}

            echo "Deleting the AKS cluster - $cluster"
            az aks delete --name $cluster --resource-group $rg

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
    echo "Create an AKS cluster"
    echo '$ aksh create'
    echo ""
    echo "Delete an AKS cluster"
    echo "$ aksh delete"
    echo ""
    echo "Delete the resource group"
    echo "$ aksh delrg"
    echo ""
}

createRG(){
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

createVNET(){
    echo "Creating vnet and subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $subnet --subnet-prefixes $subnetAddr
}

createPublicCluster() {
    
    createRG

    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)

    echo "Creating AKS cluster"
    az aks create -g $rg -n $aks --network-plugin $networkPlugin --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount

    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createPrivateCluster() {
    
    createRG

    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)

    echo "Creating private AKS cluster"
    az aks create -g $rg -n $aks --network-plugin $networkPlugin --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount --enable-private-cluster --disable-public-fqdn

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

    aks $@
}

main $@
