-- SET 'auto.offset.reset' = 'earliest';

CREATE STREAM PIPELINE_STREAM_ALL_SOL (
   host VARCHAR,
   timestamp_ns VARCHAR,
   collector_start_epoch varchar,
   collector_counter varchar,
   message VARCHAR,
   "cluster-name" VARCHAR,
   fluentd_counter BIGINT,
   fluentd_start_time BIGINT,
   tag VARCHAR
) WITH (KAFKA_TOPIC='sol', VALUE_FORMAT='json', TIMESTAMP='timestamp_ns', TIMESTAMP_FORMAT='yyyy-MM-dd''T''HH:mm:ss.nnnnnnnnnX');

CREATE STREAM PIPELINE_STREAM_META_SOL_CSCOPE
  AS SELECT host, message
  FROM PIPELINE_STREAM_ALL_SOL WHERE message LIKE '{"name":%"type":"clusterscope-metadata"}'
PARTITION BY host EMIT CHANGES;

CREATE STREAM PIPELINE_STREAM_META_TESTINFO
  AS SELECT host, message
  FROM PIPELINE_STREAM_ALL_SOL WHERE message LIKE '{"name":%"type":"test-metadata"}'
PARTITION BY host EMIT CHANGES;
