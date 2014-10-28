define laravel::vhost (
  $server_name = $name,
  $root_dir = '/var/www',
  $nginx = $::laravel::nginx,
  $use_hhvm = $::laravel::use_hhvm
){
  if ! defined(Class['laravel']) {
    fail('You must include the laravel base class before using any laravel defined resources')
  }

  if ! $use_hhvm {
    file { "/etc/nginx/sites-available/${server_name}":
      ensure   => file,
      mode     => 644,
      owner    => 'root',
      group    => 'root',
      content  => template('laravel/vhost2.erb'),
      require  => Package[$nginx],
    }
  } else {
    file { "/etc/nginx/sites-available/${server_name}":
      ensure   => file,
      mode     => 644,
      owner    => 'root',
      group    => 'root',
      content  => template('laravel/vhost_hhvm.erb'),
      require  => Package[$nginx],
    }
  }

  file { "/etc/nginx/sites-enabled/${server_name}":
    ensure  => link,
    target  => "/etc/nginx/sites-available/${server_name}",
    require => File["/etc/nginx/sites-available/${server_name}"],
    notify  => Service["nginx"],
  }


if ! defined(File["/etc/nginx/sites-enabled/default"]) {
    file {"/etc/nginx/sites-enabled/default":
      ensure  => absent,
      require => Package[$nginx],
      notify  => Service["nginx"],
    }
  }
}
