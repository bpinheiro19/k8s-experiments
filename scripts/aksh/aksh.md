Bash script to automate the creation of AKS clusters.

## Installation:
```bash
wget https://github.com/bpinheiro19/k8s-experiments/raw/main/scripts/aksh/aksh.sh
chmod +x ./aksh.sh
sudo mv ./aksh.sh /usr/local/bin/aksh
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