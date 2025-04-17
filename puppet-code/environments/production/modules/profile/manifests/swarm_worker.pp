class profile::swarm_worker {
  include profile::fail2ban
  include profile::firewall
  include profile::firewall_swarm
  include profile::logging
  include profile::packages
  include profile::timezone
}
