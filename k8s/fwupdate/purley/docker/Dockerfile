FROM debian:buster-slim

RUN apt -y update && \
   apt -y install ipmitool &&\
   apt -y install curl &&\
   apt -y install jq

# Add all the files
COPY temp-dir/*.bin /scripts/firmware.bin
COPY scripts /scripts

WORKDIR /scripts

ENTRYPOINT ["bash", "-c", "/scripts/fwupdate.sh;sleep infinity"]
