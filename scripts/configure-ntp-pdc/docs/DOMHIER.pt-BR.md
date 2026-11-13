# Configure-Time-DOMHIER.ps1 — 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Alvo: **demais servidores ingressados no domínio, inclusive DCs/PDCs filhos**. Execute localmente como Administrador em Windows Server 2016+, PowerShell 5.1/7 de 64 bits.

Simular primeiro:

```powershell
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

Aplicar com confirmação:

```powershell
.\Configure-Time-DOMHIER.ps1
```

Não informe NTP externo nem endereço do PDC. O AD descobre as fontes. Este arquivo bloqueia o PDC raiz. Resultado esperado: Type=NT5DS, NtpClient habilitado e AnnounceFlags=10. A lista manual antiga pode permanecer armazenada e NtpServer.Enabled é preservado.

WhatIf não grava arquivos. Após aplicação aprovada, abra Report.html no caminho exibido. Backup do Registro é obrigatório; não desfaz relógio. Configured não comprova sincronismo. Revise source, status /verbose e eventos. Chave de política W32Time bloqueia o fluxo; não apague para contornar GPO.

[Manual](MANUAL.pt-BR.md) · [Testing](TESTING.pt-BR.md) · [Download](../Windows-Time-v2.0.0.zip?raw=true)
