#!/bin/bash

set -e

install_deps()
{
	echo "Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y curl
	sudo apt-get install -y docker.io
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
}

config_deps()
{
	sudo chmod +x kubectl
	sudo mv kubectl /usr/local/bin/

	sudo chmod +x argocd 
	sudo mv argocd /usr/local/bin/

	sudo usermod -aG docker $USER
	newgrp docker
	
	#mkdir -p /home/vagrant/.kube

	echo "alias k='kubectl'" >> ~.bashrc
	source .bashrc
}

create_cluster()
{
	echo "Creating cluster..."
	sudo k3d cluster create mycluster
	sudo k3d kubeconfig get mycluster > /home/vagrant/.kube/config
	chown -R vagrant:vagrant /home/vagrant/.kube
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	#hay un timeout aqui porque se tarda demasiado no se si por la red o falta de recursos.
	kubectl -n argocd wait --for=condition=available deploy --all 
	kubectl -n argocd wait --for=condition=Ready pod --all 
	nohup kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443 > /dev/null &
	until curl -k https://localhost:8080/healthz 2>/dev/null; do
  		sleep 2
	done
}

create_application()
{
	echo "Creating application..."
	REPO="https://github.com/Droied4/deordone-argoCD"
	kubectl create namespace dev
#	Conseguir contrasena del usuario admin
	PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	export PASS=$PASS
	argocd login localhost:8080 --username admin --password "$PASS" --insecure
	argocd repo add $REPO
	kubectl apply -n dev -f https://raw.githubusercontent.com/Droied4/deordone-argoCD/main/install.yml
	kubectl apply -f ../conf/argo-conf.yml 
	kubectl apply -f ../conf/ingress.yml 
}

main()
{
	install_deps	
	config_deps
	create_cluster	
	create_application
}

main "$@"
