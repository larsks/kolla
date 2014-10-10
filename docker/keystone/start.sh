#!/bin/bash

. /opt/kolla/kolla-common.sh

: ${KEYSTONE_ADMIN_PASSWORD:=kolla}
: ${KEYSTONE_DB_PASSWORD:=secret}
: ${KEYSTONE_ADMIN_TOKEN:=admintoken}
: ${ADMIN_TENANT_NAME:=admin}

wait_for_mysql

mysql -h ${MARIADB_SERVICE_HOST} -u root -p"${DB_ROOT_PASSWORD}" mysql <<EOF
CREATE DATABASE IF NOT EXISTS keystone;
GRANT ALL PRIVILEGES ON keystone.* TO
    'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DB_PASSWORD}'
EOF

crudini --set /etc/keystone/keystone.conf \
    database \
    connection \
    "mysql://keystone:${KEYSTONE_DB_PASSWORD}@${MARIADB_SERVICE_HOST}/keystone"
crudini --set /etc/keystone/keystone.conf \
    DEFAULT \
    admin_token \
    "${KEYSTONE_ADMIN_TOKEN}"
crudini --del /etc/keystone/keystone.conf \
    DEFAULT \
    log_file
crudini --del /etc/keystone/keystone.conf \
    DEFAULT \
    log_dir
crudini --set /etc/keystone/keystone.conf DEFAULT use_stderr True

/usr/bin/keystone-manage db_sync
/usr/bin/keystone-manage pki_setup --keystone-user keystone --keystone-group keystone

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

/usr/bin/keystone-all &
PID=$!

export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
export SERVICE_ENDPOINT="http://127.0.0.1:35357/v2.0"
SERVICE_ENDPOINT_ADMIN="http://${KEYSTONE_ADMIN_SERVICE_HOST}:35357/v2.0"
SERVICE_ENDPOINT_USER="http://${KEYSTONE_PUBLIC_SERVICE_HOST}:5000/v2.0"

wait_for_keystone

crux user-create --update \
    -n admin -p "${KEYSTONE_ADMIN_PASSWORD}" \
    -t admin -r admin
crux endpoint-create --remove-all \
    -n keystone -t identity \
    -I "${SERVICE_ENDPOINT_USER}" \
    -A "${SERVICE_ENDPOINT_ADMIN}"

kill -TERM $PID

echo "Running keystone service."
exec /usr/bin/keystone-all
