#!/bin/bash

mapfile -t nodes < <(kubectl get nodes | tail -n +2 | awk '{print $1}')

for i in "${!nodes[@]}"; do
  printf "$i ${nodes[i]} \n"
done
        
read -p "Enter the node number: " NODE_INDEX
NODE=${nodes[NODE_INDEX]}

IMAGE="mcr.microsoft.com/dotnet/runtime-deps:6.0"
PROFILE="netadmin"
ARGS="nsenter --target 1 --mount --uts --ipc --net --pid -- bash -l"

kubectl debug node/$NODE -it  --image=$IMAGE --profile=$PROFILE -- $ARGS