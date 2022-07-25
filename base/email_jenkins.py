import smtplib 
from email.mime.multipart import MIMEMultipart 
from email.mime.text import MIMEText 
from email.mime.base import MIMEBase 
from email import encoders 
import sys

JOB_NAME = ""
NS = ""
EMAIL_LIST = []
CLUSTER = ""

def get_args():
    global JENKINS_TEST_LABEL
    global NS
    global EMAIL_LIST
    global CLUSTER
    global SYS_DPV_PWD

    JENKINS_TEST_LABEL = sys.argv[1]
    NS = sys.argv[2]
    if not sys.argv[3]:
        sys.exit()
    if ',' in sys.argv[3]:
        EMAIL_LIST = sys.argv[3].split(",") 
    else:
        EMAIL_LIST = sys.argv[3]
    CLUSTER = sys.argv[4]
    if not sys.argv[5]:
        sys.exit()
    else:
        SYS_DPV_PWD = sys.argv[5]


def email_template(job_name, ns, cluster):
    index = ""
    base = ""
    if "Purley" in cluster:
        base = "https://kibana.gdc.sova.intel.com"
        index = "b7564090-b44f-11e9-9f9b-6b0b9ee2cb20"
    elif "ICX" in cluster:
        base = "http://kibana.l10b2.deacluster.intel.com"
        index = "57cbdb10-2058-11ea-89fe-d7fec3016c71"
    elif "OPUS" in cluster:
        base = "http://kbdev1.opus.deacluster.intel.com/s/paiv"
        index = "55b104d0-d788-11ea-a60c-a90dc6d8fbb9"
    elif "FLEX" in cluster:
        base = "http://kibana.fl30lcent1.deacluster.intel.com:5601"
        index = "7e77b8b0-5468-11ec-be0d-79c3a955baaf"
        
    template = """
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
    <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <style>
            p {
                text-align: left;
                width: 74%;
                color: #333;
                font-family: 'Muli', sans-serif;
                font-size: 16px;
            }
    
            h1{
                color: white;
            }
    
        </style>
        <body>
            <div class="container-fluid" style="padding-bottom: 20px">
  <div style="background-color:#0171c5;color:white;padding:30px;">
      <h1>"""+JENKINS_TEST_LABEL+""" completed under namespace """+ NS +"""</h1>
  </div>
 <h2><b><a href=http://reportcenter-paiv.intel.com/Reports/powerbi/Xeon%20SP/Cluster/Whitley/DO%20NOT%20TOUCH/POD%20INDICATOR?filter=Indicators%2Fcontainer_name%20eq%20%27"""+JENKINS_TEST_LABEL+"""%27>Check the execution using Pod Indicator report.</a></b></h2>
 <h2><b><a href="{}/app/kibana#/discover?_g=(filters:!())&_a=(columns:!(log,kubernetes.namespace_name,kubernetes.container_name,metadata.cscope.pool),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:'{}',key:kubernetes.namespace_name,negate:!f,params:(query:{}),type:phrase),query:(match:(kubernetes.namespace_name:(query:{},type:phrase)))),('$state':(store:appState),meta:(alias:!n,disabled:!f,index:'{}',key:kubernetes.container_name,negate:!f,params:(query:{}),type:phrase),query:(match:(kubernetes.container_name:(query:{},type:phrase))))),index:'{}',interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))">Check the execution using Kibana.</a></b></h2>
<p> **** PowerBi report data refresh every 4 hours. ****<br>
This is an automatically notification from <a href="http://atscale-jenkins.amr.corp.intel.com">atscale-jenkins.amr.corp.intel.com</a></p>
                    <hr>
                    <div class="container-fluid" align="center">
                        Copyright Intel Corporation, 2021. All rights reserved.<br>
                        *Other names and brands may be claimed as the property of others. <a href="http://targetmailer.intel.com/TMService/Redir.aspx?ID=3215554">Legal Notices</a><br>
                        The contents of this page are for internal use only. Intel Confidential
                    </div>
            </div>
        </body>
    </html>
    """.format(base,index,ns,ns,index,job_name,job_name,index)
    html_text = MIMEText(template, 'html')
    return html_text



def send_email(job_name, ns, cluster, sys_dpv_pwd):
    from_email = "sys_dpv@intel.com"
    password = sys_dpv_pwd
    #today = time.strftime('%Y-%m-%d')
    # Create message container - the correct MIME type is multipart/alternative.
    msg = MIMEMultipart('alternative')
    msg['Subject'] = "Atscale-Jenkins Notification: %s completed in %s." %(job_name, cluster)
    msg['From'] = "atscale-jenkins.amr.corp.intel.com"
    html = email_template(job_name, ns, cluster)
    # Attach parts into message container.
    # According to RFC 2046, the last part of a multipart message, in this case
    # the HTML message, is best and preferred.
    msg.attach(html)

    # Send the message via local SMTP server.
    # sendmail function takes 3 arguments: sender's address, recipient's address
    # and message to send - here it is sent as one string.

    s = smtplib.SMTP('SMTPAUTH.INTEL.COM', 587)
    s.ehlo()
    s.starttls()
    s.login(from_email, password)
    s.sendmail(from_email, EMAIL_LIST, msg.as_string())
    s.quit()

get_args()
send_email(JENKINS_TEST_LABEL, NS, CLUSTER, SYS_DPV_PWD)
