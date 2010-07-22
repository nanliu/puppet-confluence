# Class: confluence
#
# Parameters:
#  *Avoid trailing /
#  ${confluence_installdir} 
#  ${confluence_datadir}
#  ${confluence_version}
#  optional: (not implemented)
#  ${confluence_aliasdir} softlink which points to installdir (recommended to maintain multiple versions
#  ${confluence_serverport} default 8000
#  ${confluence_connectorport} default 8080
# 
# Actions:
#  This will install confluence to /usr/local/confluence/ -> ../confluence-{version}/
#
# Requires:
#  puppet-mysql
# Sample Usage:
#

class confluence {
  include mysql::server
  include confluence::params

  # confluence installation defaults
  if $params::confluence_installdir=='' { 
    notice ("params::confluence_installdir unset, assuming /usr/local") 
    $confluence_installdir='/usr/local'
  } else {
    $confluence_installdir=$params::confluence_installdir
  }
  #$confluence_installdir = '/usr/local'
  #$confluence_dir = '/usr/local/confluence'
  #$confluence_datadir = '/usr/local/confluence-data'
  #$confluence_version = 'confluence-3.3-std'
  # mysql database connection info
  #$confluence_database = 'confluence'
  #$confluence_user = 'confluence'
  #$confluence_password = 'puppetrocks'
  
  if $params::confluence_database=='' { 
    notice ("params::confluence_database, assuming confluence") 
    $confluence_database='confluence'
  } else {
    $confluence_database=$params::confluence_database
  }
  if $params::confluence_user=='' { 
    notice ("params::confluence_user, assuming confluence") 
    $confluence_user='confluence'
  } else {
    $confluence_user=$params::confluence_user
  }
  if $params::confluence_password=='' { 
    notice ("params::confluence_password, assuming confluence") 
    $confluence_password='puppetrocks'
  } else {
    $confluence_password=$params::confluence_password
  }

  case $operatingsystem {
    'redhat','centos': { include confluence::redhat }
  }

  package {
    $params::default_packages:
      ensure => present,
  }

  File { owner => root, group => users, mode => 644 }
  Exec { path => "/bin:/sbin:/usr/bin:/usr/sbin" }

  file { "/tmp/confluence-3.3-std.tar.gz":
    source => "puppet:///modules/confluence/confluence-3.3-std.tar.gz",
  }

  file { [ "${params::confluence_installdir}",
           "${params::confluence_datadir}" ]:
    ensure => directory,
  }

  exec { "extract_confluence":
    command => "gtar -xf /tmp/confluence-3.3-std.tar.gz -C ${params::confluence_installdir}",
    require => File [ "${params::confluence_installdir}", 
		      "${params::confluence_datadir}" ],
    subscribe => File [ "/tmp/confluence-3.3-std.tar.gz" ],
    creates => "${params::confluence_installdir}/${params::confluence_version}/confluence",
  }

  file { "${params::confluence_dir}":
    ensure => "${params::confluence_installdir}/${params::confluence_version}",
    require => Exec [ "extract_confluence" ];
  }

  exec { "chown_confluence":
    command => "chown -R root ${params::confluence_installdir}/${params::confluence_version}",
    subscribe => Exec [ "extract_confluence" ],
    refreshonly => true,
  }

  file { "confluence-init.properties":
    name => "${params::confluence_installdir}/${params::confluence_version}/confluence/WEB-INF/classes/confluence-init.properties",
    content => template ('confluence-init.properties.erb'),
    subscribe => Exec [ "extract_confluence" ],
  }

  #file { "server.xml":
  #}

  file { "/etc/init.d/confluence":
    mode => 755,
    content => template ('confluence.erb'),
  }

  service { "confluence":
    enable => true,
    ensure => running,
    hasstatus => true,
    require => File[ "/etc/init.d/confluence" ],
    subscribe => File[ "confluence-init.properties" ];
  }


  # mysql database setup
  file {"/tmp/confluence.sql":
    source => "puppet:///modules/confluence/confluence.sql",
  }

  exec { "create_${confluence_database}":
    command => "mysql -e \"create user '${confluence_user}'@'localhost' \
               identified by '${confluence_password}'; \
	       create database ${confluence_database}; \
               grant all on ${confluence_database}.* to ${confluence_user}@localhost \
	       identified by '${confluence_password}';\"; \
	       mysqlimport ${confluence_database} /tmp/confluence.sql",
    unless => "/usr/bin/mysql ${confluence_database}",
    require => [ Service[ "mysqld" ], 
                 File["/tmp/confluence.sql"] ]; 
  }
}
