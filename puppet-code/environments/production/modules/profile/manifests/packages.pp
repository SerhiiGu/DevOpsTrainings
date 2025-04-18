class profile::packages {

  package { ['curl', 'vim', 'git', 'ntpdate', 'wget', 'ipset', 'rsyslog']:
    ensure => installed,
  }

}
