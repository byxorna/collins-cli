collins-cli
===========

CLI scripts for interacting with Collins API

[![Gem Version](https://badge.fury.io/rb/collins-cli.svg)](http://badge.fury.io/rb/collins-cli)
[![Build Status](https://travis-ci.org/byxorna/collins-cli.png?branch=master)](https://travis-ci.org/byxorna/collins-cli)

## Overview

```collins-cli``` uses the ```collins_auth``` gem for authentication, so it relies on you either typing in your credentials every time, or setting up a ~/.collins.yml file. The base format for the config file is as follows:

    ---
    host: https://collins.iata.company.com
    username: myuser
    # omit password to have collins auth prompt you
    password: mypass

(see https://github.com/tumblr/collins/tree/master/support/ruby/collins-auth for more details)

Main entry point is the ```collins``` binary:

    $ collins -h
    Usage: collins <command> [options]
    Available commands:
      query, find:        Search for assets in Collins
      modify, set:        Add and remove attributes, change statuses, and log to assets
      log:                Display log messages on assets
      provision:          Provision assets
      power:              Control and show power status
      ip, address, ipmi:  Allocate IPs, update IPMI info

## Find Assets - collins find

Use ```collins find``` to quickly construct complex queries of your assets in Collins. Bonus points for piping the output of ```collins find``` into another program.

    $ collins find -h
    Usage: collins find [options] [hostnamepattern]
    Query options:
        -t, --tag TAG[,...]              Assets with tag[s] TAG
        -T, --type TYPE                  Only show assets with type TYPE
        -n, --nodeclass NODECLASS[,...]  Assets in nodeclass NODECLASS
        -p, --pool POOL[,...]            Assets in pool POOL
        -s, --size SIZE                  Number of assets to return (Default: 9999)
        -r, --role ROLE[,...]            Assets in primary role ROLE
        -R, --secondary-role ROLE[,...]  Assets in secondary role ROLE
        -i, --ip-address IP[,...]        Assets with IP address[es]
        -S STATUS[:STATE][,...],         Asset status (and optional state after :)
            --status
        -a attribute[:value[,...]],      Arbitrary attributes and values to match in query. : between key and value
            --attribute
    
    Table formatting:
        -H, --show-header                Show header fields in output
        -c, --columns ATTRIBUTES         Attributes to output as columns, comma separated (Default: tag,hostname,nodeclass,status,pool,primary_role,secondary_role)
        -x, --extra-columns ATTRIBUTES   Show these columns in addition to the default columns, comma separated
        -f, --field-separator SEPARATOR  Separator between columns in output (Default:      )
    
    Robot formatting:
        -l, --link                       Output link to assets found in web UI
        -j, --json                       Output results in JSON (NOTE: This probably wont be what you expected)
        -y, --yaml                       Output results in YAML
    
    Extra options:
            --expire SECONDS             Timeout in seconds (0 == forever)
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help
    
    Examples:
        Query for devnodes in DEVEL pool that are VMs
          cf -n develnode -p DEVEL
        Query for asset 001234, and show its system_password
          cf -t 001234 -x system_password
        Query for all decommissioned VM assets
          cf -a is_vm:true -S decommissioned
        Query for hosts matching hostname '^web6-'
          cf ^web6-
        Query for all develnode6 nodes with a value for PUPPET_SERVER
          cf -n develnode6 -a puppet_server -H

## View Logs - collins log

Pipe the output of ```collins find``` into ```collins log``` to pull recent logs, or tail logs. Very useful while watching provisioning. Reads asset tags from ARGF if ```--tags``` aren't provided.

    Usage: collins-log [options]
        -a, --all                        Show logs from ALL assets
        -n, --number LINES               Show the last LINES log entries. (Default: 20)
        -t, --tags TAGS                  Tags to work on, comma separated
        -f, --follow                     Poll for logs every 2 seconds
        -s, --severity SEVERITY[,...]    Log severities to return (Defaults to all). Use !SEVERITY to exclude one.
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help
    
    Severities:
      EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG, NOTE
    
    Examples:
      Show last 20 logs for an asset
        collins-log -t 001234
      Show last 100 logs for an asset
        collins-log -t 001234 -n100
      Show last 10 logs for 2 assets that are ERROR severity
        collins-log -t 001234,001235 -n10 -sERROR
      Show last 10 logs all assets that are not note or informational severity
        collins-log -a -n10 -s'!informational,!note'
      Show last 10 logs for all web nodes that are provisioned having verification in the message
        cf -S provisioned -n webnode$ | collins-log -n10 -s debug | grep -i verification

## Modification - collins modify

Pipe the output of ```collins find``` into ```collins modify``` to change statuses, create and delete attributes, write log messages, etc. Reads asset tags from ARGF if ```--tags``` aren't provided.

    Usage: collins modify [options]
        -a attribute:value,              Set attribute=value. : between key and value. attribute will be uppercased.
            --set-attribute
        -d, --delete-attribute attribute Delete attribute.
        -S, --set-status status[:state]  Set status (and optionally state) to status:state. Requires --reason
        -r, --reason REASON              Reason for changing status/state.
        -l, --log MESSAGE                Create a log entry.
        -L, --level LEVEL                Set log level. Default level is NOTE.
        -t, --tags TAGS                  Tags to work on, comma separated
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help
    
    Allowed values (uppercase or lowercase is accepted):
      Status (-S,--set-status):
        ALLOCATED, CANCELLED, DECOMMISSIONED, INCOMPLETE, MAINTENANCE, NEW, PROVISIONED, PROVISIONING, UNALLOCATED
      States (-S,--set-status):
        ALLOCATED ->
          CLAIMED, SPARE, RUNNING_UNMONITORED, UNMONITORED
        MAINTENANCE ->
          AWAITING_REVIEW, HARDWARE_PROBLEM, HW_TESTING, HARDWARE_UPGRADE, IPMI_PROBLEM, MAINT_NOOP, NETWORK_PROBLEM, RELOCATION, PROVISIONING_PROBLEM
        ANY ->
          RUNNING, STARTING, STOPPING, TERMINATED
      Log levels (-L,--level):
        EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG, NOTE
    
    Examples:
      Set an attribute on some hosts:
        collins modify -t 001234,004567 -a my_attribute:true
      Delete an attribute on some hosts:
        collins modify -t 001234,004567 -d my_attribute
      Delete and add attribute at same time:
        collins modify -t 001234,004567 -a new_attr:test -d old_attr
      Set machine into maintenace noop:
        collins modify -t 001234 -S maintenance:maint_noop -r "I do what I want"
      Set machine back to allocated:
        collins modify -t 001234 -S allocated:running -r "Back to allocated"
      Set machine back to new without setting state:
        collins modify -t 001234 -S new -r "Dunno why you would want this"
      Create a log entry:
        collins modify -t 001234 -l'computers are broken and everything is horrible' -Lwarning
      Read from stdin:
        cf -n develnode | collins modify -d my_attribute
        cf -n develnode -S allocated | collins modify -a collectd_version:5.2.1-52
        echo -e "001234\n001235\n001236"| collins modify -a test_attribute:'hello world'

## Provision - collins provision

Pipe the output of ```collins find``` into ```collins provision``` to provision assets. Reads asset tags from ARGF if ```--tags``` aren't provided.

    $ collins provision -h
    Usage: collins provision [options]

        -n, --nodeclass NODECLASS        Nodeclass to provision as. (Required)
        -p, --pool POOL                  Provision with pool POOL.
        -r, --role ROLE                  Provision with primary role ROLE.
        -R, --secondary-role ROLE        Provision with secondary role ROLE.
        -s, --suffix SUFFIX              Provision with suffix SUFFIX.
        -a, --activate                   Activate server on provision (useful with SL plugin) (Default: ignored)
        -b, --build-contact USER         Build contact. (Default: gabe)

    General:
        -t, --tags TAG[,...]             Tags to work on, comma separated
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help

    Examples:
      Provision some machines:
        collins find -Sunallocated -arack_position:716|collins provision -P -napiwebnode6 -RALL

## Power Management - collins power

Manage and show power states with ```collins power```

    $ collins power -h
    Usage: collins power [options]
    
        -s, --status                     Show IPMI power status
        -p, --power ACTION               Perform IPMI power ACTION
    
    General:
        -t, --tags TAG[,...]             Tags to work on, comma separated
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help
    
    Examples:
      Reset some machines:
        collins power -t 001234,003456,007895 -p reboot

## IPAM - collins ip

Allocate and delete addresses, and show what address pools are configured in Collins.

    Usage: collins ipam [options]
    
        -s, --show-pools                 Show IP pools
        -H, --show-header                Show header fields in --show-pools output
        -a, --allocate POOL              Allocate addresses in POOL
        -n, --number [NUM]               Allocate NUM addresses (Defaults to 1 if omitted)
        -d, --delete [POOL]              Delete addresses in POOL. Deletes ALL addresses if POOL is omitted
    
    General:
        -t, --tags TAG[,...]             Tags to work on, comma separated
        -C, --config CONFIG              Use specific Collins config yaml for Collins::Client
        -h, --help                       Help
    
    Examples:
      Show configured IP address pools:
        collins ipam --show-pools -H
      Allocate 2 IPs on each asset
        collins ipam -t 001234,003456,007895 -a DEV_POOL -n2
      Deallocate IPs in DEV_POOL pool on assets:
        collins ipam -t 001234,003456,007895 -d DEV_POOL
      Deallocate ALL IPs on assets:
        collins ipam -t 001234,003456,007895 -d

## TODO

* Implement IPMI stuff in collins-ipmi
* Share code between binaries more
* Write some tests
