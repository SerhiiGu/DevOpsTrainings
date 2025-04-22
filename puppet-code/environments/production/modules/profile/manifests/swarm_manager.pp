class profile::swarm_manager {
  include profile::fail2ban
  include profile::firewall
  include profile::firewall_swarm
  include profile::logging
  include profile::packages
  include profile::timezone
  include profile::nginx_swarm
  include profile::user



}

