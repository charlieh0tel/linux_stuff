alias sysup="sudo sh -c 'apt update && apt full-upgrade'"
alias cs='chronyc  sources; chronyc sourcestats'
alias ce='sudo emacs /etc/chrony/chrony.conf'
alias cr='sudo systemctl restart chronyd.service '
alias cw='watch '\''chronyc sources; echo; chronyc sourcestats; echo; chronyc tracking'\'''
alias db='debuild -i -us -uc -b --post-clean --lintian-opts --suppress-tags dir-or-file-in-opt,bad-distribution-in-changes-file'
alias status='git status --porcelain --ignored'
alias gitclean='git clean -f -d -x'

alias s='ssh-keygen -f "/home/ch/.ssh/known_hosts" -R "10.42.0.1" && ssh root@10.42.0.1'
alias pioenv='. /home/ch/.platformio/penv/bin/activate'
