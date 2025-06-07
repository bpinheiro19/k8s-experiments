#!/bin/bash

############################################
################ Variables #################
date="$(date +%s)"
rg="aks-rg"
location="swedencentral"
extraArgs=""

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
virtualNodeSubnet="virtual-node-subnet"
aksSubnetAddr=10.0.240.0/24
apiSubnetAddr=10.0.242.0/24
virtualNodeSubnetAddr=10.0.243.0/24

#VM
vm="aksVM"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"

#AppGw
appGw="myApplicationGateway"
appGwSubnet="appgw-subnet"
appGwSubnetAddr="10.0.1.0/24"
publicIp="myPublicIp"

#Others
keyVaultName="akskeyvault$date"
grafana="aksgrafana"
monitorWorkspace="aksmonitor"

############################################
################ Functions #################

############################################
########### AKS Custom Cluster #############
aksCustom() {

    aksPublicPrivate
    aksVersion
    aksNetworkPlugin
    aksNetworkPolicy
    aksAddons

    createPublicAKSClusterWithRGAndVnet "$extraArgs"
}

aksPublicPrivate() {
    while true; do
        echo "##############         AKS Cluster Type        #################"
        echo "## 01 - Public AKS cluster                                    ##"
        echo "## 02 - Private AKS cluster                                   ##"
        echo "################################################################"

        read -p "Option: " publicprivate

        case $publicprivate in
        1)
            break
            ;;
        2)
            extraArgs+="--ssh-access disabled --enable-private-cluster --disable-public-fqdn "
            break
            ;;
        esac
    done
}

aksVersion() {
    echo "Available AKS versions:"

    mapfile -t versions < <(az aks get-versions -l swedencentral --only-show-errors -o table | tail -n +3 | awk '{print $1}')

    echo "##############       AKS Cluster Version       #################"
    for i in "${!versions[@]}"; do
        printf "## $i - ${versions[i]} \n"
    done
    echo "################################################################"

    read -p "Enter the AKS version: " INDEX
    aksVersion=${versions[INDEX]}
}

aksNetworkPlugin() {
    header
    while true; do
        echo "##############           Network Plugin        #################"
        echo "## 01 - Azure Overlay                                         ##"
        echo "## 02 - Azure CNI NodeSubnet                                  ##"
        echo "## 03 - Kubenet                                               ##"
        echo "################################################################"

        read -p "Option: " networkplugin

        case $networkplugin in
        1)
            networkPlugin="azure"
            networkPluginMode="overlay"
            extraArgs+="--network-plugin-mode $networkPluginMode --pod-cidr $podCIDR "
            break
            ;;
        2)
            networkPlugin="azure"
            break
            ;;
        3)
            networkPlugin="kubenet"
            break
            ;;
        esac
    done
}

aksNetworkPolicy() {
    header

    while true; do
        echo "##############           Network Policy        #################"
        echo "## 00 - None                                                  ##"
        echo "## 01 - Azure                                                 ##"
        echo "## 02 - Calico                                                ##"
        echo "## 03 - Cilium                                                ##"
        echo "################################################################"

        read -p "Option: " networkpolicy

        case $networkpolicy in
        0)
            networkPolicy="none"
            break
            ;;
        1)
            networkPolicy="azure"
            break
            ;;
        2)
            networkPolicy="calico"
            break
            ;;
        3)
            networkPolicy="cilium"
            extraArgs+="--network-dataplane cilium "
            break
            ;;
        esac
    done

}

aksAddons() {

    while true; do
        echo "##############             Addons              #################"
        echo "## 00 - None                                                  ##"
        echo "## 01 - Azure Key Vault                                       ##"
        echo "## 02 - Azure Monitor                                         ##"
        echo "## 03 - Azure Defender and Policy                             ##"
        echo "## 04 - App Routing                                           ##"
        echo "## 05 - AGIC                                                  ##"
        echo "## 06 - KEDA                                                  ##"
        echo "################################################################"

        read -p "Option: " addon

        case $addon in

        0)
            echo "No addons selected"
            break
            ;;
        1)
            extraArgs+="-a azure-keyvault-secrets-provider "
            break
            ;;
        2)
            extraArgs+="--enable-azure-monitor-metrics --enable-addons monitoring "
            break
            ;;
        3)
            extraArgs+="--enable-defender --enable-addons azure-policy "
            break
            ;;
        4)
            extraArgs+="--enable-app-routing "
            break
            ;;
        5)
            extraArgs+="-a ingress-appgw --appgw-name $appGw --appgw-subnet-cidr $appGwSubnetAddr "
            break
            ;;
        6)
            extraArgs+="--enable-keda "
            break
            ;;
        esac
    done
}

############################################
############# AKS Templates ################
aksTemplates() {
    header
    echo "## NETWORK PLUGINS                                            ##"
    echo "## 01 - AKS cluster with Azure CNI Overlay                    ##"
    echo "## 02 - AKS cluster with Azure CNI Node Subnet                ##"
    echo "## 03 - AKS cluster with Azure CNI Dynamic IP Allocation      ##"
    echo "## 04 - AKS cluster with Kubenet                              ##"
    echo "## 05 - AKS cluster with Bring Your Own CNI                   ##"
    echo "################################################################"
    echo "## NETWORK POLICIES                                           ##"
    echo "## 06 - AKS cluster with Azure CNI Node Subnet and Azure NPM  ##"
    echo "## 07 - AKS cluster with Azure CNI Overlay and Calico         ##"
    echo "## 08 - AKS cluster with Azure CNI Overlay and Cilium         ##"
    echo "################################################################"
    echo "## AUTHENTICATION                                             ##"
    echo "## 09 - AKS cluster with AAD and K8s RBAC                     ##"
    echo "## 10 - AKS cluster with AAD and Azure RBAC                   ##"
    echo "################################################################"
    echo "## ADDONS                                                     ##"
    echo "## 11 - AKS cluster with Azure Defender and Azure Policy      ##"
    echo "## 12 - AKS cluster with Azure Monitoring                     ##"
    echo "## 13 - AKS cluster with Azure Keyvault Secret Provider Addon ##"
    echo "## 14 - AKS cluster with AGIC Addon                           ##"
    echo "## 15 - AKS cluster with Keda Addon                           ##"
    echo "## 16 - AKS cluster with Virtual Node Addon                   ##"
    echo "## 17 - AKS cluster with Istio-based Service Mesh Addon       ##"
    echo "################################################################"
    echo "## EXTENSIONS                                                 ##"
    echo "## 18 - AKS cluster with Dapr Extension                       ##"
    echo "## 19 - AKS cluster with Flux Extension                       ##"
    echo "################################################################"
    echo "## OTHERS                                                     ##"
    echo "## 20 - AKS cluster with App Routing                          ##"
    echo "## 21 - AKS cluster with Azure Linux Nodes                    ##"
    echo "## 22 - AKS cluster with Zone Aligned Node Pools              ##"
    echo "## 23 - AKS cluster with Windows Node Pool                    ##"
    echo "## 24 - AKS cluster with Node Autoprovisioning                ##"
    echo "## 25 - AKS cluster with Network Observability                ##"
    echo "################################################################"
    echo "## PRIVATE CLUSTERS                                           ##"
    echo "## 30 - Private AKS cluster                                   ##"
    echo "## 31 - Private AKS cluster with api vnet integration         ##"
    echo "################################################################"

    while true; do

        read -p "Option: " opt

        case $opt in
        1)
            createPublicAKSClusterAzureCNIOverlay
            break
            ;;
        2)
            createPublicAKSClusterAzureCNINodeSubnet
            break
            ;;
        3)
            createPublicAKSClusterAzureCNIDynamicIPAllocation
            break
            ;;
        4)
            createPublicAKSClusterKubenet
            break
            ;;
        5)
            createPublicAKSClusterBringYourOwnCNI
            break
            ;;
        6)
            createPublicAKSClusterAzureCNINodeSubnetAzureNPM
            break
            ;;
        7)
            createPublicAKSClusterAzureCNIOverlayCalico
            break
            ;;
        8)
            createPublicAKSClusterAzureCNIOverlayCilium
            break
            ;;
        9)
            createPublicAKSClusterAADK8sRbac
            break
            ;;
        10)
            createPublicAKSClusterAADAzureRbac
            break
            ;;
        11)
            createPublicAKSClusterPolicyDefender
            break
            ;;
        12)
            createPublicAKSClusterAzureMonitoring
            break
            ;;
        13)
            createPublicAKSClusterKeyVault
            break
            ;;
        14)
            createPublicAKSClusterAGIC
            break
            ;;
        15)
            createPublicAKSClusterKeda
            break
            ;;
        16)
            createPublicAKSClusterVirtualNode
            break
            ;;
        17)
            createPublicAKSClusterIstioServiceMesh
            break
            ;;
        18)
            createPublicAKSClusterDapr
            break
            ;;
        19)
            createPublicAKSClusterFlux
            break
            ;;
        20)
            createPublicAKSClusterAppRouting
            break
            ;;
        21)
            createPublicAKSClusterAzureLinux
            break
            ;;
        22)
            createPublicAKSClusterZoneAligned
            break
            ;;
        23)
            createPublicAKSClusterWindowsNodePool
            break
            ;;
        24)
            createPublicAKSClusterNAP
            break
            ;;
        25)
            createPublicAKSClusterNetworkObservability
            break
            ;;
        30)
            createPrivateAKSClusterWithRGAndVnet
            break
            ;;
        31)
            createPrivateAKSClusterAPIIntegration
            break
            ;;
        esac

    done
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
########### Public AKS Clusters ###########
createPublicAKSClusterAzureCNIOverlay() {
    echo "Creating AKS cluster with Azure CNI Overlay"
    createPublicAKSClusterWithRGAndVNET "--network-plugin-mode overlay --pod-cidr $podCIDR"
}

createPublicAKSClusterAzureCNINodeSubnet() {
    echo "Creating AKS cluster with Azure CNI"
    createPublicAKSClusterWithRGAndVNET
}

createPublicAKSClusterAzureCNIDynamicIPAllocation() { ## TODO
    echo "Creating AKS cluster with Azure CNI Dynamic IP Allocation"
}

createPublicAKSClusterKubenet() {
    echo "Creating AKS cluster with kubenet"
    networkPlugin="kubenet"
    createPublicAKSClusterWithRGAndVNET "--pod-cidr $podCIDR"
}

createPublicAKSClusterBringYourOwnCNI() { ## TODO
    echo "Creating AKS cluster with Bring Your Own CNI"
}

createPublicAKSClusterAzureCNINodeSubnetAzureNPM() { ## TODO
    echo "Creating AKS cluster with Bring Your Own CNI"
}

createPublicAKSClusterAzureCNIOverlayCalico() { ## TEST
    echo "Creating AKS cluster with Azure CNI Overlay and Calico"
    networkPolicy="calico"
    createPublicAKSClusterWithRGAndVNET "--network-plugin-mode overlay --pod-cidr $podCIDR"
}

createPublicAKSClusterAzureCNIOverlayCilium() { ## TEST
    networkPolicy="cilium"
    networkDataplane="cilium"
    echo "Creating AKS cluster with Azure CNI Overlay and Cilium"
    createPublicAKSClusterWithRGAndVNET "--network-plugin-mode overlay --pod-cidr $podCIDR"
}

createPublicAKSClusterAADK8sRbac() { ## TEST
    echo "Creating AKS cluster with AAD and Kubernetes RBAC"
    createPublicAKSClusterWithRGAndVNET "--enable-aad"
}

createPublicAKSClusterAADAzureRbac() { ## TEST
    echo "Creating AKS cluster with AAD and Azure RBAC"
    createPublicAKSClusterWithRGAndVNET "--enable-aad --enable-azure-rbac"
}

createPublicAKSClusterPolicyDefender() { ## TEST
    echo "Creating AKS cluster with Azure CNI, Azure Defender and Azure Policy"
    createPublicAKSClusterWithRGAndVNET "--enable-defender --enable-addons azure-policy"
}

createPublicAKSClusterAzureMonitoring() { ## TEST
    echo "Creating AKS cluster with Container Insights and Managed Prometheus"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-monitor-metrics --enable-addons monitoring"
}

createPublicAKSClusterKeyVault() { ## TEST
    echo "Creating AKS cluster with Azure Key Vault"
    createPublicAKSClusterWithRGAndVNET "--enable-addons azure-keyvault-secrets-provider"

    echo "Creating a new Azure Key Vault"
    az keyvault create --name $keyVaultName --resource-group $rg --location $location --enable-rbac-authorization

    az aks connection create keyvault --connection keyvaultconnection --resource-group $rg --name $aks --target-resource-group $rg --vault $keyVaultName --enable-csi --client-type none
}

createAppGw() {
    echo "Creating Application Gateway Subnet"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $appGwSubnet --address-prefixes $appGwSubnetAddr

    echo "Creating Public IP"
    az network public-ip create --name $publicIp --resource-group $rg --allocation-method Static --sku Standard

    echo "Creating Application Gateway"
    az network application-gateway create --name $appGw --resource-group $rg --sku Standard_v2 --public-ip-address $publicIp --vnet-name $vnet --subnet $appGwSubnet --priority 100
}

createPublicAKSClusterAGIC() { ## TEST
    echo "Creating AKS cluster with AGIC Addon"
    createRG
    createVNET

    createAppGw

    appgwId=$(az network application-gateway show --name $appGw --resource-group $rg -o tsv --query "id")

    createAKSCluster "--enable-addons ingress-appgw --appgw-id $appgwId"
}

createPublicAKSClusterKeda() { ## TEST
    echo "Creating AKS cluster with Keda Addon"
    createPublicAKSClusterWithRGAndVNET "--enable-keda"
}

createPublicAKSClusterVirtualNode() {
    echo "Creating AKS cluster with Virtual Node"

    createRG
    createVNET

    az network vnet subnet create -g $rg --vnet-name $vnet --name $virtualNodeSubnet --address-prefixes $virtualNodeSubnetAddr

    createAKSCluster "--enable-addons virtual-node --aci-subnet-name $virtualNodeSubnet"
}

createPublicAKSClusterIstioServiceMesh() {
    echo "Creating AKS cluster with Istio-based Service Mesh Addon"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-service-mesh"
}

createPublicAKSClusterDapr() { ## TEST
    echo "Creating AKS cluster with Dapr extension"
    createPublicAKSClusterWithRGAndVNET "--node-count 3"

    echo "Installing Dapr extension"
    az k8s-extension create --cluster-type managedClusters --cluster-name $aks --resource-group $rg --name dapr --extension-type Microsoft.Dapr --auto-upgrade-minor-version true
}

createPublicAKSClusterFlux() { ## TEST
    echo "Creating AKS cluster with Flux extension"
    createPublicAKSClusterWithRGAndVNET

    echo "Installing Flux extension"
    az k8s-configuration flux create -g $rg -c $aks -n cluster-config --namespace cluster-config -t managedClusters --scope cluster -u https://github.com/Azure/gitops-flux2-kustomize-helm-mt --branch main --kustomization name=infra path=./infrastructure prune=true --kustomization name=apps path=./apps/staging prune=true dependsOn=\["infra"\]
}

createPublicAKSClusterAppRouting() { ## TEST
    echo "Creating AKS cluster with app routing addon"
    createPublicAKSClusterWithRGAndVNET "--enable-app-routing"
}

createPublicAKSClusterAzureLinux() { ## TEST
    echo "Creating AKS cluster with Azure Linux nodes"
    createPublicAKSClusterWithRGAndVNET "--os-sku AzureLinux"
}

createPublicAKSClusterZoneAligned() { ## TEST
    echo "Creating AKS cluster with Zone Aligned node pools"
    createPublicAKSClusterWithRGAndVNET "--node-count 3 --zones 1 2 3"

    echo "Add user node pools"
    az aks nodepool add -g $rg --cluster-name $aks --name userpool1 --mode User --node-count 1 --node-vm-size $sku --zones 1
    az aks nodepool add -g $rg --cluster-name $aks --name userpool2 --mode User --node-count 1 --node-vm-size $sku --zones 2
    az aks nodepool add -g $rg --cluster-name $aks --name userpool3 --mode User --node-count 1 --node-vm-size $sku --zones 3
}

createPublicAKSClusterWindowsNodePool() { ## TEST
    echo "Creating AKS cluster with windows node pool"
    createPublicAKSClusterWithRGAndVNET
    echo "Add new windows node pool"
    az aks nodepool add --cluster-name $aks --name win -g $rg --os-type Windows --mode User --node-count 1 --node-vm-size Standard_D2s_v3
}

createPublicAKSClusterNAP() { ## TEST
    echo "Creating AKS cluster with Node Autoprovisioning"
    networkDataplane="cilium"
    createPublicAKSClusterWithRGAndVNET "--network-plugin-mode overlay --pod-cidr $podCIDR --node-provisioning-mode Auto"
}

createPublicAKSClusterNetworkObservability() {
    echo "Creating AKS cluster with Network Observability"
    networkPolicy="cilium"
    networkDataplane="cilium"

    createRG
    createVNET

    echo "Creating Azure Monitor Workspace"
    az resource create -g $rg --namespace microsoft.monitor --resource-type accounts --name $monitorWorkspace --location $location --properties '{}'

    echo "Creating Grafana Instance"
    az grafana create --name $grafana -g $rg

    grafanaId=$(az grafana show --name $grafana -g $rg --query id --output tsv)
    monitorWorkspaceId=$(az resource show -g $rg --name $monitorWorkspace --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

    createAKSCluster "--network-plugin-mode overlay --pod-cidr $podCIDR --enable-acns --enable-azure-monitor-metrics --azure-monitor-workspace-resource-id $monitorWorkspaceId --grafana-resource-id $grafanaId"
}

createAKSCluster() {
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $aksSubnet --query id -o tsv)
    echo "Creating AKS Cluster"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --network-plugin $networkPlugin --network-policy $networkPolicy --network-dataplane $networkDataplane --vnet-subnet-id $aksSubnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $nodeCount $1

    echo "az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createPublicAKSClusterWithRGAndVNET() {
    createRG
    createVNET

    createAKSCluster "$1"
}

###########################################
########### Private AKS Cluster ###########
createPrivateAKSClusterAPIIntegration() {
    echo "Creating private AKS Cluster with API Vnet Integration"
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

createPrivateAKSClusterWithRGAndVnet() {
    echo "Creating Private AKS Cluster"
    createRG
    createVNET

    createAKSCluster "--ssh-access disabled --enable-private-cluster --disable-public-fqdn $1"

    createVM
}

###########################################
################# Others ##################
createStandaloneVM() {
    createRG
    createVNET

    createVM
}

createVM() {
    echo "Creating Virtual Machine"
    az vm create -g $rg -n $vm -l $location --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation
}

header() {
    echo "################################################################"
    echo "############    Azure Kubernetes Service helper     ############"
    echo "################################################################"
}

main() {

    while true; do
        header
        echo "## 01 - Create AKS cluster from templates                     ##"
        echo "## 02 - Create custom AKS cluster   (WORK IN PROGRESS)        ##"
        echo "## 03 - List AKS clusters                                     ##"
        echo "## 04 - Delete AKS cluster                                    ##"
        echo "## 05 - Delete resource group (aks-rg)                        ##"
        echo "################################################################"

        read -p "Option: " opt

        case $opt in
        1)
            aksTemplates
            break
            ;;
        2)
            aksCustom
            break
            ;;
        3)
            mapfile -t clusters < <(az aks list -g $rg --only-show-errors -o tsv --query '[].[name]')

            if [ ${#clusters[@]} -eq 0 ]; then
                echo "No AKS Clusters"
            else
                echo "################################################################"
                echo "##                        AKS Clusters                        ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                          ##\n"
                done
                echo "################################################################"
            fi

            break
            ;;
        4)
            mapfile -t clusters < <(az aks list -g $rg --only-show-errors -o tsv --query '[].[name]')

            if [ ${#clusters[@]} -eq 0 ]; then
                echo "No AKS Clusters"
            else
                echo "################################################################"
                echo "##                        AKS Clusters                        ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                          ##\n"
                done
                echo "################################################################"

                read -p "Enter the cluster number: " AKS_INDEX
                cluster=${clusters[AKS_INDEX]}

                echo "Deleting the AKS cluster - $cluster"
                az aks delete --name $cluster --resource-group $rg
            fi

            break
            ;;
        5)
            echo "Deleting resource group"
            az group delete -n $rg --no-wait
            break
            ;;
        esac
    done
}

main
