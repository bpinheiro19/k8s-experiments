#!/bin/bash

location="swedencentral"

rg() {
    
    for arg in "$@"; do

        case "$arg" in
        create)
            createResourceGroup
            ;;
        list)
            listResourceGroup
            ;;
        delete)
            deleteResourceGroup
            ;;
        esac

    done

}

createResourceGroup() {
    read -p "Resource group name: " rgname

    echo "Creating resource group $rgname"
    az group create -n $rgname -l $location
}

listResourceGroup() {
    echo "Listing resource groups"
    az group list -o table
}

deleteResourceGroup() {
    mapfile -t groups < <( az group list -o tsv --query '[].[name]' )

    for i in "${!groups[@]}"; do
        printf "$i ${groups[i]} \n"
    done
    read -p "Enter the resource group number: " index
    resourceGroup=${groups[index]}
    echo "Deleting resource group $resourceGroup"
    az group delete -n $resourceGroup -y
}

main() {
    if [ -z "$1" ]; then
        echo "No arguments!"
        echo ""
        help
        return 1
    fi

    rg $@
}

rg $@