
##### COMMANDS #####

## Test connectivity on loop
for i in $(seq 1 1 500); do echo -e "-------Iteration $i\n"; curl -v -m 3 <IP/FQDN> >> output.txt 2>&1; sleep 1; done

## Curl calls to API server and log to file
for i in $(seq 1 1 5); do echo -e "-------Iteration $i\n"; curl -vk -m 3 https://<api-fqdn> >> output.txt 2>&1; done


## Debug kubectl failures with extra verbose ##
kubectl --v=8 get pods 2>&1 | tee output.out
kubectl --v=8 get pods 2>&1 | tee /tmp/get-token.out | grep devicelogin

## Basic kubectl commands ##
kubectl get pods

kubectl run clipod --image=mcr.microsoft.com/azure-cli -it --restart=Never
kubectl exec -it clipod -- /bin/bash

kubectl run nginx --image=nginx -it --restart=Never

# Get Node logs
kubectl debug node/<node-name> --image=nginx
kubectl cp <pod-name>:/host/var/log/ /tmp/log

kubectl get --raw "/api/v1/nodes/<node>/proxy/logs/azure/cluster-provision-cse-output.log"

# SSH into node
#oneliner kubectl debug for manually mounting fileshare. Needs kubectl > 1.26
kubectl debug node/<node-name> -it  --image=mcr.microsoft.com/dotnet/runtime-deps:6.0 --profile=netadmin -- nsenter --target 1 --mount --uts --ipc --net --pid -- bash -l 
#mount option
fileshare=""
password=""
kubectl debug node/<node-name> -it  --image=mcr.microsoft.com/dotnet/runtime-deps:6.0 --profile=netadmin -- nsenter --target 1 --mount --uts --ipc --net --pid -- bash -l -c "mount -t cifs //$fileshare.file.core.windows.net/fileshare /mnt -o vers=3.0,username=fileshare,password=$password,dir_mode=0777,file_mode=0777,serverino"

#Invoke to run kubectl commands
az aks command invoke --resource-group <rg> --name <aks> --command "kubectl get nodes"

#API Calls azure cli
az rest --method get --url <url>

TOKEN=$(az account get-access-token -o tsv --query=accessToken)
curl -H "Authorization: Bearer $TOKEN" <url>

#TCPDUMP
kubectl debug node/<node-name> --imagemcr.microsoft.com/cbl-mariner/busybox:2.0 -- sh -xc "chroot /host tcpdump -nn -e -i any host 10.10.10.10"
kubectl cp <pod-name>:host/tmp/test.pcap test.pcap

#Get node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints --no-headers

#jq/jsonpath examples
kubectl get nodes -o json | jq '.items[].spec'
kubectl get nodes -o jsonpath='{.items[].spec.podCIDR}'

#Get the first node in the AKS cluster
kubectl get nodes | tail -n +2 | awk 'NR==1{print $1}'





#### Kubectl Apply commands ####

cat <<EOF | kubectl apply  -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nginx
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx
EOF
