# Configure-Time-DOMHIER.ps1 — 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Target: **other domain-joined servers, including child-domain DCs/PDCs**. Run locally as Administrator on Windows Server 2016+, 64-bit PowerShell 5.1/7.

Simulate first:

```powershell
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

Apply with confirmation:

```powershell
.\Configure-Time-DOMHIER.ps1
```

Do not supply external NTP or a PDC address. AD discovers sources. This file blocks the root PDC. Expected result: Type=NT5DS, NtpClient enabled and AnnounceFlags=10. Old manual entries may remain stored; NtpServer.Enabled is preserved.

WhatIf writes no files. After approved application, open Report.html at the printed path. Registry backup is mandatory but cannot undo clock changes. Configured does not prove synchronization. Review source, status /verbose and events. A W32Time policy key blocks execution; do not delete it to evade GPO.

[Manual](MANUAL.en-US.md) · [Testing](TESTING.en-US.md) · [Download](../Windows-Time-v2.0.0.zip?raw=true)
