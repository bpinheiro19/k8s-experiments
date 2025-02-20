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
            echo "################################################################"
            echo "## 01 - AKS cluster with Azure CNI                            ##"
            echo "## 02 - AKS cluster with Kubenet                              ##"
            echo "## 03 - AKS cluster with Azure CNI overlay and calico         ##"
            echo "## 04 - AKS cluster with Azure CNI overlay, cilium and ACNS   ##"
            echo "## 05 - AKS cluster with kubenet, AAD and K8s RBAC            ##"
            echo "## 06 - AKS cluster with kubenet, AAD and Azure RBAC          ##"
            echo "## 07 - AKS cluster with Defender and Policy                  ##"
            echo "## 08 - AKS cluster with Azure Monitoring                     ##"
            echo "## 09 - AKS cluster with App Routing                          ##"
            echo "## 10 - AKS cluster with Node autoprovisioning                ##"
            echo "## 11 - AKS cluster with Azure Linux nodes                    ##"
            echo "## 12 - AKS cluster with Windows node pool                    ##"            
            echo "## 13 - Private AKS cluster                                   ##"
            echo "## 14 - Private AKS cluster with api vnet integration         ##"
            echo "## 99 - Standalone VM                                         ##"
            echo "################################################################"

            while true; do

                read -p "Option: " opt

                case $opt in
                1)
                    createPublicAKSClusterCNI
                    break
                    ;;
                2)
                    createPublicAKSClusterKubenet
                    break
                    ;;
                3)
                    createPublicAKSClusterCNIOverlayCalico
                    break
                    ;;
                4)
                    createPublicAKSClusterCNIOverlayCiliumACNS
                    break
                    ;;
                5)
                    createPublicAKSClusterAADK8sRbac
                    break
                    ;;
                6)
                    createPublicAKSClusterAADAzureRbac
                    break
                    ;;
                7)
                    createPublicAKSClusterPolicyDefender
                    break
                    ;;
                8)
                    createPublicAKSClusterMonitoring
                    break
                    ;;
                9)
                    createPublicAKSClusterAppRouting
                    break
                    ;;
                10)
                    createPublicAKSClusterNAP
                    break
                    ;;
                11)
                    createPublicAKSClusterAzureLinux
                    break
                    ;;
                12)
                    createPublicAKSClusterAKSWindowsNodePool
                    break
                    ;;
                13)
                    createPrivateAKSCluster
                    break
                    ;;
                14)
                    createPrivateAKSClusterAPIIntegration
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

            mapfile -t clusters < <(az aks list -g $rg -o tsv --query '[].[name]')

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

createPublicAKSClusterAppRouting() {
    echo "Creating AKS cluster with app routing addon"
    createPublicAKSCluster "--enable-app-routing"
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

###########################################
########### PRIVATE AKS CLUSTER ###########
createPrivateAKSClusterAPIIntegration() {
    createRG
    
    echo "Creating virtual network and subnets"
    az network vnet create --name $vnet -g $rg --location $location --address-prefixes 172.19.0.0/16
    az network vnet subnet create -g $rg --vnet-name $vnet --name "apiserver-subnet" --delegations Microsoft.ContainerService/managedClusters --address-prefixes 172.19.0.0/28
    az network vnet subnet create -g $rg --vnet-name $vnet --name "cluster-subnet" --address-prefixes 172.19.1.0/24

    apiSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n "apiserver-subnet" --query id -o tsv)
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n "cluster-subnet" --query id -o tsv)

    echo "Creating identity and role assignments"
    identityId=$(az identity create -g $rg --name "aks-api-integration-identity" --location $location --query principalId -o tsv)
    identityResourceId=$(az identity list -g aks-rg --output json --query '[].id' -o tsv)
    sleep 10

    az role assignment create --scope $apiSubnetId --role "Network Contributor" --assignee {$identityId}
    az role assignment create --scope $aksSubnetId --role "Network Contributor" --assignee $identityId

    echo "Creating private AKS cluster with api vnet integration"
    az aks create -g $rg -n $aks -l $location --network-plugin azure --enable-private-cluster --enable-apiserver-vnet-integration --vnet-subnet-id $aksSubnetId --apiserver-subnet-id $apiSubnetId --assign-identity $identityResourceId --generate-ssh-keys
}

createPrivateCluster() {
    createRG
    createVNET

    subnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query id -o tsv)

    echo "Creating private AKS cluster"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $networkPlugin --vnet-subnet-id $subnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount --ssh-access disabled --enable-private-cluster $1

    echo "Creating Azure VM in the same vnet"
    az vm create -g $rg -n $vm -l $location --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation
}

########### OTHERS ###########
createVM() {
    createRG
    createVNET

    echo "Creating Ubuntu VM"
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
