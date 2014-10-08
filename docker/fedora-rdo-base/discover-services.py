#!/usr/bin/python

'''This creates /etc/hosts files for kubernetes *_SERVICE_HOST environment
variables.'''

import os
import sys
import argparse
import errno
import logging


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--hosts-file', '-f',
                   default='/etc/hosts')
    p.add_argument('--suffix',
                   default='',
                   help='append this suffix to hostnames')
    p.add_argument('--verbose', '-v',
                   action='store_const',
                   const=logging.INFO,
                   dest='loglevel')

    p.set_defaults(loglevel=logging.WARN)
    return p.parse_args()


def discover_services():
    services = {}
    for k, v in os.environ.items():
        if not k.endswith('_SERVICE_HOST'):
            continue

        service_name = k[:-(len('_SERVICE_HOST'))].lower()
        logging.info('discovered service %s at %s',
                     service_name,
                     v)
        services[service_name] = v

    return services


def main():
    args = parse_args()
    logging.basicConfig(
        level=args.loglevel)
    services = discover_services()

    services_by_addr = {}
    for service_name, service_addr in services.items():
        try:
            services_by_addr[service_addr].add(service_name)
        except KeyError:
            services_by_addr[service_addr] = {service_name}

    # lines to write to the hosts file
    hostlines = []

    # a list of addresses we have processed from the hosts file
    seen = set()

    # a set of all discovered service names
    all_names = set(services.keys())

    try:
        with open(args.hosts_file, 'r') as fd:
            for line in fd.readlines():
                line = line.strip()
                if not line:
                    hostlines.append(line)
                elif line.startswith('#'):
                    hostlines.append(line)
                else:
                    addr, names = line.split(None, 1)
                    names = set(names.split())
                    seen.add(addr)

                    names = names.difference(all_names)
                    if addr in services_by_addr:
                        names = names.union(services_by_addr[addr])
                    hostlines.append('%s\t%s' % (
                        addr, ' '.join(names)))
    except IOError as error:
        if error.errno != errno.ENOENT:
            raise

    for service_addr, service_names in services_by_addr.items():
        if service_addr not in seen:
            hostlines.append('%s\t%s' % (
                service_addr,
                ' '.join(service_names)))

    with open(args.hosts_file, 'w') as fd:
        fd.write('\n'.join(hostlines))
        fd.write('\n')


if __name__ == '__main__':
    main()
