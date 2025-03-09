#!/bin/bash

rg="aks-agic-rg"
location="uksouth"
aks="aks-agic"

appGw="myApplicationGateway"
ipName="myPublicIp"

identityName="agic-identity"
namespace="ingress"

vnetName="agic-vnet"
aksSubnet="aks-subnet"
appgwSubnet="appgw-subnet"
vnetAddr=10.0.0.0/16
aksSubnetAddr=10.0.240.0/24
appGwSubnetAddr=10.0.0.0/24

createRG() {
    echo "Create resource group"
    az group create --name $rg -l $location
}

createVnet() {
    echo "Create vnet"
    az network vnet create -g $rg -n $vnetName --address-prefix $vnetAddr --subnet-name $aksSubnet --subnet-prefixes $aksSubnetAddr -l $location
    az network vnet subnet create --resource-group $rg --vnet-name $vnetName --name $appgwSubnet --address-prefixes $appGwSubnetAddr
}

createAppGw() {
    echo "Create public IP"
    az network public-ip create --name $ipName --resource-group $rg --allocation-method Static --sku Standard

    echo "Create Application Gateway"
    az network application-gateway create --name $appGw --resource-group $rg --sku Standard_v2 --public-ip-address $ipName --vnet-name $vnetName --subnet $appgwSubnet --priority 100
    
    appgwId=$(az network application-gateway show --name $appGw --resource-group $rg -o tsv --query "id")
}

createAKSCluster() {
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnetName -n $aksSubnet --query id -o tsv)

    echo "Create AKS"
    az aks create -g $rg -n $aks -l $location --network-plugin azure --vnet-subnet-id $aksSubnetId --service-cidr 10.0.242.0/24 --dns-service-ip 10.0.242.10 --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys
}

createManagedIdentity() {
    
    echo "Creating identity $identityName in resource group $rg"
    az identity create --resource-group $rg --name $identityName
    identityPrincipalId="$(az identity show -g $rg -n $identityName --query principalId -otsv)"
    identityClientId="$(az identity show -g $rg -n $identityName --query clientId -otsv)"

    echo "Waiting 60 seconds to allow for replication of the identity..."
    sleep 60

    echo "Set up federation with AKS OIDC issuer"
    aks_oidc_issuer="$(az aks show -n "$aks" -g "$rg" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
    az identity federated-credential create --name "agic" \
        --identity-name "$identityName" \
        --resource-group $rg \
        --issuer "$aks_oidc_issuer" \
        --subject "system:serviceaccount:$namespace:ingress-azure"

    resourceGroupId=$(az group show --name $rg --query id -otsv)
    nodeResourceGroup=$(az aks show -n $aks -g $rg -o tsv --query "nodeResourceGroup")
    nodeResourceGroupId=$(az group show --name $nodeResourceGroup --query id -otsv)
    appGwSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnetName -n $appgwSubnet --query id -o tsv)

    echo "Apply role assignments to AGIC identity"
    az role assignment create --assignee-object-id $identityPrincipalId --assignee-principal-type ServicePrincipal --scope $resourceGroupId --role "Reader"
    az role assignment create --assignee-object-id $identityPrincipalId --assignee-principal-type ServicePrincipal --scope $nodeResourceGroupId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalId --assignee-principal-type ServicePrincipal --scope $appgwId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalId --assignee-principal-type ServicePrincipal --scope $appGwSubnetId --role "Network Contributor"
}

installAGIC() {
    az aks get-credentials --resource-group $rg --name $aks --overwrite-existing

    kubectl create ns $namespace

    helm install ingress-azure oci://mcr.microsoft.com/azure-application-gateway/charts/ingress-azure --namespace $namespace --version 1.8.0 --set appgw.applicationGatewayID=$appgwId \
    --set armAuth.type=workloadIdentity --set armAuth.identityClientID=$identityClientId --set rbac.enabled=true
}

applyYamls(){
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aspnetapp
  namespace: $namespace
  labels:
    app: aspnetapp
spec:
  containers:
  - image: "mcr.microsoft.com/dotnet/samples:aspnetapp"
    name: aspnetapp-image
    ports:
    - containerPort: 8080
      protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: aspnetapp
  namespace: $namespace
spec:
  selector:
    app: aspnetapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aspnetapp
  namespace: $namespace
spec:
  ingressClassName: azure-application-gateway
  rules:
  - http:
      paths:
      - path: /
        backend:
          service:
            name: aspnetapp
            port:
              number: 80
        pathType: Exact
EOF
}

main() {
    createRG
    createVnet
    createAppGw
    createAKSCluster
    createManagedIdentity
    installAGIC
    applyYamls
}

main
