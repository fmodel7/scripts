# FMODEL Windows Time 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

**Two standalone scripts for Windows time.** Windows Server 2016+ · Windows PowerShell 5.1 / PowerShell 7 · 64 bits.

[Português](README.md) · [English](README.en-US.md) · [Manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf)

## Choose the script

| File | Target | Individual guide |
|---|---|---|
| Configure-NTP-PDC.ps1 | PDC Emulator of the forest root domain | [PDC](docs/PDC.en-US.md) |
| Configure-Time-DOMHIER.ps1 | Other domain servers, including child-domain DCs | [DOMHIER](docs/DOMHIER.en-US.md) |

**Each PS1 works on its own.** The PDC file includes the four original NTP hostnames. DOMHIER uses AD time discovery without hardcoding the PDC address.

## Download

[Download Windows-Time-v2.0.0.zip](Windows-Time-v2.0.0.zip?raw=true). If the file page opens, click **Download raw file**, then **Extract All**.

Alternatively use **Code → Download ZIP → Extract All → scripts/configure-ntp-pdc** from the repository home. Neither Git nor PowerShell 7 is required: 64-bit Windows PowerShell 5.1 is supported too.

## Simulate first

Open PowerShell or VSCode **as Administrator**, open the extracted folder and run only the command appropriate for the target:

```powershell
# On the forest-root PDC:
.\Configure-NTP-PDC.ps1 -WhatIf

# On another domain server:
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

Simulation reads AD/DNS/registry/service state but does not change W32Time or create reports. It does not prove NTP connectivity or future application success.

## Apply

On the correct target, within an approved change window, remove -WhatIf:

```powershell
# Choose only ONE for your target:
.\Configure-NTP-PDC.ps1
.\Configure-Time-DOMHIER.ps1
```

**Confirmation precedes application.** W32Time may adjust the clock. The forest-root PDC accepts only the first script and is blocked by the second. Any W32Time policy key blocks either script: review GPO.

At the top of the PDC file, NtpServers contains a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br and e.st1.ntp.br. Review organizational approval first. These are not mandatory Microsoft sources and current availability was not verified. Use hostnames without literal IPs, URLs or flags.

## Read results

Open Report.html at the path printed in the console. The run folder is under the elevated account's LocalApplicationData, FMODEL/WindowsTime/Run-.... It contains a registry backup, HTML/JSON report and attempted-change journal. Do not publish live output.

Configured confirms local settings, accepted resync request and successful diagnostic command exits. **It does not certify synchronization, accuracy or forest-wide health.** ConfiguredNeedsReview requires investigation; FailedAfterMutationPossible may indicate partial application. There is no automatic rollback; backup cannot undo clock changes.

## Test without a domain or real changes

```powershell
powershell.exe -NoProfile -File .	ests\Test-WindowsTime.ps1
```

For PowerShell 7, replace powershell.exe with pwsh. A regular workstation/VSCode session is sufficient, without elevation. Allow more than 30 seconds: the suite tests a harmless child process timeout.

## Documentation

- [Complete manual](docs/MANUAL.en-US.md) · [PDF](docs/MANUAL.en-US.pdf).
- [PDC guide](docs/PDC.en-US.md) · [DOMHIER guide](docs/DOMHIER.en-US.md).
- [Validation and acceptance](docs/TESTING.en-US.md) · [Internal functions](docs/INTERNALS.en-US.md).
- [History and migration](CHANGELOG.md) · [Evidence](docs/EVIDENCE.json).

**Behavior change:** replaces 1.0.0 in the same folder. No parameters now means application after confirmation; -Apply no longer exists. Use -WhatIf for non-applying preflight. Old helper files are unnecessary.

[CI](https://github.com/fmodel7/scripts/actions/runs/43437702532): 151 assertions / 19 simulated workflows per environment: Windows PowerShell 5.1, PowerShell 7 Windows and Linux mocks. No real PDC or clock was changed.
