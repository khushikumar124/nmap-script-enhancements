#!/bin/bash
# usage: bench/run_http.sh <eN> <enhanced-script-path>   (run from the NSE-Project folder; srv.py must be running)
# Saves before/after/regression/requests under evidence/<eN>/
E=$1; NEW=$2; D=evidence/$E; STOCK=./scripts/http-generator.nse
CASES=${CASES:-"8081:/ 8082:/ 8081:/e1/stock 8081:/e1/single 8081:/e1/unquoted 8081:/e1/upper 8081:/e1/two 8081:/e1/nongen 8081:/e1/empty 8081:/e1/selfclose 8081:/e1/large"}
run() { # script port path
  local c="nmap -sV -Pn -p$2 --script $1 --script-args http-generator.path=$3 127.0.0.1"
  echo "\$ $c"; $c | grep -E "^\||^[0-9]+/tcp" | grep -v http-server-header; echo
}
mkdir -p $D; : > $D/before.txt; : > $D/after.txt
for c in $CASES; do p=${c%%:*}; u=${c#*:}
  run $STOCK $p $u >> $D/before.txt
  run $NEW   $p $u >> $D/after.txt
done
# requests: count GETs for one path, with the stock script, the enhanced script, and no script
: > $D/requests.txt
for s in "$STOCK" "$NEW" none; do
  : > bench/requests.log
  if [ $s = none ]; then nmap -sV -Pn -p8081 --script-args http-generator.path=/e1/stock 127.0.0.1 >/dev/null; else nmap -sV -Pn -p8081 --script $s --script-args http-generator.path=/e1/stock 127.0.0.1 >/dev/null; fi
  echo "script=$s  GET /e1/stock requests seen by server: $(grep -c ' /e1/stock$' bench/requests.log)   all requests: $(wc -l < bench/requests.log | tr -d ' ')" >> $D/requests.txt
done
cat $D/requests.txt
