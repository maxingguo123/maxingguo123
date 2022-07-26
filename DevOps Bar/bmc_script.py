from elasticsearch import Elasticsearch
import json
import pandas as pd
from pandas.io.json import json_normalize
import pymongo
from pymongo import MongoClient
import numpy as np
import pytz
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import datetime
from datetime import date, timedelta
import sys
import zipfile
import os.path



# global variables
time = datetime.datetime.now()
now = time.isocalendar()
week = now[1]
year = now[0]
day = now[2] #isocalendar days monday starts on 1
WEEK_day = str(week)+'.'+str(day)



### INPUT VARIABLES - CHANGE INFORMATION HERE
### To get the query body click Inspect > Request and look for the query
### This will query a given FIELD (such as log/message/event.severity) for a QUERY_STRING
### For more advanced queries, set ADVANCED to true and copy your query directly into query_body_advanced()
FIELD = 'event.severity'
QUERY_STRING = 'Critical'
INDEX = 'eventlog*'
START = (datetime.datetime.utcnow()-timedelta(days=7)).strftime("%Y-%m-%dT00:00:00") #START = '2020-11-09T00:00:00Z'
END = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S') #END = '2020-11-16T00:00:00Z'
ADVANCED = False # set this to True to use query_body_advanced()
# Directory
#DIRECTORY_mio = 'Z:\\Cluster_On-Demand_Reports\\%s\\WW%s\\' % (str(year), str(week))
DIRECTORY = 'C:\\Documents\\Cluster_On-Demand_Reports\\%s\\WW%s\\' % (str(year), str(week))
#DIRECTORY = 'C:\\home\\piv\\PIV_Ondemand\\' % (str(year), str(week))
if not os.path.exists(DIRECTORY):
os.makedirs(DIRECTORY)

SEND_EMAIL = False
SEND_EMAIL_TO = ['daniela.benavides.herrera@intel.com']
REQUESTOR = 'daniela.benavides.herrera'

### ELS VARIABLES - DO NOT CHANGE
### Information for querying ELS - will need to change for l10a or opusa
host = "10.219.23.201" #l10b2
port = 9200
timeout = 1000
size = 10000



clusts = ['l10b2','opusa']



# Parameters to update automatically



def get_args():
global START
global END
global SEND_EMAIL
global SEND_EMAIL_TO
global REQUESTOR
global STP
global BMC



 for arg in sys.argv:
if "--start" in arg.lower():
START = arg.split("=")[1].replace('\'','')
if '--end' in arg:
END = arg.split("=")[1].replace('\'','')
if '--help' in arg:
print_help()
if '--email-to' in arg:
arg = arg.split("=")[1].replace('\'','')
SEND_EMAIL = True
if "," in arg:
SEND_EMAIL_TO = arg.split(",")
REQUESTOR = SEND_EMAIL_TO[0].split('@intel.com')[0]
else:
SEND_EMAIL_TO = arg
REQUESTOR = arg.split('@intel.com')[0]
if '--bmc_version' in arg:
BMC = arg.split("=")[1].replace('\'','')
if '--stepping' in arg:
STP = arg.split("=")[1].replace('\'','').replace('_', ' ')



def print_help():
print('SUMMARY:\n\tThis script will query L10b2 ELS and output to an excel file')
print('\nINPUTS:\n\t1) --field=\t\t DESCRIPTION:\tRequired field to search on.\n\t\t\t \
REQUIREMENTS:\tMust be a valid field in the index you are searching.\n\t\t\t \
EXAMPLE:\t\'kubernetes.host\' or \'log\'\n\t\t\t \
DEFAULT:\tnone')
print('\n\t2) --query_string=\t DESCRIPTION:\tRequired query to search. \n\t\t\t \
REQUIREMENTS:\tUse _ instead of spaces if searching more than one string.\n\t\t\t \
EXAMPLE:\t\'not_ok\' or \'Critical\'\n\t\t\t \
DEFAULT:\tnone')
print('\n\t3) --index=\t\t DESCRIPTION:\tRequired index to search on in ELS.\n\t\t\t \
REQUIREMENTS:\t Include * at the end of the index name.\n\t\t\t \
EXAMPLE:\tsol* or eventlog*\n\t\t\t \
DEFAULT:\tnone')
print('\n\t4) --start=\t\t DESCRIPTION:\tOptional parameter to specify an explicit start date for your report\n\t\t\t \
REQUIREMENTS:\tMust be in datetime format as such: YYYY-MM-DDTHH:MM:SSZ\n\t\t\t \
EXAMPLE:\t2020-08-01T00:00:00Z\n\t\t\t \
DEFAULT:\t7 days ago')
print('\n\t5) --end=\t\t DESCRIPTION:\tOptional parameter to specify an explicit end date for your report\n\t\t\t \
REQUIREMENTS:\tMust be in datetime format as such: YYYY-MM-DDTHH:MM:SSZ\n\t\t\t \
EXAMPLE:\t2020-08-01T00:00:00Z\n\t\t\t \
DEFAULT:\tToday')
print('\n\t6) --email-to=\t\t DESCRIPTION:\tOptional parameter to send an email of the report.\n\t\t\t \
REQUIREMENTS:\tMust be a valid email address,\n\t\t\t \
\t\tMust NOT be any spaces between email addresses. \n\t\t\t \
EXAMPLE:\tjane.doe@intel.com,john.doe@intel.com\n\t\t\t \
DEFAULT:\tNo email will be sent')
print('\nOUTPUTS:\n\t1) An excel file within the subdirectory Cluster_On-Demand_Reports\\2020\\WW\\file.xlsx\n\t2) An email containing the .xslx file')
print('\nQUESTIONS?\n\tContact: giovanna.graciani@intel.com')
exit(0)

def query_body():
body = {
"query": {
"bool": {
"must": [],
"filter": [
{
"match_all": {}
},
{
"match_phrase": {
FIELD: {
"query": QUERY_STRING
}
}
},
{
"range": {
"@timestamp": {
"format": "strict_date_optional_time",
"gte": START,
"lte": END
}
}
}
],
}
}
}
return body



def process_hits(hits):
df = pd.DataFrame()
df = pd.json_normalize(hits)
return df



def execute_query_scroll(query_body, CLUSTER):
index = INDEX
cluster = CLUSTER



 # Init Elasticsearch instance
if cluster == 'l10b2':
es = Elasticsearch([{'host': '10.219.23.201', 'port': 9200}], timeout=timeout)
elif cluster == 'l10a':
es = Elasticsearch(['deo-infra02.deacluster.intel.com:9922'], timeout=timeout)
else: # CLUSTER == 'opusa'
es = Elasticsearch(['elastic.opus.deacluster.intel.com: 9200'],http_auth = ('paiv_admin', 'password'),use_ssl=True,verify_certs=False, timeout=timeout)



 if not es.indices.exists(index=index):
print("Index " + index + " not exists")
exit()
# Init scroll by search
data = es.search(
index=index,
scroll='2m',
size=size,
body=query_body
)



 sid = data['_scroll_id']
#sid = data.get('_scroll_id')

#while True:
scroll_size = len(data['hits']['hits'])
total_size = scroll_size



 df = pd.DataFrame()
while scroll_size > 0:
# Before scroll, process current batch of hits
df = df.append(process_hits(data['hits']['hits']))

data = es.scroll(scroll_id=sid, scroll='2m')



 # Update the scroll ID
sid = data['_scroll_id']



 # Get the number of results that returned in the last scroll
scroll_size = len(data['hits']['hits'])
total_size += scroll_size
else:
es.clear_scroll(scroll_id=sid)
print('Found %d records' % len(df))
return df



def main(CLUSTER):
get_args()



 print('initializing inputs...')
print('\tfield:\t%s ' % FIELD)
print('\tquery:\t%s ' % QUERY_STRING)
print('\tindex:\t%s ' % INDEX)
print('\tstart:\t%s ' % START)
print('\tend:\t%s ' % END)
print('\temail:\t%s ' % SEND_EMAIL)
print('\trequestor:\t%s' % REQUESTOR)
print('\tcluster:\t%s' % CLUSTER)



 if not ADVANCED:
body = query_body()
else: #not default
body = query_body_advanced()
df = execute_query_scroll(body,CLUSTER)

if CLUSTER == "l10b2":
file_df = "GDC_BMC_Critical_Event.xlsx"
else:
file_df = "OPUS_BMC_Critical_Event.xlsx"

df.to_excel(DIRECTORY+file_df)

#df.to_excel(DIRECTORY+file_df)

if SEND_EMAIL:
send_email_zip('[New Cluster On Demand Report]', file_df, DIRECTORY+file_df)



if __name__ == "__main__":
for clust in clusts:
main(clust)



# cleaning start and end parameters
START = START.split("T")[0]
END = END.split("T")[0]

# Report 1 - GDC



if os.path.isfile("GDC_BMC_Critical_Event.zip") == True:
zf = zipfile.ZipFile(DIRECTORY+'GDC_BMC_Critical_Event.zip')
df1 = pd.read_excel(zf.open(zf.namelist()[0]))
else:
df1 = pd.read_excel(DIRECTORY+"GDC_BMC_Critical_Event.xlsx")



# data cleaning
df1 = df1.rename(columns={"_source.message": "Message",
"_source.host": "Host",
"_source.event.severity": "Event_severity",
"_source.event.time": "Event_time",
"_source.metadata.cscope.stepping": "Stepping",
"_source.metadata.cscope.bmcVersion": "BMC_version",
"_source.metadata.cscope.pool": "Pool_name",
"_source.@timestamp": "Timestamp"
})



# converting event_time to datetime
df1['Event_time'] = df1['Event_time'].str.split('T').str[0]
df1['Event_time'] = pd.to_datetime(df1['Event_time'])



# extracting the BMC version
df1['BMC_version2'] = pd.to_numeric(df1['BMC_version'].str.split('-').str[2])
df1['BMC_version'] = pd.to_numeric(df1['BMC_version'].str.split('-').str[1])



# keeping only desired columns
df1 = df1[['Timestamp','Host','Message', 'Event_severity','Pool_name','BMC_version','BMC_version2','Stepping','Event_time']]



# GDC Stepping



# dropping rows with no stepping
df1 = df1.dropna()



# removing unkowns
df1 = df1[~df1['Stepping'].str.contains("unknown")]



# replacing the steppings that contain XCC only for the value they have after
df1.loc[df1['Stepping'].str.contains('-'), "Stepping"] = df1['Stepping'].str.split('-').str[1]



# FILTERING BY: STP, SPR and EXC in pool_name, stepping C2 or D0, event.time the actual week or from years 69' or 70', BMC version >= 0.72
df1 = df1[
(df1['Stepping'] >= STP) &
(df1['Event_severity'] == "Critical") &
(df1['Pool_name'].str.startswith("SPR", na = False)) &
((df1['Event_time'] >= START) | (df1['Event_time'].dt.year == 1969) | (df1['Event_time'].dt.year == 1970)) &
(df1['Event_time'] < END) &
(df1['BMC_version'] >= float(BMC))
]



# FILTERING BY: unknown errors
known_errors = ["At-Scale Debug special user is enabled",
"At-Scale Debug connection aborted/failed",
"At-Scale Debug service is now connected",
"At-Scale Debug service is started",
"User root is enabled",
"The system interface is in the unprovisioned state",
"CPU Error Occurred",
"Weak password computing hash algorithm is enabled."
]
df1 = df1[~df1['Message'].str.contains('|'.join(known_errors))]



# Findind and replacing list of terms
df1['Message'] = df1['Message'].replace({"CPU1" :"CPUx",
"CPU2" :"CPUx",
"CPU 1":"CPU x",
"CPU 2":"CPU x",
"A1" :"xx",
"B1" :"xx",
"C1" :"xx",
"D1" :"xx",
"E1" :"xx",
"F1" :"xx",
"G1" :"xx",
"H1" :"xx",
"ABC" :"xxx",
"DEF" :"xxx"
},regex=True)



# creating a new dataframe to group by Threshold inside messages containing: "sensor crossed a critical"
pr1 = df1
pr1 = pr1[pr1['Message'].str.contains("sensor crossed a critical")]
pr1['Threshold'] = pr1['Message'].str.split('Threshold=').str[1]
pr1['Threshold'] = pd.to_numeric(pr1['Threshold'].str[:-1])
pr1['Reading'] = pr1['Message'].str.split('Reading=').str[1]
pr1['Reading'] = pr1['Reading'].str.split('Threshold=').str[0]
pr1['Reading'] = pd.to_numeric(pr1['Reading'].str[:-1])



# dropping duplicates
pr1.drop_duplicates(subset ="Threshold",keep='first',inplace=True)



# removing columns Reading and Threshold
pr1 = pr1[['Timestamp','Host','Message', 'Event_severity','Pool_name','BMC_version','Stepping','Event_time']]



# removing messages containing "sensor crossed a critical" from original dataset
df1 = df1[~df1['Message'].str.contains("sensor crossed a critical")]



# joining both dataframes into a single new one
df1 = pd.concat([df1,pr1])



# group by log and count
log_c = df1.groupby('Message').size()



# create new dataframe with count per log
df1_complete = pd.DataFrame({"Log_count": log_c})



# obtain list of logs
logs = df1_complete.index.get_level_values(0)



# list comprehension to obtain the priority of each log
df1_complete['Priority'] = ['P1' if "CPU" in logs[x] else 'P2' for x in range(len(logs))]



# add the count of nodes per log
df1_complete['Node_count'] = df1.groupby('Message')['Host'].nunique()



# add the names of nodes
nodos = df1.groupby('Message')['Host'].unique()
df1_complete['Nodes'] = nodos



# change index name
df1_complete.index.names = ['Log']



# Report 2 - OPUS

if os.path.isfile("OPUS_BMC_Critical_Event.zip") == True:
zf = zipfile.ZipFile(DIRECTORY+'OPUS_BMC_Critical_Event.zip')
df2 = pd.read_excel(zf.open(zf.namelist()[0]))
else:
df2 = pd.read_excel(DIRECTORY+"OPUS_BMC_Critical_Event.xlsx")



# data cleaning
df2 = df2.rename(columns={"_source.message": "Message",
"_source.host": "Host",
"_source.event.severity": "Event_severity",
"_source.event.time": "Event_time",
"_source.metadata.cscope.stepping": "Stepping",
"_source.metadata.cscope.bmcVersion": "BMC_version",
"_source.metadata.cscope.pool": "Pool_name",
"_source.@timestamp": "Timestamp"
})



# converting event_time to datetime
df2['Event_time'] = df2['Event_time'].str.split('T').str[0]
df2['Event_time'] = pd.to_datetime(df2['Event_time'])



# extracting the BMC version
df2['BMC_version2'] = pd.to_numeric(df2['BMC_version'].str.split('-').str[2])
df2['BMC_version'] = pd.to_numeric(df2['BMC_version'].str.split('-').str[1])



# keeping only desired columns
df2 = df2[['Timestamp','Host','Message', 'Event_severity','Pool_name','BMC_version','BMC_version2','Stepping','Event_time']]



# OPUS Stepping



# dropping rows with no stepping
df2 = df2.dropna()



# removing unkowns
df2 = df2[~df2['Stepping'].str.contains("unknown")]



# replacing the steppings that contain XCC only for the value they have after
df2.loc[df2['Stepping'].str.contains('-'), "Stepping"] = df2['Stepping'].str.split('-').str[1]



# FILTERING BY: SPR and EXC in pool_name, stepping C2 or D0, event.time the actual week or from years 69' or 70', BMC version >= 0.72
df2 = df2[
(df1['Stepping'] >= STP) &
(df2['Event_severity'] == "Critical") &
(df2['Pool_name'].str.startswith("SPR", na = False)) &
((df1['Event_time'] >= START) | (df1['Event_time'].dt.year == 1969) | (df1['Event_time'].dt.year == 1970)) &
(df1['Event_time'] < END) &
(df2['BMC_version'] >= float(BMC))
]



# FILTERING BY: unknown errors
known_errors = ["At-Scale Debug special user is enabled",
"At-Scale Debug connection aborted/failed",
"At-Scale Debug service is now connected",
"At-Scale Debug service is started",
"User root is enabled",
"The system interface is in the unprovisioned state",
"CPU Error Occurred",
"Weak password computing hash algorithm is enabled."
]
df2 = df2[~df2['Message'].str.contains('|'.join(known_errors))]



# Findind and replacing list of terms
df2['Message'] = df2['Message'].replace({"CPU1" :"CPUx",
"CPU2" :"CPUx",
"CPU 1":"CPU x",
"CPU 2":"CPU x",
"A1" :"xx",
"B1" :"xx",
"C1" :"xx",
"D1" :"xx",
"E1" :"xx",
"F1" :"xx",
"G1" :"xx",
"H1" :"xx",
"ABC" :"xxx",
"DEF" :"xxx"
},regex=True)



# creating a new dataframe to group by Threshold inside messages containing: "sensor crossed a critical"
pr2 = df2
pr2 = pr2[pr2['Message'].str.contains("sensor crossed a critical")]
pr2['Threshold'] = pr2['Message'].str.split('Threshold=').str[1]
pr2['Threshold'] = pd.to_numeric(pr2['Threshold'].str[:-1])
pr2['Reading'] = pr2['Message'].str.split('Reading=').str[1]
pr2['Reading'] = pr2['Reading'].str.split('Threshold=').str[0]
pr2['Reading'] = pd.to_numeric(pr2['Reading'].str[:-1])



# dropping duplicates
pr2.drop_duplicates(subset ="Threshold",keep='first',inplace=True)



# removing columns Reading and Threshold
pr2 = pr2[['Timestamp','Host','Message', 'Event_severity','Pool_name','BMC_version','Stepping','Event_time']]



# removing messages containing "sensor crossed a critical" from original dataset
df2 = df2[~df2['Message'].str.contains("sensor crossed a critical")]



# joining both dataframes into a single new one
df2 = pd.concat([df2,pr2])



# group by log and count
log_c = df2.groupby('Message').size()



# create new dataframe with count per log
df2_complete = pd.DataFrame({"Log_count": log_c})



# obtain list of logs
logs = df2_complete.index.get_level_values(0)



# list comprehension to obtain the priority of each log
df2_complete['Priority'] = ['P1' if "CPU" in logs[x] else 'P2' for x in range(len(logs))]



# add the count of nodes per log
df2_complete['Node_count'] = df2.groupby('Message')['Host'].nunique()



# add the names of nodes
nodos = df2.groupby('Message')['Host'].unique()
df2_complete['Nodes'] = nodos



# change index name
df2_complete.index.names = ['Log']



# Final Report



# joining the 2 final reports
df = pd.concat([df1_complete,df2_complete])



# defining the list of nodes
nodes = df['Nodes']



# list comprehension to obtain the platform of each log depending on its nodes
df['Platform'] = ['GDC' if "zp" in nodes[x][0]
else 'OPUS' if "op" in nodes[x][0]
else 'ICX'
for x in range(len(nodes))]



# adding the parameters as columns to the output
df['BMC_version'] = BMC
df['Stepping'] = STP
df['Start_Date'] = START
df['End_Date'] = END



# Directory to save the final report
DIRECTORY2 = 'C:\\Documents\\PAIV_Data\\es_bash_tools\\'
df.to_csv(DIRECTORY2+'BMC_report.csv')
