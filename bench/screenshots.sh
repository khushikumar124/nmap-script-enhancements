#!/bin/bash
# Saves, verbatim, the output of every command in RUNBOOK section D ("Screenshots still to take") under evidence/screenshots/.
# Run from the repository root. Starts and stops the fake servers itself.
B=bench; O=evidence/screenshots; mkdir -p $O
start() { pkill -f srv.py; sleep 1; (nohup python3 $B/srv.py $1 > $B/srv.log 2>&1 &); sleep 2; }
shot() { # file "command"   (writes "$ command" and what the terminal shows)
  { echo "\$ $2"; bash -c "$2" 2>&1; } > $O/$1
}
shot_multi() { # file "cmd1" "cmd2" ...
  local f=$1; shift; : > $O/$f
  for c in "$@"; do { echo "\$ $c"; bash -c "$c" 2>&1; } >> $O/$f; done
}
start main
shot a-e2-structured-output.txt "nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/diff -oX - 127.0.0.1"
for n in "b1-help-e1:http-generator-e1" "b2-help-e2:http-generator-e2" "b3-help-e3:unusual-port-e3" "b4-help-e4:unusual-port-e4"; do
  shot ${n%%:*}.txt "(cd scripts && nmap --script-help ./${n#*:}.nse)"
done
shot_multi c1-regression-http-generator.txt \
  "nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e1/stock 127.0.0.1" \
  "nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/stock 127.0.0.1" \
  "nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e1/stock 127.0.0.1"
shot_multi c2-regression-unusual-port.txt \
  "nmap -sV -Pn -p22 --script ./scripts/unusual-port.nse 127.0.0.1" \
  "nmap -sV -Pn -p22 --script ./scripts/unusual-port-e3.nse 127.0.0.1" \
  "nmap -sV -Pn -p22 --script ./scripts/unusual-port-e4.nse 127.0.0.1"
start ssh993
shot_multi d1-negative-ssh-over-tls-993.txt "nmap -sV -Pn -p993 --script ./scripts/unusual-port-e4.nse 127.0.0.1"
start smtp993
shot_multi d2-negative-plaintext-smtp-993.txt "nmap -sV -Pn -p993 --script ./scripts/unusual-port-e4.nse 127.0.0.1"
start main
shot_multi e-e4-final-tls-ports.txt \
  "nmap -sV -Pn -p465,563,636,990,993,995 --script ./scripts/unusual-port-e3.nse 127.0.0.1" \
  "nmap -sV -Pn -p465,563,636,990,993,995 --script ./scripts/unusual-port-e4.nse 127.0.0.1"
pkill -f srv.py
