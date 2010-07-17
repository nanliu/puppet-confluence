# Class: confluence
#
# Parameters:
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
#  The initial mysql database will be populated with sensible defaults and mysql database. 
#  
# Requires:
#  mysql
#
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
  if $params::confluence_dir=='' { 
    notice ("params::confluence_dir unset, assuming /usr/local") 
    $confluence_dir='/usr/local/confluence'
  } else {
    $confluence_dir=$params::confluence_dir
  }
  if $params::confluence_datadir=='' { 
    notice ("params::confluence_datadir unset, assuming /usr/local") 
    $confluence_datadir='/usr/local/confluence-data'
  } else {
    $confluence_datadir=$params::confluence_datadir
  }
  if $params::confluence_version=='' { 
    notice ("params::confluence_version unset, assuming /usr/local") 
    $confluence_version='confluence-3.3-std'
  } else {
    $confluence_version=$params::confluence_version
  }

  # mysql configuration 
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

  $confluence_license='PRQrnwjXAxVHQqEgKNqBbeVCXQUANDtnDTALHhIQUqJeKJoxPCLwLnItgcdodwFtaDhWrCPdJDXeItarsXgJGwLcJNjTmhVaomflDHJXJLLCMaMFInTnftDbnfOIGRIPHPnjEFnOVaoVGOqWgtUAJkorxbFUlInStOrTFMFeJjIGOwMSOLqhmqoxhaqxhPDtbgDefaNPEkbkltlgXJJfnqCangLuiLVFiCAkDrUrNSJcaBbPVwDnXeeEAHoPSUuRcTqRbPsPammLjPUacgTpxaPSkCMKrkXcENirgsFXacNtJHCLhrLggNfwAoDECAFuQTGTh2mK6lph2xkqnR38CREwfTsEGT4qe2fgvGvlNhBoRpo&lt;lpom5Q&gt;x592J9qyP&lt;zWKLO49COOXa99MJqL7b1B09CtMCzUYInZ0W5KWjW2txmh3td1HQWNyZEeLQ5J8GKmEBNm6ehzHnBdUfm84cHO9pGdyClpbNAMxkLhtXYbNZHsexpbxYwWg8qGUgwSWhghPwAM8TcV1nQWeGr3D3rPl9QBWRqwTkukLU6ZBs6BZqo7kbzrF6jKc5WCZoce4p6Jpw&gt;Oz6xtLpqRoyQdRjgj3sHpXHFliyMoHEgqfDuXM&lt;&gt;fVEkQ9'

  case $operatingsystem {
    'redhat','centos': { include confluence::redhat }
  }

  package {
    $params::default_packages:
      ensure => present,
  }

  File { owner => '0', group => '0', mode => '0644' }
  Exec { path => "/bin:/sbin:/usr/bin:/usr/sbin" }

  file { "/tmp/confluence-3.3-std.tar.gz":
    source => "puppet:///modules/confluence/confluence-3.3-std.tar.gz",
  }

  file { [ "${confluence_installdir}",
           "${confluence_datadir}" ]:
    ensure => directory,
  }

  exec { "extract_confluence":
    command => "gtar -xf /tmp/confluence-3.3-std.tar.gz -C ${confluence_installdir}",
    require => File [ "${confluence_installdir}", 
		      "${confluence_datadir}" ],
    subscribe => File [ "/tmp/confluence-3.3-std.tar.gz" ],
    creates => "${confluence_installdir}/${confluence_version}/confluence",
  }

  file { "${confluence_dir}":
    ensure => "${confluence_installdir}/${confluence_version}",
    require => Exec [ "extract_confluence" ];
  }

  # confluence package have wrong userid 1418
  exec { "chown_confluence":
    command => "chown -R root ${confluence_installdir}/${confluence_version}",
    subscribe => Exec [ "extract_confluence" ],
    refreshonly => true,
  }

  file { "confluence-init.properties":
    name => "${confluence_installdir}/${confluence_version}/confluence/WEB-INF/classes/confluence-init.properties",
    content => template ("confluence-init.properties.erb"),
    subscribe => Exec [ "extract_confluence" ],
  }

  file { "confluence.cfg.xml":
    name => "${confluence_datadir}/confluence.cfg.xml",
    content => template ("confluence.cfg.xml.erb"),
  }

  #file { "server.xml":
  #}

  file { "/etc/init.d/confluence":
    mode => 755,
    content => template ("confluence.erb"),
  }

  service { "confluence":
    enable => true,
    ensure => running,
    hasstatus => true,
    require => File[ "/etc/init.d/confluence" ],
    subscribe => File[ "confluence-init.properties", "confluence.cfg.xml" ];
  }

  # mysql database setup (onetime)
  file {"/tmp/confluence.sql":
    source => "puppet:///modules/confluence/confluence.sql",
  }

  exec { "create_${confluence_database}":
    command => "mysql -e \"create database ${confluence_database}; \
               grant all on ${confluence_database}.* to '${confluence_user}'@'localhost' \
	       identified by '${confluence_password}';\"; \
	       mysql ${confluence_database} > /tmp/confluence.sql",
    unless => "/usr/bin/mysql ${confluence_database}",
    require => [ Service[ "mysqld" ], 
                 File[ "/tmp/confluence.sql" ] ]; 
  }
}
