#!/bin/bash
# usage: bench/run_tcp.sh <eN> <enhanced-script> "<port> <port> ..."   (run from NSE-Project; srv.py must be running)
# Saves before.txt (stock), after.txt (enhanced), requests.txt under evidence/<eN>/
# Only the unusual-port lines are kept (filter.py); everything else Nmap printed is dropped.
E=$1; NEW=$2; PORTS=$3; D=evidence/$E; STOCK=./scripts/unusual-port.nse
LOG=bench/requests.log
mkdir -p $D; : > $D/before.txt; : > $D/after.txt
for p in $PORTS; do
  for pair in "$STOCK:before" "$NEW:after"; do s=${pair%:*}; f=${pair#*:}
    echo "\$ nmap -sV -Pn -p$p --script $s 127.0.0.1" >> $D/$f.txt
    nmap -sV -Pn -p$p --script $s 127.0.0.1 | python3 bench/filter.py unusual-port >> $D/$f.txt; echo >> $D/$f.txt
  done
done
: > $D/requests.txt
p=${PORTS%% *}
for s in "$STOCK" "$NEW" none; do
  : > $LOG
  if [ $s = none ]; then nmap -sV -Pn -p$p 127.0.0.1 >/dev/null; else nmap -sV -Pn -p$p --script $s 127.0.0.1 >/dev/null; fi
  echo "port $p script=$s  connections/requests seen by the server: $(wc -l < $LOG | tr -d ' ')" >> $D/requests.txt
done
cat $D/requests.txt
