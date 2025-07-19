# Additional steps (only if you use it locally)

1. config cloudflared first time ( /etc/cloudflared/config.yml )
ingress:
  - hostname: awstats.deus207.pp.ua
    service: http://awstats.deus207.pp.ua
    originRequest:
      httpHostHeader: awstats.deus207.pp.ua

2. restart cloudflared

3. after got cert reconfig cloudflared ( /etc/cloudflared/config.yml )
ingress:
  - hostname: awstats.deus207.pp.ua
    service: https://awstats.deus207.pp.ua
    originRequest:
      httpHostHeader: awstats.deus207.pp.ua

4. restart cloudflared

5. Add awstats.deus207.pp.ua to /etc/hosts on your server to your server IP's. For example:
192.168.1.185 awstats.deus207.pp.ua


