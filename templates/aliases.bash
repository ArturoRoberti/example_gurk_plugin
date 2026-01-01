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
