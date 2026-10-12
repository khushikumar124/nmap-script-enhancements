#!/bin/bash
# Builds blog-assets/<step>/output.txt (+ compare.txt) from the step scripts. Run from NSE-Project; srv.py (main mode) must be running.
A=blog-assets
go() { # outfile append|new script ports
  local f=$1 m=$2 s=$3 p=$4; [ $m = new ] && : > $f
  { echo "\$ nmap -sV -Pn -p$p --script $s 127.0.0.1"; nmap -sV -Pn -p$p --script $s 127.0.0.1 | python3 bench/drop.py $DROP; } >> $f
}
H=8081,8082; U=22,23,5433; T=465,563,636,990,993,995
go $A/ref1/output.txt new ./scripts/http-generator.nse $H
go $A/e1/output.txt   new ./scripts/http-generator-e1.nse $H
go $A/e2/output.txt   new ./scripts/http-generator-e2.nse $H
go $A/e2/compare.txt  new ./scripts/http-generator-e1.nse $H; echo >> $A/e2/compare.txt; go $A/e2/compare.txt append ./scripts/http-generator-e2.nse $H
go $A/ref2/output.txt new ./scripts/unusual-port.nse $U
go $A/e3/output.txt   new ./scripts/unusual-port-e3.nse $U
go $A/e4/output.txt   new ./scripts/unusual-port-e4.nse $T
go $A/e4/compare.txt  new ./scripts/unusual-port-e3.nse $T; echo >> $A/e4/compare.txt; go $A/e4/compare.txt append ./scripts/unusual-port-e4.nse $T
