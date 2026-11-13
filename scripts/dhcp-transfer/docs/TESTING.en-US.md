# Testing and acceptance — DHCP Transfer 1.0.0

[CI](https://github.com/fmodel7/scripts/actions/runs/43447564768) passed: Windows PowerShell 5.1 and PowerShell 7/Windows, 227 assertions each; PowerShell 7/Linux, 225. Each environment ran 26 simulated workflows. Local PowerShell 7.4.13/Linux also passed. Real operations target Windows PowerShell 5.1; testing under 7 does not certify operational DHCP-module compatibility.

```powershell
powershell.exe -NoProfile -File .	ests\Test-DhcpTransfer.ps1
```

pwsh also runs the suite. No domain/DHCP/elevation needed. AST loads functions and replaces only worker I/O adapters. Production flow remains under test; there are no product test/bypass flags. A synthetic DhcpServer module checks real adapter binding, including Leases, ScopeOverwrite, Force and warnings. Operational entry points are not executed.

The 26 workflows cover export, configuration without leases, XML/hash collisions, runtime failure, WhatIf/refusal for both modes, failed/malformed export, failover, invalid/mismatched hash, identity change, failed/empty backup, post-backup state race, failed prior-destination XML, normal import, overwrite, restart, import without leases, native warnings and import/restart failures. Other checks cover XML/DTD, snapshot/write lock, HTML, journal, parameters, paths, simulated remote dispatch and actual ShouldProcess.

Limits: no real DHCP export/import/backup/restore, no real WinRM and no client lease acquisition/renewal. Tests do not establish version/schema compatibility, service permissions, AD authorization, real integration, failover or network availability. Synthetic backups are not restorable. CI artifacts include runtime/hashes/logs with 30-day retention.

## Isolated lab acceptance

1. Prepare source/destination with representative versions/UI language and controlled client access.
2. Review AD authorization, DNS, bindings, relays, backup permissions and cutover/recovery plan.
3. Test local/remote WhatIf and confirm no new files/DHCP changes.
4. Export and verify XML/hash after approved transfer to destination.
5. Import in the lab and inspect backups, options, scopes, reservations and leases.
6. Exercise existing-scope warnings, approved overwrite, denied backup and controlled communication failure.
7. Test native/XML recovery without assuming universally safe rollback.
8. Validate addresses, DNS/gateway and client renewal before team acceptance.

[Manual](MANUAL.en-US.md) · [Evidence](EVIDENCE.json)
