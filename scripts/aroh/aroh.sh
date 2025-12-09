#!/bin/bash

date="$(date +%s)"
rg="aro-rg"
location="swedencentral"

#ARO
aro="aro$date"
version="4.18.26"
serviceCidr=10.0.248.0/22
masterSku="Standard_D8s_v3"
workerSku="Standard_D4s_v3"
nodeCount=3

#VNET
vnet="aro-vnet$date"
vnetAddr=10.0.0.0/16
masterSubnet="master"
workerSubnet="worker"
masterSubnetAddr=10.0.240.0/23
workerSubnetAddr=10.0.244.0/23

#SP
spName="aro-cluster-SP-$date"

#VM
vm="aksVM"
vmImage="Ubuntu2204"
adminUser="azureuser"
sshLocation="~/.ssh/id_rsa.pub"


register(){
    az provider register --namespace 'Microsoft.RedHatOpenShift' --wait
    az provider register --namespace 'Microsoft.Compute' --wait
    az provider register --namespace 'Microsoft.Storage' --wait
    az provider register --namespace 'Microsoft.Authorization' --wait
    az feature register --namespace Microsoft.RedHatOpenShift --name preview
}

aro() {
    header
    echo "## 01 - Public Azure Red Hat OpenShift Cluster                    ##"
    echo "## 02 - Azure Red Hat OpenShift Cluster with Managed Identities   ##"
    echo "## 03 - Private Azure Red Hat OpenShift Cluster                   ##"
    echo "####################################################################"

    while read -p "Option: " opt; do

        case $opt in
        1)
            register
            createPublicAROCluster
            break
            ;;
        2)  
            register
            createPublicAROClusterManagedIdentities
            break
            ;;
        3)
            register
            createPrivateAROCluster
            break
            ;;
        esac
    done
}

###############################################
############## Resource Group #################
createRG(){
    echo "Creating the resource group"
    az group create -n $rg -l $location
}

###############################################
############# Virtual Network #################
createVNET(){
    echo "Creating vnet and subnet"
    az network vnet create -g $rg -n $vnet --address-prefix $vnetAddr

    az network vnet subnet create -g $rg -n $masterSubnet --vnet-name  $vnet --address-prefixes $masterSubnetAddr
    az network vnet subnet create  -g $rg -n $workerSubnet --vnet-name  $vnet --address-prefixes $workerSubnetAddr
}

###############################################
################# Identities ##################
createIdentities(){
    echo "Creating user assigned identities"
    az identity create --resource-group $rg --name aro-cluster
    az identity create --resource-group $rg --name cloud-controller-manager
    az identity create --resource-group $rg --name ingress
    az identity create --resource-group $rg --name machine-api
    az identity create --resource-group $rg --name disk-csi-driver
    az identity create --resource-group $rg --name cloud-network-config
    az identity create --resource-group $rg --name image-registry
    az identity create --resource-group $rg --name file-csi-driver
    az identity create --resource-group $rg --name aro-operator
}

assignPermissions(){
    echo "Assigning permissions to the identities"
    SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-operator"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-controller-manager"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ingress"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/machine-api"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/disk-csi-driver"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cloud-network-config"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/image-registry"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-cluster --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/file-csi-driver"

    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name cloud-controller-manager --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/master"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name cloud-controller-manager --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/worker"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name ingress --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/master"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name ingress --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/worker"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name machine-api --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/master"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name machine-api --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/worker"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name cloud-network-config --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/be7a6435-15ae-4171-8f30-4a343eff9e8f" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name file-csi-driver --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/0d7aedc0-15fd-4a67-a412-efad370c947e" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name image-registry --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/8b32b316-c2f5-4ddf-b05b-83dacd2d08b5" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-operator --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/master"
    az role assignment create --assignee-object-id "$(az identity show --resource-group $rg --name aro-operator --query principalId -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/worker"
    
    az role assignment create --assignee-object-id "$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query '[0].id' -o tsv)" --assignee-principal-type ServicePrincipal --role "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet"
}

###############################################
########### Azure RedHat Openshift ############

createAROClusterWithRGAndVNET() {
    createRG
    createVNET
    createAROCluster "$1"
}

createAROCluster(){
    echo "Creating ARO cluster"
    az aro create --resource-group $rg --name  $aro --version $version --vnet $vnet --service-cidr $serviceCidr --master-subnet $masterSubnet --worker-subnet $workerSubnet --master-vm-size $masterSku --worker-vm-size $workerSku $1
}

createPublicCluster() {
    createRG
    createVNET

    masterSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $masterSubnet --query id -o tsv)
    workerSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $workerSubnet --query id -o tsv)

    AZ_SUB_ID=$(az account show --query id -o tsv) 

    PASSWORD=$(az ad sp create-for-rbac --name $spName  --role contributor --scopes "/subscriptions/${AZ_SUB_ID}/resourceGroups/${rg}" --query "password" --output tsv)
    appID=$(az ad sp list --display-name $spName --query "[].appId" --output tsv)

    echo "Creating ARO cluster"
    az aro create -g $rg -n $aro --vnet  $vnet --service-cidr $serviceCidr --master-subnet $masterSubnet --worker-subnet $workerSubnet --client-id $appID --client-secret $PASSWORD # --master-vm-size $masterSku --worker-vm-size $workerSku --worker-count $nodeCount 
    
    az aro list-credentials -g $rg -n $aro
    az aro show -g $rg -n $aro --query "consoleProfile.url" -o tsv
  
    apiServer=$(az aro show -g $rg -n $aro --query apiserverProfile.url -o tsv)
    kubeAdminPassword=$( az aro list-credentials -g $rg -n $aro --query kubeadminPassword -o tsv)
    echo "oc login $apiServer -u kubeadmin -p $kubeAdminPassword"
}

## Preview Feature ##
createPublicAROClusterManagedIdentities(){
    createRG
    createVNET
    createIdentities
    assignPermissions

    createAROCluster "--enable-managed-identity --assign-cluster-identity aro-cluster --assign-platform-workload-identity file-csi-driver file-csi-driver --assign-platform-workload-identity cloud-controller-manager cloud-controller-manager --assign-platform-workload-identity ingress ingress --assign-platform-workload-identity image-registry image-registry --assign-platform-workload-identity machine-api machine-api --assign-platform-workload-identity cloud-network-config cloud-network-config --assign-platform-workload-identity aro-operator aro-operator --assign-platform-workload-identity disk-csi-driver disk-csi-driver"
}

createPrivateCluster() {
    createRG
    createVNET

    masterSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $masterSubnet --query id -o tsv)
    workerSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $workerSubnet --query id -o tsv)

    echo "Creating ARO cluster"
    az aro create -g $rg -n $aro --vnet  $vnet --master-subnet $masterSubnet --worker-subnet $workerSubnet --service-cidr $serviceCidr --apiserver-visibility Private --ingress-visibility Private # --master-vm-size $masterSku --worker-vm-size $workerSku --worker-count $nodeCount
   
    createVM
}

createVM(){
    echo "Creating Azure VM in the same vnet"
    az vm create -g $rg -n $vm --image $vmImage --vnet-name $vnet --admin-username $adminUser --ssh-key-value $sshLocation
}

header() {
    echo "################################################################"
    echo "##                                                            ##"
    echo "##              Azure RedHat Openshift Helper                 ##"
    echo "##                                                            ##"
    echo "################################################################"
}

main() {
    header
    echo "## 01 - Create Azure RedHat Openshift Cluster                  ##"
    echo "## 02 - List Azure RedHat Openshift Clusters                   ##"
    echo "## 03 - Delete Azure RedHat Openshift Cluster                  ##"
    echo "## 04 - Delete resource group (aro-rg)                         ##"
    echo "################################################################"
    while read -p "Option: " opt; do

        case $opt in
        1)
            aro
            break
            ;;
        2)
            mapfile -t clusters < <(az aro list -g $rg --only-show-errors -o tsv --query '[].[name]')

            if [ ${#clusters[@]} -eq 0 ]; then
                echo "No Azure RedHat Openshift Clusters"
            else
                echo "################################################################"
                echo "##                Azure RedHat Openshift Clusters                   ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                      ##\n"
                done
                echo "################################################################"
            fi

            break
            ;;
        3)
            mapfile -t clusters < <(az aro list -g $rg --only-show-errors -o tsv --query '[].[name]')

            size=${#clusters[@]}

            if [ $size -eq 0 ]; then
                echo "No Azure RedHat Openshift Clusters"
            else
                echo "################################################################"
                echo "##                Azure RedHat Openshift Clusters           ##"
                echo "################################################################"
                for i in "${!clusters[@]}"; do
                    printf "## $(($i + 1)) - ${clusters[i]}                                      ##\n"
                done
                echo "################################################################"

                read -p "Enter the cluster number: " index

                if [[ $index =~ ^[0-9]+$ ]] && (( $index <= size )); then
                  cluster=${clusters[index-1]}
                  echo "Deleting the Azure RedHat Openshift Cluster - $cluster"
                  az aro delete --name $cluster --resource-group $rg --yes
                else
                  echo "$index is NOT a valid index."
                fi                
            fi

            break
            ;;
        4)
            echo "Deleting the aro-rg resource group"
            az group delete -n $rg --no-wait
            break
            ;;
        esac
    done
}

main $@