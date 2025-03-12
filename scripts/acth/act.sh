#!/bin/bash

main_menu(){
    echo "######################################################"
    echo "##          Azure Containers Team helper            ##"
    echo "######################################################"
    echo "######################################################"
    echo "## 1 - Resource Group                               ##"
    echo "## 2 - AKS                                          ##"
    echo "## 3 - ACR                                          ##"
    echo "## 4 - ACI                                          ##"
    echo "## 5 - ARO                                          ##"
    echo "## 6 - Others                                       ##"
    echo "######################################################"
}

aks_menu_templates(){
    echo "##########################################################"
    echo "## 01 - AKS cluster with kubenet                        ##"
    echo "## 02 - AKS cluster with azure cni                      ##"
    echo "## 03 - AKS cluster with azure cni overlay and cilium   ##"
    echo "## 04 - AKS cluster with kubenet, AAD and Azure RBAC    ##"
    echo "## 05 - AKS cluster with azure cni, defender and policy ##"
    echo "## 06 - AKS cluster with monitoring                     ##"
    echo "## 07 - AKS cluster with Node autoprovisioning          ##"
    echo "## 08 - AKS cluster with AGIC addon                     ##"
    echo "## 09 - Private AKS cluster with kubenet azure cni      ##"
    echo "## 10 - Private AKS cluster with azure cni              ##"
    echo "##########################################################"
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
    echo "akstemplates"
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