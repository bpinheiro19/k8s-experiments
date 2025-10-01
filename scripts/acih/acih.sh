#!/bin/bash
rand=$RANDOM
rg="aci-rg"
location="swedencentral"

#VNET
vnet="aci-vnet$rand"
vnetAddr=10.0.0.0/16
subnet="aci-subnet"
subnetAddr=10.0.240.0/24
publicIpName="myPublicIP"
natGatewayName="myNATgateway"

#ACI
aci="appcontainer$rand"
image="mcr.microsoft.com/azuredocs/aci-helloworld"
osType="Linux"
dnsLabel="aci-demo$rand"
cpu=1
mem=2

aci() {
    header
    echo "## 01 - Azure Container Instance with Public IP               ##"
    echo "## 02 - Azure Container instance with Azure CLI image         ##"
    echo "## 03 - Azure Container instance with vnet                    ##"
    echo "## 04 - Azure Container instance with NAT Gateway             ##"
    echo "################################################################"

    while read -p "Option: " opt; do

        case $opt in
        1)
            createPublicACI
            break
            ;;
        2)
            createACIAzureCLI
            break
            ;;
        3)
            createVnetACI
            break
            ;;
        4)
            createACINatGateway
            break
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

##################################################
########### Azure Container Instances ############
createACI() {
    echo "Creating Azure Container Instance"
    az container create --name $aci --resource-group $rg --image $image --cpu $cpu --memory $mem --os-type $osType $1
}

createPublicACI() {
    createRG
    createACI "--ip-address Public --dns-name-label $dnsLabel --ports 80"
}

createVnetACI() {
    echo "Creating Azure Container Instance with vnet"
    createRG
    createVNET
    createACI "--vnet $vnet --subnet $subnet"
}

createACIAzureCLI() {
    createRG
    echo "Creating Azure Container Instance with Azure CLI image"
    az container create --name $aci --resource-group $rg --image "mcr.microsoft.com/azure-cli" --cpu $cpu --memory $mem --os-type $osType --command-line 'tail -f /dev/null'
}

createNatGateway(){
    echo "Creating Public IP for NAT Gateway"
    az network public-ip create --name $publicIpName --resource-group $rg  --sku standard --zone 1 --allocation static
   
    echo "Creating NAT Gateway"
    az network nat gateway create --resource-group $rg --name $natGatewayName --public-ip-addresses $publicIpName --idle-timeout 10

    az network vnet subnet update --resource-group $rg --vnet-name $vnet --name $subnet --nat-gateway $natGatewayName
}

createACINatGateway() {
    echo "Creating Azure Container Instance with Nat Gateway"
    createRG
    createVNET
    
    createNatGateway

    createACI "--vnet $vnet --subnet $subnet"
}

header() {
    echo "################################################################"
    echo "##                                                            ##"
    echo "##             Azure Container Instances Helper               ##"
    echo "##                                                            ##"
    echo "################################################################"
}

listACI(){
    mapfile -t containers < <(az container list -g $rg --only-show-errors -o tsv --query '[].[name]')
    
    size=${#containers[@]}

    if [ $size -eq 0 ]; then
        echo "No Azure Container Instances"
    else
        echo "################################################################"
        echo "##                Azure Container Instances                   ##"
        echo "################################################################"
        for i in $(seq 1 $size); do
            printf "## $(($i)) - ${containers[i-1]}                                      ##\n"
        done
        echo "################################################################"
    fi
}

deleteACI(){
    listACI
    
    if [ $size -ne 0 ]; then

        read -p "Enter the container number: " index
        
        if [[ $index =~ ^[1-9]+$ ]] && (( $index <= size )); then
            container=${containers[index-1]}
            echo "Deleting the Azure Container Instance - $container"
            az container delete --name $container --resource-group $rg --yes
        else
            echo "$index is NOT a valid index."
        fi
    fi                

}

deleteRG(){
    echo "Deleting the aci-rg resource group"
    az group delete -n $rg --no-wait
}

main() {
    header
    echo "## 01 - Create Azure Container Instance                       ##"
    echo "## 02 - List Azure Container Instances                        ##"
    echo "## 03 - Delete Azure Container Instance                       ##"
    echo "## 04 - Delete resource group (aci-rg)                        ##"
    echo "################################################################"
    while read -p "Option: " opt; do

        case $opt in
        1)
            aci
            break
            ;;
        2)
            listACI
            break
            ;;
        3)
            deleteACI
            break
            ;;
        4)
            deleteRG
            break
            ;;
        esac
    done
}

main
