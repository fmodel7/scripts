# FMODEL AD Health Report 1.2.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Review assisted by Akira (ChatGPT)

One-PS1 Active Directory inventory and assisted review, with **offline interactive HTML, 63 CSVs, JSON and evidence**. Queries data; no automatic environment remediation.

[Português](README.md) · [English manual](docs/MANUAL.en-US.md) · [Microsoft sources](docs/MANUAL.en-US.md#45-microsoft-sources-and-criteria) · [CSV fields](docs/MANUAL.en-US.md#43-additional-csv-fields)

## Download and open

**[Download AD-Health-Report-v1.2.0.zip](AD-Health-Report-v1.2.0.zip?raw=true)**. If the file page opens, click **Download raw file**. Right-click the ZIP → **Extract All**, then open the extracted `ad-health-report` directory.

Git is not required. Alternative: GitHub **Code → Download ZIP → Extract All → scripts/ad-health-report**. In VSCode use **File → Open Folder** and **Terminal → New Terminal**. Do not run inside the ZIP preview.

## Test at home, without a domain

From the tool directory:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

Tests also support `pwsh`. They use synthetic data/local files; no RSAT, domain credentials or elevation required. Open **examples/SYNTHETIC/Report.html** to explore fictional results without collecting anything.

## Collect in an authorized environment

Use **64-bit Windows PowerShell 5.1**, ActiveDirectory RSAT and an authorized domain account. Running on a DC is not required. Additional collectors need additional modules/rights/connectivity; review the manual and test in a lab first.

Default inventory:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1
```

Comprehensive domain collection:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -CreateArchive
```

Append `-Scope Forest` for all authorized domains, or `-Server 'REAL-DC-NAME'` to select a DC, replacing the name. `-FullAssessment` retains its 1.1 profile; the new profile is `-ComprehensiveAssessment`.

## Added capabilities

- AD Recycle Bin, topology, account flags, SPN/UPN duplicates, additional role groups by SID and lifecycle review.
- GPOs, links, XML metadata/settings, permissions, RSoP and rights by SID.
- DNS administrative configuration, zones, aging, root hints and InProgress indicators.
- Bounded SYSVOL metadata, hardware/BIOS, software and QFE/KB inventory.
- SMB, Spooler, firewall, W32Time, selected registry, audit and log configuration.
- Selected Security events, backup evidence, offline render and optional ZIP.

The original 30 datasets remain, including replication, time measurements, NTDS/SYSVOL disks, memory, services and 17 selected DCDiag tests. Adds 33 datasets. An empty CSV can mean unrequested, no results or failure: **Coverage/CollectionErrors distinguish these cases**.

## Results

Console **RunFolder** identifies the output. Default is a unique directory under `%LOCALAPPDATA%\FMODEL\ADHealth`. Open **Report.html**; CSV files sit alongside it. Use Excel UTF-8/comma import when needed.

`-CreateArchive` creates an adjacent ZIP and displays **Archive**. To regenerate reports from existing JSON:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -FromReport 'C:\Path\Run-...\report.json' -OutputPath 'C:\ADHealth-Study'
```

Replace paths. Offline rendering also supports PowerShell 7 and does not query AD. Manifest-listed evidence is copied after hash/length verification; this does not authenticate the manifest author.

## Interpretation and validation

Selected value review **is not complete SCT baseline compliance or certification**. A recent KB does not prove full patch coverage; backup evidence does not prove recoverability; an encryption flag does not prove actual use. Unknown values are not success. Read the manual for explicit scope/caps.

[Testing and acceptance](docs/MANUAL.en-US.md#44-validation-and-lab-acceptance) · [Technical evidence](tests/evidence/EVIDENCE.json) · [Changelog](CHANGELOG.md) · [CI](https://github.com/fmodel7/scripts/actions)

Automated validation uses synthetic data. No real forest was assessed for this release. Real reports may contain sensitive identities/topology/policies; do not publish them on GitHub.

Documentation is consolidated into **one manual per language**. The only additional file in `docs` is `baseline.example.json`, used by the script.
