#!/bin/bash
# usage: xmlsave.sh <outfile> <port> <script> [script-args]   appends the command, an xmllint check and the script's <script>...</script> element
f=$1; p=$2; s=$3; shift 3; args="$*"; t=$(dirname "$0")/x.xml
nmap -sV -Pn -p$p --script $s $args -oX $t 127.0.0.1 > /dev/null
{
  echo "\$ nmap -sV -Pn -p$p --script $s ${args:+$args }-oX - 127.0.0.1"
  xmllint --noout $t && echo "(xmllint --noout: well-formed; XML saved to a file for the check, same output as -oX -)"
  python3 -c 'import re,sys; m=re.search(r"<script id=\"(?:http-generator|unusual-port)[^\"]*\".*?</script>", open(sys.argv[1]).read(), re.S); print(m.group(0) if m else "(no output from the script)")' $t
  echo
} >> $f
rm -f $t
