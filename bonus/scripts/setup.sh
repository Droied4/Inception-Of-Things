#!/bin/bash

set -e

install_deps()
{
	echo "Installing dependencies..."
	#sudo apt-get update

	if ! command -v curl > /dev/null;
	then	
		echo "Installing Curl..."
		sudo apt-get install -y curl
	fi
	if ! command -v gpg > /dev/null;
	then
		echo "Installing Gpg..."
		sudo apt-get install -y gpg 
	fi
	if ! dpkg -l grep apt-transport-https > /dev/null;
	then
		echo "Installing apt-transport-https..."
		sudo apt-get install -y apt-transport-https 
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
	if ! command -v helm > /dev/null;
	then
		echo "Installing helm..."
		curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
		echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
		sudo apt update
		sudo apt install helm
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
}

create_ns_gitlab()
{
	namespace_name=gitlab

	if ! kubectl get namespaces | grep -qw "$namespace_name";
	then
		echo "Creating namespace for $namespace_name"
		kubectl create namespace "$namespace_name"

		helm repo add gitlab https://charts.gitlab.io/
		helm repo update

		helm upgrade --install gitlab gitlab/gitlab \
			--namespace gitlab \
			-f $HOME/iot/bonus/conf/values.yml \
			--timeout 20m

		kubectl get pods -n gitlab

		kubectl get secret gitlab-gitlab-initial-root-password \
			-n gitlab \
			-o jsonpath="{.data.password}" | base64 --decode ; echo
	fi
}

create_ns_argocd()
{
	namespace_name=argocd
	if ! kubectl get namespaces | grep -qw "$namespace_name";
	then
		echo "Creating namespace for $namespace_name"
		kubectl create namespace "$namespace_name"

		helm repo add argo https://argoproj.github.io/argo-helm
		helm repo update

		helm upgrade --install argocd argo/argo-cd \
			--namespace argocd

		#kubectl get secret argocd-initial-admin-secret \
		#-n argocd \
		#-o jsonpath="{.data.password}" | base64 --decode ; echo

	fi
}

create_ns_dev()
{
	REPO="https://github.com/Droied4/deordone-argoCD"
	namespace_name=dev

	echo "Creating application..."
	if ! kubectl get namespaces | grep -qw "$namespace_name";
	then
		kubectl create namespace "$namespace_name"
		#Conseguir contrasena del usuario admin
		nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 > /tmp/argocd-portforward.log 2>&1 &
		PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
		argocd login localhost:8080 --username admin --password "$PASS" --insecure
		argocd repo add $REPO
	fi
	kubectl apply -n "$namespace_name" -f https://raw.githubusercontent.com/Droied4/deordone-argoCD/main/install.yml
	
	kubectl apply -f $HOME/iot/bonus/conf/argo-conf.yml 
	kubectl apply -f $HOME/iot/bonus/conf/ingress.yml 
	echo "try $PASS"
}

main()
{
	if [ "$1" = "run" ]; then	
		kubectl port-forward svc/argocd-server -n argocd 8181:443 &
		kubectl port-forward svc/gitlab-webservice-default -n gitlab 8443:8181 &
	else
	install_deps	
	config_deps
	create_cluster	
	create_ns_gitlab
	create_ns_argocd
	create_ns_dev

	fi
}

main "$@"
