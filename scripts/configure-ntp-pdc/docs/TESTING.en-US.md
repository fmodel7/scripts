# Testing and acceptance — 2.0.0

151 assertions and 19 simulated workflows per environment passed in [CI](https://github.com/fmodel7/scripts/actions/runs/43437702532): Windows PowerShell 5.1, PowerShell 7 Windows and Linux. Local PowerShell 7.4.13/Linux also passed. EVIDENCE.json records hashes and exact source commit.

```powershell
powershell.exe -NoProfile -File .	ests\Test-WindowsTime.ps1
```

Use pwsh for PowerShell 7. No domain/elevation required. Allow more than 30 seconds. AST loading extracts functions only, never operational entries. Tests use example.test names and documentation IPs. AD/DNS reads and registry/service/W32Time mutations are replaced. The native runner uses harmless child PowerShell processes for exit zero, stderr/exit 7 and a real 30-second timeout. Temporary files are removed.

Nineteen workflows: PDC, DOMHIER member, DOMHIER child PDC, policy, disabled service, wrong PDC, root PDC blocked for DOMHIER, WhatIf, refusal, backup failure, role change after confirmation, role change after backup, settings race after backup, mutation failure, role change after mutation, verification mismatch, diagnostic query failure, resync failure and initially stopped service. Other assertions cover parsing, embedded engine equality, requirements, flags, invalid DNS names, local/invalid addresses, HTML encoding, journal and actual ShouldProcess.

Limits: no real PDC configured, no clock changed and no external NTP/DNS source probed. Real AD APIs, UDP path and actual GPO/service/registry application are not validated by mocks. This is not a synchronization or accuracy certification. CI uploads runtime metadata, hashes and logs with 30-day retention.

## Authorized lab acceptance

1. Identify current forest/domain/root PDC and approved sources; review GPO/VM policy.
2. Preserve settings/logs and recovery plan; approve the window and clock-adjustment risk.
3. Run -WhatIf on root PDC and member; confirm cross-script target blocking.
4. Apply PDC, inspect backup/journal/HTML and Type=NTP; verify source/status/events and stability.
5. Apply DOMHIER to a lab member; check NT5DS and hierarchy source; test a child DC as appropriate.
6. Exercise DNS/network failures only in controlled labs; verify review-required outcomes.
7. Record AD-team acceptance before wider GPO rollout; replan after FSMO transfer.

[Manual](MANUAL.en-US.md) · [Evidence](EVIDENCE.json)
