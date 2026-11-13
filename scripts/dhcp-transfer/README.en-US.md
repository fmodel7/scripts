# FMODEL DHCP Transfer 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

[Português](README.md) · [English](README.en-US.md) · [Manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf)

Two standalone scripts to **export/import DHCP configuration and leases**. Real operation requires a DHCP Windows Server 2016+ target and **64-bit Windows PowerShell 5.1 (powershell.exe)**. PowerShell 7 is used only for offline tests in this edition.

| File | Purpose | Individual guide |
|---|---|---|
| Export-DHCP.ps1 | Exports DHCPv4/v6 and leases to XML/hash without overwriting existing files | [Export](docs/EXPORT.en-US.md) |
| Import-DHCP.ps1 | Prepares backups and imports XML; overwrite/restart are explicit options | [Import](docs/IMPORT.en-US.md) |

## Download

[Download DHCP-Transfer-v1.0.0.zip](DHCP-Transfer-v1.0.0.zip?raw=true). If the file page opens, click **Download raw file**, then **Extract All**. Git installation is unnecessary.

Alternatively use **Code → Download ZIP → Extract All → scripts/dhcp-transfer** from the repository home. Open the folder in VSCode or Windows PowerShell. Real operations need administrative access to the chosen server.

## Test on a workstation without DHCP

From the extracted folder in a normal terminal:

```powershell
powershell.exe -NoProfile -File .	ests\Test-DhcpTransfer.ps1
```

This test can also use pwsh. Synthetic data/adapters create/remove temporary files without accessing real DHCP or WinRM.

## Export on the source

In elevated Windows PowerShell on the source server, simulate:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
```

After review, export with confirmation:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

This example generates C:\DHCP-Backup\DHCP-Lab.xml and its .sha256 **on the server**, plus an Export-UTC-GUID report/journal folder. Choose another name if it exists. Without FileName, a unique name is generated. Transfer XML through an approved method and verify integrity.

## Import on the destination

Prepare source cutover and the destination in an approved lab/window. The target DHCPServer service must be Running, requiring controls against unintended client service. After copying XML onto the destination, simulate there:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Apply with confirmation:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

**ScopeOverwrite and service restart are off by default.** Server-wide settings may still change; existing scopes may be skipped with warnings. This is not a purely additive operation. Use -ScopeOverwrite or -RestartService only under an approved plan; read the import guide.

## Remote execution and results

Add -DhcpServer with the real DNS name for remote administration. Existing WinRM configuration is required; no password is embedded and TrustedHosts is not changed. **Every path remains on the chosen server**; XML is not automatically copied to your workstation.

WhatIf reads target state/XML without backups/reports or export/import. After approved execution, open Report.html in the printed RunFolder. Backups/snapshots remain in that server folder.

ImportedAwaitingValidation means the cmdlet returned and post-inventory was read; **it does not prove complete migration or client service**. NeedsReview indicates warnings; FailedAfterImportPossible requires investigation of possible partial changes. There is no automatic rollback/retry.

## Complete documentation

- [English manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf).
- [Export](docs/EXPORT.en-US.md) · [Import](docs/IMPORT.en-US.md).
- [Testing and acceptance](docs/TESTING.en-US.md) · [Functions](docs/INTERNALS.en-US.md) · [Evidence](docs/EVIDENCE.json).
- [History](CHANGELOG.md) · [Catalog](https://github.com/fmodel7/scripts/blob/main/scripts/README.md).

Read limits on failover, AD authorization, versions/UI language, source/destination, relays, DNS credentials and client validation before production. Do not publish live XML/backups/reports. For signature blocks, inspect Get-ExecutionPolicy -List and the manual instead of disabling corporate policies.

[CI](https://github.com/fmodel7/scripts/actions/runs/43447564768): 26 simulated workflows; 227 assertions per Windows environment (5.1/7) and 225 on Linux. No real DHCP/WinRM operation was tested.
