<source>
  @id {{.name}}
  @type tail
  path {{.log_files}}
  pos_file {{.log_root}}/{{.name}}.pos
  format none
  # message_key log
  read_from_head true
  tag {{.name}}.*
</source>

<source>
  @type monitor_agent
  port {{.monitoring_port}}
</source>

{{if .extract_metadata}}
<filter {{.name}}.**>
  @type record_transformer
  <record>
# Assuming target path to be of following format: <LOG ROOT>/<TEST NAME>/<RUNID>/<HOST>/<LOGFILE>.<EXT>
# Assuming LOGFILE doesn't have a '.' in it
    host ${tag_parts[-3]}
    runid ${tag_parts[-4]}
    test ${tag_parts[-5]}
  </record>
</filter>
{{end}}

<match {{.name}}.**>
 @type rdkafka2
 @log_level info

 brokers {{range .kafka}}{{.host}}:{{.port}},{{end}}
 default_topic {{.topic}}
# Setting kafka create time to event time. Supports only upto millisecond resolution
 use_event_time true
 
 # ruby-kafka configuration
 max_send_limit_bytes 10485760
 # kafka_agg_max_bytes 10485760
 # kafka_agg_max_messages 5000
 # get_kafka_client_log true
 # compression_codec snappy
 # idempotent true
 rdkafka_options {
   "enable.idempotence" : true,
   "compression.codec": "snappy"
 }

 <format>
  @type json
 </format>

 <inject>
  tag_key tag
# Preserve nanosecond time timestamp in 'logtime' field
  time_key logtime
  time_type string
  time_format %Y-%m-%dT%H:%M:%S.%NZ
 </inject>
 
 <buffer tag>
  @type file
  path /root/fluentd-kafka-buffer
  flush_mode interval
  retry_type exponential_backoff
  flush_thread_count 3
  flush_interval 30s
  retry_timeout 1h
  retry_max_interval 120000
  chunk_limit_size 10M
  queue_limit_length 8
  overflow_action block
 </buffer>
</match>
