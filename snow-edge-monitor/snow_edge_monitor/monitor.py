"""Pure detection policy; no browser, GUI, filesystem, or Windows imports."""
from .models import Snapshot


class Detector:
    """Baseline each scope and require consecutive observations of each change.

    Only complete snapshots enter this engine. Missing/partial reads clear
    candidates but preserve the last confirmed baseline, including across refresh.
    A context change always disarms and establishes a fresh baseline silently.
    """

    def __init__(self, eligible_states, confirmation_reads=2):
        if confirmation_reads < 2:
            raise ValueError('At least two confirmations are required')
        self.eligible = {s.casefold() for s in eligible_states}
        self.reads = confirmation_reads
        self.scope = None
        self.baseline = None
        self.initial = None
        self.initial_count = 0
        self.candidates = {}

    def gap(self):
        self.candidates.clear()
        self.initial = None
        self.initial_count = 0

    def observe(self, snapshot: Snapshot | None) -> tuple[str, ...]:
        if snapshot is None:
            self.gap()
            return ()
        current = {i.number: i.state.casefold() for i in snapshot.incidents}
        if snapshot.scope != self.scope:
            self.scope = snapshot.scope
            self.baseline = None
            self.gap()
        if self.baseline is None:
            self.initial_count = self.initial_count + 1 if current == self.initial else 1
            self.initial = current
            if self.initial_count >= self.reads:
                self.baseline = current.copy()
            return ()
        alerts = []
        pending = {}
        for number, state in current.items():
            # Absent -> present and ineligible -> eligible can notify. Existing
            # eligible -> eligible changes never notify a second time.
            previous = self.baseline.get(number)
            if state == previous:
                continue
            old_state, count = self.candidates.get(number, (None, 0))
            count = count + 1 if old_state == state else 1
            if count < self.reads:
                pending[number] = (state, count)
                continue
            self.baseline[number] = state
            if state in self.eligible and previous not in self.eligible:
                alerts.append(number)
        # Keep knowledge of disappeared rows; reappearance alone cannot alert.
        self.candidates = pending
        return tuple(sorted(alerts))
