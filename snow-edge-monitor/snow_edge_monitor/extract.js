// One synchronous DOM read. Never return descriptions, assignees, or cookies.
(cfg) => {
    const tables = [...document.querySelectorAll(cfg.table_selector)]
        .filter(t => t.getClientRects().length && t.getAttribute('aria-hidden') !== 'true');
    if (tables.length !== 1 || document.readyState !== 'complete') return null;
    const table = tables[0];
    if (document.querySelector('[aria-busy="true"]')) return null;
    const value = selector => {
        const nodes = [...document.querySelectorAll(selector)];
        if (nodes.length !== 1) return null;
        return String(nodes[0].value ?? nodes[0].textContent).trim();
    };
    // Classic GlideList2 exposes list context on many ServiceNow versions.
    let list = null;
    try { list = window.GlideList2?.get(table.dataset.list_id || table.id.replace(/_table$/, '')); } catch {}
    const query = list?.getQuery ? list.getQuery() : value(cfg.query_selector);
    const first = list?.firstRow ?? value(cfg.first_selector);
    const total = list?.totalRows ?? value(cfg.total_selector);
    const headers = [...table.querySelectorAll('thead tr:last-child > th, thead tr:last-child > td')];
    if (!headers.length || headers.some(h => h.colSpan > 1 || h.rowSpan > 1)) return null;
    const keys = headers.map(h => (h.getAttribute('name') || h.dataset.field || h.getAttribute('glide_field') || h.textContent).trim().toLowerCase());
    const selected = new Set();
    for (const aliases of [cfg.number_columns, cfg.state_columns, cfg.group_columns]) {
        const matches = keys.map((key, i) => aliases.includes(key.replace(/^incident\./, '')) ? i : -1).filter(i => i >= 0);
        if (matches.length !== 1) return null;
        selected.add(matches[0]);
    }
    const rows = [];
    for (const row of table.querySelectorAll('tbody > tr')) {
        const cells = [...row.children].filter(c => c.matches('td, th'));
        if (row.matches('[data-empty="true"], .list2_no_records')) continue;
        if (cells.length !== keys.length || cells.some(c => c.colSpan > 1 || c.rowSpan > 1)) return null;
        rows.push(cells.map((c, index) => !selected.has(index) ? {text: '', value: null} : ({
            text: c.textContent.trim(),
            value: c.getAttribute('data-value') ?? c.getAttribute('sys_id') ?? (() => {
                const reference = c.querySelector('a[href*="sys_user_group.do"]');
                if (!reference) return null;
                try { return new URL(reference.getAttribute('href'), location.href).searchParams.get('sys_id'); }
                catch { return null; }
            })()
        })));
    }
    return {url: location.href, query, first, total, keys, rows};
}
