#!/bin/bash

date="$(date +%s)"
rg="aks-rg"
location="swedencentral"

#AKS
aks="aks$date"
serviceCidr=10.0.242.0/24
podCIDR=172.16.0.0/16 
dnsIp=10.0.242.10
sku="standard_d2as_v4" #"standard_b2s" Cheaper option
nodeCount=1
aksVersion="1.31.1"

#AKS Networking


#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
subnet="subnet$date"
subnetAddr=10.0.240.0/24

#VM
vm="aksVM"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"


aks() {

    for arg in "$@"; do
        echo "####################################################"
        echo "##        Azure Kubernetes Service helper         ##"
        echo "####################################################"

        case "$arg" in

        create)
            echo "##########################################################"
            echo "## 01 - AKS cluster with kubenet                        ##"
            echo "## 02 - AKS cluster with azure cni                      ##"
            echo "## 03 - Private AKS cluster with kubenet azure cni      ##"
            echo "## 04 - Private AKS cluster with azure cni              ##"
            echo "## 05 - AKS cluster with kubenet, AAD and Azure RBAC    ##"
            echo "## 06 - AKS cluster with azure cni, defender and policy ##"
            echo "## 07 - AKS cluster with monitoring                     ##"
            echo "## 08 - AKS cluster with azure cni overlay              ##"
            echo "## 09 - AKS cluster with azure cni overlay and calico   ##"
            echo "## 10 - AKS cluster with Node autoprovisioning          ##"
            echo "## 11 - AKS cluster with azure cni overlay and cilium  ##"
            echo "## 99 - Standalone VM                                   ##"
            echo "##########################################################"

            while true; do

                read -p "Option: " opt

                case $opt in
                1)
                    createPublicKubenetCluster
                    break
                    ;;
                2)
                    createPublicCNICluster
                    break
                    ;;
                3)  
                    createPrivateKubenetCluster
                    break
                    ;;
                4)
                    createPrivateCNICluster
                    break
                    ;;
                5)
                    createPublicAADCluster
                    break
                    ;;
                6)
                    createPublicCNIPolicyDefenderCluster
                    break
                    ;;
                7)
                    createPublicCNIMonitoringCluster
                    break
                    ;;
                8)
                    createPublicCNIOverlay
                    break
                    ;;
                9)
                    createPublicCNIOverlayCalico
                    break
                    ;;
                10)
                    createPublicNAP
                    break
                    ;;
                11)
                    createPublicCNICiliumACNS
                    break
                    ;;
                99)    
                    createVM
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
            az group delete -n $rg --no-wait
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
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $subnet --subnet-prefixes $subnetAddr -l $location
}

createPublicCNICluster() {
    echo "Creating AKS cluster with azure cni"
    createPublicCluster azure
}

createPublicKubenetCluster(){
    echo "Creating AKS cluster with kubenet"
    createPublicCluster kubenet "--pod-cidr $podCIDR"
}

createPublicAADCluster(){
    echo "Creating AKS cluster with AAD and Azure RBAC"
    createPublicCluster azure "--enable-aad --enable-azure-rbac"
}

createPrivateKubenetCluster(){
    echo "Creating AKS cluster with kubenet"
    createPrivateCluster kubenet
}

createPrivateCNICluster(){
    echo "Creating private AKS cluster with azure cni"
    createPrivateCluster azure 
}

createPublicCNIPolicyDefenderCluster() {
    echo "Creating AKS cluster with azure cni, defender and policy"
    createPublicCluster azure "--enable-defender --enable-addons azure-policy"
}

createPublicCNIMonitoringCluster() {
    echo "Creating AKS cluster with monitoring and prometheus"
    createPublicCluster azure "--enable-azure-monitor-metrics --enable-addons monitoring"
}

createPublicCNIOverlay() {
    echo "Creating AKS cluster with azure cni overlay"
    createPublicCluster azure "--network-plugin-mode overlay --pod-cidr $podCIDR"
}

createPublicCNIOverlayCalico() {
    echo "Creating AKS cluster with azure cni overlay and calico"
    createPublicCluster azure "--network-plugin-mode overlay --pod-cidr $podCIDR --network-policy calico"
}

createPublicCNICiliumACNS() {
    echo "Creating AKS cluster with azure cni overlay and cilium"
    createPublicCluster azure "--network-plugin-mode overlay --pod-cidr $podCIDR --network-dataplane cilium --network-policy cilium  --enable-acns"
}


createPublicNAP() {
    echo "Creating AKS cluster with Node autoprovisioning"
    createPublicCluster azure "--network-plugin-mode overlay --pod-cidr $podCIDR --network-dataplane cilium --node-provisioning-mode Auto"
}

createPublicCluster(){
    createRG
    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)
    
    echo "Creating AKS cluster with kubenet"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $1 --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount $2
    #--network-policy calico implementation missing
    
    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createPrivateCluster() {
    createRG
    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)

    echo "Creating private AKS cluster"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $1 --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount --ssh-access disabled --enable-private-cluster

    createVM
}

createVM(){
    echo "Creating Azure VM in the same vnet"
    az vm create -g $rg -n $vm -l $location --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation
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
