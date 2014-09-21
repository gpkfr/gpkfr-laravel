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
# Guillaume Pancak <gpkfr@imelbox.com>
#
# === Copyright
#
# Copyright 2014 Guillaume Pancak, unless otherwise noted.
#
class laravel (
  $use_xdebug = false,
  $use_hhvm = false,
  $npm_pkg = undef,
  $install_beanstalkd = false,
  $install_node = false,
  $install_redis = false,
  $virtual = $::virtual,
  $remote_host_ip = undef,
  $database_server = "mysql",
  $nodejs_version = $::nodejs_stable_version
)
{
  if $virtual == "virtualbox" and $::fqdn == '' {
    $fqdn = "localhost"
  }
  validate_bool($use_xdebug)

  validate_bool($use_hhvm)

  $xdebug = "php5-xdebug"
  $nginx = "nginx-light"
  $base = [ $nginx, "php5-cli", "php5-mcrypt" ]

  if $use_hhvm {
    $phpserver = "hhvm"
  } else {
    $phpserver ="php5-fpm"
  }
  

  include apt

  exec { "apt-update":
    command => "/usr/bin/apt-get update",
    require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb']],
  }


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
    require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec ['apt-update']],
  }

  if $virtual != "VMware" {
    service {"nginx":
      ensure  => running,
      require => [Package[$nginx], Exec['disable_sendfile']],
    }
    exec { 'disable_sendfile':
      command  => 'sed -i -e "s/\(sendfile\).*/\\1 off;/" /etc/nginx/nginx.conf',
      path     => "/bin",
      provider => shell,
      unless   => 'grep -Fxq "sendfile off" /etc/nginx/nginx.conf',
      notify   => Service['nginx'],
      require  => Package[$nginx],
    }
  } else {
    service {"nginx":
      ensure  => running,
      require => Package[$nginx],
    }
  }

  # Install HHVM
  if $use_hhvm {

    apt::source { 'hhvm':
      location    => 'http://dl.hhvm.com/debian',
      release     => 'wheezy',
      repos       => 'main',
      key         => '1BE7A449',
      key_source  => 'http://dl.hhvm.com/conf/hhvm.gpg.key',
      include_src => false,
      notify      => Exec['apt-update'],
    }

    package { 'hhvm':
      ensure  => latest,
      require => Apt::Source['hhvm']
    }
    
    package { 'libmemcachedutil2':
      ensure  => latest,
      before => Package['hhvm'],
    }

    service { 'hhvm':
      ensure  => running,
      require => Package['hhvm'],
      notify  => Service['nginx'],
    }

    exec { 'run_as_user_hhvm':
        command  => 'sed -i -e "s/^[# ]*\(RUN_AS_USER=\"\).*\(\"\)/\\1vagrant\2/" /etc/default/hhvm && sed -i -e "s/^[# ]*\(RUN_AS_GROUP=\"\).*\(\"\)/\\1vagrant\2/" /etc/default/hhvm',
        path     => "/bin",
        provider => shell,
        unless   => 'grep -Fxq "RUN_AS_USER=\"vagrant\"" /etc/default/hhvm',
        notify   => Service['hhvm'],
        require  => Package['hhvm'],
    }


  } else {

    package { 'hhvm':
      ensure => 'purged',
    }

  }

  if ! $use_hhvm {

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
    php::config { "Enable Xdebug":
      file    => '/etc/php5/mods-available/xdebug.ini',
      config  => $xdebug_config,
      require => Package[$xdebug],
      notify  => Service[$phpserver],
    }
  } else {
    package { $xdebug:
      ensure => purged,
      notify => Service[$phpserver],
    }
  }

  #Install & Configure Mysql_server
  if ( $database_server == "mysql" ) {
    class { '::mysql::server':
      root_password    => 'root',
      override_options => {'mysqld' => { 'max_connections' => '1024' }},
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
    }

    mysql_database { 'laravel':
      ensure  => 'present',
      charset => 'utf8',
      collate => 'utf8_unicode_ci',
    }

    package { "php5-mysql":
      ensure  => latest,
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
      notify  => Service[$phpserver],
    }

    file { "/home/vagrant/.my.cnf":
      ensure => present,
      mode => 644,
      owner => 'vagrant',
      group => 'vagrant',
      content => template('laravel/mysql/my.cnf.erb'),
    }
  } else {
    $pkgmysql = [ "php5-mysql", "mysql-common" ]
    package { $pkgmysql:
     ensure => purged,
     notify => Service[$phpserver],
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
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
      notify  => Service[$phpserver],
    }
  } else {
      $pkgpgsql = [ "php5-pgsql", "postgresql-client-common", "postgresql-common" ]
      package { $pkgpgsql:
        ensure => purged,
        notify => Service[$phpserver],
      }
  }

  #Install sqlite3
  if ( $database_server == "sqlite" ) {
    $pkgsqlite = [ "sqlite3", "php5-sqlite" ]
    package { $pkgsqlite:
      ensure  => 'latest',
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
      notify  => Service[$phpserver],
    }
  } else {
    $pkgsqlite = [ "sqlite3", "php5-sqlite" ]
    package { $pkgsqlite:
      ensure => 'purged',
      notify => Service[$phpserver],
    }
  }

  if $install_beanstalkd {
    #beanstalk install
    package { 'beanstalkd':
        ensure => latest,
        before => Exec['activate_beanstalk'],
    }

    service { 'beanstalkd':
        ensure  => running,
        enable  => true,
        require => Exec['activate_beanstalk'],
    }

    exec { 'activate_beanstalk':
        command  => 'sed -i -e "s/^[# ]*\(START=.*\)/\\1/" /etc/default/beanstalkd',
        path     => "/bin",
        provider => shell,
        unless   => 'grep -Fxq "START=yes" /etc/default/beanstalkd',
        notify   => Service['beanstalkd'],
    }

  } else {

    package { 'beanstalkd':
      ensure => purged,
    }
  }

  if $install_redis {
    #Redis-server install
    package { 'redis-server':
      ensure => latest,
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
    }

    package { 'php5-redis':
      ensure => latest,
      require => [Apt::Source['dotdebbase'], Apt::Source ['dotdeb'], Exec [ 'apt-update']],
      notify => Service[$phpserver],
    }

    service { 'redis-server':
      ensure  => running,
      enable  => true,
      require => Package['redis-server'],
    }

  } else {
    package { 'redis-server':
      ensure => purged,
    }
    package { 'php5-redis':
      ensure => purged,
      notify => Service[$phpserver],
    }
  }


  if $install_node {
    notice("is nodejs Required ?")

    if $::version_nodejs_installed != $nodejs_version {
      notice ("Install NodeJS version : {$nodejs_version}. Please, be Patient")
      class { 'nodejs':
        version => $nodejs_version,
      }->file { "/usr/local/bin/node":
        ensure  => link,
        target  => '/usr/local/node/node-default/bin/node',
      }->file { "/usr/local/bin/npm":
        ensure  => link,
        target  => '/usr/local/node/node-default/bin/npm',
      }


      if $npm_pkg != undef {
        package { $npm_pkg:
          provider => npm,
          require  => [Class['nodejs'], File['/usr/local/bin/npm']],
        }
      }
    }

    if $::version_nodejs_installed {

      notice ("Nodejs already installed")

      file { "/usr/local/bin/node":
        ensure  => link,
        target  => '/usr/local/node/node-default/bin/node',
      }

      file { "/usr/local/bin/npm":
        ensure  => link,
        target  => '/usr/local/node/node-default/bin/npm',
      }


      if $npm_pkg != undef {
        package { $npm_pkg:
        provider => npm,
        require  => File['/usr/local/bin/npm'],
        }
      }
    }
  }

#The End
}
