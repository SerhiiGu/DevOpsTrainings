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

  exec { 'Copy menu.c32 to /srv/tftp/':
    command => '/bin/cp /usr/lib/syslinux/modules/bios/menu.c32 /srv/tftp/',
    unless  => "/usr/bin/test -f /srv/tftp/menu.c32",
  }
  exec { 'Copy libcom32.c32 to /srv/tftp/':
    command => '/bin/cp /usr/lib/syslinux/modules/bios/libcom32.c32 /srv/tftp/',
    unless  => "/usr/bin/test -f /srv/tftp/libcom32.c32",
  }
  exec { 'Copy libutil.c32 to /srv/tftp/':
    command => '/bin/cp /usr/lib/syslinux/modules/bios/libutil.c32 /srv/tftp/',
    unless  => "/usr/bin/test -f /srv/tftp/libutil.c32",
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

  # Debian autoinstaller partitioning script
  file { '/var/www/html/preseed/partitioning.cfg':
    ensure  => file,
    source  => 'puppet:///modules/profile/pxe_partitioning.cfg',
    replace => false,
  }

  # Debian autoinstaller full automated install file
  file { '/var/www/html/preseed/debian12.cfg':
    ensure  => file,
    source  => 'puppet:///modules/profile/pxe_debian12.cfg',
    replace => false,
  }

  file { '/etc/puppetlabs/facter/facts.d/dhcp_iface.sh':
    ensure  => file,
    source  => 'puppet:///modules/profile/facts_dhcp_iface.sh',
    mode    => '0755',
  }

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

