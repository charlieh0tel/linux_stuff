#!/usr/bin/python

import ipaddress
import json
import sys

DOMAIN="murgatroid.com"

class MacAddress(object):
    def __init__(self, bytes):
        self._bytes = bytes
        
    @classmethod
    def Parse(cls, s):
        bytes = map(lambda x: int(x, 16), s.split(":"))
        assert len(bytes) == 6
        return MacAddress(bytes)

    def __str__(self):
        return ":".join("%02X" % x for x in self._bytes)

    def __repr__(self):
        return ("MacAddress([" + ",".join("0x%02X" % x for x in self._bytes)
                + "])")

    def __cmp__(self, other):
        return cmp(self._bytes, other._bytes)

def FQDN(s):
    s = s.lower()
    if (s.find(".") == -1):
        return s + "." + DOMAIN
    else:
        return s

def Hostname(fqdn):
    first_dot = fqdn.find(".")
    assert first_dot != -1
    return fqdn[:first_dot]

def CookOne(json):
    d = dict()
    try:
        d['fqdn'] = FQDN(json['name'])
        d['mac_addr'] = [MacAddress.Parse(s) for s in json['mac_addr']]
        d['ip'] = map(ipaddress.ip_address, json.get('ip', []))
        d['aliases'] = map(FQDN, json.get('aliases', []))
        d['old'] = json.get('old', False)
        d['mobile'] = json.get('mobile', False)
    except Exception, e:
        print "error %s on %s" % (e, json)
        assert False
    return d

def Cook(raw_json_db):
    db = map(CookOne, raw_json_db)
    return db

def VerifyDb(db):
    fqdns = set()
    hostnames = set()
    mac_addrs = set()
    ip_addrs = set()
    warnings = 0
    for host in db:
        fqdn = host['fqdn']
        if fqdn in fqdns:
            print "WARNING: fqdn duplicate: ", fqdn
            warnings += 1
        else:
            fqdns.add(fqdn)
        hostname = Hostname(fqdn)
        if hostname in hostnames:
            print "WARNING: hostname duplicate: ", hostname
            warnings += 1
        else:
            hostnames.add(hostname)
        for mac_addr in host['mac_addr']:
            if mac_addr in mac_addrs:
                print "WARNING: duplicate mac: ", fqdn
                warnings += 1
            else:
                mac_addrs.add(mac_addr)
        for ip in host['ip']:
            if ip in ip_addrs:
                print "WARNING: duplicate ip: ", ip
                warnings += 1
            else:
                ip_addrs.add(ip)
    return warnings

def Load(pathname):
    with open("db.json", "r") as f:
        raw_json_db = json.load(f)
    return Cook(raw_json_db)

def GenerateEthers(db):
    s = []
    for host in sorted(db, key=lambda v: v.get('mac_addr', [])):
        fqdn = host['fqdn']
        for mac in host['mac_addr']:
            line = "%s %s" % (mac, fqdn)
            for alias in host['aliases']:
                line += " %s" % alias
            s.append(line)
    return "\n".join(s)

def GenerateDHCPD(db):
    s = []
    for host in sorted(db, key=lambda v: v.get('ip', [])):
        if host['old'] or host['mobile']:
            next
        fqdn = host['fqdn']
        hostname = Hostname(fqdn)
        for mac in host['mac_addr']:
            if len(host['ip']) == 1:
                s.append("  host %s {\n    hardware "
                         "ethernet %s;\n    fixed-address %s;\n  }"
                         % (hostname, mac, host['ip'][0]))
    return ("group {\n  use-host-decl-names on;\n" +
            "\n".join(s) +
            "\n}")

def GenerateZone(db):
    s = []
    for host in sorted(db, key=lambda v: v.get('ip', [])):
        if host['old']:
            next
        fqdn = host['fqdn']
        for ip in host['ip']:
            s.append("%s.\t\tA\t%s" % (fqdn, ip))
    return "\n".join(s)

def GenerateReverseZone(db):
    s = []
    for host in sorted(db, key=lambda v: v.get('ip', [])):
        if host['old']:
            next
        fqdn = host['fqdn']
        for ip in host['ip']:
            s.append("%s.\t\tA\t%s." % (ip.reverse_pointer, fqdn))
    return "\n".join(s)

def Main(argv):
    db = Load("db.json")
    print "Verifying database..."
    n_warnings = VerifyDb(db)
    assert(n_warnings == 0)
    with open("out/ethers", "w") as f:
        print >>f, GenerateEthers(db)
    with open("out/dhcpd.conf", "w") as f:
        print >>f, GenerateDHCPD(db)
    with open("out/dns.zone", "w") as f:
        print >>f, GenerateZone(db)
    with open("out/dns_reverse.zone", "w") as f:
        print >>f, GenerateReverseZone(db)

if __name__ == "__main__":
    Main(sys.argv)
