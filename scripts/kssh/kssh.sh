#!/bin/bash

mapfile -t nodes < <(kubectl get nodes | tail -n +2 | awk '{print $1}')

size=${#nodes[@]}

if [ $size -eq 0 ]; then
    echo "No Nodes available"
else
  for i in $(seq 1 $size); do
    printf "$(($i)) - ${nodes[i-1]} \n"
  done

  read -p "Enter the node number: " index

  if [ -z $index ] || ( [[ $index =~ ^[1-9]+$ ]] && (( $index <= size ))); then
    NODE=${nodes[index-1]}
    kubectl debug node/$NODE -it --image=mcr.microsoft.com/azurelinux/busybox:1.36 --profile=sysadmin -- sh -xc "chroot /host"
  else
    echo "$index is not a valid index."
  fi 
fi