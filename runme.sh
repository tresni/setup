#! /usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

function confirm {
	if hash gum 2>/dev/null; then
		gum confirm "$1"
	else
		local reply
		read -r -p "$1 [y/N] " reply
		[[ "$reply" =~ ^[Yy] ]]
	fi
}

function validate_keys {
	# GitHub exits 1 even on success (no shell access), so look for the greeting
	ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com 2>&1 \
		| grep -q "successfully authenticated"
}

if ! sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT 1" &>/dev/null; then
	open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
	confirm "Does the current terminal have Full Disk Access?"
fi

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if ! pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto &>/dev/null; then
	sudo softwareupdate --install-rosetta --agree-to-license
fi

# Check the install location rather than PATH: /opt/homebrew/bin isn't on PATH
# until the playbook writes /etc/paths, so a rerun in a new shell can't see it.
if [ ! -x /opt/homebrew/bin/brew ]; then
	echo "Installing Homebrew..."
	if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
		echo "Failed to install homebrew."
		exit 1
	fi
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew bundle install --file=Brewfile
brew cleanup

until validate_keys; do
	osascript -e 'tell application "1Password" to launch'
	confirm "Is 1Password unlocked with the SSH agent enabled?"
done

while [ -z "$(op account list)" ]; do
	confirm "Have you enabled \"Integrate with 1Password CLI\" in the 1Password settings?"
done

# Run with RUN_MACOS=yes to apply ~/.macos at the end
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

if ! plutil -extract Accounts.0.AccountID raw ~/Library/Preferences/MobileMeAccounts.plist &>/dev/null; then
	open x-apple.systempreferences:com.apple.AppleAccount-Settings.extension
	confirm "Are you signed into your apple account?"
fi

brew bundle install --file Brewfile.mas
