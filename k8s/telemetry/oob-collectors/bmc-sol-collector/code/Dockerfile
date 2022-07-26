FROM ubuntu:18.04

ADD pip-requirements.txt /tmp/requirements.txt
ADD service-code/ /opt/sol-collector
RUN adduser --system --uid 42 websock && \
    apt-get update && \
    apt-get install -y vim python3-pip net-tools lsof ipmitool libgpgme-dev swig less vim && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt

EXPOSE 9666
USER websock
ENTRYPOINT [ "/usr/bin/python3", "/opt/sol-collector/sol-collector.py" ]
