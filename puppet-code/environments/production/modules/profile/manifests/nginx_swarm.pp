class profile::nginx_swarm ()
{

  package { ['nginx']:
    ensure => installed,
  }

  file { '/etc/nginx/sites-available/traefik':
    ensure  => file,
    source  => 'puppet:///modules/profile/traefik.nginx',
    mode    => '0644',
    notify  => Service['nginx'],
  }

  exec { 'create_traefik_symlink':
    command     => 'ln -s /etc/nginx/sites-available/traefik /etc/nginx/sites-enabled/traefik',
    creates     => '/etc/nginx/sites-enabled/traefik',
    path        => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
    user        => 'root',
    group       => 'root',
    notify      => Service['nginx'],
  }

  service { 'nginx':
    ensure => running,
    enable => true,
  }


}

