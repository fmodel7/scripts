import copy
import unittest
from helpers import capture, settings, GROUP
from snow_edge_monitor.browser import parse_snapshot


class CaptureTests(unittest.TestCase):
    def test_selection_column_does_not_shift_fields(self):
        result = parse_snapshot(capture(), settings())
        self.assertEqual(result.incidents[0].number, 'INC0000001')
        self.assertEqual(result.incidents[0].state, '1')

    def test_reordered_columns_and_table_prefix(self):
        raw = capture()
        order = [3, 2, 0, 1]
        raw['keys'] = [('incident.' + raw['keys'][i]) if raw['keys'][i] else '' for i in order]
        raw['rows'] = [[row[i] for i in order] for row in raw['rows']]
        self.assertIsNotNone(parse_snapshot(raw, settings()))

    def test_all_states_are_read(self):
        raw = capture([(f'INC{i:07}', str(i), GROUP) for i in range(1, 9)])
        self.assertEqual(len(parse_snapshot(raw, settings()).incidents), 8)

    def test_empty_complete_list(self):
        self.assertEqual(parse_snapshot(capture([]), settings()).incidents, ())

    def test_incomplete_or_page_two_rejected(self):
        for kwargs in ({'total': '20'}, {'first': '2'}, {'total': None}, {'first': None}, {'total': '1 of 2'}):
            with self.subTest(kwargs=kwargs): self.assertIsNone(parse_snapshot(capture(**kwargs), settings()))

    def test_changed_query_rejected(self):
        self.assertIsNone(parse_snapshot(capture(query=settings().query + '^state=1'), settings()))

    def test_wrong_url_or_scope_rejected(self):
        for url in ('https://other.example.invalid/incident_list.do', 'http://example.service-now.com/incident_list.do',
                    'https://example.service-now.com/login.do', settings().list_url + '&sysparm_fixed_query=state%3D1',
                    settings().list_url + '&sysparm_query=state%3D1'):
            with self.subTest(url=url): self.assertIsNone(parse_snapshot(capture(url=url), settings()))

    def test_group_id_is_mandatory(self):
        for group in ('1' * 32, None, 'Example support'):
            self.assertIsNone(parse_snapshot(capture([('INC0000001', '1', group)]), settings()))

    def test_bad_number_empty_state_duplicate_rows(self):
        for rows in ([('TASK0000001', '1', GROUP)], [('INC0000001', '', GROUP)],
                     [('INC0000001', '1', GROUP)] * 2):
            self.assertIsNone(parse_snapshot(capture(rows), settings()))

    def test_missing_duplicate_or_unknown_columns(self):
        for keys in (['', 'number', 'state', 'state'], ['', 'number', '', 'assignment_group'],
                     ['', 'number', 'state', 'number']):
            self.assertIsNone(parse_snapshot(capture(keys=keys), settings()))

    def test_state_display_fallback(self):
        raw = capture()
        raw['rows'][0][2] = {'text': 'New', 'value': None}
        self.assertEqual(parse_snapshot(raw, settings()).incidents[0].state, 'new')

    def test_malformed_payloads_fail_closed(self):
        for raw in (None, [], {}, {'url': None}, capture(rows=[] , total='1')):
            self.assertIsNone(parse_snapshot(raw, settings()))
        raw = capture(); raw['rows'][0].pop()
        self.assertIsNone(parse_snapshot(raw, settings()))

    def test_sort_url_changes_scope(self):
        a = parse_snapshot(capture(), settings())
        b = parse_snapshot(capture(url=settings().list_url + '&sysparm_orderby=number'), settings())
        self.assertNotEqual(a.scope, b.scope)

    def test_capture_not_mutated(self):
        raw = capture(); before = copy.deepcopy(raw)
        parse_snapshot(raw, settings())
        self.assertEqual(raw, before)

    def test_safe_order_directives_and_eq_are_supported(self):
        for suffix in ('^ORDERBYnumber', '^ORDERBYDESCsys_created_on', '^EQ', '^ORDERBYnumber^EQ'):
            self.assertIsNotNone(parse_snapshot(capture(query=settings().query + suffix), settings()))

    def test_additional_filters_or_or_directives_rejected(self):
        for suffix in ('^state=1', '^ORstate=1', '^NQstate=1', '^ORDERBYnumber^active=true'):
            self.assertIsNone(parse_snapshot(capture(query=settings().query + suffix), settings()))
