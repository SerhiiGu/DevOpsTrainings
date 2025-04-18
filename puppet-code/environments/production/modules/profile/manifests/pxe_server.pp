class profile::pxe_server {
  include profile::packages
  include profile::timezone


  package { ['tftpd-hpa', 'isc-dhcp-server', 'nginx', 'syslinux', 'pxelinux', 'facter']:
    ensure => installed,
  }

  file { '/srv/tftp/pxelinux.cfg':
    ensure => directory,
  }

  file { '/var/www/html/preseed':
    ensure => directory,
  }

  file { '/var/www/html/debian-installer':
    ensure => directory,
  }

  file { '/var/www/html/rescue':
    ensure => directory,
  }

  exec { 'Copy pxelinux.0 to /srv/tftp/':
    command => '/bin/cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/',
    unless  => "/usr/bin/test -f /srv/tftp/pxelinux.0",
  }

  exec { 'Copy ldlinux.c32 to /srv/tftp/':
    command => '/bin/cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/',
    unless  => "/usr/bin/test -f /srv/tftp/ldlinux.c32",
  }

  file { '/srv/tftp/pxelinux.cfg/default':
    ensure  => file,
    source  => 'puppet:///modules/profile/pxelinux.cfg.default',
  }

  file { '/etc/dhcp/dhcpd.conf':
    ensure  => file,
    source  => 'puppet:///modules/profile/dhcpd.conf',
  }

  file { '/etc/dhcp/mac_filter.conf':
    ensure  => file,
    source  => 'puppet:///modules/profile/dhcp_mac_filter.conf',
    replace => false,
  }

  file { '/var/www/html/preseed/partitioning.cfg':
    ensure  => file,
    source  => 'puppet:///modules/profile/pxe_partitioning.cfg',
    replace => false,
  }

  file { '/etc/puppetlabs/facter/facts.d/dhcp_iface.sh':
    ensure  => file,
    source  => 'puppet:///modules/profile/facts_dhcp_iface.sh',
    mode    => '0755',
  }

#  $dhcp_iface = $facts['dhcp_iface']
  file { '/etc/default/isc-dhcp-server':
    ensure  => file,
    content => template('profile/isc-dhcp-server.erb'),
    require => Package['isc-dhcp-server'],
    notify  => Service['isc-dhcp-server'],
  }

  service { 'isc-dhcp-server':
    ensure => running,
    enable => true,
  }

}

