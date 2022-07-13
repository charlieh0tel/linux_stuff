# Using unbound with bind and isc-dhcp-server for dhcpd and dnyamic DNS behind NAT


## Network configuration

Local domain: foobar.internal

Local networks: 10.0/16 (hosts with static IPs), 10.1/16 (hosts with dhcp address)

IPv6: no

Note: this recipe likely doesn't work properly with IPv6 enabled.

All clients are configured to use unbound for DNS.

Bind is configured to handle for the local static and dynamic domains
(forward and reverse).  DHCP and bind are configured and work in the
usual fashion for dynamic dns.

We separate the static and dynamic forward and reverse domains to keep
bind from modifying thestatic zone files.  (It can all be done
together with a single forward and single reverse domain, but then you
have to be diligent about freezing and thawing the zones and be OK
with the dynamic hosts getting all mixed up with the static hosts.)

The main trick required is to run bind on 127.0.0.2 and configure
unbound to go to bind at that addy for the forward and reverse local
domains.

(You could probably replace bind+dhcpd with dnsmasq, supposing you can
stomach the dnsmasq config file.)


## /etc/unbound/unbound.conf.d/ddns.conf

    server:
            local-zone: "10.in-addr.arpa." nodefault

            private-domain: "foobar.internal"
            domain-insecure: "foobar.internal"

            private-domain: "dyn.foobar.internal"
            domain-insecure: "dyn.foobar.internal"

            domain-insecure: "0.0.10.in-addr.arpa"
            domain-insecure: "1.0.10.in-addr.arpa"

    stub-zone:
            name: "foobar.internal"
            stub-addr: 127.0.0.2

    stub-zone:
            name: "dyn.foobar.internal"
            stub-addr: 127.0.0.2
            stub-no-cache: yes

    stub-zone:
            name: "0.0.10.in-addr.arpa"
            stub-addr: 127.0.0.2

    stub-zone:
            name: "1.0.10.in-addr.arpa"
            stub-addr: 127.0.0.2
            stub-no-cache: yes


## /etc/unbound/unbound.conf.d/server.conf (abridged)

(not sure how much of this is necessary)

    server:
            interface: 127.0.0.1
            interface: $HOSTADDR
            do-not-query-localhost: no
            do-not-query-address: 127.0.0.1/32

            do-ip4: yes
            prefer-ip4: yes
            do-ip6: no
            prefer-ip6: no

## /etc/unbound/unbound.conf.d/private-addresses.conf

    server:
            private-address: 10.0.0.0/8
            private-address: 172.16.0.0/12
            private-address: 192.168.0.0/16
            private-address: 169.254.0.0/16
            private-address: fd00::/8
            private-address: fe80::/10
            private-address: ::ffff:0:0/96

## /etc/network/interfaces (abridged)

    auto lo
    iface lo inet loopback
          post-up ip addr add 127.0.0.2 dev lo


## /etc/default/isc-dhcp-server (abridged)

Only brings up DHCP for IPv4.

    INTERFACESv4="$IFACE"
    INTERFACESv6=""

## /etc/bind/named.conf.local


    include "/etc/bind/dhcp-update.key";

    zone "foobar.internal" {
            type master;
            file "/var/lib/bind/foobar.internal.zone"; 
    };

    zone "0.0.10.in-addr.arpa" {
            type master;
            notify no;
            file "/var/lib/bind/0.0.10.in-addr.arpa.zone"; 
    };

    zone "dyn.foobar.internal" {
            type master;
            allow-update { key "dhcp-update"; };
            file "/var/lib/bind/dyn.foobar.internal.zone"; 
    };

    zone "1.0.10.in-addr.arpa" {
            type master;
            notify no;
            allow-update { key "dhcp-update"; };
            file "/var/lib/bind/1.0.10.in-addr.arpa.zone"; 
    };

## /etc/bind/named.conf.options (abridged)


    options {
            directory "/var/cache/bind";

            listen-on { 127.0.0.2/32; };
            listen-on-v6 { none; };

            dnssec-enable yes;
            dnssec-validation auto;
    };

## /etc/bind/dhcp-update.key

    key dhcp-update {
      // $YOUR_KEYING_MATERIAL.  must match dhcpd config
    }

## /etc/bind/named.conf.default-zones

Delete all but zone ".".   Likely this one can be deleted too.

## /var/lib/bind/foobar.internal.zone

Make a forward zone file for your static hosts.

    $ORIGIN .
    $TTL 86400	; 1 day
    foobar.internal		IN SOA	$NAMESERVER.foobar.internal. root.foobar.internal. (
    				2022052104 ; serial
    				10800      ; refresh (3 hours)
    				3600       ; retry (1 hour)
    				604800     ; expire (1 week)
    				86400      ; minimum (1 day)
    				)

    			NS	$NAMESERVER.foobar.internal.

    $ORIGIN foobar.internal.

    $NAMESERVER	A	10.0.$X.$Y

## /var/lib/bind/0.0.10.in-addr.arpa.zone

Make a reverse zone file for your static hosts.

    $ORIGIN .
    $TTL 86400	; 1 day
    0.0.10.in-addr.arpa		IN SOA	$NAMESERVER.foobar.internal. root.foobar.internal. (
    				2022052104 ; serial
    				10800      ; refresh (3 hours)
    				3600       ; retry (1 hour)
    				604800     ; expire (1 week)
    				86400      ; minimum (1 day)
    				)
    			NS	$NAMESERVER.foobar.internal.


## /var/lib/bind/dyn.foobar.internal.zone

If bind doesn't create this for you, make an empty zone file with just
an SOA for dyn.foobar.internal.  You should never have to touch this
file again.

## /var/lib/bind/1.0.10.in-addr.arpa.zone

If bind doesn't create this for you, make an empty zone file with just
an SOA for 1.0.10.in-addr.arpa.  You should never have to touch this
file again.

## /etc/dhcp/dchpd.conf (abridged)

    ddns-updates on;
    ddns-update-style standard; 
    update-optimization false;
    update-static-leases off;
    ignore client-updates;

    key dhcp-update {
      // $YOUR_KEYING_MATERIAL – must match what bind has.
    }

    subnet 10.0.0.0 netmask 255.255.0.0 {
      authoritative;
      default-lease-time 6000;
      max-lease-time 7200;

      range 10.0.1.1 10.0.1.199;

      option subnet-mask 255.255.0.0;
      option broadcast-address 10.0.255.255;
      option routers $ROUTER_IP;
      option domain-name "foobar.internal";
      option domain-search "foobar.internal", "dyn.foobar.internal";
      option domain-name-servers $NAMESERVER_IP;
      option ntp-servers $NTPSERVER_IP;

      zone 1.0.10.in-addr.arpa. {
        primary 127.0.0.2;
        key dhcp-update;
      }

      zone dyn.foobar.internal. {
        primary 127.0.0.2;
        key dhcp-update;
      }

      ddns-domainname "dyn.foobar.internal.";
      ddns-rev-domainname "in-addr.arpa.";
    }

## How to deal with dumb dhcp clients (often there are many) and how to give a dhcp-enabled host a "static" IP address

Add to /etc/dhcp/dhcpd.conf:

    group {
      use-host-decl-names on;

      # These all call themselves foo.  Make them distinct.
      host foo-bar {
        hardware ethernet $MACADDR1;
        ddns-hostname "foo-bar";
      }
      host foo-baz {
        hardware ethernet $MACADDR2;
        ddns-hostname "foo-baz";
      }

      // Same for hosts that send no name or bad names.

      // N.B. if the hostname is in the static zones, the host
      // will always get the same IP. 
    }

