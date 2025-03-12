#!/bin/bash

date="$(date +%s)"
rg="aks-rg"
location="swedencentral"

#AKS
aks="aks$date"
aksVersion="1.31.1"
networkPlugin="azure"
serviceCidr=10.0.242.0/24
podCIDR=172.16.0.0/16
dnsIp=10.0.242.10
sku="standard_d2as_v4" #"standard_b2s" Cheaper option
nodeCount=1

#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
subnet="aks-subnet"
subnetAddr=10.0.240.0/24

#VM
vm="aksVM"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"

#Others
keyVaultName="akskeyvault$date"

#AppGw
appGw="myApplicationGateway"
appGwSubnet="appgw-subnet"
appGwSubnetAddr="10.0.1.0/24"
publicIp="myPublicIp"

###########################################
############## Resource Group #############
createRG() {
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

###########################################
############# Virtual Network #############
createVNET() {
    echo "Creating virtual network and subnets"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $subnet --subnet-prefixes $subnetAddr -l $location
}

###########################################
########### PUBLIC AKS CLUSTER ############
createPublicAKSClusterCNI() {
    echo "Creating AKS cluster with azure cni"
    createPublicAKSCluster
}

createPublicAKSClusterKubenet() {
    echo "Creating AKS cluster with kubenet"
    networkPlugin="kubenet"
    createPublicAKSCluster "--pod-cidr $podCIDR"
}

createPublicAKSClusterCNIOverlayCalico() {
    echo "Creating AKS cluster with azure cni overlay and calico"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --network-policy calico"
}

createPublicAKSClusterCNIOverlayCiliumACNS() {
    echo "Creating AKS cluster with azure cni overlay and cilium"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --network-dataplane cilium --network-policy cilium  --enable-acns"
}

createPublicAKSClusterAADK8sRbac() {
    echo "Creating AKS cluster with AAD and K8s RBAC"
    createPublicAKSCluster "--enable-aad"
}

createPublicAKSClusterAADAzureRbac() {
    echo "Creating AKS cluster with AAD and Azure RBAC"
    createPublicAKSCluster "--enable-aad --enable-azure-rbac"
}

createPublicAKSClusterPolicyDefender() {
    echo "Creating AKS cluster with azure cni, defender and policy"
    createPublicCluster "--enable-defender --enable-addons azure-policy"
}

createPublicAKSClusterMonitoring() {
    echo "Creating AKS cluster with monitoring and prometheus"
    createPublicAKSCluster "--enable-azure-monitor-metrics --enable-addons monitoring"
}

createPublicAKSClusterKeyVault() {
    echo "Creating AKS cluster with azure key vault"
    createPublicAKSCluster "--enable-addons azure-keyvault-secrets-provider"

    echo "Creating a new Azure key vault"
    az keyvault create --name $keyVaultName --resource-group $rg --location $location --enable-rbac-authorization

    az aks connection create keyvault --connection keyvaultconnection --resource-group $rg --name $aks --target-resource-group $rg --vault $keyVaultName --enable-csi --client-type none
}

createPublicAKSClusterAppRouting() {
    echo "Creating AKS cluster with app routing addon"
    createPublicAKSCluster "--enable-app-routing"
}

createPublicAKSClusterAGIC() {
    echo "Creating AKS cluster with AGIC addon"
    createRG
    createVNET

    echo "Creating Application Gateway subnet"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $appGwSubnet --address-prefixes $appGwSubnetAddr

    echo "Creating public ip"
    az network public-ip create --name $publicIp --resource-group $rg --allocation-method Static --sku Standard

    echo "Creating Application Gateway"
    az network application-gateway create --name $appGw --resource-group $rg --sku Standard_v2 --public-ip-address $publicIp --vnet-name $vnet --subnet $appGwSubnet --priority 100

    appgwId=$(az network application-gateway show --name $appGw --resource-group $rg -o tsv --query "id")

    echo "Creating public AKS cluster"
    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)
    
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $networkPlugin --vnet-subnet-id $subnetId \
    --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount --enable-addons ingress-appgw --appgw-id $appgwId

    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createPublicAKSClusterNAP() {
    echo "Creating AKS cluster with Node autoprovisioning"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --network-dataplane cilium --node-provisioning-mode Auto"
}

createPublicAKSClusterAzureLinux() {
    echo "Creating AKS cluster with Azure Linux nodes"
    createPublicAKSCluster "--os-sku AzureLinux"
}

createPublicAKSClusterAKSWindowsNodePool() {
    echo "Creating AKS cluster with windows node pool"
    createPublicAKSCluster
    echo "Add new windows node pool"
    az aks nodepool add --cluster-name $aks --name win -g $rg --os-type Windows --mode User --node-count 1 --node-vm-size Standard_D2s_v3
}

createPublicAKSCluster() {
    createRG
    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)

    echo "Creating public AKS cluster"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $networkPlugin --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount $1

    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

aks() {

    for arg in "$@"; do
        echo "####################################################"
        echo "##        Azure Kubernetes Service helper         ##"
        echo "####################################################"

        case "$arg" in

        azure)
            createPublicAKSClusterCNI
            break
            ;;
        kubenet)
            createPublicAKSClusterKubenet
            break
            ;;
        overlay)
            createPublicAKSClusterCNIOverlayCalico
            break
            ;;
        cillium)
            createPublicAKSClusterCNIOverlayCiliumACNS
            break
            ;;
        aad)
            createPublicAKSClusterAADK8sRbac
            break
            ;;
        aadrbac)
            createPublicAKSClusterAADAzureRbac
            break
            ;;
        policydefender)
            createPublicAKSClusterPolicyDefender
            break
            ;;
        monitoring)
            createPublicAKSClusterMonitoring
            break
            ;;
        keyvault)
            createPublicAKSClusterKeyVault
            break
            ;;
        approuting)    
            createPublicAKSClusterAppRouting
            break
            ;;
        agic)
            createPublicAKSClusterAGIC
            break
            ;;
        nap)
            createPublicAKSClusterNAP
            break
            ;;
        azurelinux)
            createPublicAKSClusterAzureLinux
            break
            ;;
        windows)
            createPublicAKSClusterAKSWindowsNodePool
            break
            ;;
        private)
            createPrivateAKSCluster
            break
            ;;
        privateapi)
            createPrivateAKSClusterAPIIntegration
            break
            ;;
        esac
    done
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