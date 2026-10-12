# Nmap script enhancements

Four small, observation-only enhancements to two scripts that already exist in Nmap's repository. They are written so that each one could be sent upstream as a separate patch. No new Nmap scripts are written here.

| Reference script (Nmap) | Written by |
|---|---|
| `http-generator.nse` | Michael Kohl |
| `unusual-port.nse` | Patrik Karlsson |

The enhancements follow a few rules: observation only (no scores, risk labels or advice), no new network probes (same single `http.get`, same `-sV` data), the first line of output stays what the stock script printed, Nmap code style, and one patch per enhancement.

## The six scripts, in order

All are in `scripts/`. Each prints its own filename as the output label.

| # | File | What it is |
|---|---|---|
| ref1 | `http-generator.nse` | Stock Nmap script, unchanged. Finds the `generator` meta tag with one fixed pattern. |
| E1 | `http-generator-e1.nse` | Reads every `<meta>` tag attribute by attribute (any order, any quotes, any case), lists all generator tags, scans only the head or the first 64 KB. |
| E2 | `http-generator-e2.nse` | E1 plus the `X-Generator` response header, with the source of each finding and structured (`-oX`) output. |
| ref2 | `unusual-port.nse` | Stock Nmap script, unchanged. Prints `ssh unexpected on port tcp/23`. |
| E3 | `unusual-port-e3.nse` | Keeps that sentence and adds the expected service, the detection method and the confidence, with structured output. |
| E4 | `unusual-port-e4.nse` | E3 plus: services Nmap found inside TLS (`ssl/imap` on 993, ...) are no longer reported as unexpected. |

E2 is the final HTTP script and E4 the final TCP script. The script arguments are the same as in the stock scripts (for example `http-generator.path`), so each version can be used in place of the stock one.

## Results in one line each

(From `blog-assets/<step>/output.txt`; the saved evidence for each step is in `evidence/`.)

- ref1: nothing printed for the Gatsby page (8081) or the Hugo page (8082).
- E1: `Gatsby 5.13` and `Hugo 0.120`.
- E2: also `Drupal 10 (https://www.drupal.org) (X-Generator header)` on 8081.
- ref2: `ssh unexpected on port tcp/23`.
- E3: the same sentence plus `expected telnet; detection probed, confidence 10`.
- E4: the six TLS-wrapped services (465, 563, 636, 990, 993, 995), all flagged by the stock script, are no longer flagged.

## Folders

- `scripts/`: the six scripts above.
- `patches/`: `e1.diff` to `e4.diff`, unified diffs against the upstream filenames (`http-generator.nse`, `unusual-port.nse`). Apply them in order with `patch -p1`. `commit-messages.txt` has a message for each in Nmap style.
- `bench/`: the fake servers (`srv.py`) and the scripts that run and save every test.
- `evidence/`: for each enhancement, `before.txt`, `after.txt`, `regression.txt`, `notes.md` and, where relevant, `xml.txt` and `requests.txt`. `evidence/e4/measure.txt` is the measurement made before E4.
- `blog-assets/`: for each step, `output.txt` (one command and its output), `what-changed.txt` and `step.diff`.
- `RUNBOOK.md`: every command, in order, with how to install the scripts into Nmap and how to stop the servers.

## How to run

Tested with Nmap 7.99 on macOS (Homebrew), with Python 3.9. Always use `-sV` (both scripts depend on service detection), and only scan `127.0.0.1`:

```
nmap -sV -Pn -p8081,8082 --script ./scripts/http-generator-e2.nse 127.0.0.1
nmap -sV -Pn -p23,5433,465,993 --script ./scripts/unusual-port-e4.nse 127.0.0.1
```

## How to reproduce the tests

```
bench/make_certs.sh                     # throw-away TLS certificate for the fake servers
python3 bench/srv.py &                  # fake web, mail, ldap, ftp, nntp and ssh servers on localhost
bench/run_all.sh                        # whole test matrix; rewrites evidence/ and blog-assets/
pkill -f srv.py
```

On macOS a normal user can bind ports below 1024 only on all addresses, so some fake servers listen on all addresses. The scans only target 127.0.0.1. `RUNBOOK.md` has the individual commands.

## License

The stock scripts are part of Nmap and are not our work. The enhanced scripts are derived from them and keep the same license, the line already in the script headers: "Same as Nmap--See https://nmap.org/book/man-legal.html". See https://nmap.org/book/man-legal.html.

Enhancements by Khushi Kumar. Nothing here has been sent to the Nmap project.
