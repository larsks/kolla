#!/bin/sh

set -e

. /opt/kolla/config-nova-controller.sh

brctl addbr br-nova
ip link set br-nova up

exec /usr/bin/nova-network
