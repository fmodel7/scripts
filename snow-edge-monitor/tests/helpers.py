from snow_edge_monitor.config import Settings
from snow_edge_monitor.models import Incident, Snapshot

GROUP = '0' * 32


def settings(**overrides):
    return Settings(**dict(dict(instance_url='https://example.service-now.com',
                               assignment_group=GROUP, eligible_states=('1', '2')), **overrides))


def snapshot(*records, scope='scope'):
    return Snapshot(scope, tuple(Incident(n, s) for n, s in records))


def capture(rows=None, **overrides):
    rows = rows if rows is not None else [('INC0000001', '1', GROUP)]
    def cell(text, value=None):
        return {'text': text, 'value': value}
    result = dict(url=settings().list_url, query=settings().query, first='1', total=str(len(rows)),
                  keys=['', 'number', 'state', 'assignment_group'],
                  rows=[[cell(''), cell(n), cell('Display state', s), cell('Example support', g)]
                        for n, s, g in rows])
    result.update(overrides)
    return result
