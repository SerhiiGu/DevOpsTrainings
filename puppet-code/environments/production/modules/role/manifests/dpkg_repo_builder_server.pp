class role::dpkg_repo_builder_server {
  include base_server
  include puppet_related

  include profile::fail2ban
  include profile::firewall
  include profile::logging
  include profile::packages
  include profile::timezone

  include profile::dpkg_repo_server
  include profile::dpkg_builder_server
}

