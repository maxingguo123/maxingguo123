FROM fedora:30

ADD . /
WORKDIR /
RUN dnf install -y python3-pyyaml efibootmgr
RUN chmod +x /*.sh /*.py

ENTRYPOINT ["/Init.sh"]
