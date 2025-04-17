class profile::firewall (
  Array[Integer] $allowed_ports = [],
) {

  package { ['iptables', 'iptables-persistent']:
    ensure => installed,
  }

  file { '/etc/iptables':
    ensure => directory,
  }

  $allowed_ports.each |$port| {
    exec { "allow-port-${port}":
      command => "iptables -C INPUT -p tcp --dport ${port} -j ACCEPT || iptables -A INPUT -p tcp --dport ${port} -j ACCEPT",
      unless  => "iptables -C INPUT -p tcp --dport ${port} -j ACCEPT",
      path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
      notify  => Exec['save-iptables'],
    }
  }

  exec { 'save-iptables':
    command     => 'iptables-save > /etc/iptables/rules.v4',
    refreshonly => true,
    path        => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

}

