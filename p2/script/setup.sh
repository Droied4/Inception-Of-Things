#!/bin/bash
set -e 

install_deps()
{
	echo "Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y curl 
	ufw disable

	echo "alias k='kubectl'" >> .bashrc
	source .bashrc
}

install_controller()
{
	export K3S_NODE_IP=192.168.56.110
	echo "Installing k3s controller..."
	curl -sfL https://get.k3s.io/ | sh -s - \
		--node-ip 192.168.56.110 \
		--write-kubeconfig-mode 644
}

init_manifests()
{
	kubectl apply -f /home/vagrant/config-map.yml
	kubectl apply -f /home/vagrant/services.yml
	kubectl apply -f /home/vagrant/ingress.yml
	kubectl apply -f /home/vagrant/deployments.yml
}

main()
{
	install_deps	
	install_controller
	init_manifests
}

main "$@"
