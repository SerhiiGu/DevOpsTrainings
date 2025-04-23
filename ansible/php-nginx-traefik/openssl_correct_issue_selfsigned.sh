#!/bin/bash


openssl req -x509 -nodes -days 365 -newkey rsa:4096 -sha256 \
  -keyout privkey.key \
  -out cert.crt \
  -subj "/CN=php.local" \
  -addext "subjectAltName=DNS:php.local"

