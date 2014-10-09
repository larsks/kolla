#!/bin/sh

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-glance.sh

wait_for_mysql

mysql -h ${MARIADB_PORT_3306_TCP_ADDR} -u root -p${DB_ROOT_PASSWORD} mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${GLANCE_DB_NAME} DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON ${GLANCE_DB_NAME}.* TO
       '${GLANCE_DB_USER}'@'%' IDENTIFIED BY '${GLANCE_DB_PASSWORD}'

EOF

/usr/bin/glance-manage db_sync

exec /usr/bin/glance-registry
