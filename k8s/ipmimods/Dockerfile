FROM fedora:33

RUN dnf install -y ipmitool
ADD set-fan-speed.sh /

ENTRYPOINT ["/bin/bash"]
