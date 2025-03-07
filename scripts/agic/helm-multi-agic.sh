#!/bin/bash

rg="aks-agic-rg"
location="uksouth"
aks="aks-agic"

namespaceOne="ingress-azure-one"
namespaceTwo="ingress-azure-two"

appGwOne="myApplicationGatewayOne"
appGwTwo="myApplicationGatewayTwo"

ipNameOne="myPublicIpOne"
ipNameTwo="myPublicIpTwo"

identityNameOne="agic-identity-one"
identityNameTwo="agic-identity-two"

vnetName="agic-vnet"
aksSubnet="aks-subnet"
appgwSubnetOne="appgw-subnet-one"
appgwSubnetTwo="appgw-subnet-two"
vnetAddr=10.0.0.0/16
aksSubnetAddr=10.0.240.0/24
appGwSubnetAddrOne=10.0.0.0/24
appGwSubnetAddrTwo=10.0.1.0/24

createRG() {
    echo "Create resource group"
    az group create --name $rg -l $location
}

createVnet() {
    echo "Create vnet"
    az network vnet create -g $rg -n $vnetName --address-prefix $vnetAddr --subnet-name $aksSubnet --subnet-prefixes $aksSubnetAddr -l $location
    az network vnet subnet create --resource-group $rg --vnet-name $vnetName --name $appgwSubnetOne --address-prefixes $appGwSubnetAddrOne
    az network vnet subnet create --resource-group $rg --vnet-name $vnetName --name $appgwSubnetTwo --address-prefixes $appGwSubnetAddrTwo
}

createAppGw() {
    echo "Create public IP"
    az network public-ip create --name $ipNameOne --resource-group $rg --allocation-method Static --sku Standard
    az network public-ip create --name $ipNameTwo --resource-group $rg --allocation-method Static --sku Standard

    echo "Create Application Gateway"
    az network application-gateway create --name $appGwOne --resource-group $rg --sku Standard_v2 --public-ip-address $ipNameOne --vnet-name $vnetName --subnet $appgwSubnetOne --priority 100
    az network application-gateway create --name $appGwTwo --resource-group $rg --sku Standard_v2 --public-ip-address $ipNameTwo --vnet-name $vnetName --subnet $appgwSubnetTwo --priority 100

    appGwOneId=$(az network application-gateway show --name $appGwOne --resource-group $rg -o tsv --query "id")
    appGwTwoId=$(az network application-gateway show --name $appGwTwo --resource-group $rg -o tsv --query "id")
}

createAKSCluster() {
    aksSubnetId=$(az network vnet subnet show -g $rg --vnet-name $vnetName -n $aksSubnet --query id -o tsv)

    echo "Create AKS"
    az aks create -g $rg -n $aks -l $location --network-plugin azure --vnet-subnet-id $aksSubnetId --service-cidr 10.0.242.0/24 --dns-service-ip 10.0.242.10 --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys
}

createManagedIdentity() {
    
    echo "Creating identity $identityNameOne in resource group $rg"
    az identity create --resource-group $rg --name $identityNameOne
    identityPrincipalOneId="$(az identity show -g $rg -n $identityNameOne --query principalId -otsv)"
    identityClientOneId="$(az identity show -g $rg -n $identityNameOne --query clientId -otsv)"

    echo "Creating identity $identityNameTwo in resource group $rg"
    az identity create --resource-group $rg --name $identityNameTwo
    identityPrincipalTwoId="$(az identity show -g $rg -n $identityNameTwo --query principalId -otsv)"
    identityClientTwoId="$(az identity show -g $rg -n $identityNameTwo --query clientId -otsv)"

    echo "Waiting 60 seconds to allow for replication of the identity..."
    sleep 60

    echo "Set up federation with AKS OIDC issuer"
    aks_oidc_issuer="$(az aks show -n "$aks" -g "$rg" --query "oidcIssuerProfile.issuerUrl" -o tsv)"

    az identity federated-credential create --name "agic-one" --identity-name "$identityNameOne" --resource-group $rg --issuer "$aks_oidc_issuer" --subject "system:serviceaccount:$namespaceOne:$namespaceOne"

    az identity federated-credential create --name "agic-two" --identity-name "$identityNameTwo" --resource-group $rg --issuer "$aks_oidc_issuer" --subject "system:serviceaccount:$namespaceTwo:$namespaceTwo"

    resourceGroupId=$(az group show --name $rg --query id -otsv)
    nodeResourceGroup=$(az aks show -n $aks -g $rg -o tsv --query "nodeResourceGroup")
    nodeResourceGroupId=$(az group show --name $nodeResourceGroup --query id -otsv)
    appGwSubnetOneId=$(az network vnet subnet show -g $rg --vnet-name $vnetName -n $appgwSubnetOne --query id -o tsv)
    appGwSubnetTwoId=$(az network vnet subnet show -g $rg --vnet-name $vnetName -n $appgwSubnetTwo --query id -o tsv)

    echo "Apply role assignments to AGIC identities"
    az role assignment create --assignee-object-id $identityPrincipalOneId --assignee-principal-type ServicePrincipal --scope $resourceGroupId --role "Reader"
    az role assignment create --assignee-object-id $identityPrincipalOneId --assignee-principal-type ServicePrincipal --scope $nodeResourceGroupId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalOneId --assignee-principal-type ServicePrincipal --scope $appGwOneId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalOneId --assignee-principal-type ServicePrincipal --scope $appGwSubnetOneId --role "Network Contributor"

    az role assignment create --assignee-object-id $identityPrincipalTwoId --assignee-principal-type ServicePrincipal --scope $resourceGroupId --role "Reader"
    az role assignment create --assignee-object-id $identityPrincipalTwoId --assignee-principal-type ServicePrincipal --scope $nodeResourceGroupId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalTwoId --assignee-principal-type ServicePrincipal --scope $appGwTwoId --role "Contributor"
    az role assignment create --assignee-object-id $identityPrincipalTwoId --assignee-principal-type ServicePrincipal --scope $appGwSubnetTwoId --role "Network Contributor"
}

installAGIC() {
    az aks get-credentials --resource-group $rg --name $aks --overwrite-existing

    kubectl create ns $namespaceOne
    kubectl create ns $namespaceTwo

    helm install ingress-azure-one oci://mcr.microsoft.com/azure-application-gateway/charts/ingress-azure --namespace ingress-azure-one --version 1.8.0 --set appgw.applicationGatewayID=$appGwOneId \
    --set armAuth.type=workloadIdentity --set armAuth.identityClientID=$identityClientOneId --set rbac.enabled=true --set kubernetes.watchNamespace=ingress-azure-one --set kubernetes.ingressClassResource.name=azure-application-gateway-one

    helm install ingress-azure-two oci://mcr.microsoft.com/azure-application-gateway/charts/ingress-azure  --namespace ingress-azure-two --version 1.8.0 --set appgw.applicationGatewayID=$appGwTwoId \
    --set armAuth.type=workloadIdentity --set armAuth.identityClientID=$identityClientTwoId --set rbac.enabled=true --set kubernetes.watchNamespace=ingress-azure-two --set kubernetes.ingressClassResource.name=azure-application-gateway-two
}

applyYamls(){
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aspnetapp
  namespace: $1
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
  namespace: $1
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
  namespace: $1
spec:
  ingressClassName: $2
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
    applyYamls ingress-azure-one azure-application-gateway-one
    applyYamls ingress-azure-two azure-application-gateway-two
}

main