import logging as log
import pprint
import time

from datetime import datetime, timedelta
from elasticsearch import Elasticsearch

import config


ES = None
log.basicConfig(level=log.DEBUG)


def init():
    global ES
    if not ES:
        # TODO: Auth support
        ES = Elasticsearch(["%s://%s:%d" % (config.protocol,
                                            config.host,
                                            config.port)])


def date_range():
    start = datetime.strptime(config.start_date, "%Y.%m.%d").date()
    end = datetime.strptime(config.end_date, "%Y.%m.%d").date()
    day = timedelta(days=1)
    while start <= end:
        yield start.strftime("%Y.%m.%d")
        start += day


def reindex():
    # Iterate by start and stop dates
    dates = date_range()
    for date in dates:
        src = "%s-%s" % (config.src_index, date)
        dest = "%s-%s" % (config.dest_index, date)
        pprint.pprint(src)
        pprint.pprint(dest)
        pprint.pprint(config.filter())
        ES.reindex({"source": {
                        "index": src,
                        "query": config.filter()
                        },
                    "dest": {
                    "index": dest
                    }},
                   slices="auto",
                   wait_for_completion=True,
                   request_timeout=1800)
        # Sleep to control the reindex between two days
        # Allow the cluster to do other operations
        time.sleep(config.breathe)


if __name__ == "__main__":
    init()
    reindex()
