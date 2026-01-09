#!/bin/bash
set -e 

CONTROLLER_IP="192.168.56.110"
TOKEN_FILE="/vagrant/k3s_token"

k3_installation()
{
	echo "Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y curl 
	ufw disable

	echo "alias k='kubectl'" >> ~/.bashrc
	source ~/.bashrc
}

install_controller()
{
	export K3S_NODE_IP=192.168.56.110
	echo "Installing k3s controller..."
	curl -sfL https://get.k3s.io/ | sh -s - \
		--node-ip 192.168.56.110 \
		--write-kubeconfig-mode 644
	
	echo "Waiting for token to be created..."
	while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
		sleep 2
	done

	echo "Saving token to shared folder..."
	sudo cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"
	alias k=kubectl
}

install_agent()
{
	export K3S_NODE_IP=192.168.56.111
	echo "Waiting for controller token..."
    while [ ! -f "$TOKEN_FILE" ]; do
		echo "Waiting for Token file"
        sleep 2
    done

    TOKEN=$(cat "$TOKEN_FILE")

	echo "Installing k3s agent..."
    curl -sfL https://get.k3s.io | \
        K3S_URL="https://${CONTROLLER_IP}:6443" \
        K3S_TOKEN="$TOKEN" \
        sh -s - \
		--node-ip 192.168.56.111
}

main()
{
	ROLE="$1"
	k3_installation
	if [ "$ROLE" = "controller" ]; then
		install_controller
	elif [ "$ROLE" = "agent" ]; then
		install_agent 
	fi
}

main "$@"
