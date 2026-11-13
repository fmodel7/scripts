# Validation and acceptance — AD Health Report 1.1.0

Validated source: c8d0f20c276ee82abce9e16f5575c9a6221db55a. [GitHub Actions](https://github.com/fmodel7/scripts/actions/runs/43465971682). Windows PowerShell 5.1 and PowerShell 7/Linux each passed 985 assertions; PowerShell 7/Windows passed 981. All ran 15 full synthetic workflows. Four native-runner checks use a harmless C# executable on 5.1 and shell on Linux; these are skipped on 7/Windows. No actual dcdiag was executed.

```powershell
powershell.exe -NoProfile -File .	ests\Test-AdHealth.ps1
```

pwsh also runs the suite, but the operational entry requires 64-bit Windows PowerShell 5.1/RSAT. Tests extract functions through AST, replace AD/CIM/native adapters and create temporary files. They neither run the operational entry nor contact a domain. Do not dot-source tests in an active administration session.

Fifteen workflows cover default/no-findings collection, denied user reads, deliberate skips, complete/partial forests, optional diagnostics, CIM failure, native timeout/error, unavailable schema, missing privileged group, replication findings, WhatIf and bootstrap failure. Other checks cover dates, schema, unknown OS, escaped-comma DNs, CSV Unicode/formulas/quotes/newlines, empty headers, HTML cap, malicious data, CSP and file manifests. The JSON verifier was corrected for PowerShell 5.1's array-enumeration difference.

Chromium/Playwright exercised the renderer with fictional data at 1440px and 390px widths: search, navigation, expansion, caps, encoding and no external requests/JavaScript errors. See RENDERER-TESTS.json. The renderer volume test reuses references to one synthetic row, not real forest/LDAP collection; it is not a production-scale benchmark.

## Limits and acceptance

No real AD query, remote CIM or dcdiag ran. RSAT integration, permissions, topology, current replication and production scale remain unverified. CI artifacts retain runtime/hash/logs for 30 days. EVIDENCE.json preserves source identity and limitations.

1. Use an authorized lab/account and review Domain scope before Forest.
2. Compare samples with AD consoles/Microsoft queries, including null/zero and direct groups.
3. Test denied permissions/unavailable domains: expect Partial/errors rather than complete inventory.
4. Inspect CSV/JSON, encoding, hashes, HTML cap and sensitive data.
5. Approve rights/load before CIM/dcdiag and review native output in the local OS language.
6. Measure runtime/RAM at representative scale; PageSize does not cap object count or JSON memory.
7. Record technical acceptance. Findings need human review and authorize no automatic remediation.

[Manual](MANUAL.en-US.md) · [Evidence](EVIDENCE.json)

## Operational suite 1.1

```powershell
powershell.exe -NoProfile -File .	ests\Test-AdOperations.ps1
```

353 assertions and 10 additional operational workflows per environment. Combined with regression: 25 scenarios, 1338 assertions on Windows PowerShell 5.1/Linux or 1334 on PowerShell 7/Windows. Covers FullAssessment, thresholds, blocked ICMP without gating, boot/memory, mounts/denied registry, hidden volumes, negative offsets/unknown parsing, empty/capped/denied events, dashboard and real durations. Network/AD/CIM/event/time adapters are synthetic; no live remote call occurred.

Additional acceptance: review actual NTDS/SYSVOL volume mapping, compare time samples with an approved reference, verify collector clock, test CIM/registry/Event Log rights and event caps/load. Browser checks used a full fictional 30-CSV example, recorded in RENDERER-TESTS.json.
