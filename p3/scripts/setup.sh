#!/bin/bash
set -e 

install_deps()
{
	echo "Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y curl 
    sudo apt-get install docker
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

	echo "alias k='kubectl'" >> .bashrc
	source .bashrc
}

main()
{
	install_deps	
}

main "$@"
