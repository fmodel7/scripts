# FMODEL DHCP Transfer 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

[Português](README.md) · [English](README.en-US.md) · [Manual](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf)

Dois scripts independentes para **exportar/importar configuração DHCP e leases**. Operação real: Windows Server 2016+ com DHCP e **Windows PowerShell 5.1 de 64 bits (powershell.exe)**. PowerShell 7 é usado apenas nos testes offline desta edição.

| Arquivo | Função | Guia próprio |
|---|---|---|
| Export-DHCP.ps1 | Exporta DHCPv4/v6 e leases para XML/hash, sem sobrescrever arquivo existente | [Exportação](docs/EXPORT.pt-BR.md) |
| Import-DHCP.ps1 | Prepara backups e importa XML; overwrite e reinício são opções explícitas | [Importação](docs/IMPORT.pt-BR.md) |

## Baixar

[Baixar DHCP-Transfer-v1.0.0.zip](DHCP-Transfer-v1.0.0.zip?raw=true). Se abrir a página do arquivo, clique em **Download raw file**, depois **Extrair Tudo**. Não precisa instalar Git.

Alternativa: **Code → Download ZIP → Extrair Tudo → scripts/dhcp-transfer** na página principal. Abra a pasta no VSCode ou Windows PowerShell. Para operação real, use uma sessão administrativa com acesso ao servidor.

## Testar em uma estação, sem DHCP

Na pasta extraída, em terminal normal:

```powershell
powershell.exe -NoProfile -File .	ests\Test-DhcpTransfer.ps1
```

Pode usar pwsh no lugar de powershell.exe nesse teste. Ele usa dados/adaptadores falsos, cria e remove arquivos temporários e não acessa DHCP ou WinRM real.

## Exportar na origem

No Windows PowerShell elevado do servidor de origem, simule:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
```

Após revisar, execute com confirmação:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

O exemplo gera C:\DHCP-Backup\DHCP-Lab.xml e .sha256 **no servidor**, além da pasta Export-UTC-GUID com relatório HTML e journal. Se já existir, escolha outro nome. Sem FileName, um nome único é gerado automaticamente. Copie o XML e confirme sua integridade por um meio corporativo aprovado.

## Importar no destino

Prepare o corte da origem e o destino em laboratório/janela autorizada. O serviço DHCPServer do alvo precisa estar Running; isso exige controle para não atender clientes indevidamente. Depois de copiar o XML para o destino, simule lá:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Para aplicar com confirmação:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

**O padrão não usa ScopeOverwrite nem reinicia o serviço.** Ainda pode aplicar configurações globais; escopos existentes podem ser ignorados com avisos. Não é uma operação puramente aditiva. Só use -ScopeOverwrite ou -RestartService conforme um plano aprovado; veja o guia de importação.

## Remoto e resultado

Para administrar remotamente, acrescente -DhcpServer com o nome DNS real. Exige WinRM já configurado; não há senha embutida nem alteração automática de TrustedHosts. **Todos os caminhos continuam no servidor escolhido**, e o XML não é copiado automaticamente para sua estação.

WhatIf consulta estado/XML no alvo, sem criar backups/relatórios ou importar/exportar. Após execução aprovada, abra Report.html no RunFolder exibido. Backups e snapshots ficam nessa pasta do servidor.

ImportedAwaitingValidation significa que o cmdlet retornou e houve leitura posterior; **não comprova migração completa ou atendimento aos clientes**. NeedsReview indica avisos; FailedAfterImportPossible exige investigar possíveis mudanças parciais. Não há rollback/retry automático.

## Documentação completa

- [Manual PT-BR](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf).
- [Exportar](docs/EXPORT.pt-BR.md) · [Importar](docs/IMPORT.pt-BR.md).
- [Testes e aceite](docs/TESTING.pt-BR.md) · [Funções](docs/INTERNALS.pt-BR.md) · [Evidências](docs/EVIDENCE.json).
- [Histórico](CHANGELOG.md) · [Catálogo](https://github.com/fmodel7/scripts/blob/main/scripts/README.md).

Leia os limites sobre failover, autorização AD, versões/idioma, origem/destino, relays, credenciais DNS e validação de clientes antes de produção. Não publique XMLs/backups/relatórios reais. Para bloqueio de assinatura, consulte Get-ExecutionPolicy -List e o manual; não desative políticas corporativas.

[CI](https://github.com/fmodel7/scripts/actions/runs/43447564768): 26 simulated workflows; 227 assertions per Windows environment (5.1/7) and 225 on Linux. No real DHCP/WinRM operation was tested.
