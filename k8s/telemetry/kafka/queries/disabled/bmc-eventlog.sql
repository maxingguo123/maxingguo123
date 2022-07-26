SET 'auto.offset.reset' = 'earliest';

-- create metadata ktables
CREATE TABLE PIPELINE_KTABLE_SOL_CSCOPE (host VARCHAR PRIMARY KEY, message VARCHAR) WITH (kafka_topic='PIPELINE_STREAM_META_SOL_CSCOPE', value_format='json');
CREATE TABLE PIPELINE_KTABLE_TESTINFO (host VARCHAR PRIMARY KEY, message VARCHAR) WITH (kafka_topic='PIPELINE_STREAM_META_TESTINFO', value_format='json');
CREATE TABLE PIPELINE_KTABLE_DIRECT_CSCOPE (name VARCHAR PRIMARY KEY, metadata VARCHAR) WITH (kafka_topic='cluster_scope', value_format='json');
UNSET 'auto.offset.reset';

-- create event stream
CREATE STREAM PIPELINE_STREAM_ALL_SEL (event VARCHAR, collection_timestamp BIGINT, collection_run_id INT, collection_counter INT, host VARCHAR, message VARCHAR) WITH (KAFKA_TOPIC='bmc_sel', VALUE_FORMAT='json', REPLICAS=3);

CREATE STREAM PIPELINE_SEL_JOIN01
  AS SELECT
    a.*,
    solcscope.MESSAGE as "SOLCSCOPE"
FROM PIPELINE_STREAM_ALL_SEL a
  LEFT JOIN PIPELINE_KTABLE_SOL_CSCOPE solcscope ON a.HOST=solcscope.HOST
EMIT CHANGES;

CREATE STREAM PIPELINE_SEL_JOIN02
  AS SELECT
    a.*,
    directcscope.METADATA as "DIRECTCSCOPE"
FROM PIPELINE_SEL_JOIN01 a
  LEFT JOIN PIPELINE_KTABLE_DIRECT_CSCOPE directcscope ON a.A_HOST=directcscope.NAME
EMIT CHANGES;

CREATE STREAM sel_with_metadata
  AS SELECT
    a.a_a_host as "host",
    a.a_a_event as "event",
    a.a_a_collection_run_id as "collection_run_id",
    a.a_a_collection_counter as "collector_counter",
    a.a_a_collection_timestamp as "collection_timestamp",
    a.a_a_message as "message",
    MAP('cscope':= CASE
          WHEN a.A_SOLCSCOPE IS NOT NULL THEN a.A_SOLCSCOPE
          WHEN a.DIRECTCSCOPE IS NOT NULL THEN a.DIRECTCSCOPE
          ELSE '{}'
          END,
        'test':= CASE
        WHEN b.MESSAGE IS NOT NULL THEN b.MESSAGE
        ELSE '{}'
        END
    ) as "metadata"
FROM PIPELINE_SEL_JOIN02 a
  LEFT JOIN PIPELINE_KTABLE_TESTINFO b ON a.a_a_host=b.HOST
EMIT CHANGES;
