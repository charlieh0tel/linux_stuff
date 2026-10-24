greplog () {
  grep -i -e "$1" ~/.fldigi/logs/logbook.adif ~/.fldigi/logs/logbook.adif.[0-9]* \
    ~/.local/share/WSJT-X/wsjtx.log ~/.local/share/JTDX/wsjtx.log 2>/dev/null
}

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias sysup="sudo sh -c 'apt update && apt full-upgrade'"
alias cs='chronyc  sources; chronyc sourcestats'
alias ce='sudo emacs /etc/chrony/chrony.conf'
alias cr='sudo systemctl restart chronyd.service '
alias cw='watch '\''chronyc sources; echo; chronyc sourcestats; echo; chronyc tracking'\'''
alias db='debuild -i -us -uc -b --post-clean --lintian-opts --suppress-tags dir-or-file-in-opt,bad-distribution-in-changes-file'
alias status='git status --porcelain --ignored'
alias gitclean='git clean -f -d -x'
alias wgr='sudo wg-quick down wg0; sudo wg-quick up wg0'

alias s='ssh-keygen -f "/home/ch/.ssh/known_hosts" -R "10.42.0.1" && ssh root@10.42.0.1'
alias pioenv='. /home/ch/.platformio/penv/bin/activate'
alias giddyup='for x in *; do [ -d "${x}/.git" ] && echo "${x}" && git -C "${x}" pull --ff-only; done'
