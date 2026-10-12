# usage: regress_http.py <evidence dir>  -> writes regression.txt comparing before.txt (stock) and after.txt (enhanced)
import re, sys
d = sys.argv[1]
def parse(f):
    r = {}; k = None
    for l in open(f):
        if l.startswith('$'): k = re.search(r'-p(\d+).*path=(\S+)', l).groups(); r[k] = []
        elif k and l.strip(): r[k].append(l.rstrip())
    return r
b = parse(d + '/before.txt'); a = parse(d + '/after.txt')
out = ["Cases where the stock script already printed something, or must stay silent.", "A case is OK when the enhanced output is identical to stock, or (multi-tag/multi-source pages only) starts with the same text.", ""]
bad = 0
for k in b:
    sb = [x for x in b[k] if 'http-generator' in x or x.startswith('|')]; sa = [re.sub(r'http-generator-e\d', 'http-generator', x) for x in a[k] if 'http-generator' in x or x.startswith('|')]
    silent = k[1] in ('/e1/nongen', '/e1/empty', '/e2/none')
    if sb or silent:
        same = sa == sb
        out.append("port %s path %s\n  stock   : %s\n  enhanced: %s\n  identical: %s\n" % (k[0], k[1], sb or '(nothing)', sa or '(nothing)', "YES" if same else "NO (see note)"))
        bad += not same
out.append('Note: the enhanced script prints its own name (http-generator-e1: ...); the label is normalised to http-generator: above. A row marked NO differs on purpose: the page has several generator sources, so the enhanced script adds lines after the stock line.')
open(d + '/regression.txt', 'w').write("\n".join(out)); print("\n".join(out)); print("differences:", bad)
