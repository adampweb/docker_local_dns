FROM localhost:5000/debian-buster-slim


RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y nano procps ca-certificates wget gnupg gnupg2 iputils-ping net-tools \
    && wget -qO - https://www.webmin.com/jcameron-key.asc | apt-key add - \
    && echo "deb https://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y webmin

WORKDIR /etc/webmin

EXPOSE 10000