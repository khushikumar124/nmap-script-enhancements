# usage: nmap ... | filter.py <script-name>   keeps the "PORT" header, the port lines and the output blocks of one script
import re, sys
name = sys.argv[1]; keep = False; hdr = re.compile(r'^\|[_ ]\s?([a-z0-9]+(?:-[a-z0-9.]+)+):')
for l in sys.stdin:
    l = l.rstrip('\n')
    if re.match(r'^(PORT|\d+/(tcp|udp))\s', l): print(l); continue
    m = hdr.match(l)
    if m: keep = bool(re.fullmatch(re.escape(name) + r'(-e\d)?', m.group(1)))
    elif not l.startswith('|'): keep = False
    if keep and l.startswith('|'): print(l)
