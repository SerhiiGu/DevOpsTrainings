class puppet_related() {

  exec { 'symlink puppet':
    command => '/usr/bin/ln -s /opt/puppetlabs/bin/puppet /usr/local/bin/puppet',
    creates => '/usr/local/bin/puppet',
    onlyif  => '/usr/bin/test -f /opt/puppetlabs/bin/puppet',
  }

}

