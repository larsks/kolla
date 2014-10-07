#!/bin/bash

[ -f /startconfig ] && . /startconfig

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

: ${PUBLIC_IP:=$MY_IP}
: ${KEYSTONE_ADMIN_PASSWORD:=kolla}
: ${ADMIN_TENANT_NAME:=admin}
: ${KEYSTONE_ADMIN_TOKEN:=ADMINTOKEN}
: ${KEYSTONE_DB_PASSWORD:=secret}
: ${KEYSTONE_ROLE:=minion}

if [ ! -f /startconfig ]; then
    cat > /startconfig <<EOF
PUBLIC_IP=$PUBLIC_IP
KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD
ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME
KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN
KEYSTONE_DB_PASSWORD=$KEYSTONE_DB_PASSWORD
EOF
fi

crudini --set /etc/keystone/keystone.conf \
    DEFAULT \
    public_bind_host \
    ${MY_IP}
crudini --set /etc/keystone/keystone.conf \
    DEFAULT \
    admin_bind_host \
    ${MY_IP}
crudini --set /etc/keystone/keystone.conf \
    database \
    connection \
    "mysql://keystone:${KEYSTONE_DB_PASSWORD}@127.0.0.1/keystone"
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
crudini --set /etc/keystone/keystone.conf \
    DEFAULT \
    use_stderr \
    True
crudini --set /etc/keystone/keystone.conf \
    paste_deploy \
    config_file \
    /usr/share/keystone/keystone-dist-paste.ini

grep -v '^$|^#' /etc/keystone/keystone.conf

if [ "$KEYSTONE_ROLE" = "master" ]; then

    crudini --set /etc/keystone/keystone.conf \
        DEFAULT \
        admin_port \
        35358

    if [ -z "$DB_ROOT_PASSWORD" ]; then
        echo "ERROR: missing DB_ROOT_PASSWORD" >&2
        exit 1
    fi

    # wait for mysql to start
    while !  mysql -h 127.0.0.1 -u root -p${DB_ROOT_PASSWORD} -e "select 1" mysql > /dev/null 2>&1; do
        echo "waiting for mysql..."
        sleep 1
    done

    mysql -h 127.0.0.1 -u root -p"${DB_ROOT_PASSWORD}" mysql <<EOF
CREATE DATABASE IF NOT EXISTS keystone;
GRANT ALL PRIVILEGES ON keystone.* TO
    'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DB_PASSWORD}'
EOF

    /usr/bin/keystone-manage db_sync
    /usr/bin/keystone-manage pki_setup --keystone-user keystone --keystone-group keystone

    /usr/bin/keystone-all &
    PID=$!

    export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
    export SERVICE_ENDPOINT="http://${MY_IP}:35358/v2.0"

    # wait for keystone to become active
    while ! curl -o /dev/null -s --fail ${SERVICE_ENDPOINT}; do
        sleep 1;
    done

    crux user-create -n admin -p "${KEYSTONE_ADMIN_PASSWORD}" -t admin -r admin
    crux endpoint-create -n keystone -t identity \
        -I "http://127.0.0.1:5000/v2.0" \
        -P "http://${PUBLIC_IP}:5000/v2.0" \
        -A "http://127.0.0.1:35357/v2.0"

    kill -TERM $PID
else
    export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
    export SERVICE_ENDPOINT="http://127.0.0.1:35358/v2.0"

    # wait for keystone to become active
    while ! curl -o /dev/null -s --fail ${SERVICE_ENDPOINT}; do
        echo "waiting for keystone..."
        sleep 1;
    done
fi

echo "Running keystone service."
exec /usr/bin/keystone-all
