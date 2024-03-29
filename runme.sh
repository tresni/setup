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

# Check if Rossetta is needed/installed
if [ "$CPUTYPE" = "arm64" ] && ! [ -e "/usr/libexec/rosetta" ]; then
	sudo softwareupdate --install-rosetta --agree-to-license
fi

if hash brew 2>/dev/null; then
	echo "Homebrew is already installed!"
else
	echo "Installing Homebrew..."
	if ! yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ; then
		echo "Failed to install homebrew."
		exit 1
	fi
	eval "$(/usr/local/bin/brew shellenv 2> /dev/null || /opt/homebrew/bin/brew shellenv)"
fi

brew bundle install --file=Brewfile --no-lock
brew cleanup

if [ -e ~/.oh-my-zsh ]; then
    echo "Oh My ZSH already installed"
else
    echo "Installing Oh My ZSH"
	if ! RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" ; then
		echo "Failed to install Oh My ZSH."
		exit 1
	fi
fi

RUN_MACOS=${RUN_MACOS:-no}
if chezmoi status > /dev/null ; then
    echo "chezmoi has been initialized"
else
    if [ -e ~/.zshrc ]; then
		echo "backing up ~/.zshrc to ~/.zshrc_setup"
		mv ~/.zshrc ~/.zshrc_setup
	fi
	if ! chezmoi init --apply tresni; then
		echo "Failed to install dotfiles."
		exit 1
	fi
	RUN_MACOS=yes
fi

poetry install -n --no-root --only main

# shellcheck source=/dev/null
. ./.venv/bin/activate

ansible-playbook setup.yml

# This is going to kill iTerm/Terminal/etc so ...
if [ $RUN_MACOS = "yes" ]; then
	~/.macos
fi
