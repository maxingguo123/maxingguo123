[Unit]
Description=Atscale Fluentd Service: {{.name}}
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker exec %n stop
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull prt-registry.sova.intel.com/sraghav1/fluentd-plugins:v3.0.2 
ExecStart=/usr/bin/docker run --name %n \
    --entrypoint=/run.sh \
    -p 0.0.0.0:{{.monitoring_port}}:{{.monitoring_port}}/tcp \
    -v {{.log_root}}:{{.log_root}}:rw \
    -v /etc/atscale/fluentd/{{.name}}:/etc/fluent/config.d:ro \
    --env "FLUENTD_ARGS=-q --no-supervisor" \
    prt-registry.sova.intel.com/sraghav1/fluentd-plugins:v3.0.2 
ExecStop=/usr/bin/docker stop -t 2 %n


[Install]
WantedBy=default.target
