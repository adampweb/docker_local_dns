FROM debian:buster-slim AS debian-base


RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y man nano procps ca-certificates wget gnupg gnupg2 iputils-ping net-tools supervisor

FROM debian-base AS webmin-base

RUN set -x \
    && wget -qO - https://www.webmin.com/jcameron-key.asc | apt-key add - \
    && echo "deb https://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y webmin

WORKDIR /etc/webmin

EXPOSE 10000

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]

FROM webmin-base AS webmin-ssl

# Configure OpenSSL...
ADD ssl/create-ssl.sh /
RUN chmod +x /create-ssl.sh

ADD ssl/root-openssl.cnf /root/ca/openssl.cnf

ADD ssl/intermediate-openssl.cnf /root/ca/intermediate/openssl.cnf

ADD ssl/site-openssl.cnf /root/ca/intermediate/site-openssl.cnf

ADD ssl/site-openssl-original.cnf /root/ca/intermediate/site-openssl-original.cnf