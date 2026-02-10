#!/bin/bash

############################################
################ Variables #################
date="$(date +%s)"
rg="aks-rg"
location="uksouth"
extraArgs=""
output="none"

#AKS
aks="aks$date"
aksVersion="1.32.9"
aksTier="Free"
networkPlugin="azure"
networkPolicy="none"
networkDataplane="azure"
serviceCidr=10.0.241.0/24
podCIDR=172.16.0.0/16
dnsIp=10.0.241.10
nodePoolMode="user"
nodePoolType="VirtualMachineScaleSets"
sku="Standard_D2as_v5"
minNodeCount=1
maxNodeCount=3
outboundType="loadBalancer"
overlay="--network-plugin-mode overlay --pod-cidr $podCIDR "
autoscaler="--enable-cluster-autoscaler --min-count $minNodeCount --max-count $maxNodeCount "
aksUAMIdentity="aks-identity$date"
hasAPISubnet=false
hasPodSubnet=false
hasVirtualNodeSubnet=false

#VNET
vnet="vnet$date"
vnetAddr=10.0.0.0/16
aksSubnet="aks-subnet"
apiSubnet="apiserver-subnet"
virtualNodeSubnet="virtual-node-subnet"
podSubnet="pod-subnet"
aksSubnetAddr=10.0.240.0/24
apiSubnetAddr=10.0.242.0/24
virtualNodeSubnetAddr=10.0.243.0/24
podSubnetAddr=10.0.244.0/22

#VM
vm="aksVM$date"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"

#AppGw
appGw="myApplicationGateway$date"
appGwSubnet="appgw-subnet"
appGwSubnetAddr="10.0.1.0/24"
publicIp="myPublicIp"

#Firewall
firewall="aks-firewall$date"
firewallPublicIP="firewall-public-ip$date"
firewallSubnet="AzureFirewallSubnet"
firewallSubnetAddr=10.0.248.0/24
firewallIPConfig="firewall-config"
firewalRouteTable="firewall-route-table$date"
firewallRouteName="firewall-route"
firewallRouteInternet="firewall-route-internet"

#Backup
blobcontainer="backupcontainer"
storageaccount="backupsa$date"
backupvault="backupVault$date"

#Others
keyVaultName="akskeyvault$date"
grafana="aksgrafana$date"
monitorWorkspace="aksmonitor$date"
acr="aksacr$date"

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

    createPublicAKSClusterWithRGAndVNET "$extraArgs"
}

aksPublicPrivate() {
    header
    echo "##############         AKS Cluster Type        #################"
    echo "## 01 - Public AKS cluster                                    ##"
    echo "## 02 - Private AKS cluster                                   ##"
    echo "################################################################"

    while read -p "Option: " publicprivate; do

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
    header

    mapfile -t versions < <(az aks get-versions -l swedencentral --only-show-errors -o table | tail -n +3 | awk '{print $1}')

    echo "##############       AKS Cluster Version       #################"
    for i in "${!versions[@]}"; do
        printf "## $i - ${versions[i]} \n"
    done
    echo "################################################################"

    read -p "Enter the AKS version: " INDEX
    aksVersion=${versions[INDEX]} ## TODO Should fail when INDEX is out of range
}

aksNetworkPlugin() {
    header
    echo "##############           Network Plugin        #################"
    echo "## 01 - Azure Overlay                                         ##"
    echo "## 02 - Azure CNI NodeSubnet                                  ##"
    echo "## 03 - Kubenet                                               ##"
    echo "################################################################"

    while read -p "Option: " networkplugin; do
    
        case $networkplugin in
        1)
            networkPlugin="azure"
            extraArgs+="$overlay "
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
    echo "##############           Network Policy        #################"
    echo "## 00 - None                                                  ##"
    echo "## 01 - Azure                                                 ##"
    echo "## 02 - Calico                                                ##"
    echo "## 03 - Cilium                                                ##"
    echo "################################################################"
    
    while read -p "Option: " networkpolicy; do    

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
            networkDataplane="cilium"
            break
            ;;
        esac
    done
}

aksAddons() {
    header
    echo "##############             Addons              #################"
    echo "## 00 - None                                                  ##"
    echo "## 01 - Azure Key Vault                                       ##"
    echo "## 02 - Azure Monitor                                         ##"
    echo "## 03 - Azure Defender and Policy                             ##"
    echo "## 04 - App Routing                                           ##"
    echo "## 05 - AGIC                                                  ##"
    echo "## 06 - KEDA                                                  ##"
    echo "################################################################"

    while read -p "Option: " addon; do

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
    echo "## ---------------------------------------------------------- ##"
    echo "##                      NETWORK PLUGINS                       ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 01 - AKS cluster with Azure CNI Overlay                    ##"
    echo "## 02 - AKS cluster with Azure CNI Node Subnet                ##"
    echo "## 03 - AKS cluster with Azure CNI Dynamic IP Allocation      ##"
    echo "## 04 - AKS cluster with Kubenet                              ##"
    echo "## 05 - AKS cluster with Bring Your Own CNI                   ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                      NETWORK POLICIES                      ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 10 - AKS cluster with Azure CNI Node Subnet and Azure NPM  ##"
    echo "## 11 - AKS cluster with Azure CNI Overlay and Calico         ##"
    echo "## 12 - AKS cluster with Azure CNI Overlay and Cilium         ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                       AUTHENTICATION                       ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 20 - AKS cluster with AAD and Kubernetes RBAC              ##"
    echo "## 21 - AKS cluster with AAD and Azure RBAC                   ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                           ADDONS                           ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 30 - AKS cluster with Azure Defender and Azure Policy      ##"
    echo "## 31 - AKS cluster with Azure Monitoring                     ##"
    echo "## 32 - AKS cluster with Azure KeyVault Secret Provider Addon ##"
    echo "## 33 - AKS cluster with AGIC Addon                           ##"
    echo "## 34 - AKS cluster with Keda Addon                           ##"
    echo "## 35 - AKS cluster with Virtual Node Addon                   ##"
    echo "## 36 - AKS cluster with Istio-based Service Mesh Addon       ##"
    echo "## 37 - AKS cluster with Cost Analysis Addon                  ##"
    echo "## 38 - AKS cluster with Application Routing Addon            ##"
    echo "## 39 - AKS cluster with Vertical Pod Autoscaling             ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                         EXTENSIONS                         ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 40 - AKS cluster with Dapr Extension                       ##"
    echo "## 41 - AKS cluster with Flux Extension                       ##"
    echo "## 42 - AKS cluster with Azure Container Storage Extension    ##"
    echo "## 43 - AKS cluster with Azure Machine Learning Extension     ##"
    echo "## 44 - AKS cluster with Azure Backup Extension               ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                           OTHERS                           ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 50 - AKS cluster with App Routing                          ##"
    echo "## 51 - AKS cluster with Azure Linux Nodes                    ##"
    echo "## 52 - AKS cluster with Zone Aligned Node Pools              ##"
    echo "## 53 - AKS cluster with Windows Node Pool                    ##"
    echo "## 54 - AKS cluster with Node Autoprovisioning                ##"
    echo "## 55 - AKS cluster with Network Observability                ##"
    echo "## 56 - AKS cluster with ACR                                  ##"
    echo "## 57 - AKS cluster with Spot Node Pool                       ##"
    echo "## 58 - AKS cluster with Virtual Machines Node Pool           ##"
    echo "## 59 - AKS cluster with GPU Spot Node Pool                   ##"
    echo "## 60 - AKS cluster with Long Term Support                    ##"
    echo "## 61 - AKS cluster with ArgoCD                               ##"
    echo "## 62 - AKS cluster with Istio Ingress Gateway                ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                      PRIVATE CLUSTERS                      ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 70 - Private AKS cluster                                   ##"
    echo "## 71 - Private AKS cluster with API VNet Integration         ##"
    echo "## 72 - Private AKS cluster with User Defined Routing         ##"
    echo "## ---------------------------------------------------------- ##"
    echo "##                    AUTOMATIC CLUSTERS                      ##"
    echo "## ---------------------------------------------------------- ##"
    echo "## 80 - Automatic AKS cluster                                 ##"
    echo "## ---------------------------------------------------------- ##"
    echo "################################################################"

    while read -p "Option: " opt; do

        case $opt in
        ## NETWORK PLUGINS ##
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
        ## NETWORK POLICIES ##
        10)
            createPublicAKSClusterAzureCNINodeSubnetAzureNPM
            break
            ;;
        11)
            createPublicAKSClusterAzureCNIOverlayCalico
            break
            ;;
        12)
            createPublicAKSClusterAzureCNIOverlayCilium
            break
            ;;
        ## AUTHENTICATION ##
        20)
            createPublicAKSClusterAADK8sRbac
            break
            ;;
        21)
            createPublicAKSClusterAADAzureRbac
            break
            ;;
        ## ADDONS ##
        30)
            createPublicAKSClusterPolicyDefender
            break
            ;;
        31)
            createPublicAKSClusterAzureMonitoring
            break
            ;;
        32)
            createPublicAKSClusterKeyVault
            break
            ;;
        33 )
            createPublicAKSClusterAGIC
            break
            ;;
        34)
            createPublicAKSClusterKeda
            break
            ;;
        35)
            createPublicAKSClusterVirtualNode
            break
            ;;
        36)
            createPublicAKSClusterIstioServiceMesh
            break
            ;;
        37)
            createPublicAKSClusterCostAnalysis
            break
            ;;
        38)
            createPublicAKSClusterApplicationRouting
            break
            ;;
        39)
            createPublicAKSClusterVerticalPodAutoscaling
            break
            ;;
        ## EXTENSIONS ##
        40)
            createPublicAKSClusterDapr
            break
            ;;
        41)
            createPublicAKSClusterFlux
            break
            ;;
        42)
            createPublicAKSClusterAzureContainerStorage
            break
            ;;
        43)
            createPublicAKSClusterAzureMachineLearning
            break
            ;;
        44)
            createPublicAKSClusterAzureBackup
            break
            ;;
        ## OTHERS ##
        50)
            createPublicAKSClusterAppRouting
            break
            ;;
        51)
            createPublicAKSClusterAzureLinux
            break
            ;;
        52)
            createPublicAKSClusterZoneAligned
            break
            ;;
        53)
            createPublicAKSClusterWindowsNodePool
            break
            ;;
        54)
            createPublicAKSClusterNAP
            break
            ;;
        55)
            createPublicAKSClusterNetworkObservability
            break
            ;;
        56)
            createPublicAKSWithACR
            break
            ;;
        57)
            createPublicAKSClusterSpotNodePool
            break
            ;;
        58)
            createPublicAKSClusterVirtualMachinesNodePool
            break
            ;;
        59)
            createPublicAKSClusterGPUSpotNodePool
            break
            ;;
        60) 
            createPublicAKSClusterLongTermSupport
            break
            ;;
        61) 
            createPublicAKSClusterArgoCD
            break
            ;;
        62) 
            createPublicAKSClusterIstioIngressGateway
            break
            ;;
        ## PRIVATE CLUSTERS ##
        70)
            createPrivateAKSClusterWithRGAndVnet
            break
            ;;
        71)
            createPrivateAKSClusterAPIIntegration
            break
            ;;
        72)
            createPrivateAKSClusterUDR
            break
            ;;
        ## AUTOMATIC CLUSTERS ##
        80)
            createPublicAutomaticAKSCluster
            break
            ;;
        esac

    done
}

###########################################
############## Resource Group #############
createRG() {
    echo "Creating ${rg} Resource Group"
    az group create -n $rg -l $location -o $output
}

###########################################
############# Virtual Network #############
createVNET() {
    echo "Creating ${vnet} Virtual Network and ${aksSubnet} subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr --subnet-name $aksSubnet --subnet-prefixes $aksSubnetAddr -l $location -o $output
    vnetId=$(az network vnet show -g $rg -n $vnet --query id -o tsv)

    if [ "$hasAPISubnet" = true ] ; then
        createAPISubnet
    fi

    if [ "$hasPodSubnet" = true ] ; then
        createPodSubnet
    fi

    if [ "$hasVirtualNodeSubnet" = true ] ; then
        createVirtualNodeSubnet
    fi
}

createAPISubnet() {
    echo "Creating ${apiSubnet} subnet in the ${vnet} Virtual Network"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $apiSubnet --delegations Microsoft.ContainerService/managedClusters --address-prefixes $apiSubnetAddr -o $output
    apiSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $apiSubnet --query id -o tsv)
}

createPodSubnet() {
    echo "Creating ${podSubnet} subnet in the ${vnet} Virtual Network"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $podSubnet --address-prefixes $podSubnetAddr -o $output
    podSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $podSubnet --query id -o tsv)
}

createVirtualNodeSubnet() {
    echo "Creating ${virtualNodeSubnet} subnet in the ${vnet} Virtual Network"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $virtualNodeSubnet --address-prefixes $virtualNodeSubnetAddr -o $output
    virtualNodeSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $virtualNodeSubnet --query id -o tsv)
}

###########################################
################ Identity #################
createUserAssignedManagedIdentity() {
    echo "Creating AKS Managed Identity - ${aksUAMIdentity}"
    az identity create --resource-group $rg --name $aksUAMIdentity --location $location -o $output
    principalId=$(az identity show --resource-group $rg --name $aksUAMIdentity --query principalId -o tsv)
    sleep 10
    createRoleAssignmentForAKSManagedIdentity
}

createRoleAssignmentForAKSManagedIdentity() {
    echo "Creating Network Contributor role assignment for AKS Managed Identity in ${vnet}"
    az role assignment create --scope $vnetId --role "Network Contributor" --assignee $principalId -o $output
}

###########################################
########### Public AKS Clusters ###########
createPublicAKSClusterAzureCNIOverlay() {
    echo "Creating AKS cluster with Azure CNI Overlay"
    createPublicAKSClusterWithRGAndVNET "$overlay"
}

createPublicAKSClusterAzureCNINodeSubnet() {
    echo "Creating AKS cluster with Azure CNI"
    createPublicAKSClusterWithRGAndVNET
}

createPublicAKSClusterAzureCNIDynamicIPAllocation() {
    echo "AKS cluster with Azure CNI Dynamic IP Allocation"
    createPublicAKSClusterWithRGAndVNET "--pod-subnet-id $podSubnetId"
}

createPublicAKSClusterKubenet() {
    echo "Creating AKS cluster with kubenet"
    networkPlugin="kubenet"
    createPublicAKSClusterWithRGAndVNET "--pod-cidr $podCIDR"
}

createPublicAKSClusterBringYourOwnCNI() {
    echo "Creating AKS cluster with Bring Your Own CNI"
    networkPlugin="none"
    createPublicAKSClusterWithRGAndVNET
}

createPublicAKSClusterAzureCNINodeSubnetAzureNPM() {
    echo "Creating AKS cluster with Azure CNI Node Subnet and Azure NPM"
    networkPolicy="azure"
    createPublicAKSClusterWithRGAndVNET
}

createPublicAKSClusterAzureCNIOverlayCalico() {
    echo "Creating AKS cluster with Azure CNI Overlay and Calico"
    networkPolicy="calico"
    createPublicAKSClusterWithRGAndVNET "$overlay"
}

createPublicAKSClusterAzureCNIOverlayCilium() {
    networkPolicy="cilium"
    networkDataplane="cilium"
    echo "Creating AKS cluster with Azure CNI Overlay and Cilium"
    createPublicAKSClusterWithRGAndVNET "$overlay"
}

createPublicAKSClusterAADK8sRbac() {
    echo "Creating AKS cluster with AAD and Kubernetes RBAC"
    createPublicAKSClusterWithRGAndVNET "--enable-aad"
}

createPublicAKSClusterAADAzureRbac() {
    echo "Creating AKS cluster with AAD and Azure RBAC"
    createPublicAKSClusterWithRGAndVNET "--enable-aad --enable-azure-rbac"
}

createPublicAKSClusterPolicyDefender() {
    echo "Creating AKS cluster with Azure CNI, Azure Defender and Azure Policy"
    createPublicAKSClusterWithRGAndVNET "--enable-defender --enable-addons azure-policy"
}

createPublicAKSClusterAzureMonitoring() {
    echo "Creating AKS cluster with Container Insights and Managed Prometheus"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-monitor-metrics --enable-addons monitoring"
}

createAzureKeyVault(){
    echo "Creating a new Azure Key Vault"
    az keyvault create --name $keyVaultName --resource-group $rg --location $location --enable-rbac-authorization -o $output

    az aks connection create keyvault --connection keyvaultconnection$date --resource-group $rg --name $aks --target-resource-group $rg --vault $keyVaultName --enable-csi --client-type none -o $output
}

createPublicAKSClusterKeyVault() {
    echo "Creating AKS cluster with Azure Key Vault"
    createPublicAKSClusterWithRGAndVNET "--enable-addons azure-keyvault-secrets-provider"

    createAzureKeyVault
}

createAppGw() {
    echo "Creating Application Gateway Subnet"
    az network vnet subnet create -g $rg --vnet-name $vnet --name $appGwSubnet --address-prefixes $appGwSubnetAddr -o $output

    echo "Creating Public IP"
    az network public-ip create --name $publicIp --resource-group $rg --allocation-method Static --sku Standard -o $output

    echo "Creating Application Gateway"
    az network application-gateway create --name $appGw --resource-group $rg --sku Standard_v2 --public-ip-address $publicIp --vnet-name $vnet --subnet $appGwSubnet --priority 100 -o $output
}

createPublicAKSClusterAGIC() {
    echo "Creating AKS cluster with AGIC Addon"
    createRgVnetUami

    createAppGw

    appgwId=$(az network application-gateway show --name $appGw -g $rg -o tsv --query "id")
    createAKSCluster "--enable-addons ingress-appgw --appgw-id $appgwId"
}

createPublicAKSClusterKeda() {
    echo "Creating AKS cluster with Keda Addon"
    createPublicAKSClusterWithRGAndVNET "--enable-keda"
}

createPublicAKSClusterVirtualNode() {
    echo "Creating AKS cluster with Virtual Node"
    createPublicAKSClusterWithRGAndVNET "--enable-addons virtual-node --aci-subnet-name $virtualNodeSubnet"
}

createPublicAKSClusterIstioServiceMesh() {
    echo "Creating AKS cluster with Istio-based Service Mesh Addon"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-service-mesh"
}

createPublicAKSClusterCostAnalysis() {
    echo "Creating AKS cluster with Cost Analysis Addon"
    createPublicAKSClusterWithRGAndVNET "--tier standard --enable-cost-analysis"
}

createPublicAKSClusterApplicationRouting(){
    echo "Creating AKS cluster with Application Routing Addon"
    createPublicAKSClusterWithRGAndVNET "--enable-app-routing"
}

createPublicAKSClusterVerticalPodAutoscaling(){
    echo "Creating AKS cluster with Vertical Pod Autoscaling"
    createPublicAKSClusterWithRGAndVNET "--enable-vpa"
}

createPublicAKSClusterDapr() {
    echo "Creating AKS cluster with Dapr extension"
    createPublicAKSClusterWithRGAndVNET "--node-count 3"

    echo "Installing Dapr extension"
    az k8s-extension create --cluster-type managedClusters --cluster-name $aks --resource-group $rg --name dapr --extension-type Microsoft.Dapr --auto-upgrade-minor-version true -o $output
}

createPublicAKSClusterFlux() {
    echo "Creating AKS cluster with Flux extension"
    createPublicAKSClusterWithRGAndVNET

    echo "Installing Flux extension"
    az k8s-configuration flux create -g $rg -c $aks -n cluster-config --namespace cluster-config -t managedClusters --scope cluster -u https://github.com/Azure/gitops-flux2-kustomize-helm-mt --branch main --kustomization name=infra path=./infrastructure prune=true --kustomization name=apps path=./apps/staging prune=true dependsOn=\["infra"\] -o $output
}

createPublicAKSClusterAzureContainerStorage() {
    echo "Creating AKS cluster with Azure Container Storage extension"
    minNodeCount=3
    maxNodeCount=5
    sku="Standard_D8s_v5"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-container-storage azureDisk $autoscaler "
}

createPublicAKSClusterAzureMachineLearning() {
    echo "Creating AKS cluster with Azure Machine Learning extension"
    createPublicAKSClusterWithRGAndVNET
    
    echo "Installing Azure Machine Learning extension"
    az k8s-extension create --name azuremachinelearning --extension-type Microsoft.AzureML.Kubernetes --config enableTraining=True enableInference=True inferenceRouterServiceType=LoadBalancer allowInsecureConnections=True InferenceRouterHA=False --cluster-type managedClusters --cluster-name $aks --resource-group $rg --scope cluster -o $output
}

createPublicAKSClusterAzureBackup() {
    echo "Creating AKS cluster"
    createPublicAKSClusterWithRGAndVNET

    subscriptionId="$(az account show --query id --output tsv)"

    echo "Creating Azure Backup Vault"
    az dataprotection backup-vault create --resource-group $rg --vault-name $backupvault --location $location --type SystemAssigned --storage-settings datastore-type="VaultStore" type="LocallyRedundant"

    echo "Creating Azure Storage Account and Container"
    az storage account create --name $storageaccount --resource-group $rg --location $location --sku Standard_LRS
    az storage container create --name $blobcontainer --account-name $storageaccount --auth-mode login

    echo "Installing Azure Backup extension"
    az k8s-extension create --name azure-aks-backup --extension-type microsoft.dataprotection.kubernetes --scope cluster --cluster-type managedClusters --cluster-name $aks --resource-group $rg --release-train stable --configuration-settings blobContainer=$blobcontainer storageAccount=$storageaccount storageAccountResourceGroup=$rg storageAccountSubscriptionId=$subscriptionId

    az role assignment create --assignee-object-id $(az k8s-extension show --name azure-aks-backup --cluster-name $aks --resource-group $rg --cluster-type managedClusters --query aksAssignedIdentity.principalId --output tsv) --role 'Storage Blob Data Contributor' --scope /subscriptions/$subscriptionId/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$storageaccount

    az aks trustedaccess rolebinding create --cluster-name $aks --name backuprolebinding --resource-group $rg --roles Microsoft.DataProtection/backupVaults/backup-operator --source-resource-id /subscriptions/$subscriptionId/resourceGroups/$rg/providers/Microsoft.DataProtection/BackupVaults/$backupvault
    
    echo "Azure Backup extension installed successfully"
}

createPublicAKSClusterAppRouting() {
    echo "Creating AKS cluster with app routing addon"
    createPublicAKSClusterWithRGAndVNET "--enable-app-routing"
}

createPublicAKSClusterAzureLinux() {
    echo "Creating AKS cluster with Azure Linux nodes"
    createPublicAKSClusterWithRGAndVNET "--os-sku AzureLinux"
}

createPublicAKSClusterZoneAligned() {
    echo "Creating AKS cluster with Zone Aligned node pools"
    createPublicAKSClusterWithRGAndVNET "--node-count 3 --zones 1 2 3"

    echo "Add user node pools"
    createAKSNodePool "--name userpool1 --zones 1 "
    createAKSNodePool "--name userpool2 --zones 2 "
    createAKSNodePool "--name userpool3 --zones 3 "
}

createPublicAKSClusterWindowsNodePool() {
    echo "Creating AKS cluster with windows node pool"
    createPublicAKSClusterWithRGAndVNET

    echo "Add new windows node pool"
    createAKSNodePool "--name win --os-type Windows "
}

createPublicAKSClusterNAP() {
    echo "Creating AKS cluster with Node Autoprovisioning"
    networkPolicy="cilium"
    networkDataplane="cilium"
    createPublicAKSClusterWithRGAndVNET "$overlay --node-provisioning-mode Auto"
}

createAzureMonitorAndGrafana() {
    echo "Creating Azure Monitor Workspace"
    az resource create -g $rg --namespace microsoft.monitor --resource-type accounts --name $monitorWorkspace --location $location --properties '{}' -o $output

    echo "Creating Grafana Instance"
    az grafana create --name $grafana -g $rg -o $output
}

createPublicAKSClusterNetworkObservability() {
    echo "Creating AKS cluster with Network Observability"
    networkPolicy="cilium"
    networkDataplane="cilium"

    createRgVnetUami

    createAzureMonitorAndGrafana

    grafanaId=$(az grafana show --name $grafana -g $rg --query id --output tsv)
    monitorWorkspaceId=$(az resource show -g $rg --name $monitorWorkspace --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

    createAKSCluster "$overlay --enable-acns --enable-azure-monitor-metrics --azure-monitor-workspace-resource-id $monitorWorkspaceId --grafana-resource-id $grafanaId"
}

createACR() {
    echo "Creating the Azure Container Registry"
    az acr create --name $acr --resource-group $rg --sku premium -o $output
}

createPublicAKSWithACR() {
    echo "Starting creation of AKS cluster with Azure Container Registry"
    createRgVnetUami
    createACR

    echo "Importing nginx image to ACR: $acr"
    az acr import --name $acr --source docker.io/library/nginx:latest --image nginx:v1

    createAKSCluster "--attach-acr $acr"
    echo "Create pod with ACR image: kubectl run my-nginx --image=$acr.azurecr.io/nginx:v1"
}

createPublicAKSClusterSpotNodePool(){
    echo "Creating AKS cluster with Spot Node Pool"
    createPublicAKSClusterWithRGAndVNET

    echo "Creating Spot Node Pool"
    createAKSNodePool "--name spot --priority Spot --eviction-policy Delete --spot-max-price "-1" $autoscaler "
}

createPublicAKSClusterVirtualMachinesNodePool(){
    echo "Creating AKS cluster with Virtual Machines Node Pool"
    nodePoolType="VirtualMachines"
    createPublicAKSClusterWithRGAndVNET "--vm-sizes $sku "
    az aks nodepool manual-scale add -g $rg --cluster-name $aks --name nodepool1 --vm-sizes "Standard_D4s_v5" --node-count $minNodeCount -o $output
}

createPublicAKSClusterGPUSpotNodePool(){
    echo "Creating AKS cluster with GPU Spot Node Pool"
    createPublicAKSClusterWithRGAndVNET 

    echo "Creating GPU Spot Node Pool"
    minNodeCount=0
    sku="Standard_NC4as_T4_v3"
    createAKSNodePool "--name spot --priority Spot --eviction-policy Delete --spot-max-price "-1" --mode User --node-count 1 $autoscaler "
}

createPublicAKSClusterLongTermSupport(){
    echo "Creating AKS cluster with Long Term Support"
    aksTier="premium"
    aksVersion="1.29.101"
    createPublicAKSClusterWithRGAndVNET "--k8s-support-plan AKSLongTermSupport --auto-upgrade-channel patch"
}

createPublicAKSClusterArgoCD(){
    echo "Creating AKS cluster with ArgoCD"
    createPublicAKSClusterWithRGAndVNET

    echo "Changing kubectl context to $aks"
    az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
}

createPublicAKSClusterIstioIngressGateway() {
    echo "Creating AKS cluster with Istio Ingress Gateway"
    createPublicAKSClusterWithRGAndVNET "--enable-azure-service-mesh $autoscaler"

    az aks mesh enable-ingress-gateway -g $rg -n $aks --ingress-gateway-type external
}

createAKSNodePool(){
    az aks nodepool add -g $rg --cluster-name $aks --mode $nodePoolMode --node-count $minNodeCount --node-vm-size $sku -o $output $1
}

createAKSCluster() {
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $aksSubnet --query id -o tsv)
    identityResourceId=$(az identity show --resource-group $rg --name $aksUAMIdentity --query id -o tsv)

    echo "Creating AKS Cluster - ${aks}"
    az aks create -g $rg -n $aks -l $location --kubernetes-version $aksVersion --tier $aksTier --network-plugin $networkPlugin --network-policy $networkPolicy --network-dataplane $networkDataplane --vnet-subnet-id $aksSubnetId --service-cidr $serviceCidr --dns-service-ip $dnsIp --node-vm-size $sku --node-count $minNodeCount --vm-set-type $nodePoolType --outbound-type $outboundType --assign-identity $identityResourceId -o $output $1

    echo "AKS Cluster created successfully"
    echo "Download cluster credentials: az aks get-credentials --resource-group $rg --name $aks -f $KUBECONFIG"
}

createRgVnetUami() {
    createRG
    createVNET
    createUserAssignedManagedIdentity
}

createPublicAKSClusterWithRGAndVNET() {
    createRgVnetUami
    createAKSCluster "$1"
}

###########################################
########### Private AKS Cluster ###########
createPrivateAKSClusterAPIIntegration() {
    echo "Creating private AKS Cluster with API Vnet Integration"
    hasAPISubnet=true
    createRgVnetUami
    createAKSCluster "--enable-apiserver-vnet-integration --apiserver-subnet-id $apiSubnetId "
}

createAzureFirewall() {
    az network vnet subnet create -g $rg --vnet-name $vnet --name $firewallSubnet --address-prefix $firewallSubnetAddr -o $output
    
    echo "Creating Public IP"
    az network public-ip create -g $rg -n $firewallPublicIP -l $location --sku "Standard" -o $output

    echo "Creating Azure Firewall"
    az network firewall create -g $rg -n $firewall -l $location --enable-dns-proxy true -o $output

    az network firewall ip-config create -g $rg -f $firewall -n $firewallIPConfig --public-ip-address $firewallPublicIP --vnet-name $vnet -o $output

    echo "Creating Network rules in the firewall"
    az network firewall network-rule create -g $rg -f $firewall --collection-name 'aksfwnr' -n 'apiudp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$location" --destination-ports 1194 --action allow --priority 100 -o $output
    az network firewall network-rule create -g $rg -f $firewall --collection-name 'aksfwnr' -n 'apitcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$location" --destination-ports 9000 -o $output
    az network firewall network-rule create -g $rg -f $firewall --collection-name 'aksfwnr' -n 'time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123 -o $output

    echo "Creating Application rules in the firewall"
    az network firewall application-rule create -g $rg -f $firewall --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 100 -o $output
    az network firewall application-rule create -g $rg -f $firewall --collection-name 'aksfwarweb' -n 'storage' --source-addresses $aksSubnetAddr --protocols 'https=443' --target-fqdns '*.blob.storage.azure.net' '*.blob.core.windows.net' --action allow --priority 101 -o $output
    az network firewall application-rule create -g $rg -f $firewall --collection-name 'aksfwarweb' -n 'website' --source-addresses $aksSubnetAddr --protocols 'https=443' --target-fqdns 'ghcr.io' '*.docker.io' '*.docker.com' '*.githubusercontent.com' -o $output
}

createPrivateAKSClusterUDR() {
    echo "Starting creation of private AKS Cluster with User Defined Routing"
    minNodeCount=2
    outboundType="userDefinedRouting"

    createRgVnetUami
    createAzureFirewall

    fwPublicIP=$(az network public-ip show -g $rg -n $firewallPublicIP --query "ipAddress" -o tsv)
    fwPrivateIP=$(az network firewall show -g $rg -n $firewall --query "ipConfigurations[0].privateIPAddress" -o tsv)

    az network vnet update -g $rg --name $vnet --dns-servers $fwPrivateIP -o $output

    az network route-table create -g $rg -l $location --name $firewalRouteTable -o $output
    az network route-table route create -g $rg --name $firewallRouteName --route-table-name $firewalRouteTable --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $fwPrivateIP -o $output
    az network route-table route create -g $rg --name $firewallRouteInternet --route-table-name $firewalRouteTable --address-prefix $fwPublicIP/32 --next-hop-type Internet -o $output
    az network vnet subnet update -g $rg --vnet-name $vnet --name $aksSubnet --route-table $firewalRouteTable -o $output

    createPrivateAKSCluster
    createVM
}

createPrivateAKSCluster(){
    createAKSCluster "--ssh-access disabled --enable-private-cluster --disable-public-fqdn $1"
}

createPrivateAKSClusterWithRGAndVnet() {
    echo "Creating Private AKS Cluster"
    createRgVnetUami
    createPrivateAKSCluster "$1"
    createVM
}

###########################################
########## AutomaticAKS Cluster ###########
createPublicAutomaticAKSCluster(){
    echo "Creating Automatic AKS cluster"
    hasAPISubnet=true
    networkPolicy="cilium"
    networkDataplane="cilium"
    sku="Standard_D4ads_v6"

    createRgVnetUami
    createAKSCluster "--apiserver-subnet-id $apiSubnetId --sku automatic --node-provisioning-mode Auto "
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
    az vm create -g $rg -n $vm -l $location --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation -o $output
}

header() {
    echo "################################################################"
    echo "##                                                            ##"
    echo "##              Azure Kubernetes Service Helper               ##"
    echo "##                                                            ##"
    echo "################################################################"
}

listAKS(){
    mapfile -t clusters < <(az aks list -g $rg --only-show-errors -o tsv --query '[].[name]')

    size=${#clusters[@]}

    if [ $size -eq 0 ]; then
        echo "No AKS Clusters"
    else
        echo "################################################################"
        echo "##                        AKS Clusters                        ##"
        echo "################################################################"
        for i in $(seq 1 $size); do
            printf "## $(($i)) - ${clusters[i-1]}                                            ##\n"
        done
        echo "################################################################"
    fi
}

deleteAKS(){
    listAKS

    if [ $size -ne 0 ]; then

        read -p "Enter the cluster number: " index

        if [[ $index =~ ^[1-9]+$ ]] && (( $index <= $size )); then
            cluster=${clusters[index-1]}
            echo "Deleting the AKS cluster - $cluster"
            az aks delete --name $cluster --resource-group $rg
        else
            echo "Selected index ($index) is not valid."
        fi
    fi
}

deleteRG(){
    echo "Deleting $rg resource group"
    az group delete -n $rg --no-wait
}

main() {
    header
    echo "## 01 - Create AKS cluster from templates                     ##"
    echo "## 02 - Create custom AKS cluster                             ##"
    echo "## 03 - List AKS clusters                                     ##"
    echo "## 04 - Delete AKS cluster                                    ##"
    echo "## 05 - Delete resource group (aks-rg)                        ##"
    echo "################################################################"
    while read -p "Option: " opt; do

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
            listAKS
            break
            ;;
        4)
            deleteAKS
            break
            ;;
        5)
            deleteRG
            break
            ;;
        esac
    done
}

main
