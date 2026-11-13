# Export-DHCP.ps1 — 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Use 64-bit Windows PowerShell 5.1 with elevated administration on a Windows Server 2016+ target and DHCPServer Running. All paths belong to the selected server.

Simulate:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
```

Run with confirmation:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

Includes all IPv4/IPv6 scopes/settings and leases. -ConfigurationOnly omits leases, not scopes. -ExportPath selects the base; -FileName accepts a simple XML leaf name. Overwrite is forbidden. Omitting FileName generates a unique UTC/ID name.

The console prints File and SHA256; the .sha256 sidecar accompanies XML. Export-UTC-GUID contains Report.html, report.json and actions.jsonl. Export does not shut down the source or prepare cutover.

For remote execution, add -DhcpServer REAL-DNS-NAME; WinRM must already work. XML/reports remain on the target with no automatic transfer. WhatIf creates no files. Do not use pwsh for real operations in this edition.

[Manual completo / Full manual](MANUAL.en-US.md) · [Testing](TESTING.en-US.md) · [Download](../DHCP-Transfer-v1.0.0.zip?raw=true)
