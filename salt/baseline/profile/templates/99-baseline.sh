#!/bin/bash

export HISTTIMEFORMAT="%d/%m/%y %T "
export HISTSIZE=100000
export HISTFILESIZE=200000

shopt -s histappend

if [[ ":${PROMPT_COMMAND}:" != *":history -a;"* ]]; then
    export PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND}"
fi

export HISTCONTROL="ignoredups"

readonly HISTFILE HISTFILESIZE HISTSIZE HISTCONTROL HISTTIMEFORMAT PROMPT_COMMAND

if [[ -n "${PS1-}" ]]; then
    export TMOUT=1800
    readonly TMOUT

    if [ "$(id -u)" -eq 0 ]; then
        export PS1="\[\e[36m\]\t\[\e[m\] \[\e[30;41m\]\u\[\e[m\]\[\e[30;41m\]@\[\e[m\]\[\e[30;41m\]\h\[\e[m\] \[\e[35m\]\w\[\e[m\] \[\e[33m\]\\$\[\e[m\] "
    else
        export PS1="\[\e[36m\]\t\[\e[m\] \[\e[32m\]\u\[\e[m\]\[\e[32m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\] \[\e[35m\]\w\[\e[m\] \[\e[33m\]\\$\[\e[m\] "
    fi
fi

umask 027
ulimit -S -c 0 > /dev/null 2>&1
export EDITOR=vi
