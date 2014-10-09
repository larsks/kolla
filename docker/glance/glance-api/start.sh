#!/bin/sh

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-glance.sh

check_required_vars KEYSTONE_ADMIN_TOKEN
wait_for_keystone

export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
export SERVICE_ENDPOINT="http://${KEYSTONE_ADMIN_SERVICE_HOST}:35357/v2.0"

crux user-create -n "${GLANCE_KEYSTONE_USER}" \
    -p "${GLANCE_KEYSTONE_PASSWORD}" \
    -t "${ADMIN_TENANT_NAME}" \
    -r admin

crux endpoint-create -n glance -t image \
    -I "http://${GLANCE_API_SERVICE_HOST}:9292" \
    -P "http://${PUBLIC_IP}:9292" \
    -A "http://${GLANCE_API_SERVICE_HOST}:9292"

exec /usr/bin/glance-api
