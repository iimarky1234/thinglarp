#!/bin/sh
set -e

# Substitute environment variables into mosquitto.conf
awk -v db="${POSTGRES_DB:-iot}" \
    -v pw="${PG_MQTT_AUTH_PASSWORD}" \
    '{
        gsub(/\$\{POSTGRES_DB\}/, db);
        gsub(/\$\{PG_MQTT_AUTH_PASSWORD\}/, pw);
        print;
    }' /etc/mosquitto/mosquitto.conf.template > /etc/mosquitto/mosquitto.conf

exec /usr/bin/tini -- /usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
