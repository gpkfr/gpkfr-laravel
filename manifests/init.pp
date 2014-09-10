# == Class: laravel
#
# Full description of class laravel here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { laravel:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2014 Your name here, unless otherwise noted.
#
class laravel (
  $use_xdebug = false,
  $virtual = $::virtual,
  $remote_host_ip = undef,
  $database_server = "mysql"
)
{
  validate_bool($use_xdebug)

  $xdebug = "php5-xdebug"
  $nginx = "nginx-light"
  $base = [ $nginx, "php5-cli", "php5-mcrypt", "redis-server" ]

  exec { "apt-update": 
    command => "/usr/bin/apt-get update",
  }

  include apt

  apt::source { 'dotdebbase':
    location   => 'http://packages.dotdeb.org',
    release    => 'wheezy',
    repos      => 'all',
    key        => '89DF5277',
    key_source => 'http://www.dotdeb.org/dotdeb.gpg',
  }

  apt::source { 'dotdeb':
  location   => 'http://packages.dotdeb.org',
  release    => 'wheezy-php55',
  repos      => 'all',
  key        => '89DF5277',
  key_source => 'http://www.dotdeb.org/dotdeb.gpg',
  }

  package { $base:
    ensure  => 'latest',
    require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
  }

  include phpfpm

  phpfpm::pool { 'www':
    ensure => 'absent',
  }->phpfpm::pool { 'vagrant':
    listen       => '/var/run/php5-fpm.sock',
    user         => 'vagrant',
    group        => 'vagrant',
    listen_owner => 'vagrant',
    listen_group => 'vagrant',
    listen_mode  => 0666,
  }

  #Install composer
  class { ['php::composer', 'php::composer::auto_update']: }

  if $use_xdebug {
    package { $xdebug:
      ensure => 'latest',
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
    }

    if ($virtual == "VMware") { 
      $xdebug_config=[
        'set xdebug/xdebug.remote_enable 1',
        'set xdebug/xdebug.idekey vagrant',
        'set xdebug/xdebug.remote_handler dbgp',
        'set xdebug/xdebug.remote_port 9000',
        'set xdebug/xdebug.remote_autostart 1',
        'set xdebug/xdebug.remote_connect_back 0',
        "set xdebug/xdebug.remote_host $remote_host_ip",
        'set xdebug/xdebug.remote_log /tmp/xdebug_remote.log',
      ]
    } else {
       $xdebug_config=[
        'set xdebug/xdebug.remote_enable 1',
        'set xdebug/xdebug.idekey vagrant',
        'set xdebug/xdebug.remote_handler dbgp',
        'set xdebug/xdebug.remote_port 9000',
        'set xdebug/xdebug.remote_autostart 1',
        'set xdebug/xdebug.remote_connect_back 1',
        'set xdebug/xdebug.remote_log /tmp/xdebug_remote.log',
      ]
    }

    #Configure Xdebug
    php::fpm::config { "Enable Xdebug":
      file    => '/etc/php5/mods-available/xdebug.ini',
      config  => $xdebug_config,
      require => Package[$xdebug],
    }
  } else {
    package { $xdebug:
      ensure => purged,
    }
  }

  #Install & Configure Mysql_server
  if ( $database_server == "mysql" ) {
    class { '::mysql::server':
      root_password    => 'root',
      override_options => {'mysqld' => { 'max_connections' => '1024' }}
    }

    mysql_database { 'laravel':
      ensure  => 'present',
      charset => 'utf8',
      collate => 'utf8_unicode_ci',
    }

    package { "php5-mysql":
      ensure  => latest,
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']]
    }
  } else {
    $pkgmysql = [ "php5-mysql", "mysql-common" ]
    package { $pkgmysql:
     ensure => purged,
    }
  }

  #Install and configure postgresql
  if ( $database_server == "postgresql" ) {

    class { 'postgresql::server':
      ip_mask_deny_postgres_user => '0.0.0.0/32',
      ip_mask_allow_all_users    => '0.0.0.0/0',
      listen_addresses           => '*',
      postgres_password          => 'vagrant',
      require                    => Exec['apt-update'],
    }

    postgresql::server::db { 'laravel':
      user     => 'root',
      password => postgresql_password('root','root'),
    }

    package { "php5-pgsql":
      ensure  => 'latest',
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']]
    } 
  } else {
      $pkgpgsql = [ "php5-pgsql", "postgresql-client-common", "postgresql-common" ]
      package { $pkgpgsql:
        ensure => purged,
      }
  }

  #Install sqlite3
  if ( $database_server == "sqlite" ) {
    $pkgsqlite = [ "sqlite3", "php5-sqlite" ]
    package { $pkgsqlite:
      ensure  => 'latest',
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']]
    }
  } else {
    $pkgsqlite = [ "sqlite3", "php5-sqlite" ]
    package { $pkgsqlite:
      ensure => 'purged',
    }
  }

#The End
}
