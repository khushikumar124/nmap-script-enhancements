#!/bin/bash
# Makes the throw-away test certificate used by the TLS fake servers in srv.py (bench/c.pem, bench/k.pem; both are git-ignored).
cd "$(dirname "$0")" && openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -days 30 -subj /CN=mail.example.com 2>/dev/null && echo "wrote bench/c.pem and bench/k.pem"
