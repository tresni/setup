#! /usr/bin/env bash

set -e

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

if ! sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT 1" 2>/dev/null; then
	open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
	gum confirm "Does the current terminal have Full Disk Access?"
fi

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

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

set +e
xcode-select --install 2> /dev/null
set -e

brew bundle install --file=Brewfile
brew cleanup

if ! validate_keys; then
	osascript -e 'tell application "1Password" to launch'
	gum confirm "Are your SSH keys loaded and ready?"
fi

# From now on, we decide to do this or not at runtime.
RUN_MACOS=${RUN_MACOS:-no}
# `chezmoi status` returns 0 if the folder was created but git wasn't properly initialized
# So we check the git repo with a basic "are you a git repo?"
if chezmoi status > /dev/null && git -C "$(chezmoi source-path)" status > /dev/null; then
    echo "chezmoi has been initialized"
else
    if [ -e ~/.zshrc ]; then
		echo "backing up ~/.zshrc to ~/.zshrc_setup"
		mv ~/.zshrc ~/.zshrc_setup
	fi
	if ! chezmoi init --apply --ssh tresni; then
		echo "Failed to install dotfiles."
		exit 1
	fi
fi

uv sync --no-dev

uv run ansible-playbook setup.yml -K

# This is going to kill iTerm/Terminal/etc so ...
if [ "$RUN_MACOS" = "yes" ]; then
	~/.macos
fi

if ! plutil -extract "Accounts".0."AccountID" raw ~/Library/Preferences/MobileMeAccounts.plist &>/dev/null; then
	open x-apple.systempreferences:com.apple.AppleAccount-Settings.extension
	gum confirm "Are you signed into your apple account?"
fi

brew bundle install --file Brewfile.mas
