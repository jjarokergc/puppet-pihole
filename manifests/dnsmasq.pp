# Class: pihole::dnsmasq
#
# Create configuration files for dnsmasq
#
class pihole::dnsmasq {
  # VARIABLES
  $dm = lookup('pihole::dnsmasq')    # Configuration file directives

  if $dm != undef {
    # For each path...
    $dm.each | Integer $conf_i, Hash $conf | {
      $path = $conf['path']
      $files = $conf['files']

      # For each file within this path...
      $files.each | Integer $file_i, Hash $file | {
        $filename = $file['name']
        $filecomment = "#\n# ${file['comment']}\n#\n# This file is managed by puppet.\n#\n\n"
        $directives = $file['directives']

        $filepath = "${path}/${filename}"

        # Manage the config file
        file { $filepath:
          ensure  => file,
          replace => false,
          content => $filecomment,
          require => Exec['Install Pihole'],
        }

        # For each directive within this file...
        $directives.each | Integer $directive_i, Hash $directive | {
          $entry = "${directive['entry']} \t # ${directive['comment']}"
          $match =$directive['match']

          # Add directives to this config file
          file_line { "${conf_i} ${file_i} ${directive_i}":
            path               => $filepath,
            line               => $entry,
            match              => $match,
            multiple           => false,
            replace            => true,
            append_on_no_match => true,
            require            => File[$filepath],
            notify             => Exec['Sighup piholeFTL'],
          }
        }
      } # ... For each file within this path
    } #... For each path
  }
}
