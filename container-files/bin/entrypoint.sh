#!/bin/bash

set -xe

j2 /opt/riotkit/etc/collectd.conf.j2 > /opt/riotkit/etc/collectd.conf
exec supervisord -n -c /etc/supervisor/supervisord.conf

