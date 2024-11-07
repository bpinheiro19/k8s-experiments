
echo "Creating Nginx Ingress Controller"
echo "Creating dev Namespace"
kubectl create namespace dev

echo "Deploying nginx ingress controller"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

echo "Creating the deployment"
kubectl apply -f deployment.yaml 

echo "Creating the service"
kubectl apply -f service.yaml    

echo "Creating the ingress"
kubectl apply -f ingress.yaml    

echo "Finished"
kubectl get ing,deploy,svc -n dev