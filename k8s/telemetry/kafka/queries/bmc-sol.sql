-- create metadata ktables
-- SET 'auto.offset.reset' = 'earliest';
CREATE TABLE PIPELINE_KTABLE_SOL_CSCOPE (host VARCHAR PRIMARY KEY, message VARCHAR) WITH (kafka_topic='PIPELINE_STREAM_META_SOL_CSCOPE', value_format='json');
CREATE TABLE PIPELINE_KTABLE_TESTINFO (host VARCHAR PRIMARY KEY, message VARCHAR) WITH (kafka_topic='PIPELINE_STREAM_META_TESTINFO', value_format='json');
-- CREATE TABLE PIPELINE_KTABLE_DIRECT_CSCOPE (name VARCHAR PRIMARY KEY, metadata VARCHAR) WITH (kafka_topic='cluster_scope', value_format='json');
-- UNSET 'auto.offset.reset';

-- create event stream
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

-- join everything
CREATE STREAM PIPELINE_SOL_JOIN01
  AS SELECT
    a.host as host,
    a.timestamp_ns as timestamp_ns,
    a.collector_start_epoch as collector_start_epoch,
    a.collector_counter as collector_counter,
    a.message as message,
    a.`cluster-name` as "cluster-name",
    a.fluentd_counter as fluentd_counter,
    a.fluentd_start_time as fluentd_start_time,
    solcscope.MESSAGE as SOLCSCOPE
FROM PIPELINE_STREAM_ALL_SOL a
  LEFT JOIN PIPELINE_KTABLE_SOL_CSCOPE solcscope ON a.HOST=solcscope.HOST
EMIT CHANGES;

-- Disable use of direct cscope when run on test clusters
-- CREATE STREAM PIPELINE_SOL_JOIN02
--   AS SELECT
--     a.*,
--     directcscope.METADATA as "DIRECTCSCOPE"
-- FROM PIPELINE_SOL_JOIN01 a
--   LEFT JOIN PIPELINE_KTABLE_DIRECT_CSCOPE directcscope ON a.A_HOST=directcscope.NAME
-- EMIT CHANGES;

-- Use field names in double quotes to preserve case
CREATE STREAM "sol_with_metadata"
  AS SELECT
    a.host as "host",
    a.timestamp_ns as "timestamp_ns",
    a.collector_start_epoch as "collector_start_epoch",
    a.collector_counter as "collector_counter",
    a.message as "message",
    a.`cluster-name` as "cluster-name",
    a.fluentd_counter as "fluentd_counter",
    a.fluentd_start_time as "fluentd_start_time",
    MAP('cscope':= CASE
          WHEN a.SOLCSCOPE IS NOT NULL THEN a.SOLCSCOPE
          -- WHEN a.DIRECTCSCOPE IS NOT NULL THEN a.DIRECTCSCOPE
          ELSE '{}'
          END,
        'test':= CASE
        WHEN b.MESSAGE IS NOT NULL THEN b.MESSAGE
        ELSE '{}'
        END
    ) as "metadata"
FROM PIPELINE_SOL_JOIN01 a
  LEFT JOIN PIPELINE_KTABLE_TESTINFO b ON a.host=b.HOST
EMIT CHANGES;

