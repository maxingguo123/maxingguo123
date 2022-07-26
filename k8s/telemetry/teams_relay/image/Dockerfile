FROM python:3-alpine

COPY relay.py /relay.py

RUN pip3 install flask
RUN pip3 install requests

ENTRYPOINT ["python", "/relay.py"]
