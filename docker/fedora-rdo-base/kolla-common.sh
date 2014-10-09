#!/bin/bash

check_required_vars() {
    for var in $*; do
        if [ -z "${!var}" ]; then
            echo "ERROR: missing $var" >&2
            exit 1
        fi
    done
}

wait_for_glance() {
    check_required_vars GLANCE_API_SERVICE_HOST

    GLANCE_API_URL="http://${GLANCE_API_SERVICE_HOST}:9292/"

    while ! curl -sf -o /dev/null "$GLANCE_API_URL"; do
        echo "waiting for glance @ $GLANCE_API_URL"
        sleep 1
    done

    echo "glance is active @ $GLANCE_API_URL"
}

wait_for_keystone() {
    check_required_vars KEYSTONE_PUBLIC_SERVICE_HOST

    KEYSTONE_URL="http://${KEYSTONE_PUBLIC_SERVICE_HOST}:5000/v2.0"

    while ! curl -sf -o /dev/null "$KEYSTONE_URL"; do
        echo "waiting for keystone @ $KEYSTONE_URL"
        sleep 1
    done

    echo "keystone is active @ $KEYSTONE_URL"
}

wait_for_mysql() {
    check_required_vars MARIADB_SERVICE_HOST DB_ROOT_PASSWORD

    while !  mysql -h ${MARIADB_SERVICE_HOST} -u root -p"${DB_ROOT_PASSWORD}" \
            -e "select 1" mysql > /dev/null 2>&1; do
        echo "waiting for database @ ${MARIADB_SERVICE_HOST}"
        sleep 1
    done

    echo "database is active @ ${MARIADB_SERVICE_HOST}"
}

