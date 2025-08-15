#!/bin/sh
# Génère le crontab pour supercronic
echo "${PURGE_SCHEDULE} /usr/local/bin/purger.sh" > /tmp/crontab
exec /usr/local/bin/supercronic /tmp/crontab