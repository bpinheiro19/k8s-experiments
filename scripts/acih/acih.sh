#!/bin/bash
rand=$RANDOM
rg="aci-rg"
location="uksouth"

#VNET
vnet="aci-vnet$rand"
vnetAddr=10.0.0.0/16
subnet="aci-subnet"
subnetAddr=10.0.240.0/24

#ACI
aci="appcontainer$rand"
image="mcr.microsoft.com/azuredocs/aci-helloworld"
osType="Linux"
dnsLabel="aci-demo$rand"
cpu=1
mem=2

aci() {

    for arg in "$@"; do

        case "$arg" in

        create)
            echo "################################################################"
            echo "## 01 - Public Azure Container Instance                       ##"
            echo "## 02 - Azure Container instance with vnet                    ##"
            echo "################################################################"

            read -p "Option: " opt

                case $opt in
                1)
                    createPublicACI
                    break
                    ;;
                2)
                    createVnetACI
                    break
                    ;;
                esac
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

##################################################
################# Resource Group #################
createRG() {
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

##################################################
################# Virtual Network ################
createVNET() {
    echo "Creating vnet and subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $subnet --subnet-prefixes $subnetAddr
}

###########################################
########### Azure Container Instances ############
createACI() {
    echo "Creating Azure Container Instance"
    az container create --name $aci --resource-group $rg --image $image --cpu $cpu --memory $mem --os-type $osType $1
}
createACIWithRGAndVNET() {
    createRG
    createVNET

    createACI $1
}

createPublicACI() {
    echo "Creating Public Azure Container Instance"
    createACIWithRGAndVNET "--ip-address Public --dns-name-label $dnsLabel --ports 80"
}

createVnetACI() {
    echo "Creating Azure Container Instance with vnet"
    createACIWithRGAndVNET "--vnet $vnet --subnet $subnet"
}

help() {
    echo 'Help:'
    echo "Create an Azure Container Instance"
    echo '$ acih create'
    echo ""
    echo "Delete the resource group"
    echo "$ acih delrg"
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
