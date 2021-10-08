#! /usr/bin/bash

sudo -K
sudo true

if hash brew 2>/dev/null; then
	echo "Homebrew is already installed!"
else
	echo "Installing Homebrew..."
	yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	exit_status=$?
	if [ $exit_status != 0 ]; then
		echo "Failed to install homebrew."
		exit 1
	fi
fi

brew bundle install --file=Brewfile --no-lock
brew cleanup

if [ -e ~/.oh-my-zsh ]; then
    echo "Oh My ZSH already installed"
else
    echo "Installing Oh My ZSH"
    RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    exit_status=$?
	if [ $exit_status != 0 ]; then
		echo "Failed to install Oh My ZSH."
		exit 1
	fi
fi

if [ -e ~/.dotfiles ]; then
    echo "dotfiles are already installed"
else
    curl -L http://bit.ly/tresni-dotfiles | bash
    exit_status=$?
	if [ $exit_status != 0 ]; then
		echo "Failed to install dotfiles."
		exit 1
	fi
fi

poetry install -n --no-root --no-dev
. .venv/bin/activate

ansible-playbook setup.yml