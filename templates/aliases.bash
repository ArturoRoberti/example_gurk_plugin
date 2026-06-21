# Git
if command -v code >/dev/null 2>&1; then
	export GIT_EDITOR="code --wait"
fi

# Easy copy to clipboard - Usage: "command_with_output | clip [-s|--suppress]"
clip() {
	local xc='xclip -selection clipboard'
	if [[ " $* " == *" -s "* || " $* " == *" --suppress "* ]]; then
		# Suppressed: only send to clipboard
		$xc
	else
		# Normal: show + send to clipboard
		tee >($xc)
	fi
}

# CPU Temperature
alias cpu_temp='awk "{printf \"%.1f°C\n\", \$1/1000}" /sys/class/thermal/thermal_zone0/temp'

# Software upgrades
_software_upgrade() {
	upgrade_cmd="$1"
	package_manager="$2"
	package_manager_cmd="${3:-$package_manager}"

	if ! command -v "$package_manager_cmd" >/dev/null 2>&1; then
		echo "Package manager '$package_manager_cmd' not found. Skipping $package_manager upgrade."
		return
	fi

	echo "${BLUE}Upgrading $package_manager packages...${NC}"
	eval "$upgrade_cmd"
	echo -e "${GREEN}Done!${NC}\n"
}
software_upgrade() {
	# Get sudo permissions upfront
	sudo -v

	# apt
	_software_upgrade "sudo apt update && sudo apt upgrade -y" apt
	# snap
	_software_upgrade "sudo snap refresh" snap
	# flatpak
	_software_upgrade "flatpak update -y" flatpak
	# npm
	_software_upgrade "sudo npm update -g" npm
	# pipx
	_software_upgrade "pipx upgrade-all" pipx
}
