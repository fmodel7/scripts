# Configure NTP PDC — FMODEL

**Version 1.0.0 · PowerShell 5.1 and 7 · 64-bit Windows**  
**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · revision assisted by Akira (ChatGPT) · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)

[Português](README.md) · [Full English manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf) · [Review findings](docs/REVIEW.en-US.md)

Audits and configures Windows Time (W32Time) **only on the current PDC Emulator of the forest-root domain**, using explicitly approved manual NTP peers. Other DCs and members normally follow the AD time hierarchy.

**Audit is the default:** without `-Apply`, it does not change W32Time, the service or the clock. Local reports are written. No NTP provider is selected automatically. Real changes require an authorized environment and maintenance window.

## 1. Download the complete folder

[Download v1.0.0 ZIP](Configure-NTP-PDC-v1.0.0.zip?raw=true). Open the file on GitHub and select **Download raw file**, then extract everything.

Alternatively: [Scripts FMODEL](https://github.com/fmodel7/scripts) → **Code → Download ZIP**, extract and open `scripts/configure-ntp-pdc`.

Keep the main PS1 and `src` together. Do not dot-source `tests/Mock-Adapters.ps1` into a work session: it defines fake commands.

## 2. Test without touching a domain

These tests need no elevation or domain. Mutations use synthetic adapters. On Windows, the core suite also reads local registry/CIM state and invokes real w32tm help, without configuring the service.

Run each command separately from this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File .\tests\Test-Core.ps1
pwsh -NoProfile -File .\tests\Test-Workflow.ps1
pwsh -NoProfile -File .\tests\Test-EntryPoint.ps1
```

Use `powershell.exe` instead of `pwsh` for Windows PowerShell 5.1. Expect `PASS`. Linux tests validate mocked functions/workflows; the actual tool requires Windows.

Download and open the [fictional English HTML example](examples/Report-SYNTHETIC.en-US.html) to preview the report. It is not real DC evidence.

## 3. Audit the server first

Open **PowerShell as Administrator** on the Windows server. An elevated VSCode terminal can also be used. Open the tool directory:

```powershell
Get-Location
Get-ChildItem
.\Configure-NTP-PDC.ps1
```

Do not repeat `cd configure-ntp-pdc` when already there. The output shows the run folder and HTML path. Default output: `%LOCALAPPDATA%\FMODEL\NtpPdc\Run-...` for the process account.

Open `Report.en-US.html`. Check domain, root PDC, service, policy and previous state. `AuditCompleted` means the audit finished, not that the clock or target is approved for changes.

## 4. Plan and preview

Select approved sources for your organization: suitable internal appliances or authorized external services. Public peers in examples are not automatically appropriate.

These names came from the supplied script; **they are not defaults and were not queried during development**. Confirm current availability, terms, location, latency and suitability:

```powershell
$peers = @('a.st1.ntp.br', 'c.st1.ntp.br', 'd.st1.ntp.br', 'e.st1.ntp.br')
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply -WhatIf
```

Pass names/IPs only, **without `,0x8`**. The script constructs flags. Preview still performs AD/DNS reads and writes reports. It does not export the `.reg` backup or change registry/service/time state.

Policies, an ineligible target or failed preconditions block Apply, including its preview. No bypass switch exists.

## 5. Apply

Only after reviewing the report and approved sources, in the elevated session:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply
```

The confirmation identifies target and operation. After approval, the script rechecks target/policy, saves backup, configures peers/providers/announcement, restarts or starts W32Time and requests resynchronization. **No automatic rollback exists; a registry export cannot undo a clock adjustment.**

`-Confirm:$false` suppresses the PowerShell prompt when an automation procedure explicitly permits that. Other guards remain; this is not a substitute for review.

## 6. Results

| State | Meaning |
|---|---|
| `AuditCompleted` | Audit finished; no configuration applied. |
| `WhatIf` / `Declined` | Preview or declined operation; W32Time unchanged. |
| `AppliedVerified` | Local settings and observed status met implemented criteria. Not proof of accuracy, upstream authentication or forest-wide synchronization. |
| `AppliedNeedsReview` | Changes occurred; some criteria remain unconfirmed. Not synchronization success. |
| `Blocked` | No W32Time mutation was initiated; local reports/backup may exist. |
| `FailedAfterMutationPossible` | An alteration was attempted; state may be partial. Inspect journal/current state/backup before considering another attempt. |

Outputs include PT-BR/EN-US HTML, technical JSON, previous-state snapshot, native diagnostics, action journal and, for approved Apply, a registry export. They may contain internal names, IPs and operator identity; do not commit real output.

**Validation:** automated Windows PowerShell 5.1, PowerShell 7 on Windows and Linux mocks. No real PDC was configured during development. See [evidence](docs/EVIDENCE.json), [CI](https://github.com/fmodel7/scripts/actions/runs/40010481878), [full manual](docs/MANUAL.en-US.md) and [environment acceptance](docs/ACCEPTANCE.en-US.md).
