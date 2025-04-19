class profile::dpkg_builder_server {

  package { ['build-essential', 'devscripts', 'debhelper', 'dh-make', 'fakeroot', 'lintian', 'equivs']:
    ensure => installed,
  }

}
