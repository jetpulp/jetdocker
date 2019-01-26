export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

alias cd..='cd ..'
alias cd...='cd ../..'
alias cd....='cd ../../..'
alias cd.....='cd ../../../..'
alias chgrp='chgrp --preserve-root'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias header='curl -I'
alias headerc='curl -I --compress'
alias l='ls -la'
alias la='ls -lA'
alias ll='ls -l'
alias ls='ls --color=tty'
alias lsa='ls -lah'
alias rm='rm -I --preserve-root'
alias sl='ls'

touch ~/.my_aliases
. ~/.my_aliases