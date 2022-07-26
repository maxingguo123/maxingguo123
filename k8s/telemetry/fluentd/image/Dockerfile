FROM quay.io/fluentd_elasticsearch/fluentd:v3.2.0
RUN apt-get update
RUN apt-get install -y inotify-tools curl 
RUN apt-get install -y vim net-tools procps ruby-dev 
RUN apt-get install -y libsnappy-dev build-essential libtool automake autoconf 
RUN fluent-gem install fluent-plugin-kafka --no-document
RUN fluent-gem install fluent-plugin-rewrite-tag-filter --no-document
RUN fluent-gem install fluent-plugin-record-modifier --no-document
RUN gem install snappy
RUN gem install rdkafka
RUN gem install fluent-plugin-throttle
RUN gem install fluent-plugin-prometheus
COPY ./filter_throttle.rb /usr/local/bundle/gems/fluent-plugin-throttle-0.0.5/lib/fluent/plugin/filter_throttle.rb
ENTRYPOINT /entrypoint.sh
