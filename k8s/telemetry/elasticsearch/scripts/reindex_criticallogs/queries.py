from elasticsearch_dsl import Q


def Q1(type, key, val):
    return Q(type, **{key: val})


def find_critical():
    s = (Q1("match_phrase", "log", "test-start-indicator")
         | Q1("match_phrase", "log", "test-end-indicator")
         | Q1("match_phrase", "kubernetes.container_name", "node-heartbeat")
         | Q1("match_phrase", "log", "more than the expected time")
         | (Q1("match_phrase", "log", "less than")
            & Q1("match_phrase", "log", "of the expected time"))
         | Q1("match_phrase", "log", "TEST PASSED")
         | Q1("match_phrase", "log", "TEST FAILED")
         | Q1("match_phrase", "log", "not ok")
         # omm kill logs usually have the form "oom-kill:constraint"
         # Elasticsearch parses this to think oom is a separate work and
         # kill:constraint is the next word. Using 'AND' and regexp to match
         # "oom" and "kill.*" to pickup such patterns
         | (Q1("match_phrase", "log", "oom")
            & Q1("regexp", "log", "kill.*")
            & (~Q1("match_phrase", "log", "log_monitor")))
         | Q1("match_phrase", "log", "out of memory")
         | (Q1("match_phrase", "log", "mcelog")
            & (Q1("match_phrase", "log", "Hardware event")
                | Q1("match_phrase", "log", "Corrected error")))
         | Q1("match_phrase", "log", "Hardware Error")
         | (Q1("match_phrase", "log", "mce")
            & Q1("match_phrase", "log", "temperature above threshold"))
         | (Q1("match_phrase", "log", "NodeNotReady")
            & Q1("match_phrase", "log", "ADDED"))
         | Q1("match_phrase", "log", "HIB")
         | Q1("match_phrase", "log", "LIB")
         )

    return s.to_dict()
