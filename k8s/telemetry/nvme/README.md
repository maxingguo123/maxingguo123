# NVMe SMART collector

Enables telemetry collection from NVMe drives with extra metrics for Intel NVMe drives.  

Dockerfile with Prometheus exporter code available in: https://gitlab.devtools.intel.com/atScaleCluster/docker-images/nvme-exporter/

## Data collection

**Collection Method:** Scrape - The metrics are retrieved at the time of request  
**Framework/Library:** Promethues Client (python)  
**Description:**  
The NVMe collector utilizes the Prometheus Client's HTTP server to provide an endpoint for collecting metrics. The metrics are gathered at the time of request by invoking the nvme-cli tool with the --json argument.   

## Cluster Status

NVMe-collector runs in the clusters with hundreds of instances.  
Grafana dashboards exist for this collector.  

## Priority Metrics

### Histograms

The following 'gauge' type metrics have been indentified as being more valuable with historical data (histogram):

 Metric name                                 |  Status            
---------------------------------------------|---------------------
nvme_critical_warning                        | Not Converted    
nvme_endurance_grp_critical_warning_summary  | Not Converted    
nvme_temperature                             | Not Converted    

## Exported Metrics

### All NVMe

 Name                                                                 | Type    | Description                                            | Sample Data
----------------------------------------------------------------------|---------|--------------------------------------------------------|-------------------------------------------
 python_gc_objects_collected_total                                    | counter | Objects collected during gc                            | python_gc_objects_collected_total{generation="0"} 63.0
 python_gc_objects_uncollectable_total                                | counter | Uncollectable object found during GC                   | python_gc_objects_uncollectable_total{generation="0"} 0.0
 python_gc_collections_total                                          | counter | Number of times this generation was collected          | python_gc_collections_total{generation="0"} 37.0
 python_info                                                          | gauge   | Python platform information                            | python_info{implementation="CPython",major="3",minor="8",patchlevel="6",version="3.8.6"} 1.0
 process_virtual_memory_bytes                                         | gauge   | Virtual memory size in bytes.                          | process_virtual_memory_bytes 1.7446912e+08
 process_resident_memory_bytes                                        | gauge   | Resident memory size in bytes.                         | process_resident_memory_bytes 1.9337216e+07
 process_start_time_seconds                                           | gauge   | Start time of the process since unix epoch in seconds. | process_start_time_seconds 1.61231780001e+09
 process_cpu_seconds_total                                            | counter | Total user and system CPU time spent in seconds.       | process_cpu_seconds_total 22.93
 process_open_fds                                                     | gauge   | Number of open file descriptors.                       | process_open_fds 6.0
 process_max_fds                                                      | gauge   | Maximum number of open file descriptors.               | process_max_fds 1.048576e+06
 nvme_critical_warning                                                | gauge   |  nvme_critical_warning                                 | nvme_critical_warning{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_temperature                                                     | gauge   |  nvme_temperature                                      | nvme_temperature{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 320.0
 nvme_avail_spare_total                                               | counter |  nvme_avail_spare_total                                | nvme_avail_spare_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 100.0
 nvme_spare_thresh_total                                              | counter |  nvme_spare_thresh_total                               | nvme_spare_thresh_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 10.0
 nvme_percent_used                                                    | gauge   |  nvme_percent_used                                     | nvme_percent_used{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_endurance_grp_critical_warning_summary                          | gauge   |  nvme_endurance_grp_critical_warning_summary           | nvme_endurance_grp_critical_warning_summary{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_data_units_read_total                                           | counter |  nvme_data_units_read_total                            | nvme_data_units_read_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 2.942967e+06
 nvme_data_units_written_total                                        | counter |  nvme_data_units_written_total                         | nvme_data_units_written_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 3.059095e+06
 nvme_host_read_commands_total                                        | counter |  nvme_host_read_commands_total                         | nvme_host_read_commands_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 2.0253915e+07
 nvme_host_write_commands_total                                       | counter |  nvme_host_write_commands_total                        | nvme_host_write_commands_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 2.6564125e+07
 nvme_controller_busy_time_total                                      | counter |  nvme_controller_busy_time_total                       | nvme_controller_busy_time_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 124.0
 nvme_power_cycles_total                                              | counter |  nvme_power_cycles_total                               | nvme_power_cycles_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 71.0
 nvme_power_on_hours_total                                            | counter |  nvme_power_on_hours_total                             | nvme_power_on_hours_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 3741.0
 nvme_unsafe_shutdowns_total                                          | counter |  nvme_unsafe_shutdowns_total                           | nvme_unsafe_shutdowns_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 68.0
 nvme_media_errors_total                                              | counter |  nvme_media_errors_total                               | nvme_media_errors_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_num_err_log_entries_total                                       | counter |  nvme_num_err_log_entries_total                        | nvme_num_err_log_entries_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_warning_temp_time_total                                         | counter |  nvme_warning_temp_time_total                          | nvme_warning_temp_time_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_critical_comp_time_total                                        | counter |  nvme_critical_comp_time_total                         | nvme_critical_comp_time_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_thm_temp1_trans_count_total                                     | counter |  nvme_thm_temp1_trans_count_total                      | nvme_thm_temp1_trans_count_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_thm_temp2_trans_count_total                                     | counter |  nvme_thm_temp2_trans_count_total                      | nvme_thm_temp2_trans_count_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_thm_temp1_total_time_total                                      | counter |  nvme_thm_temp1_total_time_total                       | nvme_thm_temp1_total_time_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_thm_temp2_total_time_total                                      | counter |  nvme_thm_temp2_total_time_total                       | nvme_thm_temp2_total_time_total{firmware="10105120",model="WDC CL SN720 SDAQNTW-512G-1020",physical_size="0.51T",sector_size="512",serial="20120F801353"} 0.0
 nvme_temperature_sensor_1_total                                      | counter |  nvme_temperature_sensor_1_total                       | nvme_temperature_sensor_1_total{firmware="EDA74F2Q",model="SAMSUNG MZ1LB960HAJQ-000FB",physical_size="0.9T",sector_size="4096",serial="S4S2NA0N408955"} 307.0
 nvme_temperature_sensor_2_total                                      | counter |  nvme_temperature_sensor_2_total                       | nvme_temperature_sensor_2_total{firmware="EDA74F2Q",model="SAMSUNG MZ1LB960HAJQ-000FB",physical_size="0.9T",sector_size="4096",serial="S4S2NA0N408955"} 312.0
 nvme_temperature_sensor_3_total                                      | counter |  nvme_temperature_sensor_3_total                       | nvme_temperature_sensor_3_total{firmware="EDA74F2Q",model="SAMSUNG MZ1LB960HAJQ-000FB",physical_size="0.9T",sector_size="4096",serial="S4S2NA0N408955"} 318.0


## Intel NVMe

 Name                                                                 | Type    | Description                                                   | Sample Data
----------------------------------------------------------------------|---------|---------------------------------------------------------------|------------------------------------------
 nvme_intel_program_fail_count_normalized_total                       | counter |  nvme_intel_program_fail_count_normalized_total               | nvme_intel_program_fail_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 100.0
 nvme_intel_program_fail_count_raw_total                              | counter |  nvme_intel_program_fail_count_raw_total                      | nvme_intel_program_fail_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_erase_fail_count_normalized_total                         | counter |  nvme_intel_erase_fail_count_normalized_total                 | nvme_intel_erase_fail_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_erase_fail_count_raw_total                                | counter |  nvme_intel_erase_fail_count_raw_total                        | nvme_intel_erase_fail_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 1.90215511605248e+014
 nvme_intel_wear_leveling_normalized_total                            | counter |  nvme_intel_wear_leveling_normalized_total                    | nvme_intel_wear_leveling_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 104.0
 nvme_intel_wear_leveling_raw_min_total                               | counter |  nvme_intel_wear_leveling_raw_min_total                       | nvme_intel_wear_leveling_raw_min_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 102.0
 nvme_intel_wear_leveling_raw_max_total                               | counter |  nvme_intel_wear_leveling_raw_max_total                       | nvme_intel_wear_leveling_raw_max_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 47104.0
 nvme_intel_wear_leveling_raw_avg_total                               | counter |  nvme_intel_wear_leveling_raw_avg_total                       | nvme_intel_wear_leveling_raw_avg_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_end_to_end_error_detection_count_normalized_total         | counter |  nvme_intel_end_to_end_error_detection_count_normalized_total | nvme_intel_end_to_end_error_detection_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_end_to_end_error_detection_count_raw_total                | counter |  nvme_intel_end_to_end_error_detection_count_raw_total        | nvme_intel_end_to_end_error_detection_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 4.29496780544e+011
 nvme_intel_crc_error_count_normalized_total                          | counter |  nvme_intel_crc_error_count_normalized_total                  | nvme_intel_crc_error_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_crc_error_count_raw_total                                 | counter |  nvme_intel_crc_error_count_raw_total                         | nvme_intel_crc_error_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 2.8147068829696e+014
 nvme_intel_timed_workload_media_wear_normalized_total                | counter |  nvme_intel_timed_workload_media_wear_normalized_total        | nvme_intel_timed_workload_media_wear_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_timed_workload_media_wear_raw_total                       | counter |  nvme_intel_timed_workload_media_wear_raw_total               | nvme_intel_timed_workload_media_wear_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 4.19424e+06
 nvme_intel_timed_workload_host_reads_normalized_total                | counter |  nvme_intel_timed_workload_host_reads_normalized_total        | nvme_intel_timed_workload_host_reads_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 100.0
 nvme_intel_timed_workload_host_reads_raw_total                       | counter |  nvme_intel_timed_workload_host_reads_raw_total               | nvme_intel_timed_workload_host_reads_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 65535.0
 nvme_intel_timed_workload_timer_normalized_total                     | counter |  nvme_intel_timed_workload_timer_normalized_total             | nvme_intel_timed_workload_timer_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_timed_workload_timer_raw_total                            | counter |  nvme_intel_timed_workload_timer_raw_total                    | nvme_intel_timed_workload_timer_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 2.6388279066624e+014
 nvme_intel_thermal_throttle_status_normalized_total                  | counter |  nvme_intel_thermal_throttle_status_normalized_total          | nvme_intel_thermal_throttle_status_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_thermal_throttle_status_raw_pct_total                     | counter |  nvme_intel_thermal_throttle_status_raw_pct_total             | nvme_intel_thermal_throttle_status_raw_pct_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_thermal_throttle_status_raw_cnt_total                     | counter |  nvme_intel_thermal_throttle_status_raw_cnt_total             | nvme_intel_thermal_throttle_status_raw_cnt_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 6.5536e+06
 nvme_intel_retry_buffer_overflow_count_normalized_total              | counter |  nvme_intel_retry_buffer_overflow_count_normalized_total      | nvme_intel_retry_buffer_overflow_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_retry_buffer_overflow_count_raw_total                     | counter |  nvme_intel_retry_buffer_overflow_count_raw_total             | nvme_intel_retry_buffer_overflow_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 4.29496792064e+011
 nvme_intel_pll_lock_loss_count_normalized_total                      | counter |  nvme_intel_pll_lock_loss_count_normalized_total              | nvme_intel_pll_lock_loss_count_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_pll_lock_loss_count_raw_total                             | counter |  nvme_intel_pll_lock_loss_count_raw_total                     | nvme_intel_pll_lock_loss_count_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 1.11097925599232e+014
 nvme_intel_nand_bytes_written_normalized_total                       | counter |  nvme_intel_nand_bytes_written_normalized_total               | nvme_intel_nand_bytes_written_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_nand_bytes_written_raw_total                              | counter |  nvme_intel_nand_bytes_written_raw_total                      | nvme_intel_nand_bytes_written_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 100.0
 nvme_intel_host_bytes_written_normalized_total                       | counter |  nvme_intel_host_bytes_written_normalized_total | nvme_intel_host_bytes_written_normalized_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0
 nvme_intel_host_bytes_written_raw_total                              | counter |  nvme_intel_host_bytes_written_raw_total | nvme_intel_host_bytes_written_raw_total{firmware="VCV10370",model="INTEL SSDPELKX020T8",physical_size="2.0T",sector_size="512",serial="PHLJ9371009E2P0J"} 0.0

 ## Implementation Details

Translates output of 2 commands to the Prometheus format:

```
>nvme smart-log /dev/nvme0n1
Smart Log for NVME device:nvme0n1 namespace-id:ffffffff
critical_warning                    : 0
temperature                         : 32 C
available_spare                     : 100%
available_spare_threshold           : 10%
percentage_used                     : 0%
data_units_read                     : 199,532
data_units_written                  : 2,868,426
host_read_commands                  : 2,236,159
host_write_commands                 : 168,751,569
controller_busy_time                : 14
power_cycles                        : 28
power_on_hours                      : 3,619
unsafe_shutdowns                    : 20
media_errors                        : 0
num_err_log_entries                 : 0
Warning Temperature Time            : 0
Critical Composite Temperature Time : 0
Thermal Management T1 Trans Count   : 0
Thermal Management T2 Trans Count   : 0
Thermal Management T1 Total Time    : 0
Thermal Management T2 Total Time    : 0
```

and

```
> nvme intel smart-log-add /dev/nvme0n1
Additional Smart Log for NVME device:nvme0n1 namespace-id:ffffffff
key                               normalized raw
program_fail_count              : 100%       0
erase_fail_count                : 100%       0
wear_leveling                   : 100%       min: 4, max: 5, avg: 4
end_to_end_error_detection_count: 100%       0
crc_error_count                 : 100%       0
timed_workload_media_wear       : 100%       63.999%
timed_workload_host_reads       : 100%       65535%
timed_workload_timer            : 100%       65535 min
thermal_throttle_status         : 100%       0%, cnt: 0
retry_buffer_overflow_count     : 100%       0
pll_lock_loss_count             : 100%       0
nand_bytes_written              : 100%       sectors: 155767
host_bytes_written              : 100%       sectors: 43768
```
