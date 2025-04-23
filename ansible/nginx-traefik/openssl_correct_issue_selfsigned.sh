#!/bin/bash


openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout key.pem -days 365 \
  -out cert.pem \
  -subj "/CN=phpqwe123.local" \
  -addext "subjectAltName=DNS:phpqwe123.local"

openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout traefik.key -days 365 \
  -out traefik.crt \
  -subj "/CN=traefik.local" \
  -addext "subjectAltName=DNS:traefik.local"


#openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem \
#  -out cert.pem -days 365 \
#  -subj "/CN=nginx.local" \
#  -addext "subjectAltName=DNS:nginx.local"
