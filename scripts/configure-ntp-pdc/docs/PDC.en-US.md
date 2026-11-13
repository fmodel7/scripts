# Configure-NTP-PDC.ps1 — 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Target: **PDC Emulator of the forest root domain**. Run locally as Administrator on Windows Server 2016+, 64-bit PowerShell 5.1/7.

Simulate first:

```powershell
.\Configure-NTP-PDC.ps1 -WhatIf
```

Apply with confirmation:

```powershell
.\Configure-NTP-PDC.ps1
```

Edit NtpServers at the top. Defaults: a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br and e.st1.ntp.br. Use approved hostnames, not IPs or flags. DNS is checked; UDP reachability and trust are not certified.

Expected local result: Type=NTP, approved peers, NtpClient/NtpServer enabled and AnnounceFlags=10.

WhatIf writes no files. After approved application, open Report.html at the printed path. Registry backup is mandatory but cannot undo clock changes. Configured does not prove synchronization. Review source, status /verbose and events. A W32Time policy key blocks execution; do not delete it to evade GPO.

[Manual](MANUAL.en-US.md) · [Testing](TESTING.en-US.md) · [Download](../Windows-Time-v2.0.0.zip?raw=true)
