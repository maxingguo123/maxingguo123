FROM rockylinux:8

RUN dnf install -y epel-release
RUN dnf install -y python3 msr-tools
RUN pip3 install inotify pyyaml

ADD msr-monitor.py /usr/bin/
RUN chmod +x /usr/bin/msr-monitor.py

ENTRYPOINT ["python3", "-u", "/usr/bin/msr-monitor.py"]
