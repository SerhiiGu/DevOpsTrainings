class profile::timezone (
  String $timezone = 'Europe/Kyiv',
) {

  file { '/etc/timezone':
    ensure  => file,
    content => "${timezone}\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  exec { 'set-timezone':
    command     => "/usr/bin/timedatectl set-timezone ${timezone}",
    unless      => "/usr/bin/timedatectl | grep 'Time zone: ${timezone}'",
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
    subscribe   => File['/etc/timezone'],
  }

}

