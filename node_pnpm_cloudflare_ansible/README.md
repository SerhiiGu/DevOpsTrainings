## Setup stack for work with CloudFlare:
Node.js
npm
pnpm
wrangler
AWS CLI (for CloudFlare R2 buckets)

## aws CLI profile for CF
    Create API token:
    Go to dash.cloudflare.com to your account
    then R2 Object Storage, click API => Manage API tokens
    Create Account API Token (set Name, Permissions, TTL - then Create).
    Store Token value(for API); Access Key ID and Secret Access Key(for aws cli)
    
aws configure --profile cf-r2
    Use Access/Secret Key here.

   Add to `~/.aws/config` block:

[profile cf-r2]
region = auto
s3 = endpoint_url = https://<ACCOUNT_ID>.r2.cloudflarestorage.com


    where ACCOUNT_ID - your ACCOUNT ID (32 char hex string)

    And you can use:
aws --profile cf-r2 s3 ls

## CloudFlared tunnel (if your server haven't direct access to the Internet)
cloudflared tunnel login
    # follow the instructions

cloudflared tunnel create voc # voc - TUNNEL_NAME
    # you will use this info  later:
    ### Tunnel credentials written to /root/.cloudflared/57693deb-40f8-...
    ### Created tunnel voc with id 57693deb-40f8...

mkdir /etc/cloudflared/
cat /etc/cloudflared/config.yml
    ======================
tunnel: 57693deb-40f8...
credentials-file: /root/.cloudflared/d2530cb7-40f8....json

ingress:
  - hostname: voc.deus207.pp.ua
    service: https://voc.deus207.pp.ua
  - service: http_status:404

originRequest:
  httpHostHeader: voc.deus207.pp.ua
    ========================

cloudflared tunnel route dns voc voc.deus207.pp.ua

    # add to /etc/hosts
192.168.1.185  voc.deus207.pp.ua  # your local IP here

    # run tunnel(to check first)
cloudflared tunnel run voc

    # if all good, setup systemd service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

