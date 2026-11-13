"""Read-only Edge adapter with strict scope and full-list validation."""
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import parse_qs, urlsplit

from .models import Incident, Snapshot

EXTRACT_SCRIPT = Path(__file__).with_name('extract.js').read_text(encoding='utf-8')
NUMBER = re.compile(r'INC\d{6,10}', re.I)


def query_in_scope(query, settings):
    if not isinstance(query, str):
        return False
    clauses = query.split('^')
    return (clauses[0].casefold() == settings.query.casefold()
            and all(clause == 'EQ' or re.fullmatch(r'ORDERBY(?:DESC)?[a-zA-Z_][a-zA-Z0-9_.]*', clause)
                    for clause in clauses[1:]))


def parse_snapshot(raw, settings):
    """Reject ambiguous, partial, filtered, foreign, or paginated captures."""
    if not isinstance(raw, dict):
        return None
    try:
        url = urlsplit(raw['url'])
        origin = urlsplit(settings.instance_url)
        if (url.scheme, url.netloc) != (origin.scheme, origin.netloc):
            return None
        if url.path != '/incident_list.do' or not query_in_scope(raw['query'], settings):
            return None
        params = parse_qs(url.query)
        url_queries = params.get('sysparm_query', [settings.query])
        if len(url_queries) != 1 or not query_in_scope(url_queries[0], settings):
            return None
        if any(key in params for key in ('sysparm_search', 'sysparm_fixed_query')):
            return None
        if not re.fullmatch(r'\d+', str(raw['total'])) or not re.fullmatch(r'\d+', str(raw['first'])):
            return None
        total, first = int(raw['total']), int(raw['first'])
        if first not in ((0, 1) if total == 0 else (1,)) or total != len(raw['rows']):
            return None
        keys = [k.strip().casefold().removeprefix('incident.') for k in raw['keys']]
        indices = []
        for aliases in (settings.number_columns, settings.state_columns, settings.group_columns):
            matches = [i for i, key in enumerate(keys) if key in aliases]
            if len(matches) != 1:
                return None
            indices.append(matches[0])
        incidents = []
        for row in raw['rows']:
            if len(row) != len(keys):
                return None
            number_cell, state_cell, group_cell = (row[i] for i in indices)
            number = number_cell['text'].strip().upper()
            state = str(state_cell['value'] if state_cell['value'] is not None else state_cell['text']).strip().casefold()
            group = group_cell['value']
            if not NUMBER.fullmatch(number) or not state or str(group).casefold() != settings.assignment_group.casefold():
                return None
            incidents.append(Incident(number, state))
        if len({i.number for i in incidents}) != total:
            return None
        # Do not store URLs or group identifiers in events or logs.
        scope = hashlib.sha256(json.dumps([raw['url'], raw['query'], keys], sort_keys=True).encode()).hexdigest()
        return Snapshot(scope, tuple(sorted(incidents)))
    except (KeyError, TypeError, ValueError, IndexError, AttributeError):
        return None


class EdgeBrowser:
    """All Playwright objects stay on the worker thread that created them."""

    def __init__(self, settings, profile_dir):
        self.settings = settings
        self.profile_dir = profile_dir
        self.context = None
        self.playwright = None
        self.page = None
        self.inflight = set()
        self.network_epoch = 0
        self.last_network_epoch = None

    def __enter__(self):
        from playwright.sync_api import sync_playwright
        try:
            self.playwright = sync_playwright().start()
            self.context = self.playwright.chromium.launch_persistent_context(
                str(self.profile_dir), channel='msedge', headless=False, no_viewport=True)
            self.page = self.context.pages[0] if self.context.pages else self.context.new_page()
            self.page.on('request', self._request)
            self.page.on('requestfinished', self._finished)
            self.page.on('requestfailed', self._finished)
            self.page.goto(self.settings.list_url, wait_until='domcontentloaded', timeout=30000)
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def _request(self, request):
        if request.resource_type in ('document', 'xhr', 'fetch'):
            self.inflight.add(request)
            self.network_epoch += 1

    def _finished(self, request):
        self.inflight.discard(request)

    def snapshot(self):
        # Give Playwright a chance to deliver request/navigation callbacks.
        self.page.wait_for_timeout(20)
        if self.inflight:
            return None
        if self.last_network_epoch != self.network_epoch:
            self.last_network_epoch = self.network_epoch
            return None
        found = []
        for frame in self.page.frames:
            try:
                raw = frame.evaluate(EXTRACT_SCRIPT, asdict(self.settings))
                snapshot = parse_snapshot(raw, self.settings)
                if snapshot is not None:
                    found.append(snapshot)
            except Exception:
                # Detached/login/loading frames are invalid reads, never empty lists.
                return None
        return found[0] if len(found) == 1 and not self.inflight else None

    def refresh(self):
        self.page.reload(wait_until='domcontentloaded', timeout=30000)

    def __exit__(self, *_):
        try:
            if self.context:
                self.context.close()
        finally:
            if self.playwright:
                self.playwright.stop()
