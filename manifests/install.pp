# Clone Pihole installation script from github at requested version
# Execute installation script to install pihole
#
# NOTE: This does not update an existing pihole installation
#
# Requires
#   mod 'puppetlabs-accounts', '8.1.0' 
#   mod 'puppetlabs-vcsrepo', '6.1.0'
#   mod 'puppetlabs-git', '0.5.0'
#
class pihole::install {
  # VARIABLES
  $phi = lookup('pihole::install')    # Installation parameters
  $phs = lookup('pihole::setup')      # Setup variables
  $phf = lookup('pihole::ftldns')     # FTLDNS configuration
  $phl = lookup('pihole::list')       # White- and black-lists

# Configuration Files
  $setup_vars_conf = "${phi['path']['config']}/setupVars.conf"

# Clone pihole from github 
# This clones the pihole installation script at the specified revision
# This does not update the pihole service
  vcsrepo { $phi['path']['download'] :
    ensure   => latest,
    provider => git,
    revision => $phi['revision'],
    source   => $phi['repo'],
    depth    => 1,
    notify   => Exec['Install Pihole'],
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
  file { $phi['path']['config']:
    ensure => directory,
    group  => 'pihole',
    owner  => 'pihole',
    mode   => '0775',
  }
  file { 'preseed setupVars' :
    ensure  => file,
    replace => false, # Do not overwrite changes. Future updates manged by file_line below
    path    => $setup_vars_conf,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('pihole/setupVars.conf.epp', { 'phs' => $phs, }),
    require => File[$phi['path']['config']],
    notify  => Exec['Update Pihole'],
  }
# Placeholder index.html
  file { '/var/www/html/index.html':
    ensure  => file,
    replace => false,
    content => epp('pihole/index.html.epp', { 'fqdn' => $facts['fqdn'] }),
    require => Exec['Install Pihole'],
  }
# Maintain consistent configuration of variables specified in
# pihole::setup data. GUI changes will be overwritten for all
# variables in this list.
  $phs.each | String $k, String $v | {
    file_line { $k:
      path               => $setup_vars_conf,
      line               => "${k}=${v}",
      match              => "^${k}=",
      multiple           => false, # Should only be one instance of a variable
      replace            => true,
      append_on_no_match => true,
      require            => File['preseed setupVars'],
      notify             => Exec['Update Pihole'],
    }
  }
# FTLDNS Update pihole-FTL.conf onfiguration file
# Maintain consistent configuration of variables specified in
# pihole::ftldns. GUI changes will be overwritten for all
# variables in this list.
  $phf.each | String $k, String $v | {
    file_line { $k:
      path               => "${phi['path']['config']}/pihole-FTL.conf",
      line               => "${k}=${v}",
      match              => "^${k}",
      multiple           => false, # Should only be one instance of a variable
      replace            => true,
      append_on_no_match => true,
      require            => Exec['Install Pihole'],
      notify             => Exec['Sighup piholeFTL'],
    }
  }

# Install pihole
  exec { 'Install Pihole':
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
    #creates     => '/usr/local/bin/pihole',
    refreshonly => true,
    require     => [
      Vcsrepo[$phi['path']['download']],
      File['preseed setupVars'],
    ],
  }

# Restart pihole upon configuration changes
  exec { 'Update Pihole':
    path        => ['/bin/', '/usr/bin', '/usr/local/bin/'],
    command     => 'pihole -g',
    user        => 'root',
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
# For each type of list defined in pihole::list: yaml data structure
  if $phl != undef { # pihole::list is defined in the yaml config file

    $phl.each | String $list_name, Array $list_domain | { # $list_name: pihole white/black list name such as 'white-wild'
      # $list_domain: array of domain names or regex expressions
      # For each domain name within this list

      $phl[$list_name].each | Integer $index, String $dom | { # $integer: array index
        # $dom: domain/regex value in array

        # Form the correct options for the pihole command that updates white/black lists
        case $list_name { # $list_name: must match array name in pihole::list: yaml data
          'whitelist':  # Whitelist domain
            {
              # Grep search string. This is used for the 'unless' match.
              $dom_grep = $dom
              # Pihole command line directive
              $option = '-w'
            }
            'blacklist':  # Blacklist domain
            { fail("NOT IMPLEMENTED '${list_name}'")
              # Pihole command line directive
              $option = '-b'
            }
            'white-regex':# Whitelist domain as regex
            { fail("NOT IMPLEMENTED '${list_name}'")
              # Pihole command line directive
              $option = '--white-regex'
            }
            'white-wild': # Whitelist domain with wildcard subdomains
            {
              # Form regex version. This is used for the 'unless' match.
              $dom_escape = regexpescape($dom)
              # Grep search string to prefix white-wild string.  This is used for the 'unless' match.
              $dom_grep = "(\.|^)${dom_escape}"
              # Pihole command line directive
              $option = '--white-wild'
            }
            'black-regex':# Blacklist domain as regex
            {
              # Grep search string to prefix white-wild string.  This is used for the 'unless' match.
              $dom_grep = $dom
              # Pihole command line directive
              $option = '--regex'
            }
            'black-wild': # Blacklist domain with wildcard subdomains
            { fail("NOT IMPLEMENTED '${list_name}'")
              # Pihole command line directive
              $option = '--wild'
            }
            default:
            { fail("Hiera 'pihole::list' data does not contain array name ${list_name}") }
        } # Case

        # Use pihole command to add the domain to the white/black list
        exec { "${list_name}-${dom}":
          path    => ['/bin/', '/usr/bin', '/usr/local/bin/'],
          command => "pihole ${option} '${dom}' --comment 'Managed by Puppet'",
          user    => 'root',
          unless  => "pihole ${option} --list | grep -iF '${dom_grep}'",
          notify  => Exec['Update Pihole'],
          require => Exec['Install Pihole'],
        } # Exec
      } # For each domain within the list
    } # For each pihole::list element
  } # If pihole::list is defined
}
