class profile::firewall_swarm (
  Array[Integer] $allowed_ports = [],
) {

  file { '/usr/local/bin/firewall_fix_forward_for_docker.sh':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/profile/firewall_swarm_fix_forward_for_docker.sh',
  }

  exec { 'run_fix_iptables_script':
    command     => '/usr/local/bin/firewall_fix_forward_for_docker.sh',
    path        => ['/bin', '/usr/bin', '/usr/local/bin'],
    loglevel    => 'debug',
  }

  exec { "block-port-8900-except-localhost(go-rust project - my )":
    command => "iptables -I FORWARD 1 -p tcp --dport 8900 -m set ! --match-set swarm_allowed_nets src -j DROP || iptables -C FORWARD -p tcp --dport 8900 -m set ! --match-set swarm_allowed_nets src -j DROP",
    unless  => "iptables -C FORWARD -p tcp --dport 8900 -m set ! --match-set swarm_allowed_nets src -j DROP",
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
    require => Exec['create-ipset-swarm_allowed_nets'],
    loglevel    => 'debug',
  }

  exec { "block-port-9100-except-localhost(node-exporter)":
    command => "iptables -I FORWARD 1 -p tcp --dport 9100 -m set ! --match-set swarm_allowed_nets src -j DROP || iptables -C FORWARD -p tcp --dport 9100 -m set ! --match-set swarm_allowed_nets src -j DROP",
    unless  => "iptables -C FORWARD -p tcp --dport 9100 -m set ! --match-set swarm_allowed_nets src -j DROP",
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
    require => Exec['create-ipset-swarm_allowed_nets'],
    loglevel    => 'debug',
  }

  exec { "block-port-8081-except-localhost(cadvisor)":
    command => "iptables -I FORWARD 1 -p tcp --dport 8081 -m set ! --match-set swarm_allowed_nets src -j DROP || iptables -C FORWARD -p tcp --dport 8081 -m set ! --match-set swarm_allowed_nets src -j DROP",
    unless  => "iptables -C FORWARD -p tcp --dport 8081 -m set ! --match-set swarm_allowed_nets src -j DROP",
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
    require => Exec['create-ipset-swarm_allowed_nets'],
    loglevel    => 'debug',
  }

exec { 'create-ipset-swarm_allowed_nets':
  command => '/usr/sbin/ipset create swarm_allowed_nets hash:net',
  unless  => '/usr/sbin/ipset list swarm_allowed_nets',
}

  ['127.0.0.1', '192.168.1.0/24'].each |String $ip| {
    exec { "ipset-add-${ip}":
      command => "/usr/sbin/ipset add swarm_allowed_nets ${ip}",
      unless  => "/usr/sbin/ipset test swarm_allowed_nets ${ip}",
      require => Exec['create-ipset-swarm_allowed_nets'],
    }
  }

}

