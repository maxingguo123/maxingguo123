import sys
import json
import requests
import traceback
from flask import Flask, request, abort
from string import Template

app = Flask(__name__)
teamsHook = ""

msgTemplate = """
   {
       "@context": "http://schema.org/extensions",
       "@type": "MessageCard",
       "sections": [
           {
               "facts": [],
               "text": "",
               "title": "Details"
           }
       ],
       "summary": "$rule",
       "title": "$title"
   }
"""

def make_event(src):
    print(json.dumps(src, indent=4), file=sys.stderr)

    if src['state'] != 'alerting':
        return {}

    t = Template(msgTemplate)
    strMsg = t.substitute(title = src['title'], rule = src['ruleName'])
    msg = json.loads(strMsg)

    try:
        count = 0

        if 'message' in src:
            msg['sections'][0]['text'] = src['message']

        for e in src['evalMatches']:
            msg['sections'][0]['facts'].append(
                    {
                        'name': "Event: %s" % e['tags']['event'],
                        'value': "Host: %s, Test: %s, RunID: %s" % (e['tags']['host'], e['tags']['test'], e['tags']['runid'])
                            })
            count += 1
            if count == 3:
                msg['sections'][0]['facts'].append({'name': '...and more', 'value': 'Please check grafana'})
                break
    except:
            print("Ignoring: Failed to extract event metadata", file=sys.stderr)
            traceback.print_exc()

    return msg

@app.route('/', methods=['POST'])
def webhook():
    if request.method == 'POST':
        event = make_event(request.get_json())
        if event:
            print(json.dumps(event, indent=4), file=sys.stderr)
            r = requests.post(teamsHook, json=event)
            print(r.status_code, r.content, file=sys.stderr)
        return '', 200
    else:
        abort(400)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    teamsHook = sys.argv[1]
    app.run(host='0.0.0.0')

