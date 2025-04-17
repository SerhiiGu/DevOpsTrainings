#!/bin/bash

CHAIN="FORWARD"
EXPECTED_RULES=("DOCKER-USER" "DOCKER-FORWARD")
CRON_CMD="/usr/local/bin/puppet agent -t"
CRON_TAG="# puppet-trigger"


fix_rules() {
    /usr/sbin/iptables -F $CHAIN

    # Insert rules in correct order
    /usr/sbin/iptables -A $CHAIN -j DOCKER-USER
    /usr/sbin/iptables -A $CHAIN -j DOCKER-FORWARD
}

add_cron_job() {
    (crontab -l 2>/dev/null | grep -v "$CRON_TAG"; echo "*/2 * * * * $CRON_CMD $CRON_TAG") | crontab -
}

remove_cron_job() {
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab -
}

### main ###
LAST=`/usr/sbin/iptables -L FORWARD | tail -1 | grep -E 'DOCKER-(USER|FORWARD)' | wc -l`
BEFORE_LAST=`/usr/sbin/iptables -L FORWARD | tail -2 | head -1 | grep -E 'DOCKER-(USER|FORWARD)' | wc -l`
echo LAST=${LAST} BEFORE_LAST=${BEFORE_LAST}
if [[ "${LAST}" -eq "0" || "${BEFORE_LAST}" -eq "0" ]]; then
echo fix_rules
    fix_rules
fi

exit 0
