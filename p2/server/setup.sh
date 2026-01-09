#!/bin/bash
set -e 

k3_installation()
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

main()
{
	k3_installation
	install_controller
}

main "$@"
