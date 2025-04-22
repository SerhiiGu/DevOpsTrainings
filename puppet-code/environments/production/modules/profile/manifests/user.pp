class profile::user {

  user { 'deployer':
    ensure     => present,
    managehome => true,
    groups     => ['sudo'],
    shell      => '/bin/bash',
  }

  file { ['/home/deployer/.ssh']:
    ensure => directory,
    owner  => 'deployer',
    group  => 'deployer',
    mode   => '0644',
  }

  file { ['/home/deployer/.ssh/authorized_keys']:
    ensure  => file,
    content => hiera('deployer_ssh_key'),
    owner   => 'deployer',
    group   => 'deployer',
    mode    => '0400',
    require => File['/home/deployer/.ssh'],
  }


}
