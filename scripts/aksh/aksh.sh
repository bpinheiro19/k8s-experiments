#!/bin/bash

date="$(date +%s)"
rg="aks-rg"
location="swedencentral"

#AKS
aks="aks$date"
aksVersion="1.31.7"
networkPlugin="azure"
networkPolicy="none"
networkDataplane="azure"
serviceCidr=10.0.241.0/24
podCIDR=172.16.0.0/16
dnsIp=10.0.241.10
sku="Standard_D2ps_v6"
nodeCount=1

#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
aksSubnet="aks-subnet"
apiSubnet="apiserver-subnet"
aksSubnetAddr=10.0.240.0/24
apiSubnetAddr=10.0.242.0/24

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

aks() {

    for arg in "$@"; do
        echo "################################################################"
        echo "############    Azure Kubernetes Service helper     ############"
        echo "################################################################"

        case "$arg" in

        create)
            echo "################################################################"
            echo "## 01 - AKS cluster with Azure CNI                            ##"
            echo "## 02 - AKS cluster with Kubenet                              ##"
            echo "## 03 - AKS cluster with Azure CNI overlay and calico         ##"
            echo "## 04 - AKS cluster with Azure CNI overlay, cilium and ACNS   ##"
            echo "## 05 - AKS cluster with Kubenet, AAD and K8s RBAC            ##"
            echo "## 06 - AKS cluster with Kubenet, AAD and Azure RBAC          ##"
            echo "## 07 - AKS cluster with Defender and Policy                  ##"
            echo "## 08 - AKS cluster with Azure Monitoring                     ##"
            echo "## 09 - AKS cluster with Azure Key Vault                      ##"
            echo "## 10 - AKS cluster with App Routing                          ##"
            echo "## 11 - AKS cluster with AGIC addon                           ##"
            echo "## 12 - AKS cluster with Node autoprovisioning                ##"
            echo "## 13 - AKS cluster with Azure Linux nodes                    ##"
            echo "## 14 - AKS cluster with Windows node pool                    ##"            
            echo "## 15 - AKS cluster with Zone Aligned node pools              ##"
            echo "## 16 - AKS cluster with Dapr extension                       ##"
            echo "## 17 - AKS cluster with Flux extension                       ##"
            echo "## 18 - AKS cluster with Keda addon                           ##"
            echo "## 30 - Private AKS cluster                                   ##"
            echo "## 31 - Private AKS cluster with api vnet integration         ##"
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
                    createPublicAKSClusterKeyVault
                    break
                    ;;
                10)    
                    createPublicAKSClusterAppRouting
                    break
                    ;;
                11)
                    createPublicAKSClusterAGIC
                    break
                    ;;
                12)
                    createPublicAKSClusterNAP
                    break
                    ;;
                13)
                    createPublicAKSClusterAzureLinux
                    break
                    ;;
                14)
                    createPublicAKSClusterAKSWindowsNodePool
                    break
                    ;;
                15)
                    createPublicAKSClusterZoneAligned
                    break
                    ;;
                16)
                    createPublicAKSClusterDapr
                    break
                    ;;
                17)
                    createPublicAKSClusterFlux
                    break
                    ;;
                18)
                    createPublicAKSClusterKeda
                    break
                    ;;
                30)
                    createPrivateAKSCluster
                    break
                    ;;
                31)
                    createPrivateAKSClusterAPIIntegration
                    break
                    ;;           
                99)
                    createStandaloneVM
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
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $aksSubnet --subnet-prefixes $aksSubnetAddr -l $location
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
    networkPolicy="calico"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR"
}

createPublicAKSClusterCNIOverlayCiliumACNS() {
    networkPolicy="cilium"
    networkDataplane="cilium"
    echo "Creating AKS cluster with azure cni overlay and cilium"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --enable-acns"
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
    createPublicAKSCluster "--enable-defender --enable-addons azure-policy"
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

createAppGw(){
    echo "Creating Application Gateway subnet"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $appGwSubnet --address-prefixes $appGwSubnetAddr

    echo "Creating public ip"
    az network public-ip create --name $publicIp --resource-group $rg --allocation-method Static --sku Standard

    echo "Creating Application Gateway"
    az network application-gateway create --name $appGw --resource-group $rg --sku Standard_v2 --public-ip-address $publicIp --vnet-name $vnet --subnet $appGwSubnet --priority 100
}

createPublicAKSClusterAGIC() {
    echo "Creating AKS cluster with AGIC addon"
    createRG
    createVNET

    createAppGw

    appgwId=$(az network application-gateway show --name $appGw --resource-group $rg -o tsv --query "id")
    
    createAKSCluster "--enable-addons ingress-appgw --appgw-id $appgwId"
}

createPublicAKSClusterNAP() {
    echo "Creating AKS cluster with Node autoprovisioning"
    networkDataplane="cilium"
    createPublicAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --node-provisioning-mode Auto"
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

createPublicAKSClusterZoneAligned() {
    echo "Creating AKS cluster with Zone Aligned node pools"
    createPublicAKSCluster "--node-count 3 --zones 1 2 3"

    echo "Add user node pools"
    az aks nodepool add -g $rg --cluster-name $aks --name userpool1  --mode User --node-count 1 --node-vm-size $sku --zones 1
    az aks nodepool add -g $rg --cluster-name $aks --name userpool2  --mode User --node-count 1 --node-vm-size $sku --zones 2
    az aks nodepool add -g $rg --cluster-name $aks --name userpool3  --mode User --node-count 1 --node-vm-size $sku --zones 3
}

createPublicAKSClusterDapr() {
    echo "Creating AKS cluster with Dapr extension"
    createPublicAKSCluster "--node-count 3"
    
    echo "Installing Dapr extension"
    az k8s-extension create --cluster-type managedClusters --cluster-name $aks --resource-group $rg --name dapr --extension-type Microsoft.Dapr --auto-upgrade-minor-version true
}

createPublicAKSClusterFlux() {
    echo "Creating AKS cluster with Flux extension"
    createPublicAKSCluster
    
    echo "Installing Flux extension"
    az k8s-configuration flux create -g $rg -c $aks -n cluster-config --namespace cluster-config -t managedClusters --scope cluster -u https://github.com/Azure/gitops-flux2-kustomize-helm-mt --branch main --kustomization name=infra path=./infrastructure prune=true --kustomization name=apps path=./apps/staging prune=true dependsOn=\["infra"\]
}

createPublicAKSClusterKeda() {
    echo "Creating AKS cluster with Keda addon"
    createPublicAKSCluster "--enable-keda"
}

createAKSCluster(){
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $aksSubnet --query id -o tsv)
    echo "Creating AKS cluster"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $networkPlugin --network-policy $networkPolicy --network-dataplane $networkDataplane --vnet-subnet-id $aksSubnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount $1

    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createPublicAKSCluster() {

    createRG
    createVNET

    createAKSCluster $1
}

###########################################
########### PRIVATE AKS CLUSTER ###########
createPrivateAKSClusterAPIIntegration() {
    echo "Creating private AKS cluster with API vnet integration"

    createRG
    createVNET
    az network vnet subnet create -g $rg --vnet-name $vnet --name "apiserver-subnet" --delegations Microsoft.ContainerService/managedClusters --address-prefixes $apiSubnetAddr

    apiSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $apiSubnet --query id -o tsv)
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $aksSubnet --query id -o tsv)

    echo "Creating identity and role assignments"
    identityId=$(az identity create -g $rg --name "aks-api-integration-identity" --location $location --query principalId -o tsv)
    identityResourceId=$(az identity list -g aks-rg --output json --query '[].id' -o tsv)
    sleep 10
    
    az role assignment create --scope $apiSubnetId --role "Network Contributor" --assignee {$identityId}
    az role assignment create --scope $aksSubnetId --role "Network Contributor" --assignee $identityId    

    createAKSCluster "--ssh-access disabled --enable-private-cluster --disable-public-fqdn --enable-apiserver-vnet-integration --apiserver-subnet-id $apiSubnetId --assign-identity $identityResourceId "
    
    createVM
}


createPrivateAKSCluster() {
    echo "Creating private AKS cluster"

    createRG
    createVNET

    createAKSCluster "--ssh-access disabled --enable-private-cluster --disable-public-fqdn "

    createVM
}

########### OTHERS ###########
createStandaloneVM() {
    createRG
    createVNET

    createVM
}

createVM(){
    echo "Creating Virtual Machine"
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
