#!/bin/sh

if ! [ "$KEYSTONE_ADMIN_TOKEN" ]; then
        echo "*** Missing KEYSTONE_ADMIN_TOKEN" >&2
        exit 1
fi

. /opt/glance/config-glance.sh

export SERVICE_TOKEN="${KEYSTONE_ADMIN_TOKEN}"
export SERVICE_ENDPOINT="http://127.0.0.1:35357/v2.0"

while ! curl -sf -o /dev/null "$SERVICE_ENDPOINT"; do
	echo "waiting for keystone..."
	sleep 1
done

crux user-create -n "${GLANCE_KEYSTONE_USER}" \
	-p "${GLANCE_KEYSTONE_PASSWORD}" \
	-t "${ADMIN_TENANT_NAME}" \
	-r admin

crux endpoint-create -n glance -t image \
	-I "http://127.0.0.1:9292" \
	-P "http://${PUBLIC_IP}:9292" \
	-A "http://127.0.0.1:9292"

exec /usr/bin/glance-api
