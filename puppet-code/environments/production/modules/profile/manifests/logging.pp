class profile::logging {

  file { '/etc/rsyslog.d/custom.conf':
    ensure  => file,
    source  => 'puppet:///modules/profile/custom.conf',
    notify  => Service['rsyslog'],
  }

  file { '/var/log/custom':
    ensure => directory,
    owner  => 'root',
    group  => 'adm',
    mode   => '0755',
  }

  file { '/etc/logrotate.d/custom':
    ensure  => file,
    source  => 'puppet:///modules/profile/logrotate-custom',
    mode    => '0644',
  }

  file { '/var/log/auth.log':
    ensure => present,
    mode   => '0640',
    owner  => 'root',
    group  => 'adm',
    replace => false,
  }

  service { 'rsyslog':
    ensure => running,
    enable => true,
  }
}

