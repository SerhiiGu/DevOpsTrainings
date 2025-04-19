class profile::dpkg_repo_server {

  package { ['dpkg-dev', 'nginx']:
    ensure => installed,
  }

#  file { '/var/www/html/deb12-local':
#    ensure => directory,
#  }


  service { 'nginx':
    ensure => running,
    enable => true,
  }


}
