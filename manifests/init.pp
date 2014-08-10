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
class laravel {

  $nginx = "nginx-light"
  $base = [ $nginx, "php5-cli", "php5-mcrypt", "php5-mysql", "redis-server" ]

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
    listen_mode => 0666,
  }

  #Install composer
  class { ['php::composer', 'php::composer::auto_update']: }

  #Install & Configure Mysql_server

  class { '::mysql::server':
    root_password    => 'root',
    override_options => {'mysqld' => { 'max_connections' => '1024' }}
  }
  
  mysql_database { 'laravel':
    ensure  => 'present',
    charset => 'utf8',
    collate => 'utf8_unicode_ci',
  }
}