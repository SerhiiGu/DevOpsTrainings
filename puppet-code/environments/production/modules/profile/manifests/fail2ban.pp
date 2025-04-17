class profile::fail2ban (
  Integer $maxretry      = 3,
  Integer $bantime       = 3600,
  Integer $findtime      = 600,
  String  $log_path = '/root/build/task-3/django/traefik/logs/traefik.log',
) {

  package { 'fail2ban':
    ensure => installed,
  }

  # Значення за замовчуванням для кожного jail
  $default_jail = {
    'enabled'  => true,
    'filter'   => 'default-filter',
    'action'   => 'iptables[name=DEFAULT, port=http, protocol=tcp]',
    'logpath'  => '/var/log/default.log',
    'maxretry' => 3,
  }

  # Lookup custom jails with deep merge
  $custom_jails_raw = lookup('profile::fail2ban::custom_jails', { merge => 'deep', default_value => {} })

  # Робимо merge для кожного jail окремо
  $merged_custom_jails = $custom_jails_raw.reduce({}) |$memo, $pair| {
    $jail_name = $pair[0]
    $params    = $pair[1]
    $memo + { $jail_name => deep_merge($default_jail, $params) }
  }

  file { '/etc/fail2ban/jail.local':
    ensure  => file,
    content => epp('profile/jail.local.epp', {
      maxretry     => $maxretry,
      bantime      => $bantime,
      findtime     => $findtime,
      custom_jails => $merged_custom_jails,
    }),
    notify  => Service['fail2ban'],
  }

  file { '/etc/fail2ban/filter.d/nginx-http-auth.conf':
    ensure  => file,
    content => template('profile/nginx-http-auth.conf.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Service['fail2ban'],
  }

  file { '/etc/fail2ban/filter.d/traefik-dashboard.conf':
    ensure  => file,
    content => epp('profile/traefik-dashboard.conf.epp'),
    notify  => Service['fail2ban'],
  }

  # Cтворення або видалення jails в залежності від наявності лог файлу
  file { '/etc/fail2ban/jail.d/traefik-dashboard.template':
    ensure  => file,
    content => "[traefik-dashboard]\nenabled = true\nfilter = traefik-dashboard\nlogpath = ${log_path}\nmaxretry = ${maxretry}\nfindtime = ${findtime}\nbantime = ${bantime}\n",
  }

  exec { 'enable traefik jail if log exists':
    command => '/bin/cp /etc/fail2ban/jail.d/traefik-dashboard.template /etc/fail2ban/jail.d/traefik-dashboard.conf',
    unless  => "/usr/bin/test -f /etc/fail2ban/jail.d/traefik-dashboard.conf || ! /usr/bin/test -f '${log_path}'",
    notify  => Service['fail2ban'],
  }

  exec { 'remove traefik jail if log does not exist':
    command => '/bin/rm -f /etc/fail2ban/jail.d/traefik-dashboard.conf',
    unless  => "/usr/bin/test ! -f /etc/fail2ban/jail.d/traefik-dashboard.conf || /usr/bin/test -f '${log_path}'",
    notify  => Service['fail2ban'],
  }

  service { 'fail2ban':
    ensure => running,
    enable => true,
    subscribe => File['/etc/fail2ban/jail.local'],
  }
}

