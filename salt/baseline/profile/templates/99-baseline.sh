#!/bin/bash

# -----------------------------------------------------------------------------
# 1. HISTORY & FORENSICS (Critical for Incident Response)
# -----------------------------------------------------------------------------
# Date format for history (standard auditing format)
export HISTTIMEFORMAT="%d/%m/%y %T "

# History File Configuration
# Use a large number rather than "unlimited" (empty) to prevent memory exhaustion DoS,
# but make it large enough to retain significant context.
export HISTSIZE=100000
export HISTFILESIZE=200000

# PREVENT HISTORY TAMPERING/LOSS:
# 1. 'histappend': Append to the history file, don't overwrite it when the session closes.
#    This prevents one terminal session from wiping out the history of another.
shopt -s histappend

# 2. PROMPT_COMMAND: Write history to disk immediately after every command.
#    If the shell crashes or an attacker kills the session, the logs are saved.
#    Idempotent guard prevents accumulation on re-sourcing (bash -l, su -, profile.d, etc.).
if [[ ":${PROMPT_COMMAND}:" != *":history -a;"* ]]; then
    export PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND}"
fi

# 3. HISTCONTROL:
#    - REMOVED 'ignorespace': Prevents users from hiding commands by putting a space in front.
#    - REMOVED 'erasedups': Keeps the chronological order of commands intact for forensics.
#    - kept 'ignoredups': Only ignores consecutive duplicates (cleaner, but doesn't break timeline).
export HISTCONTROL="ignoredups"

# Make history variables readonly to prevent users from disabling logging in the session
readonly HISTFILE
readonly HISTFILESIZE
readonly HISTSIZE
readonly HISTCONTROL
readonly HISTTIMEFORMAT
readonly PROMPT_COMMAND

# -----------------------------------------------------------------------------
# 2. SESSION SECURITY (interactive shells only)
# -----------------------------------------------------------------------------
if [[ -n "${PS1-}" ]]; then
    # Auto-logout idle sessions after 1800 seconds (30 minutes).
    export TMOUT=1800
    readonly TMOUT

    # -----------------------------------------------------------------------------
    # 3. VISUALS & USABILITY (interactive shells only)
    # -----------------------------------------------------------------------------
    if [ "$(id -u)" -eq 0 ]; then
        # RED prompt for ROOT to clearly indicate elevated privileges
        export PS1="\[\e[36m\]\t\[\e[m\] \[\e[30;41m\]\u\[\e[m\]\[\e[30;41m\]@\[\e[m\]\[\e[30;41m\]\h\[\e[m\] \[\e[35m\]\w\[\e[m\] \[\e[33m\]\\$\[\e[m\] "
    else
        # GREEN prompt for standard users
        export PS1="\[\e[36m\]\t\[\e[m\] \[\e[32m\]\u\[\e[m\]\[\e[32m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\] \[\e[35m\]\w\[\e[m\] \[\e[33m\]\\$\[\e[m\] "
    fi
fi

# -----------------------------------------------------------------------------
# 4. SYSTEM-WIDE HARDENING (applies to all shells, including non-interactive)
# -----------------------------------------------------------------------------
# Set restrictive umask.
# 027 = User(rwx), Group(rx), Others(no access).
# This ensures new files created aren't world-readable/writable.
umask 027

# Disable Core Dumps
# Prevents sensitive memory contents from being written to disk if a program crashes.
ulimit -S -c 0 > /dev/null 2>&1

# Standard editor (affects many tools)
export EDITOR=vi
