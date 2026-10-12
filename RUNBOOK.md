# RUNBOOK: reproducing the tests and installing the scripts

Run every command from the root of this repository. The output label of each script is its own filename (`http-generator-e1:`, `unusual-port-e3:`, ...); the stock ones print `http-generator:` and `unusual-port:`. Tested with Nmap 7.99 (macOS, Homebrew). Only 127.0.0.1 is scanned, and every scan uses `-sV`.
Blog order: ref1, e1, e2, ref2, e3, e4. Each step's script is in `scripts/`; its saved outputs are in `blog-assets/<step>/` and `evidence/`.

## A. Install the enhanced scripts (needed only for steps 35 to 37, "by name")

The enhanced scripts have their own names (`http-generator-e1`, `http-generator-e2`, `unusual-port-e3`, `unusual-port-e4`), so they are installed next to the stock ones. Nothing is replaced, so there is nothing to back up or restore. They are also in `./scripts/`.

A1. Find the scripts folder:
```bash
brew --prefix nmap
ls "$(brew --prefix nmap)"/share/nmap/scripts | head -3
```
A2. Copy the four enhanced scripts in (use `sudo` if you get "Permission denied") and update the script database:
```bash
sudo cp ./scripts/http-generator-e1.nse ./scripts/http-generator-e2.nse ./scripts/unusual-port-e3.nse ./scripts/unusual-port-e4.nse "$(brew --prefix nmap)"/share/nmap/scripts/
sudo nmap --script-updatedb
```
A3. To remove them again:
```bash
sudo rm "$(brew --prefix nmap)"/share/nmap/scripts/{http-generator-e1,http-generator-e2,unusual-port-e3,unusual-port-e4}.nse
sudo nmap --script-updatedb
```
Note: `-sV` also runs every installed script of the `version` category. If another script of yours is installed in that folder, its output can appear in the scans.

## B. Screenshot commands, in order

### Setup
1. (setup) Nmap version. Screenshot: the line `Nmap 7.99`.
```bash
nmap --version
```
2. (setup) Make the throw-away test certificate once (`bench/c.pem` and `bench/k.pem`, git-ignored), then start the fake servers in the background (ports 8081, 8082, 465, 563, 636, 990, 993, 995 TLS/plain, 22, 23, 2222, 5433). Screenshot: not needed; `srv.log` should stay empty.
```bash
bench/make_certs.sh
python3 bench/srv.py > bench/srv.log 2>&1 &
```
3. (setup) Check they are listening. Screenshot: the list of ports.
```bash
lsof -nP -iTCP -sTCP:LISTEN | grep Python
```

### ref1: stock http-generator (script `blog-assets/ref1/http-generator.nse`)
4. (ref1) Stock script on the Gatsby page (8081) and the reversed-order Hugo page (8082). Screenshot: both ports with **no** `http-generator` line.
```bash
nmap -sV -Pn -p8081,8082 --script ./scripts/http-generator.nse 127.0.0.1
```
5. (ref1) Proof that the server really sends the header and tag the stock script misses. Screenshot: the `X-Generator:` line and the `<meta data-react-helmet ... name="generator">` tag.
```bash
curl -si http://127.0.0.1:8081/ | grep -i -E "x-generator|name=\"generator\""
```

### E1 (script `blog-assets/e1/http-generator-e1.nse`)
6. (E1) Same command as step 4. Screenshot: `Gatsby 5.13` on 8081 and `Hugo 0.120` on 8082.
```bash
nmap -sV -Pn -p8081,8082 --script ./scripts/http-generator-e1.nse 127.0.0.1
```
7. (E1) Two generator tags on one page. Screenshot: both lines (`WordPress 6.4` and `Elementor 3.18`).
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/two 127.0.0.1
```
8. (E1) Body over 2 MB: stock prints nothing, E1 prints `Big 1.0`. Screenshot: run both and show both outputs.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e1/large 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/large 127.0.0.1
```
9. (E1) Regression: stock-style tag gives the same line with both scripts. Screenshot: the identical `TYPO3 4.2 CMS` lines.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e1/stock 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/stock 127.0.0.1
```
10. (E1) Regression: a non-generator meta tag and an empty generator print nothing with E1. Screenshot: no `http-generator` line in both.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/nongen 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e1.nse --script-args http-generator.path=/e1/empty 127.0.0.1
```
11. (E1) Diff against stock. Screenshot: the diff (scroll in two parts).
```bash
cat blog-assets/e1/step.diff
```

### E2 (script `blog-assets/e2/http-generator-e2.nse`)
12. (E2) Same command as step 4. Screenshot: 8081 shows `Gatsby 5.13` plus `Drupal 10 (https://www.drupal.org) (X-Generator header)`; 8082 still shows `Hugo 0.120` only.
```bash
nmap -sV -Pn -p8081,8082 --script ./scripts/http-generator-e2.nse 127.0.0.1
```
13. (E2) Header-only page: stock prints nothing, E2 prints the header value. Screenshot: both outputs.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e2/header 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/header 127.0.0.1
```
14. (E2) Same value in tag and header is listed once; neither prints nothing. Screenshot: one `Drupal 10` line, then no line.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/same 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/none 127.0.0.1
```
15. (E2) Regression: meta-only page prints exactly the stock text. Screenshot: both outputs `Hugo 0.120`.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e2/meta 127.0.0.1
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/meta 127.0.0.1
```
16. (E2) XML output with the source field. Screenshot: the `<table>` blocks with `source` `meta` and `header`.
```bash
nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/diff -oX - 127.0.0.1
```
17. (E2) Request count: stock and E2 each cause exactly 1 GET of the page. Screenshot: both `1`.
```bash
: > bench/requests.log; nmap -sV -Pn -p8081 --script ./scripts/http-generator.nse --script-args http-generator.path=/e2/diff 127.0.0.1 > /dev/null; grep -c " /e2/diff" bench/requests.log
: > bench/requests.log; nmap -sV -Pn -p8081 --script ./scripts/http-generator-e2.nse --script-args http-generator.path=/e2/diff 127.0.0.1 > /dev/null; grep -c " /e2/diff" bench/requests.log
```
18. (E2) Diff against E1. Screenshot: the diff.
```bash
cat blog-assets/e2/step.diff
```

### ref2: stock unusual-port (script `blog-assets/ref2/unusual-port.nse`)
19. (ref2) Stock script. Screenshot: one-line `ssh unexpected on port tcp/23` and `http unexpected on port tcp/5433`; port 22 silent.
```bash
nmap -sV -Pn -p22,23,5433 --script ./scripts/unusual-port.nse 127.0.0.1
```
20. (ref2) The false alarm on TLS-wrapped services. Screenshot: `ssl/smtp` and `smtp unexpected on port tcp/465`.
```bash
nmap -sV -Pn -p465 --script ./scripts/unusual-port.nse 127.0.0.1
```

### E3 (script `blog-assets/e3/unusual-port-e3.nse`)
21. (E3) Same command as step 19. Screenshot: the first line unchanged, plus `expected telnet; detection probed, confidence 10`.
```bash
nmap -sV -Pn -p22,23,5433 --script ./scripts/unusual-port-e3.nse 127.0.0.1
```
22. (E3) Regression: ssh on 2222 is still flagged, ssh on 22 is silent. Screenshot: both.
```bash
nmap -sV -Pn -p22,2222 --script ./scripts/unusual-port-e3.nse 127.0.0.1
```
23. (E3) XML output. Screenshot: the `<elem key=...>` lines (port, protocol, detected, expected, confidence, method).
```bash
nmap -sV -Pn -p23 --script ./scripts/unusual-port-e3.nse -oX - 127.0.0.1
```
24. (E3) No new connections: the server log has the same number of lines with no script, with stock and with E3. Screenshot: three equal numbers.
```bash
: > bench/requests.log; nmap -sV -Pn -p23 127.0.0.1 > /dev/null; wc -l < bench/requests.log
: > bench/requests.log; nmap -sV -Pn -p23 --script ./scripts/unusual-port.nse 127.0.0.1 > /dev/null; wc -l < bench/requests.log
: > bench/requests.log; nmap -sV -Pn -p23 --script ./scripts/unusual-port-e3.nse 127.0.0.1 > /dev/null; wc -l < bench/requests.log
```
25. (E3) Diff against stock. Screenshot: the diff.
```bash
cat blog-assets/e3/step.diff
```

### E4 (script `blog-assets/e4/unusual-port-e4.nse`)
26. (E4) Measurement: stock script on all six TLS ports. Screenshot: six `unexpected` lines (or the saved file).
```bash
nmap -sV -Pn -p465,563,636,990,993,995 --script ./scripts/unusual-port.nse 127.0.0.1
```
27. (E4) Same command with E4. Screenshot: all six `ssl/...` services and **no** `unusual-port` lines.
```bash
nmap -sV -Pn -p465,563,636,990,993,995 --script ./scripts/unusual-port-e4.nse 127.0.0.1
```
28. (E4) Regression: plain cases unchanged. Screenshot: the same results as step 21.
```bash
nmap -sV -Pn -p22,23,2222,5433 --script ./scripts/unusual-port-e4.nse 127.0.0.1
```
29. (E4) Must still be flagged: ssh inside TLS on 993. Stop the servers, restart in `ssh993` mode, scan, restore. Screenshot: `ssl/ssh` and `ssh unexpected on port tcp/993`.
```bash
pkill -f srv.py; sleep 1; python3 bench/srv.py ssh993 > bench/srv.log 2>&1 &
```
```bash
nmap -sV -Pn -p993 --script ./scripts/unusual-port-e4.nse 127.0.0.1
```
30. (E4) Must still be flagged: plaintext smtp on 993 (mode `smtp993`). Screenshot: `smtp unexpected on port tcp/993`.
```bash
pkill -f srv.py; sleep 1; python3 bench/srv.py smtp993 > bench/srv.log 2>&1 &
```
```bash
nmap -sV -Pn -p993 --script ./scripts/unusual-port-e4.nse 127.0.0.1
```
31. (E4) Go back to the normal servers. Screenshot: not needed.
```bash
pkill -f srv.py; sleep 1; python3 bench/srv.py > bench/srv.log 2>&1 &
```
32. (E4) Diff against E3. Screenshot: the diff.
```bash
cat blog-assets/e4/step.diff
```

### Script help (NSEDoc) and syntax check, final scripts
33. (E1/E2) Screenshot: description, usage, `@output` and `@xmloutput` text.
```bash
nmap --script-help ./scripts/http-generator-e2.nse
```
34. (E3/E4) Screenshot: the description with the new paragraphs.
```bash
nmap --script-help ./scripts/unusual-port-e4.nse
```

### After installing (section A), run by name
35. (E1/E2) Screenshot: each HTTP script by name, 8081 and 8082 (labels `http-generator-e1:` and `http-generator-e2:`).
```bash
nmap -sV -Pn -p8081,8082 --script http-generator-e1 127.0.0.1
nmap -sV -Pn -p8081,8082 --script http-generator-e2 127.0.0.1
```
36. (E3/E4) Screenshot: each TCP script by name (labels `unusual-port-e3:` and `unusual-port-e4:`). E3 flags the TLS ports, E4 does not.
```bash
nmap -sV -Pn -p23,5433,465,993 --script unusual-port-e3 127.0.0.1
nmap -sV -Pn -p23,5433,465,993 --script unusual-port-e4 127.0.0.1
```
37. (final) Full diffs, stock script against the final enhanced script. Screenshot: each in turn.
```bash
diff -u scripts/http-generator.nse scripts/http-generator-e2.nse
diff -u scripts/unusual-port.nse scripts/unusual-port-e4.nse
```

## C. Stop the fake servers afterwards
```bash
pkill -f srv.py
lsof -nP -iTCP -sTCP:LISTEN | grep Python   # should print nothing
```
`bench/run_all.sh` re-runs the whole test matrix on fresh servers and rewrites `evidence/` and `blog-assets/`.
