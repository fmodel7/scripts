# Configure-NTP-PDC.ps1 — 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Alvo: **PDC Emulator do domínio raiz da floresta**. Execute localmente como Administrador em Windows Server 2016+, PowerShell 5.1/7 de 64 bits.

Simular primeiro:

```powershell
.\Configure-NTP-PDC.ps1 -WhatIf
```

Aplicar com confirmação:

```powershell
.\Configure-NTP-PDC.ps1
```

Edite NtpServers no início do arquivo. Defaults: a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br e e.st1.ntp.br. Use nomes aprovados, não IPs ou flags. DNS é verificado, conectividade UDP e confiança não são certificadas.

Resultado local esperado: Type=NTP, peers aprovados, NtpClient/NtpServer habilitados e AnnounceFlags=10.

WhatIf não grava arquivos. Após aplicação aprovada, abra Report.html no caminho exibido. Backup do Registro é obrigatório; não desfaz relógio. Configured não comprova sincronismo. Revise source, status /verbose e eventos. Chave de política W32Time bloqueia o fluxo; não apague para contornar GPO.

[Manual](MANUAL.pt-BR.md) · [Testing](TESTING.pt-BR.md) · [Download](../Windows-Time-v2.0.0.zip?raw=true)
