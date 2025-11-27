#!/bin/bash
set -e 

k3_installation()
{
	echo "Installing K3..."
	sudo apt-get update
	sudo apt-get install -y curl 
	ufw disable
	
	curl -sfL https://get.k3s.io/ | sh
}

main()
{
	k3_installation
}

main
