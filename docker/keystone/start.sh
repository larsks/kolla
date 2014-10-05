#!/bin/bash

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

: ${PUBLIC_IP:=$MY_IP}
: ${KEYSTONE_ADMIN_PASSWORD:=kolla}
: ${ADMIN_TENANT_NAME:=admin}

if ! [ "$KEYSTONE_ADMIN_TOKEN" ]; then
    KEYSTONE_ADMIN_TOKEN=$(openssl rand -hex 15)
fi

if ! [ "$KEYSTONE_DB_PASSWORD" ]; then
    KEYSTONE_DB_PASSWORD=$(openssl rand -hex 15)
fi

if [ ! -f /startconfig ]; then
    cat > /startconfig <<EOF
PUBLIC_IP=$PUBLIC_IP
KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD
ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME
KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN
KEYSTONE_DB_PASSWORD=$KEYSTONE_DB_PASSWORD
EOF
fi

# wait for mysql to start
while !  mysql -h mariadb -u root -p${DB_ROOT_PASSWORD} -e "select 1" mysql > /dev/null 2>&1; do
    echo "waiting for mysql..."
    sleep 1
done

mysql -h mariadb -u root -p${DB_ROOT_PASSWORD} mysql <<EOF
CREATE DATABASE IF NOT EXISTS keystone;
GRANT ALL PRIVILEGES ON keystone.* TO
    'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DB_PASSWORD}'
EOF

crudini --set /etc/keystone/keystone.conf \
    database \
    connection \
    "mysql://keystone:${KEYSTONE_DB_PASSWORD}@mariadb/keystone"
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

cat /etc/keystone/keystone.conf

/usr/bin/keystone-manage db_sync
/usr/bin/keystone-manage pki_setup --keystone-user keystone --keystone-group keystone

/usr/bin/keystone-all &
PID=$!

export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
export SERVICE_ENDPOINT="http://127.0.0.1:35357/v2.0"

# wait for keystone to become active
while ! curl -o /dev/null -s --fail ${SERVICE_ENDPOINT}; do
    sleep 1;
done

crux user-create -n admin -p "${KEYSTONE_ADMIN_PASSWORD}" -t admin -r admin
crux endpoint-create -n keystone -t identity \
    -I "http://keystone:5000/v2.0" \
    -A "http://keystone:35357/v2.0" \
    -P "http://${PUBLIC_IP}:5000/v2.0"

kill -TERM $PID

echo "Running keystone service."
exec /usr/bin/keystone-all
