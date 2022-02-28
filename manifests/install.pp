#
# Install Pihole from github
#
class pihole::install {

  # VARIABLES
  $phi = lookup('pihole::install')    # Installation parameters
  $phs = lookup('pihole::setup')      # Setup variables
  $phf = lookup('pihole::ftldns')     # FTLDNS configuration
  $phl = lookup('pihole::list')       # White- and black-lists


  # Network Interface
  $netmask_cidr = extlib::netmask_to_cidr($::netmask)
  $ipv4_address = "${::ipaddress}/${netmask_cidr}"

  # Configuration Files
  $setup_vars_conf = "${phi['path']['config']}/setupVars.conf"

  # Download pihole
  vcsrepo { $phi['path']['download'] :
    ensure   => present,
    provider => git,
    source   => $phi['repo'],
    depth    => 1,
  }

  # Create user and group
  accounts::user { 'pihole':
  uid      => 1998,
  gid      => 1998,
  groups   => ['www-data'],
  password => '!!',
  system   => true,
  shell    => '/usr/sbin/nologin',
  }

  # Pre-seed variables for unattended install
  file {$phi['path']['config']:
    ensure => directory,
    group  => 'pihole',
    owner  => 'pihole',
    mode   => '0775',
  }
  file { 'preseed setupVars' :
    ensure  => present,
    replace => false, # Do not overwrite changes. Future updates manged by file_line below
    path    => $setup_vars_conf,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('pihole/setupVars.conf.epp',
        {
        'phs'          => $phs,
        'ipv4_address' => $ipv4_address,
        }
      ),
    require => File[ $phi['path']['config'] ],
  }

  # Maintain consistent configuration
  # Enforce setupVars
  $phs.each | String $k, String $v | {
    file_line { $k:
      path               => $setup_vars_conf,
      line               => "${k}=${v}",
      multiple           => false, # Should only be one instance of a variable
      replace            => true,
      append_on_no_match => true,
      require            => File[ $phi['path']['config'] ],
      notify             => Exec['Update Pihole']
    }
  }
  # FTLDNS Update pihole-FTL.conf onfiguration file
  $phf.each | String $k, String $v | {
    file_line { $k:
      path               => "${phi['path']['config']}/pihole-FTL.conf",
      line               => "${k}=${v}",
      multiple           => false, # Should only be one instance of a variable
      replace            => true,
      append_on_no_match => true,
      require            => Exec['Install Pihole'],
      notify             => Exec['Sighup piholeFTL']
    }
  }

  # Install pihole
  exec{'Install Pihole':
    path        => '/usr/bin:/usr/sbin:/bin',
    user        => 'root',
    command     => [
        '/bin/bash',
        "${phi['path']['download']}/automated install/basic-install.sh",
        '--unattended',
        ],
    environment => [
        'USER=pihole',
        ],
    creates     => '/usr/local/bin/pihole',
    require     => [
        Vcsrepo[ $phi['path']['download'] ],
        File[ 'preseed setupVars' ],
        ],
  }

  # Restart pihole upon configuration changes
  exec { 'Update Pihole':
    path        => ['/bin/', '/usr/bin', '/usr/local/bin/'],
    command     => 'pihole -g',
    user        => 'root',
    subscribe   => File[ 'preseed setupVars' ],
    refreshonly => true,
  }

  # Restart FTLDNS upon configuration change
  exec { 'Sighup piholeFTL':
    path        => ['/bin/', '/usr/bin', '/usr/local/bin/'],
    command     => 'pkill -SIGRTMIN+0 pihole-FTL',
    user        => 'root',
    refreshonly => true,
  }

  # White and Black Listing
  $phl['white-wild'].each | String $ww | {

    # Form regex version. This is used for the 'unless' match.
    $ww_escape = regexpescape($ww)
    # Grep search string to prefix white-wild string.  This is used for the 'unless' match.
    $wwgrep = "(\.|^)${ww_escape}"

    # Use pihole command to update list
    exec {"White Wildcard ${ww}":
      path    => ['/bin/', '/usr/bin', '/usr/local/bin/'],
      command => "pihole --white-wild '${ww}' --comment 'Managed by Puppet'",
      user    => 'root',
      unless  => "pihole --white-wild --list | grep -F '${wwgrep}'",
      notify  => Exec['Update Pihole'],
      require => Exec['Install Pihole'],
    }
  }

}
