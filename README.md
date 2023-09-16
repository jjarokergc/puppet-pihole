# Puppet module to install and configure pihole

The development repository is located at: <https://gitlab.jaroker.org>.  A mirror repository is pushed to: <https://github.com/jjarokergc/puppet-pihole> for public access.

## Installation

Installation of Pi-hole is performed by cloning the installatin script from the github repository, followed by execution of unattended installation.

### Upgrading Pi-hole
This module does not upgrade Pi-hole.  This must be performed manually.  

## Configuration

This module enforces the variables defined in pihole::setup and pihole::ftldns.  

The setupVars.conf template can have more variables defined than those specified in pihole::setup and these will be used in the unattended installation, but these extra variables are managed by Pihole and can be modified via the web interface.  Only the variables specified in pihole::setup and pihole::ftldns will be restored to their defined values at each puppet run.

## Managing pihole custom.list

See example in `collection.pp`.  Nodes use exported resources to report their
ip address and domain name.  The `pihole::collection` class aggregates this (using concat module) and creates the `custom.list` file used by pihole.

## Hiera Data

```yaml
# Clone pihole installation script from git
pihole::install:
  repo: 'https://github.com/pi-hole/pi-hole.git'
  revision: 'v5.17.1'  # Version of script to install; not final pihole version
  path: 
    download: '/tmp/pihole'
    config: '/etc/pihole'

# Parameters in setupVar.conf used in unattended installation and enforced afterwards.
# - Any changes from the admin page to the list below will be overwritten on the next puppet run.
# - Admin-page changes to variables not on this list are managed by pihole
pihole::setup: 
  # WEBPASSWORD: #'<hash of password>'
  PIHOLE_INTERFACE: "%{networking.primary}" # primary listening interface
  DNSMASQ_LISTENING: 'all' # Allow queries from non-local networks (such as VPNs)
  # PIHOLE_DNS_1: '192.168.1.1'       # Router is used for upstream, allowing local DNS
  # PIHOLE_DNS_2: '8.8.4.4'
  # PIHOLE_DNS_3: '208.67.222.222'  # OpenDNS
  # PIHOLE_DNS_4: '208.67.220.220'
  # PIHOLE_DNS_5: '4.2.2.1'         # Level3
  # PIHOLE_DNS_6: '4.2.2.2'
  REV_SERVER: 'true'       # Convert IPs to hostnames by checking with router
  REV_SERVER_CIDR: '192.168.0.0/16'
  REV_SERVER_TARGET: '192.168.1.1'
  REV_SERVER_DOMAIN: ''

pihole::ftldns: # parameters in pihole-FTL.conf
  BLOCKINGMODE: 'NULL' #NULL|IP-NODATA-AAAA|IP|NXDOMAIN¶
  PRIVACYLEVEL: '0' # Show everything
  PIHOLE_PTR: 'HOSTNAMEFQDN' # Host's global hostname

# Pi-hole Lists
# Keys should match the pihole defined lists
# Values are an array of urls to add to the list
# The defined-list keys must have at least one array-element url
pihole::list:
  # white-wild: # Wildcard whitelist for domain and subdomains
  #   - example.com
  # whitelist: # Whitelist domains (no regex)
  #   - atleastone.example.com
  # blacklist:
  #   - atleastone.example.com
  # white-regex:
  #   - atleastone.example.com
  # black-regex:
  #   - atleastone.example.com
  # black-wild:
  #   - atleastone.example.com

# PiHole Local DNS
# See pihole::collection for examples
# If puppetdb is installed, then this resource can be exported by nodes.
# This is useful in homelab environments.
pihole::custom_list:  # DNS entries to add to custom.list
#  example.localdomain: 192.168.1.200
```

## Dependencies

* mod 'puppetlabs-accounts', '8.1.0' 
* mod 'puppetlabs-vcsrepo', '6.1.0'
* mod 'puppetlabs-git', '0.5.0'


## Versions

### 2.0.1
* Update to readme
* Update to dependency

### 2.0.0
* Modified hiera data.  May break version 1.0.0 installations unless the missing data is added to an environment yaml file
* Improvements in handling empty lists, such as "white-list".  These can now be empty.
* Removed unecessary dependency on extlibs.