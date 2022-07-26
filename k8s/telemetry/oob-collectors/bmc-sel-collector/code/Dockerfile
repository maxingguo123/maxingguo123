FROM python:3.8-buster

ADD pip-requirements.txt /tmp/requirements.txt
ADD app/ /opt/service
RUN pip install --no-cache-dir -r /tmp/requirements.txt

EXPOSE 9666
ENTRYPOINT [ "/usr/local/bin/python3", "/opt/service/process-manager.py" ]
