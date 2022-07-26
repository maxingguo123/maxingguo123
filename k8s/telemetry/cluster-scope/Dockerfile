FROM alpine:latest

RUN apk --no-cache add curl jq bash
RUN apk --no-cache add lshw dmidecode
RUN apk --no-cache add msr-tools --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted
ADD run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT "/run.sh"
