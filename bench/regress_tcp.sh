#!/bin/bash
# usage: bench/regress_tcp.sh <eN> <enhanced-script> "<ports>"  -> evidence/<eN>/regression.txt
# For each port: stock output vs enhanced output; "same first line" compares the text after "unusual-port:".
E=$1; NEW=$2; PORTS=$3; F=evidence/$E/regression.txt
STOCK=./scripts/unusual-port.nse
echo "Unchanged cases: stock vs enhanced on ports where the stock script is silent or its sentence must stay the same." > $F; echo >> $F
for p in $PORTS; do
  a=$(nmap -sV -Pn -p$p --script $STOCK 127.0.0.1 | python3 bench/filter.py unusual-port | grep -v -E '^(PORT|[0-9]+/)')
  b=$(nmap -sV -Pn -p$p --script $NEW 127.0.0.1 | python3 bench/filter.py unusual-port | grep -v -E '^(PORT|[0-9]+/)')
  fa=$(echo "$a" | head -1 | sed 's/^|[_ ] *//'); fb=$(echo "$b" | head -1 | sed 's/^|[_ ] *//; s/unusual-port-e[0-9]:/unusual-port:/')
  [ "$fa" = "$fb" ] && r=MATCH || r=DIFFERENT
  { echo "port $p"; echo "  stock   : ${a:-(nothing)}" | sed '2,$s/^/            /'; echo "  enhanced: ${b:-(nothing)}" | sed '2,$s/^/            /'; echo "  first line: $r"; echo; } >> $F
done
cat $F
