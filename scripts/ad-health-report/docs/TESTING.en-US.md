# Validation — AD Health Report 1.2.0

FMODEL · F. Model · fmodel@fmodel.com.br

Operational source passed [CI](https://github.com/fmodel7/scripts/actions/runs/43498148487), commit `7d037054f9917e465610c4ba845d14376323fd0d`. Delivered operational files match it. EVIDENCE.json/MANIFEST-SHA256.txt record hashes.

| Runtime | Regression | Operational | Comprehensive | End-to-end scenarios |
|---|---|---|---|---|
| Windows PowerShell 5.1 | 1843 | 650 | 699 | 36 |
| PowerShell 7 Windows | 1839 | 650 | 699 | 36 |
| PowerShell 7 Linux | 1843 | 650 | 699 | 36 |

Test columns are assertions. Four harmless native helper checks are omitted under PowerShell 7 Windows. There are 36 scenarios per runtime, not real DC assessments or compliance certification.

## Run without a domain

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

pwsh also works. Suites load functions through AST without the operational entry. No domain/RSAT/elevation required. Synthetic adapters replace AD, DNS, CIM/remoting, GPO, events and diagnostics. Local files and harmless helper processes exercise local boundaries.

## Coverage

- Inventory, domain/forest discovery, SIDs, skips, missing attributes, replication, findings and exit codes.
- ICMP does not gate collectors; DNS, volumes/mount points/NTDS, memory/boot, signed offsets, bounded events and coverage/errors.
- UAC, distinct-owner SPN/UPN duplicates across two domains, denied/mismatched GPOs, nonzero-version empty extension data, links/flags, RSoP/rights by SID.
- DNS administration, host/software/QFE, backup evidence and registry value comparison; unknown/missing data does not become success.
- Namespaced/repeated XML, prohibited DTD/XXE, malformed/oversized XML and normalization caps.
- SYSVOL traversal uses synthetic local files, not a share. Job ownership/cleanup uses adapters without stopping unrelated jobs.
- Windows PowerShell 5.1 JSON arrays, offline render, allowed dataset/path names, manifest evidence copying, changed hashes and adjacent ZIP output.
- All 63 CSVs, formula neutralization, UTF-8, JSON and HTML encoding of markup-bearing names/messages.

Actual GroupPolicy/DnsServer modules and remoting endpoints were not accessed. Remote worker was statically reviewed without a live session. Tests do not establish installed module/permission compatibility in your infrastructure.

## HTML and package

SYNTHETIC includes fictional data in 63 tables across two domains/DCs. Browser checks search, expansion, CSV links, encoding, no external requests/dialogs/JavaScript errors and mobile layout; see RENDERER-TESTS.json. Local links, PDF, recursive manifest and ZIP contents are checked during packaging.

## Authorized lab acceptance

1. Verify Windows PowerShell 5.1 x64, required modules and approved read account; begin with default inventory.
2. Test individual options and ADWS/LDAP, SMB, WSMan/remoting, event/RPC and DNS rights/connectivity. The tool enables none of them.
3. Compare ADUC/ADAC, GPMC, Event Viewer, DNS and backup samples; verify selected domain/DC, source and timestamps.
4. Exercise multiple domains, RODC/separate DNS if available, localized servers, denied access and an unavailable collector; verify partial results.
5. Select the approved OS/role baseline; exercise differing, absent and unexpected-type values. Supplied profile is partial, not complete SCT.
6. Adjust limits and inspect Coverage/GPOCoverage/DirectoryCoverage/EventLogCoverage, durations and truncation.
7. Open HTML/CSV, verify hashes, render offline and create ZIP. Restrict real data access and do not publish it on GitHub.

No real AD was used. Production transport, permissions and installed module versions require lab acceptance.
