# ~/.config/git/git-prompt.sh
#
# Git for Windows sources this file from /etc/profile.d/git-prompt.sh INSTEAD of
# its built-in prompt block whenever it exists. It runs for every login shell
# (bash and zsh), so it is the supported place to keep zsh out of the bash-only
# git-completion.bash, which otherwise prints
#   "ERROR: this script is obsolete, please see git-completion.zsh"
# on every zsh start.

# zsh: starship draws the prompt, native zsh git completion is already loaded.
if test -n "$ZSH_VERSION"
then
	return 0
fi

# bash: reproduce Git for Windows' default prompt so Git Bash / Claude Code's
# shell look exactly as before.
PS1='\[\033]0;$TITLEPREFIX:$PWD\007\]' # set window title
PS1="$PS1"'\n'                 # new line
PS1="$PS1"'\[\033[32m\]'       # change to green
PS1="$PS1"'\u@\h '             # user@host<space>
PS1="$PS1"'\[\033[35m\]'       # change to purple
PS1="$PS1"'$MSYSTEM '          # show MSYSTEM
PS1="$PS1"'\[\033[33m\]'       # change to brownish yellow
PS1="$PS1"'\w'                 # current working directory
if test -z "$WINELOADERNOEXEC"
then
	GIT_EXEC_PATH="$(git --exec-path 2>/dev/null)"
	COMPLETION_PATH="${GIT_EXEC_PATH%/libexec/git-core}"
	COMPLETION_PATH="${COMPLETION_PATH%/lib/git-core}"
	COMPLETION_PATH="$COMPLETION_PATH/share/git/completion"
	if test -f "$COMPLETION_PATH/git-prompt.sh"
	then
		. "$COMPLETION_PATH/git-completion.bash"
		. "$COMPLETION_PATH/git-prompt.sh"
		PS1="$PS1"'\[\033[36m\]'  # change color to cyan
		PS1="$PS1"'`__git_ps1`'   # bash function
	fi
fi
PS1="$PS1"'\[\033[0m\]'        # change color
PS1="$PS1"'\n'                 # new line
PS1="$PS1"'$ '                 # prompt: always $
