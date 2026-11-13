# Testes e aceite — DHCP Transfer 1.0.0

[CI](https://github.com/fmodel7/scripts/actions/runs/43447564768) aprovada: Windows PowerShell 5.1 e PowerShell 7/Windows com 227 verificações cada; PowerShell 7/Linux com 225. São 26 fluxos simulados por ambiente. Localmente também passou em PowerShell 7.4.13/Linux. O funcionamento real é destinado a Windows PowerShell 5.1; executar testes no 7 não certifica compatibilidade operacional do módulo DHCP.

```powershell
powershell.exe -NoProfile -File .	ests\Test-DhcpTransfer.ps1
```

Pode usar pwsh para a suíte. Não exige domínio/DHCP/elevação. AST carrega funções e substitui somente adaptadores de I/O do worker. O fluxo de produção permanece no teste; não há flags de bypass/teste no produto. Um módulo DhcpServer sintético testa os argumentos dos adaptadores reais, inclusive Leases, ScopeOverwrite, Force e avisos. A entrada operacional não é executada.

Os 26 fluxos incluem exportação, configuração sem leases, colisão de XML e hash, falha de runtime, WhatIf/recusa nos dois modos, falha/estrutura inválida na exportação, failover, hash inválido/divergente, troca de identidade, falha/backup vazio, corrida após backup, falha no XML anterior do destino, importação padrão, overwrite, reinício, importação sem leases, avisos nativos e falhas na importação/reinício. Verifica XML/DTD, snapshot e bloqueio de escrita, HTML, journal, parâmetros, caminhos, roteamento remoto simulado e ShouldProcess real.

Limites: sem export/import/backup/restauração DHCP real, sem WinRM real, sem aquisição/renovação de lease por clientes. Os testes não provam versões/schema compatíveis, permissões do serviço, autorização AD, integração real, failover ou disponibilidade de rede. Dados e backups sintéticos não são restauráveis. Artifacts da CI incluem runtime/hashes/logs, com retenção de 30 dias.

## Aceite em laboratório isolado

1. Preparar origem/destino com versões/idioma representativos e controlar acesso dos clientes.
2. Revisar autorização AD, DNS, bindings, relays, permissões de backup e plano de corte/retorno.
3. Testar WhatIf local/remoto e confirmar ausência de novos arquivos/alterações DHCP.
4. Exportar e verificar XML/hash após transferência aprovada ao destino.
5. Importar em destino de laboratório, revisar backups, opções, escopos, reservas e leases.
6. Testar escopo preexistente/avisos e sobrescrita explicitamente aprovada; testar backup negado e falha de comunicação controlada.
7. Testar recuperação com backup nativo e XML anterior, sem supor rollback universal.
8. Validar endereços, DNS/gateway e renovação nos clientes antes do aceite da equipe.

[Manual](MANUAL.pt-BR.md) · [Evidências](EVIDENCE.json)
