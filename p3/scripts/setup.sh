#!/bin/bash

set -e

install_deps()
{
	echo "Installing dependencies..."
	sudo apt-get update
	if ! command -v curl > /dev/null;
	then	
		echo "Installing Curl..."
		sudo apt-get install -y curl
	fi
	if ! command -v docker > /dev/null;
	then	
		echo "Installing Docker..."
		sudo apt-get install -y docker.io
	fi
	if ! command -v k3d > /dev/null;
	then	
		echo "Installing k3d..."
		curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
		sudo apt-get install -y docker.io
	fi
	if ! command -v kubectl > /dev/null;
	then
		echo "Installing kubectl..."
		curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o $HOME/kubectl
		sudo chmod +x $HOME/kubectl
		sudo mv $HOME/kubectl /usr/local/bin
	fi
	if ! command -v argocd > /dev/null; 
	then
		echo "Installing argocd..."
		curl -sSL -o $HOME/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
		sudo chmod +x $HOME/argocd 
		sudo mv $HOME/argocd /usr/local/bin/
	fi
}

config_deps()
{
	echo "configuring environment"
	if ! id -nG "$USER" | grep -qw docker; 
	then 
		sudo usermod -aG docker "$USER"
		newgrp docker
	fi
	
	if ! grep -q "alias k='kubectl'" "$HOME/.bashrc" > /dev/null;
	then
		echo "alias k='kubectl'" >> "$HOME/.bashrc"
		echo "alias added to .bashrc"
		source "$HOME/.bashrc"
	fi
}

create_cluster()
{
	cluster_name=mycluster
	namespace_name=argocd
	echo "Creating cluster..."
	if ! k3d cluster list | grep -qw "$cluster_name"; 
	then
		sudo k3d cluster create "$cluster_name"
	fi
	if [ ! -d $HOME/.kube ];
	then
		mkdir -p $HOME/.kube
	fi
	if [ ! -f $HOME/.kube/config ];
	then
		echo "Creating config file"
		sudo k3d kubeconfig get "$cluster_name" > $HOME/.kube/config
		chown -R $USER:$USER $HOME/.kube
	fi

	if ! kubectl get namespaces | grep -qw "$namespace_name";
	then
		echo "Creating namespace for $namespace_name"
		kubectl create namespace "$namespace_name"
		kubectl apply --server-side -n "$namespace_name" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
		kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	fi

	kubectl -n argocd wait --for=condition=available deploy --all 
	kubectl -n argocd wait --for=condition=Ready pod --all 
	echo "PODS AVAILABLE!"

	if ! ps aux | grep -qw "kubectl port-forward svc/argocd-server -n --address 0.0.0.0 8080:443"; 
	then
		echo "running proccess port-forward"
		nohup kubectl port-forward svc/argocd-server -n "$namespace_name" --address 0.0.0.0 8080:443 > /dev/null &
	fi
	until curl -k https://localhost:8080/healthz 2>/dev/null; do
		echo "waiting for connection to localhost:8080"
  		sleep 2
	done
}

create_application()
{
	REPO="https://github.com/Droied4/deordone-argoCD"
	namespace_name=dev

	echo "Creating application..."
	if ! kubectl get namespaces | grep -qw "$namespace_name";
	then
		kubectl create namespace "$namespace_name"
		#Conseguir contrasena del usuario admin
		PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
		argocd login localhost:8080 --username admin --password "$PASS" --insecure
		argocd repo add $REPO
	fi
	kubectl apply -n "$namespace_name" -f https://raw.githubusercontent.com/Droied4/deordone-argoCD/main/install.yml
	
	kubectl apply -f $HOME/iot/p3/conf/argo-conf.yml 
	kubectl apply -f $HOME/iot/p3/conf/ingress.yml 
	echo "try $PASS"
}

main()
{
	install_deps	
	config_deps
	create_cluster	
	create_application
}

main "$@"
