# Hyper-V Health Report — by FMODEL

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · **1.0.0**

[Português](README.md) · [Complete EN-US manual](docs/MANUAL.en-US.md) · [Manual completo PT-BR](docs/MANUAL.pt-BR.md)

Read-only Hyper-V host/VM/cluster inventory and review, with **searchable offline HTML, 54 CSV files, JSON, SHA256 manifest and optional ZIP**. Includes 23 contextual review rules informed by Microsoft references, without automatic remediation.

## Download

**[⬇ DOWNLOAD HYPER-V 1.0.0 PACKAGE](https://github.com/fmodel7/scripts/raw/refs/heads/main/scripts/hyper-v-health-report/HyperV-Health-Report-v1.0.0.zip)**

Download, right-click the ZIP and choose **Extract All**. Open the directory containing `Export-HyperVHealthReport.ps1`. Git is not required.

## Try it without Hyper-V

In PowerShell or VSCode's terminal, paste the extracted directory path when prompted:

```powershell
$folder = Read-Host 'Paste the extracted directory path'
Set-Location -LiteralPath $folder.Trim('"')
Get-ChildItem -LiteralPath .
```

After reviewing the source and trusting its origin:

```powershell
Unblock-File -LiteralPath .\Export-HyperVHealthReport.ps1
$result = .\Export-HyperVHealthReport.ps1 -CreateExample -Language en-US
Invoke-Item -LiteralPath $result.Html
```

This creates a clearly **synthetic** report without querying servers. Example/offline paths work in PowerShell 5.1/7. Run the offline suite:

```powershell
Unblock-File -LiteralPath .\tests\Test-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVCollectors.ps1
.\tests\Test-HyperVHealthReport.ps1
.\tests\Test-HyperVCollectors.ps1
```

If AllSigned/Group Policy requires signatures, follow organizational signing procedures. Unblocking does not sign a PS1. The tool does not change execution policies.

## Collect live evidence

Use **64-bit Windows PowerShell 5.1**, an authorized account and a lab Hyper-V target. From PowerShell 7, enter Windows PowerShell first:

```powershell
powershell.exe -NoProfile
```

From the script directory, choose **one** of these:

```powershell
# Current Hyper-V host
$result = .\Export-HyperVHealthReport.ps1 -OutputPath C:\Reports\HyperV -Language en-US -CreateZip

# Remote hosts — replace these names
$result = .\Export-HyperVHealthReport.ps1 -ComputerName HV01,HV02 -Language en-US -CreateZip

# Cluster — actual member node
$result = .\Export-HyperVHealthReport.ps1 -ClusterNode HV01 -Language en-US -CreateZip

Invoke-Item -LiteralPath $result.Html
```

These are read queries: no VM start/restart, checkpoint removal, network changes, Test-Cluster or feature installation. Queries still consume resources; start with a small scope. Target Hyper-V/FailoverClusters modules must already exist. Remoting requires existing WinRM/DNS/access configuration. Current identity is used; `-Credential (Get-Credential)` optionally selects another identity for remote targets.

In VSCode use **File → Open Folder → Terminal → New Terminal**. Verify your current directory with Get-ChildItem; do not repeat cd into a folder you are already in. The [manual](docs/MANUAL.en-US.md) covers every step.

## Collection scope

| Area | Examples |
|---|---|
| Hosts | OS/boot, CPU/memory, NUMA, services, QFE, supported VM versions, settings and reboot signals |
| VMs | State/generation/version, CPU/memory, integration, attachments/VHD chains, checkpoints, Replica and existing metering |
| Network | Adapters/IPs, vSwitch/SET/VLAN, guards/MAC, management adapters, RDMA/VMQ/SR-IOV |
| Security | Secure Boot, vTPM/shielding, Device Guard, SMB settings/connections |
| Cluster | Nodes, roles, resources, CSV volumes, networks and quorum |
| Diagnostics | Bounded events, optional existing BPA results, findings, coverage and errors |

CSV contains all **actually exported** records within caps/permissions/timeouts. HTML defaults to 500 rows per dataset; search covers displayed rows only. Missing evidence does not become zero or a health certificate. Manuals explain every dataset, field, unit, rule, parameter and limitation.

## Outputs and learning

Each run creates a unique directory with report.html, report.json, csv/ and MANIFEST-SHA256.txt. Preserve the complete directory or ZIP to keep CSV links working. Real reports may contain internal names/IPs/paths/notes/events; use an appropriately protected output directory and authorized sharing channels.

- [EN-US manual](docs/MANUAL.en-US.md): setup, permissions, all 54 datasets, parameters/rules/interpretation, Microsoft references and presentation Q&A.
- [PT-BR manual](docs/MANUAL.pt-BR.md): complete Portuguese edition.
- [EN-US](examples/en-US/report.html) and [PT-BR](examples/pt-BR/report.html) examples: download and open locally; GitHub displays HTML source.
- [Validation evidence](tests/evidence/VALIDATION.json) and [changelog](CHANGELOG.md).

Offline rendering without server access:

```powershell
$file = Read-Host 'Paste the report.json path'
$result = .\Export-HyperVHealthReport.ps1 -InputJson $file.Trim('"') -Language en-US -CreateZip
```

Interface language changes; stored recommendations retain the original assessment language. Collect with `-Language en-US` for English recommendations throughout.

## Validation and credits

Automated validation covers Windows PowerShell 5.1 and PowerShell 7 Windows/Linux with synthetic providers, a real local child process returning fictional evidence, and Chromium report checks. **Real Hyper-V/WinRM/cluster/SMB acceptance remains required.** No real infrastructure was queried during development. Checkpoints/Replica/no alerts do not certify backup or compliance.

Independent FMODEL implementation. Scope compared with user-supplied Get-HyperVReport.ps1 v1.5 (2015), attributed to **Serhat AKINCI**; legacy source is not bundled. No general reuse license has been selected for the library; see [repository guidance](https://github.com/fmodel7/scripts/blob/main/README.en-US.md).
