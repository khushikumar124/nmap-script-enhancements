# usage: nmap ... | drop.py [name ...]   removes the output blocks of the named scripts (other scripts that -sV runs) and an empty "Host script results:" header
import re, sys
drop = set(sys.argv[1:]); skip = False; out = []
hdr = re.compile(r'^\|[_ ]\s?([a-z0-9]+(?:-[a-z0-9.]+)+):')
for l in sys.stdin:
    l = l.rstrip('\n'); m = hdr.match(l)
    if m: skip = m.group(1) in drop
    elif not l.startswith('|'): skip = False
    if not skip: out.append(l)
text = "\n".join(out) + "\n"
text = re.sub(r'Host script results:\n\n', '', text)
sys.stdout.write(text)
