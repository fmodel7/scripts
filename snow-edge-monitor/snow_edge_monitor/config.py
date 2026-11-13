"""Validated settings. Runtime state lives outside the source tree."""
from dataclasses import dataclass
import json
import math
import os
from pathlib import Path
import re
from urllib.parse import urlencode, urlsplit


@dataclass(frozen=True)
class Settings:
    instance_url: str
    assignment_group: str
    eligible_states: tuple[str, ...]
    poll_seconds: float = 5
    refresh_seconds: float = 60
    failure_seconds: float = 60
    confirmation_reads: int = 2
    page_limit: int = 1000
    table_selector: str = 'table[data-list_id="incident"]'
    query_selector: str = 'input[name="sysparm_query"]'
    first_selector: str = 'input[id="incident.first_row"]'
    total_selector: str = '[id="incident.total_rows"]'
    number_columns: tuple[str, ...] = ('number',)
    state_columns: tuple[str, ...] = ('state', 'incident_state')
    group_columns: tuple[str, ...] = ('assignment_group', 'assignment group')
    siren_enabled: bool = True
    popup_enabled: bool = True

    def __post_init__(self):
        if not isinstance(self.instance_url, str):
            raise ValueError('instance_url must be a string')
        url = urlsplit(self.instance_url)
        if (url.scheme != 'https' or not url.hostname or url.username or url.password
                or url.query or url.fragment or url.path not in ('', '/')
                or url.port not in (None, 443)):
            raise ValueError('instance_url must be an HTTPS origin without credentials or parameters')
        if not isinstance(self.assignment_group, str) or not re.fullmatch(r'[a-fA-F0-9]{32}', self.assignment_group):
            raise ValueError('assignment_group must be a 32-character group sys_id')
        for key in ('eligible_states', 'number_columns', 'state_columns', 'group_columns'):
            value = getattr(self, key)
            if not isinstance(value, (list, tuple)) or not value or any(
                    not isinstance(v, str) or not v.strip() for v in value):
                raise ValueError(f'{key} must be a nonempty list of strings')
            object.__setattr__(self, key, tuple(v.strip().casefold() for v in value))
        for key in ('poll_seconds', 'refresh_seconds', 'failure_seconds'):
            value = getattr(self, key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError(f'{key} must be a positive finite number')
        for key in ('confirmation_reads', 'page_limit'):
            value = getattr(self, key)
            if type(value) is not int or value < (2 if key == 'confirmation_reads' else 1):
                raise ValueError(f'{key} is out of range')
        for key in ('table_selector', 'query_selector', 'first_selector', 'total_selector'):
            if not isinstance(getattr(self, key), str) or not getattr(self, key).strip():
                raise ValueError(f'{key} must be a CSS selector')
        for key in ('siren_enabled', 'popup_enabled'):
            if type(getattr(self, key)) is not bool:
                raise ValueError(f'{key} must be boolean')

    @property
    def query(self):
        # Observe all states, then evaluate eligible transitions locally.
        return f'assignment_group={self.assignment_group}'

    @property
    def list_url(self):
        return self.instance_url.rstrip('/') + '/incident_list.do?' + urlencode({
            'sysparm_query': self.query, 'sysparm_limit': self.page_limit})


def load_settings(path: Path) -> Settings:
    try:
        return Settings(**json.loads(path.read_text(encoding='utf-8')))
    except (OSError, TypeError, ValueError) as exc:
        # Never echo settings or a potentially sensitive input value.
        raise ValueError('Invalid configuration; check the example and field types') from exc


def runtime_dir() -> Path:
    base = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local'))
    path = base / 'SNOWEdgeMonitor'
    path.mkdir(parents=True, exist_ok=True)
    return path
