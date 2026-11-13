# FMODEL AD Health Report 1.1.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Revision assistance: Akira (ChatGPT)

Active Directory inventory and assisted assessment with an **interactive offline HTML report, CSV and JSON**. The script queries data and writes local reports; it does not repair, remove, disable or change directory objects.

[Português](README.md) · [Complete English manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf) · [Validation evidence](docs/EVIDENCE.json)

## What is included

- Forest/domain, DC, OU, computer, user and group inventory.
- FSMO roles, schema version, password policies, trusts and direct members of selected sensitive groups resolved by SID.
- Structured replication data, collection coverage, errors and findings requiring review.
- HTML with local search, a complete CSV per dataset and technical JSON.
- Optional CIM/WSMan service reads and native diagnostics restricted to selected tests.

**Finishing collection does not prove AD health or compliance.** Permissions, scope and optional checks limit coverage. Missing data is not automatically zero or a positive result.

## Expanded unified collection — 1.1

To combine inventory and operational checks in one PS1:

```powershell
.\Export-ADHealthReport.ps1 -FullAssessment
```

FullAssessment enables A/AAAA/SRV DNS, informational ICMP, boot/memory, volumes and NTDS/SYSVOL paths, W32Time samples/evidence, recent events, services and the 17 selected extended DCDiag tests. Default collection remains lighter. FullAssessment expands depth; scope remains Domain. Add -Scope Forest for all authorized domains.

HTML includes a consolidated DC table with metrics/statuses; every dataset has CSV. Unknown data/access denial never becomes success. Event window/caps are explicit; CSVs preserve all obtained rows within those limits. Review the new parameters before full production collection.

## Download

[Download AD-Health-Report-v1.1.0.zip](AD-Health-Report-v1.1.0.zip?raw=true). If the file page opens, click **Download raw file**, then **Extract All**.

Alternatively use **Code → Download ZIP → Extract All → scripts/ad-health-report** from the repository. Git installation is unnecessary. Open the extracted folder, not the ZIP preview.

## Test first without a domain

From the tool folder in a normal PowerShell session:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
```

The suite also runs with `pwsh`. It uses synthetic data/adapters and does not validate a real forest. No RSAT, domain or elevation is required. [EVIDENCE.json](docs/EVIDENCE.json) records actual tested environments, results and limitations.

## Run a real collection

Use **64-bit Windows PowerShell 5.1 (`powershell.exe`)**, the **ActiveDirectory/RSAT module** and an account with the necessary directory-read permissions. Elevation is not required by default; optional diagnostics can require additional access.

From the extracted folder:

```powershell
.\Export-ADHealthReport.ps1
```

This collects the **selected domain** using implemented defaults. To select a DC explicitly:

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com
```

Replace `dc01.example.com` with an authorized real server. The context is pinned to the DC identified by RootDSE; the example hostname is not a built-in default.

## Expand collection when appropriate

Collect domains in the forest:

```powershell
.\Export-ADHealthReport.ps1 -Scope Forest
```

Include optional services/native diagnostics:

```powershell
.\Export-ADHealthReport.ps1 -IncludeServiceChecks -IncludeDcDiagnostics
```

These options add queries and can require different access/connectivity. They do not enable WinRM or modify firewall/services. No independent test is gated by successful ping; access failures/timeouts are collection limitations, not isolated proof that a DC is down.

## Open HTML and CSV

The default output is a unique folder under `%LOCALAPPDATA%\FMODEL\ADHealth` for the executing account. Open **Report.html** using the path printed in the console.

`MaxHtmlRows` limits HTML presentation only. CSV/JSON retain collected data even when browser tables are reduced. This does not recover failed/skipped queries: inspect `coverage.csv` and `collectionerrors.csv`.

CSV uses commas and UTF-8 with BOM. If Excel does not detect it correctly, use **Data → From Text/CSV**, choosing UTF-8 and comma delimiters. Potential spreadsheet formulas receive an apostrophe prefix; JSON is not subjected to this spreadsheet neutralization.

## Documentation and limits

The [English manual](docs/MANUAL.en-US.md) and [Portuguese manual](docs/MANUAL.pt-BR.md) explain every parameter, dataset, state, permission, finding rule, limitation and authorized lab acceptance. PDF editions are in `docs`.

The report does not read passwords, password hashes, LAPS secrets or gMSA keys. It is not a complete ACL, effective privilege, GPO, patch or AD security audit. Names, SIDs, memberships and topology are sensitive: **do not publish real reports in GitHub**.

No production forest was validated for this delivery. Automated tests and their evidence do not replace acceptance in the authorized environment.

## Preview and validation

After extracting the ZIP, open [examples/SYNTHETIC/Report.html](examples/SYNTHETIC/Report.html) to explore fictional data without a domain. The example includes all 30 CSVs and matching JSON; it is not evidence of a real environment.

[CI](https://github.com/fmodel7/scripts/actions/runs/43465971682) · [Testing](docs/TESTING.en-US.md) · [Internal reference](docs/INTERNALS.en-US.md)
