#!/bin/bash
# Full clean run of the whole test matrix. Run from the NSE-Project folder: bench/run_all.sh
# Starts fresh fake servers, regenerates every file under evidence/ and blog-assets/, stops the servers.
B=bench; A=./blog-assets; EV=evidence
R1=./scripts/http-generator.nse; R2=./scripts/unusual-port.nse
E1=./scripts/http-generator-e1.nse; E2=./scripts/http-generator-e2.nse; E3=./scripts/unusual-port-e3.nse; E4=./scripts/unusual-port-e4.nse
start() { pkill -f srv.py; sleep 1; : > $B/requests.log; (nohup python3 $B/srv.py $1 > $B/srv.log 2>&1 &); sleep 2; }
start main
echo "== before-sec3"; mkdir -p $EV/before-sec3
$B/save.sh $EV/before-sec3/http-8081-8082.txt new nmap -sV -Pn -p8081,8082 --script $R1 127.0.0.1
$B/save.sh $EV/before-sec3/unusual-465.txt new nmap -sV -Pn -p465 --script $R2 127.0.0.1
echo "== E1"
$B/run_http.sh e1 $E1 > /dev/null; python3 $B/regress_http.py $EV/e1 > /dev/null
nmap --script-help $E1 > $EV/e1/script-help.txt
echo "== E2"
CASES="8081:/e2/header 8081:/e2/meta 8081:/e2/same 8081:/e2/diff 8081:/e2/none 8081:/e1/stock 8081:/ 8082:/" $B/run_http.sh e2 $E2 > /dev/null; python3 $B/regress_http.py $EV/e2 > /dev/null
: > $EV/e2/xml.txt; $B/xmlsave.sh $EV/e2/xml.txt 8081 $E2 --script-args http-generator.path=/e2/header; $B/xmlsave.sh $EV/e2/xml.txt 8081 $E2 --script-args http-generator.path=/e2/diff
nmap --script-help $E2 > $EV/e2/script-help.txt
echo "== E3"
$B/run_tcp.sh e3 $E3 "23 5433 2222 22" > /dev/null; $B/regress_tcp.sh e3 $E3 "22 8081 23 5433 2222" > /dev/null
: > $EV/e3/xml.txt; $B/xmlsave.sh $EV/e3/xml.txt 23 $E3; $B/xmlsave.sh $EV/e3/xml.txt 2222 $E3
nmap --script-help $E3 > $EV/e3/script-help.txt
echo "== E4"
M=$EV/e4/measure.txt; : > $M
echo "# Stock unusual-port on TLS-wrapped services ($(nmap --version | head -1 | cut -d" " -f1-3)). Servers: bench/srv.py (main mode)." >> $M; echo >> $M
for p in 465 993 995 636 990 563; do $B/save.sh $M append nmap -sV -Pn -p$p --script $R2 127.0.0.1; done
python3 - >> $M <<'PY'
import re
print("nmap-services entries for these ports (tcp), from /opt/homebrew/opt/nmap/share/nmap/nmap-services:")
want={465,993,995,636,990,563,22,23}; seen={}
for l in open('/opt/homebrew/opt/nmap/share/nmap/nmap-services'):
    m=re.match(r'(\S+)\s+(\d+)/tcp\s+([\d.]+)',l)
    if m and int(m.group(2)) in want: seen[int(m.group(2))]=m.group(1)
for p in sorted(want): print("  %d/tcp -> %s"%(p,seen.get(p)))
PY
nmap -sV -Pn -p465,993,995,636,990,563 -oX - 127.0.0.1 | grep -o '<service name="[^"]*"[^>]*tunnel="[^"]*"' | sed 's/product.*tunnel/ ... tunnel/' >> $M
$B/run_tcp.sh e4 $E4 "465 993 995 636 990 563" > /dev/null; $B/regress_tcp.sh e4 $E4 "22 23 2222 5433" > /dev/null
N=$EV/e4/negative.txt; : > $N; echo "Cases that must STILL be flagged by the enhanced script (stock shown for comparison)." >> $N
for m in ssh993 smtp993; do
  start $m; echo "## srv.py mode $m" >> $N
  for s in $R2 $E4; do { echo "\$ nmap -sV -Pn -p993 --script $s 127.0.0.1"; nmap -sV -Pn -p993 --script $s 127.0.0.1 | python3 $B/filter.py unusual-port; echo; } >> $N; done
done
start main
nmap --script-help $E4 > $EV/e4/script-help.txt
echo "== blog-assets"
$B/make_assets.sh
for i in 1 2 3 4; do :; done
diff -u ./scripts/http-generator.nse $E1 > $A/e1/step.diff; diff -u $E1 $E2 > $A/e2/step.diff; diff -u ./scripts/unusual-port.nse $E3 > $A/e3/step.diff; diff -u $E3 $E4 > $A/e4/step.diff
pkill -f srv.py; rm -f $B/x.xml; echo "== finished"
