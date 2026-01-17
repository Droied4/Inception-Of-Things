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
	sudo snap install microk8s --classic
//	curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
}

config_deps()
{
	sudo chmod +x kubectl
	sudo mv kubectl /usr/local/bin/

	sudo usermod -aG docker $USER
	newgrp docker
	
	microk8s enable dns && microk8s stop && microk8s start

	mkdir -p ~/.kube
	sudo k3d kubeconfig get mycluster > ~/.kube/config

	echo "alias k='kubectl'" >> .bashrc
	source .bashrc
}

create_cluster()
{
	echo "Creating cluster..."
	sudo k3d cluster create mycluster
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	// exponer el puerto	
	// kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443
	// conseguir contrasena y usuario admin
	// kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
}

create_application()
{
	echo "Creating application..."
	kubectl create namespace dev
//	argocd repo add https://github.com/tu-usuario/tu-repo.git

}

main()
{
	install_deps	
	config_deps
	create_cluster	
	create_application
}

main "$@"
