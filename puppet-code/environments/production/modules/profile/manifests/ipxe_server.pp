class profile::ipxe_server {
  include profile::packages
  include profile::timezone
  include profile::logging

  package { ['isc-dhcp-server', 'tftpd-hpa', 'nginx', 'build-essential', 'facter']:
    ensure => installed,
  }

  file { '/srv/tftp':
    ensure => directory,
  }

  file { '/srv/httpboot':
    ensure => directory,
    owner  => 'www-data',
    group  => 'www-data',
  }

  file { '/srv/httpboot/systemrescue':
    ensure => directory,
  }

  file { '/etc/dhcp/dhcpd.conf':
    ensure  => file,
    source  => 'puppet:///modules/profile/ipxe_dhcpd.conf',
    require => Package['isc-dhcp-server'],
    notify  => Service['isc-dhcp-server'],
  }

  file { '/etc/dhcp/mac_filter.conf':
    ensure  => file,
    source  => 'puppet:///modules/profile/ipxe_dhcp_mac_filter.conf',
    replace => false,
  }

  exec { 'download-ipxe-bios':
    command => 'wget https://boot.ipxe.org/ipxe.pxe -O /srv/tftp/ipxe.pxe',
    creates => '/srv/tftp/ipxe.pxe',
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

  exec { 'download-ipxe-efi':
    command => 'wget https://boot.ipxe.org/ipxe.efi -O /srv/tftp/ipxe.efi',
    creates => '/srv/tftp/ipxe.efi',
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

  # Debian12 autoinstaller full automated answer file
  file { '/srv/httpboot/debian12.cfg':
    ensure  => file,
    source  => 'puppet:///modules/profile/pxe_debian12.cfg',
  }

  exec { 'download-and-extract-vmlinuz':
    command => "/bin/bash -c 'cd /tmp && wget http://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/netboot.tar.gz && tar xzf netboot.tar.gz ./debian-installer/amd64/linux -O > /srv/httpboot/vmlinuz && rm -f netboot.tar.gz'",
    creates => '/srv/httpboot/vmlinuz',
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

  exec { 'download-and-extract-initrd':
    command => "/bin/bash -c 'cd /tmp && wget http://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/netboot.tar.gz && tar xzf netboot.tar.gz ./debian-installer/amd64/initrd.gz -O > /srv/httpboot/initrd.gz && rm -f netboot.tar.gz'",
    creates => '/srv/httpboot/initrd.gz',
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

  exec { 'download-and-extract-memtst':
    command => "/bin/bash -c 'cd /tmp && wget https://memtest.org/download/v7.20/mt86plus_7.20.binaries.zip && unzip -j mt86plus_7.20.binaries.zip 'memtest64.bin' -d /srv/httpboot/ && rm -f mt86plus_7.20.binaries.zip'",
    creates => '/srv/httpboot/memtest64.bin',
    path    => ['/usr/sbin', '/sbin', '/usr/bin', '/bin'],
  }

  file { '/etc/puppetlabs/facter/facts.d/dhcp_iface.sh':
    ensure  => file,
    source  => 'puppet:///modules/profile/facts_dhcp_iface.sh',
    mode    => '0755',
  }

  file { '/srv/httpboot/boot.ipxe':
    ensure  => file,
    source  => 'puppet:///modules/profile/ipxe_boot.ipxe',
    notify  => Service['tftpd-hpa'],
    require => Package['tftpd-hpa'],
  }

  file_line { 'TFTP_OPTIONS':
    path    => '/etc/default/tftpd-hpa',
    line    => 'TFTP_OPTIONS="--secure --create"',
    match   => '^\s*TFTP_OPTIONS\s*=\s*".*"$',
    notify  => Service['tftpd-hpa'],
    require => Package['tftpd-hpa'],
  }

  file { '/etc/default/isc-dhcp-server':
    ensure  => file,
    content => template('profile/isc-dhcp-server.erb'),
    require => Package['isc-dhcp-server'],
    notify  => Service['isc-dhcp-server'],
  }

  file { '/etc/nginx/sites-enabled/httpboot':
    ensure  => file,
    source  => 'puppet:///modules/profile/ipxe_nginx_httpboot',
    require => Package['nginx'],
    notify  => Service['nginx'],
  }

  service { 'isc-dhcp-server':
    ensure => running,
    enable => true,
  }

  service { 'tftpd-hpa':
    ensure => running,
    enable => true,
  }

  service { 'nginx':
    ensure => running,
    enable => true,
  }

}

