#! /usr/bin/env bash

function validate_keys {
	LOADED=$(ssh-add -ql)
	if ! [ "$?" -eq "0" ]; then
		return 1
	fi
	KEYS=$(ssh-keygen -lf <(curl -s https://github.com/tresni.keys) 2> /dev/null | awk '{ print $2 }')
	if [ -z "$KEYS" ]; then
		return 1
	fi
	for key in "${KEYS[@]}"; do
		if grep -q "$key" <(echo "$LOADED"); then
			return 0
		fi
	done
	return 1
}

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if ! validate_keys; then
	echo "Load your SSH keys first"
	exit 1
fi

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

BREW_PATH=/usr/local/bin/brew

if ! [ -e "$BREW_PATH" ]; then
	BREW_PATH=/opt/homebrew/bin/brew
fi


"$BREW_PATH" bundle install --file=Brewfile --no-lock
"$BREW_PATH" cleanup

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
    if [ -e ~/.zshrc]; then
		echo "backing up ~/.zshrc to ~/.zshrc_setup"
		mv ~/.zshrc ~/.zshrc_setup
	fi
    curl -L http://bit.ly/tresni-dotfiles | bash
    exit_status=$?
	if [ $exit_status != 0 ]; then
		echo "Failed to install dotfiles."
		exit 1
	fi
    echo "Running ~/.macos"
    ~/.macos
fi

poetry install -n --no-root --no-dev
. .venv/bin/activate
ansible-playbook setup.yml

# We should be all set to load into zsh
exec /usr/bin/env zsh -l
