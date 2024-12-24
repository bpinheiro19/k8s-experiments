Bash script to automate the creation of AKS clusters.

## Installation:
```bash
wget https://github.com/bpinheiro19/k8s-experiments/blob/dev/scripts/aksh/aksh.sh
chmod +x ./aksh
sudo mv ./aksh /usr/local/bin/aksh
```

## Help:
```bash
Create an AKS cluster
$ aksh create

Delete an AKS cluster
$ aksh delete

Delete the resource group
$ aksh delrg
```