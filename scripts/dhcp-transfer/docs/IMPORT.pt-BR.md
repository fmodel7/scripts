# Import-DHCP.ps1 — 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

Use Windows PowerShell 5.1 de 64 bits, com administração elevada no alvo Windows Server 2016+ com DHCPServer Running. Todos os caminhos pertencem ao servidor escolhido.

Simular:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Executar com confirmação:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

Antes da importação, revise autorização, origem/corte, versões/idioma, rede e clientes. O padrão pode mudar opções globais, mesmo sem -ScopeOverwrite. Escopos existentes podem ser ignorados com aviso. Use -ScopeOverwrite somente para substituição aprovada, e -RestartService somente se o reinício for desejado. Nenhuma dessas opções está ativa por padrão.

-ConfigurationOnly omite leases, não escopos. -ExpectedSha256 aceita o hash aprovado. -BackupPath seleciona a base da pasta Import-UTC-GUID. Ali ficam InputSnapshot.xml, PreImportNative, DestinationBefore.xml, ImportCmdletBackup e os relatórios. Falha nos dois backups preparatórios bloqueia o import. Destino com failover é bloqueado; origem com failover exige procedimento próprio.

ImportedAwaitingValidation não comprova atendimento DHCP. Revise avisos, opções, escopos/leases e teste clientes antes de concluir. Não há rollback automático.

Para remoto, acrescente -DhcpServer NOME-DNS-REAL; WinRM deve existir. O XML e relatórios continuam no alvo, sem transferência automática. WhatIf não cria arquivos. Não use pwsh para a operação real desta edição.

[Manual completo / Full manual](MANUAL.pt-BR.md) · [Testing](TESTING.pt-BR.md) · [Download](../DHCP-Transfer-v1.0.0.zip?raw=true)
