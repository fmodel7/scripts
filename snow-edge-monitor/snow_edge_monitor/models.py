"""Immutable values shared by the browser adapter and detection engine."""
from dataclasses import dataclass


@dataclass(frozen=True, order=True)
class Incident:
    number: str
    state: str


@dataclass(frozen=True)
class Snapshot:
    scope: str
    incidents: tuple[Incident, ...]
