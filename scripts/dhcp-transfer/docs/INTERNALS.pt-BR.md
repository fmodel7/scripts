# Funções internas — DHCP Transfer 1.0.0

Os PS1 são entradas executáveis, não módulos. Não faça dot-sourcing. O worker embutido é idêntico nos dois arquivos; as funções internas não são uma API pública.

## Invoke-DhcpWorker

Worker completo executado no alvo: pré-validação, mutex, exportação/importação, backups e relatórios. [Source](../Export-DHCP.ps1#L29).

## Get-DhcpContext

Valida Windows Server/PowerShell 5.1/elevação/serviço, carrega DhcpServer e lê escopos e failover locais. [Source](../Export-DHCP.ps1#L34).

## Resolve-DhcpPath

Exige caminho absoluto de volume local, rejeita UNC/rede, wildcard, ADS e reparse points existentes. [Source](../Export-DHCP.ps1#L58).

## Test-DhcpFileName

Valida nome XML ASCII simples, extensão, limite e nomes DOS reservados. [Source](../Export-DHCP.ps1#L79).

## Get-DhcpXmlInfo

Leitura streaming com DTD proibido; verifica raiz/documento e calcula bytes/SHA256. Não valida XSD. [Source](../Export-DHCP.ps1#L87).

## Invoke-DhcpExport

Chama Export-DhcpServer local sem Force, com Leases explícito e erros/avisos terminantes. [Source](../Export-DHCP.ps1#L110).

## Invoke-DhcpBackup

Chama Backup-DhcpServer local com erros/avisos terminantes. [Source](../Export-DHCP.ps1#L116).

## Invoke-DhcpImport

Importa snapshot com BackupPath, Leases e ScopeOverwrite explícitos; coleta avisos. Force suprime pergunta nativa após confirmação externa. [Source](../Export-DHCP.ps1#L121).

## Restart-DhcpLocalService

Reinicia no alvo sem ComputerName/Force e aguarda Running até 30 s após retorno de Restart-Service. [Source](../Export-DHCP.ps1#L129).

## Write-DhcpJournal

Acrescenta JSONL com FileStream e Flush(true). [Source](../Export-DHCP.ps1#L134).

## Write-DhcpReport

Grava JSON e HTML offline bilíngue, codificando dados inseridos. [Source](../Export-DHCP.ps1#L142).

## Copy-DhcpSnapshot

Copia fonte aberta para leitura, destino CreateNew e Flush(true). [Source](../Export-DHCP.ps1#L166).

## Get-DhcpPlan

Verifica contexto/caminhos, colisões de exportação, failover do destino, XML/hash da entrada. [Source](../Export-DHCP.ps1#L175).

## Invoke-DhcpTarget

Escolhe chamada local ou Invoke-Command, enviando o worker completo e uma requisição ao alvo. [Source](../Export-DHCP.ps1#L280).

## Invoke-DhcpTransfer

Valida nome/hash, solicita Plan, chama ShouldProcess e envia Apply com o plano aprovado. [Source](../Export-DHCP.ps1#L289).

Request é um objeto interno com Mode, Stage, caminhos, opções e Plan; não há endpoint de serviço público ou backdoor de testes. Resultado inclui Status, ExitCode, Computer, File, SHA256, RunFolder e Error.
