#!/bin/bash
# usage: save.sh <outfile> <append|new> <command...>   writes "$ command" then the output, verbatim
f=$1; m=$2; shift 2
[ $m = new ] && : > "$f"
{ echo "\$ $*"; "$@" 2>&1; echo; } >> "$f"
