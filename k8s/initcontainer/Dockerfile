FROM fedora:30

ADD . /
WORKDIR /
RUN dnf install -y msr-tools ipmitool python3-pyyaml
RUN chmod +x /*.sh /*.py

ENTRYPOINT ["/runInit.sh"]
