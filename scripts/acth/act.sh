#!/bin/bash

date="$(date +%s)"
rg="aks-rg"
location="uksouth"

#AKS
aks="aks$date"
serviceCidr=10.0.242.0/24
podCIDR=172.16.0.0/16
dnsIp=10.0.242.10
sku="standard_d2as_v4"
nodeCount=1

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

main_menu(){
    echo "################################################################"
    echo "##          Azure Containers Team helper                      ##"
    echo "################################################################"
    echo "################################################################"
    echo "## 1 - Resource Group                                         ##"
    echo "## 2 - Azure Kubernetes Service                               ##"
    echo "## 3 - Azure Container Registry                               ##"
    echo "## 4 - Azure Container Instance                               ##"
    echo "## 5 - Azure Redhat Openshift                                 ##"
    echo "## 6 - Others                                                 ##"
    echo "################################################################"
}

aks_menu_templates(){
    echo "################################################################"
    echo "## 01 - AKS cluster with Azure CNI                            ##"
    echo "## 02 - AKS cluster with Kubenet                              ##"
    echo "## 03 - AKS cluster with Azure CNI overlay and calico         ##"
    echo "## 04 - AKS cluster with Azure CNI overlay, cilium and ACNS   ##"
    echo "## 05 - AKS cluster with kubenet, AAD and K8s RBAC            ##"
    echo "## 06 - AKS cluster with kubenet, AAD and Azure RBAC          ##"
    echo "## 07 - AKS cluster with Defender and Policy                  ##"
    echo "## 08 - AKS cluster with Azure Monitoring                     ##"
    echo "## 09 - AKS cluster with Azure Key Vault                      ##"
    echo "## 10 - AKS cluster with App Routing                          ##"
    echo "## 11 - AKS cluster with AGIC addon                           ##"
    echo "## 12 - AKS cluster with Node autoprovisioning                ##"
    echo "## 13 - AKS cluster with Azure Linux nodes                    ##"
    echo "## 14 - AKS cluster with Windows node pool                    ##"
    echo "## 15 - Private AKS cluster                                   ##"
    echo "## 16 - Private AKS cluster with api vnet integration         ##"
    echo "################################################################"
}

rg() {
    echo "rg"
}

aks() {
    echo "####################################################"
    echo "##           Azure Kubernetes Cluster             ##"
    echo "####################################################"

    echo "####################################################"
    echo "##            AKS configuration                   ##"
    echo "## 1 - Templates                                  ##"
    echo "## 2 - Custom cluster                             ##"
    echo "####################################################"

    read -p "Option: " aksconfigargs
    case "$aksconfigargs" in
    1)
        akstemplates
        ;;
    2)
        akscustom
        ;;
    esac
}

akstemplates(){
    aks_menu_templates

    read -p "Option: " opt

    case $opt in
    1)
        ./aks.sh azure
        ;;
    2)
        ./aks.sh kubenet
        ;;
    3)
        ./aks.sh overlay
        ;;
    4)
        ./aks.sh cillium
        ;;
    5)
        ./aks.sh aad
        ;;
    6)
        ./aks.sh aadrbac
        ;;
    7)
        ./aks.sh policydefender
        ;;
    8)
        ./aks.sh monitoring
        ;;
    9)
        ./aks.sh keyvault
        ;;
    10)    
        ./aks.sh approuting
        ;;
    11)
        ./aks.sh agic
        ;;
    12)
        ./aks.sh nap
        ;;
    13)
        ./aks.sh azurelinux
        ;;
    14)
        ./aks.sh windows
        ;;
    15)
        ./aks.sh private
        ;;
    16)
        ./aks.sh privateapi
        ;;
    esac
}

akscustom(){
    echo "akscustom"
}

acr() {
    echo "acr"
}

aci() {
    echo "aci"
}

aro() {
    echo "aro"
}

others() {
    echo "others"
}

main() {

    main_menu

    read -p "Option: " cargs
    case "$cargs" in
    1)
        rg
        ;;
    2)
        aks
        ;;
    3)
        acr
        ;;
    4)
        aci
        ;;
    5)
        aro
        ;;
    6)
        others
        ;;
    esac
   
}

main