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
}

config_deps()
{
	sudo chmod +x kubectl
	sudo mv kubectl /usr/local/bin/

	sudo usermod -aG docker $USER
	newgrp docker

	echo "alias k='kubectl'" >> .bashrc
	source .bashrc
}

main()
{
	install_deps	
	config_deps
}

main "$@"
