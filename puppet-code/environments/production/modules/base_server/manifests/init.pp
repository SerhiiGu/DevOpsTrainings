class base_server (
  String $hostname = lookup('base_server::hostname'),
  String $ip       = lookup('base_server::ip'),
  String $os       = lookup('base_server::os'),
  Integer $os_ver  = lookup('base_server::os_ver'),
  $server_type = lookup('base_server::type', String, 'first', 'unknown'),
) {

  notify { "Configuring ${hostname} (${ip}) on ${os} ${os_ver} with base type ${server_type}": }

  case $server_type {
    'docker-swarm-manager': {
    }

    'docker-swarm-worker': {
      include puppet_related
    }

    default: {
      notice("No extra config for unknown server type: ${server_type}")
    }
  }

  file { '/root/.vimrc':
    ensure  => file,
    source  => 'puppet:///modules/base_server/vimrc',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

   file { '/etc/puppetlabs/facter':
    ensure => directory,
  }
  file { '/etc/puppetlabs/facter/facts.d':
    ensure => directory,
    require => File['/etc/puppetlabs/facter'],
  }

  user { 'toor':
    ensure   => absent,
    system   => true,
    managehome => false,
  }

  file { '/etc/hostname':
    content => "${hostname}\n",
    notify  => Exec['set-hostname'],
  }

  exec { 'set-hostname':
    command     => "/bin/hostnamectl set-hostname ${hostname}",
    refreshonly => true,
  }

  file_line { 'PermitRootLogin yes':
    path   => '/etc/ssh/sshd_config',
    line   => 'PermitRootLogin yes',
    match  => '^\s*#?\s*PermitRootLogin\s+.*$',
    notify => Service['ssh'],
  }

  service { 'ssh':
    ensure => running,
    enable => true,
 }


}

