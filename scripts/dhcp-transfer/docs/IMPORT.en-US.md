# Import-DHCP.ps1 — 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Use 64-bit Windows PowerShell 5.1 with elevated administration on a Windows Server 2016+ target and DHCPServer Running. All paths belong to the selected server.

Simulate:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Run with confirmation:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

Before import, review authorization, source cutover, versions/UI language, networking and clients. Server-wide options may change even without -ScopeOverwrite. Existing scopes may be skipped with warnings. Use -ScopeOverwrite only for approved replacement and -RestartService only when restart is intended. Both are off by default.

-ConfigurationOnly omits leases, not scopes. -ExpectedSha256 accepts an approved hash. -BackupPath selects the Import-UTC-GUID base. It contains InputSnapshot.xml, PreImportNative, DestinationBefore.xml, ImportCmdletBackup and reports. Failure of either preparatory backup blocks import. A failover destination is blocked; failover sources require a dedicated procedure.

ImportedAwaitingValidation does not prove DHCP service. Review warnings, options, scopes/leases and test clients before completion. There is no automatic rollback.

For remote execution, add -DhcpServer REAL-DNS-NAME; WinRM must already work. XML/reports remain on the target with no automatic transfer. WhatIf creates no files. Do not use pwsh for real operations in this edition.

[Manual completo / Full manual](MANUAL.en-US.md) · [Testing](TESTING.en-US.md) · [Download](../DHCP-Transfer-v1.0.0.zip?raw=true)
