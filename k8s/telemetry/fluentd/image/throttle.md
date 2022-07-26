# Modified Fluentd Throttle Plugin

The original plugin does not properly sequence "rate exceeded" and "rate back down" messages which prevents us from setting the metric to zero. 
The modification intercepts the exceeded pod removal and publishes a "rate back down" message. Not all "rate back down" messages can be set to zero so in Grafana we set the chart to only display above the rate limit.

## Metric 

The input.containers.conf file in our fluentd-kafka config creates the metric 'fluentd_input_status_rate_exceeded_guage'. The host and throttled container are included as labels in the metric.

### Grafana 

To display the metric in Grafana, create a new time series panel with the following properties:

```
Metrics: fluentd_input_status_rate_exceeded_guage > 100 # rate limit per sec
Legend:  {{ instance }} 
```
