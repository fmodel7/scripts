# Export-DHCP.ps1 — 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Use Windows PowerShell 5.1 de 64 bits, com administração elevada no alvo Windows Server 2016+ com DHCPServer Running. Todos os caminhos pertencem ao servidor escolhido.

Simular:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
```

Executar com confirmação:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

Inclui todos os escopos/configurações IPv4/IPv6 e leases. -ConfigurationOnly omite apenas leases, não escopos. -ExportPath muda a pasta base; -FileName aceita nome XML simples, sem diretórios. Nenhuma sobrescrita é permitida. Sem FileName, gera UTC/ID único.

O console retorna File e SHA256; o sidecar .sha256 fica junto do XML. A pasta Export-UTC-GUID contém Report.html, report.json e actions.jsonl. Exportação não desliga a origem ou prepara automaticamente o corte.

Para remoto, acrescente -DhcpServer NOME-DNS-REAL; WinRM deve existir. O XML e relatórios continuam no alvo, sem transferência automática. WhatIf não cria arquivos. Não use pwsh para a operação real desta edição.

[Manual completo / Full manual](MANUAL.pt-BR.md) · [Testing](TESTING.pt-BR.md) · [Download](../DHCP-Transfer-v1.0.0.zip?raw=true)
