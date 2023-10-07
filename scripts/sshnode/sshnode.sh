#!/bin/bash

mapfile -t nodes < <(kubectl get nodes | tail -n +2 | awk '{print $1}')

for i in "${!nodes[@]}"; do
  printf "$i ${nodes[i]} \n"
done
        
read -p "Enter the node number: " NODE_INDEX
NODE=${nodes[NODE_INDEX]}

IMAGE="alpine"
POD="$NODE-hostpath-mount"

OVERRIDES="$(cat <<EOT
{
  "spec": {
    "nodeName": "$NODE",
    "hostPID": true,
    "containers": [
      {
        "securityContext": {
          "privileged": true,
          "capabilities": {
               "add": [ "SYS_PTRACE" ]
          }
        },
        "image": "$IMAGE",
        "name": "nsenter",
        "stdin": true,
        "stdinOnce": true,
        "tty": true,
        "command": [ "nsenter", "--target", "1", "--mount", "--uts", "--ipc", "--net", "--pid", "--", "bash", "-l" ]
      }
    ]
  }
}
EOT
)"

kubectl run --rm --image $IMAGE --overrides="$OVERRIDES" -ti "$POD"
