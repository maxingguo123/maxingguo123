FROM python:3.8-slim-buster

RUN mkdir -p /cluster-health
COPY ./cluster-health.py /cluster-health
COPY ./requirements.txt /cluster-health

RUN pip3 install -r /cluster-health/requirements.txt
RUN chmod +x /cluster-health/cluster-health.py

CMD ["python3", "/cluster-health/cluster-health.py"]
