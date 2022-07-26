import queries

# Elasticsearch endpoint
protocol = "http"
host = "10.219.23.201"
port = 9200
user = ""
password = ""

# Reindex config
src_index = "qpool"
dest_index = "critical-qpool"
start_date = "2020.04.01"
end_date = "2020.04.01"
# end_date = "2020.09.22"
filter = queries.find_critical
breathe = 300
