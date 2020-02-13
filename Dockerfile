#
# Collectd compiled from sources
#
FROM python:3.8-alpine3.11 as builder
ARG COLLECTD_VERSION=5.10.0

COPY container-files/bin/* /bin/

RUN apk add --update bison automake autoconf gcc g++ flex libtool git make musl-dev pkgconfig \
       rabbitmq-c-dev mongo-c-driver-dev librdkafka-dev hiredis-dev varnish-dev net-snmp-dev rrdtool-dev postgresql-dev  \
       liboping-dev openldap-dev mariadb-connector-c-dev mosquitto-dev libmemcached-dev \
       grpc-dev libdbi-dev iptables-dev libpcap-dev curl-dev yajl-dev libxml2-dev \
       libcurl grpc protobuf-c libmicrohttpd yajl libxml2 \
    && cd /usr/src \
    && git clone https://github.com/collectd/collectd \
    && cd collectd \
    && git checkout $COLLECTD_VERSION \
    && ./build.sh \
    && bash /bin/collectd-configure.sh \
    && make clean all \
    && make install


#
# Our collectd container
#
FROM python:3.8-alpine3.11

ARG BUILD_DATE=unknown
ARG VERSION=dev
ARG VCS_REF=unknown
ARG COLLECTD_VERSION=5.10.0

LABEL org.opencontainers.image.created="$BUILD_DATE" \
      org.opencontainers.image.ref.name="riotkit/collectd-node-collector" \
      org.opencontainers.image.title="Collectd" \
      org.opencontainers.image.description="Collectd server that aggregates results of other collectd instances and passes to InfluxDB" \
      org.opencontainers.image.documentation="https://riotkit.org" \
      org.opencontainers.image.source="https://github.com/riotkit-org/collectd-collector-node" \
      org.opencontainers.image.url="https://github.com/riotkit-org/collectd-collector-node" \
      org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.authors="RiotKit technical collective" \
      org.riotkit.collectd.version="$COLLECTD_VERSION"

ENV FORWARD_ADDRESS="1.2.3.4" \
    FORWARD_PORT="25826" \
    FORWARD_USER= \
    HOSTNAME=riotkit\
    # Security level - sign, encrypt, none
    FORWARD_SECURITY_LEVEL=Encrypt\
    # Password for the
    FORWARD_PASSWORD=\
    # CPU
    PLUGIN_CPU=0\
    # Disk I/O
    PLUGIN_DISK=1\
    # Disk space
    PLUGIN_DF=1\
    # LOAD AVG.
    PLUGIN_LOAD=1\
    # MEMORY
    PLUGIN_MEMORY=1\
    # SWAP
    PLUGIN_SWAP=1\
    # DOCKER
    PLUGIN_DOCKER=1\
    # NGINX
    PLUGIN_NGINX=0\
    # Network interfaces
    PLUGIN_INTERFACE=1\
    # Syslog log level
    LOG_LEVEL=info \
    # URL to Docker daemon
    DOCKER_URL=unix://var/run/docker.sock \
    # Docker connection timeout
    DOCKER_TIMEOUT=3\
    # URL to NGINX statistics
    NGINX_URL=http://gateway:8433\
    # NGINX statistics username
    NGINX_USER=\
    # NGINX statistics password
    NGINX_PASSWORD=\
    # Network interfaces list, format: "eth0,eth1"
    ENABLED_INTERFACES=

COPY container-files/bin/* /bin/
COPY --from=builder /opt/riotkit /opt/riotkit

RUN addgroup -g 1000 -S riotkit \
    && adduser -u 1000 -S riotkit -G riotkit

RUN pip install --no-cache-dir j2cli \
    && apk add --update bash rsyslog supervisor libcurl grpc protobuf-c libmicrohttpd yajl libxml2 git \
    && chmod +x /bin/entrypoint.sh /bin/collectd-configure.sh

COPY container-files/opt/riotkit/etc/* /opt/riotkit/etc/
COPY container-files/etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

#
# Docker plugin for Collectd
#
RUN mkdir -p /usr/share/collectd/ \
    && cd /usr/share/collectd/ \
    && git clone https://github.com/signalfx/docker-collectd-plugin \
    && cd docker-collectd-plugin \
    && pip install -r ./requirements.txt

RUN mkdir -p /var/log/supervisor/ \
    && cat /usr/share/collectd/docker-collectd-plugin/dockerplugin.db >> /usr/share/collectd/types.db

USER root
ENTRYPOINT ["/bin/entrypoint.sh"]
