#!/bin/bash
# Custom aliases and functions
# Add your aliases and functions below this line

alias smol='firefox $(getent hosts smol.local | awk "{print \$1}")'
alias datablock='firefox $(getent hosts datablock.local | awk "{print \$1}")'
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

# Functions
yte() {
  # Usage: yte <url> <pattern>
  # We wrap $1 in quotes to handle special characters in URLs
  yt "$1" | fabric -sp "$2"
}

# Example aliases:
# alias ll='ls -la'
# alias gs='git status'
# alias gp='git pull'
