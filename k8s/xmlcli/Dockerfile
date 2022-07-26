FROM ubuntu:focal

RUN apt-get -y update
RUN apt-get -y install python3

WORKDIR /xmlcli
COPY pysvtools/ pysvtools/
COPY XmlCliCmd.py XmlCliCmd.py
COPY xmlcli_monitor.sh xmlcli_monitor.sh
RUN chmod +x xmlcli_monitor.sh

ENTRYPOINT ["python3", "XmlCliCmd.py", "environment"]
