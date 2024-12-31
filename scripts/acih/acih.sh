#!/bin/bash

rg="aci-rg"
location="uksouth"

#VNET
vnet="aci-vnet"
vnetAddr=10.0.0.0/16
subnet="aci-subnet"
subnetAddr=10.0.240.0/24

#ACI
aci="appcontainer"
image="mcr.microsoft.com/azure-cli" #"mcr.microsoft.com/azuredocs/aci-helloworld"

aci() {

    for arg in "$@"; do

        case "$arg" in
        create)
            echo "Creating the resource group"
            az group create -n $rg -l $location
            
            echo "Creating vnet and subnet"
            az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $subnet --subnet-prefixes $subnetAddr
            
            echo "Creating Azure Container Instance"
            az container create --name $aci --resource-group $rg --image $image --vnet $vnet --subnet $subnet  --command-line "tail -f /dev/null"
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

main() {
    if [ -z "$1" ]; then
        echo "No arguments!"
        echo ""
        help
        return 1
    fi

    aci $@
}

main $@

