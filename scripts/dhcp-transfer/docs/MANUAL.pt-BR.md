# Manual completo — FMODEL DHCP Transfer 1.0.0

FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO  
F. Model · fmodel@fmodel.com.br · Revisão com assistência de Akira (ChatGPT)  
13/11/2026 · [English](MANUAL.en-US.md) · [Início](../README.md)

## 1. Objetivo e alcance

Export-DHCP.ps1 exporta configurações DHCPv4/DHCPv6 e, por padrão, concessões (leases) para XML. Import-DHCP.ps1 importa um XML no destino após confirmação e preparação de backups. Cada PS1 é independente e contém o mesmo mecanismo interno; não há módulo auxiliar da FMODEL para instalar.

São ferramentas de exportação/importação, não uma migração completa de infraestrutura. Não instalam a função, não autorizam/desautorizam servidores no AD, não desligam a origem, não mudam IP, DNS, bindings ou relays, não recriam failover e não validam aquisição de endereço por clientes. As configurações presentes no XML podem ser aplicadas pelo cmdlet nativo; o script não edita ou remove partes do XML para tentar garantir compatibilidade.

## 2. Correções sobre os arquivos recebidos

O importador estava dentro de um comentário de bloco; agora é um arquivo executável separado. A sobrescrita de arquivos de exportação não é mais forçada. ScopeOverwrite deixa de ser automático e passa a exigir opção explícita. Restart-Service não recebe ComputerName: o reinício opcional ocorre no próprio destino, sem -Force. O tratamento de erros usa Stop nas operações verificadas, registra estado e diferencia falha antes/depois da tentativa de importar.

O log fixo é substituído por uma pasta única por execução, relatório HTML/JSON e diário JSONL. A importação prepara backup nativo e XML anterior e usa uma cópia estável do arquivo de entrada. O script não declara atendimento DHCP comprovado porque um cmdlet terminou sem erro.

## 3. Requisitos e permissões

Para operação real: Windows Server 2016 ou posterior no alvo, função DHCP e módulo DhcpServer instalados, serviço DHCPServer em Running e contexto administrativo elevado no alvo. O worker exige Windows PowerShell 5.1 de 64 bits. Use powershell.exe, não pwsh.exe. PowerShell 7 é utilizado para testes offline, não para a execução operacional desta edição.

Não há senha embutida nem parâmetro Credential. A execução local usa o token atual; a remota usa a configuração existente do PowerShell Remoting/WinRM. O contexto real e SID são registrados. A ferramenta não habilita remoting, não muda TrustedHosts, políticas de execução ou firewall e não concede privilégios. Permissão de administrar DHCP não equivale automaticamente à permissão de autorizar um servidor no AD.

O operador precisa criar/ler arquivos no diretório escolhido. A identidade usada pelo serviço/API de backup também precisa conseguir gravar ali. ACLs não são alteradas automaticamente; se houver Access Denied, corrija o acesso estritamente necessário com a equipe responsável, sem conceder Full Control a Everyone. Planeje espaço para XML, snapshot e múltiplos backups.

## 4. Baixar e abrir

Na pasta scripts/dhcp-transfer do GitHub, abra DHCP-Transfer-v1.0.0.zip, clique em Download raw file e Extraia Tudo. Alternativa: Code → Download ZIP na página principal, extrair e entrar em scripts/dhcp-transfer. Não execute dentro da visualização do ZIP. Os dois PS1 podem ser distribuídos isoladamente, mas o pacote inclui documentação e testes.

No Windows, abra Windows PowerShell como Administrador e use Set-Location com o caminho real da pasta extraída. No VSCode, abra como Administrador, File → Open Folder, selecione a pasta e abra um terminal com perfil Windows PowerShell. A extensão Microsoft PowerShell ajuda na edição, mas não é requisito. Se o perfil padrão for PowerShell 7, selecione Windows PowerShell ou inicie powershell.exe. Preserve UTF-8 com BOM ao editar.

```powershell
Get-Location
Get-ChildItem
$PSVersionTable
```

## 5. Testes offline para alunos

Em uma estação comum, sem domínio, DHCP ou elevação:

```powershell
powershell.exe -NoProfile -File .\tests\Test-DhcpTransfer.ps1
```

Também funciona com pwsh no lugar de powershell.exe. A suíte extrai funções pela AST, não executa as entradas operacionais. Usa XML e dados sintéticos, módulo DHCP falso e adaptadores substituídos. Cria arquivos temporários e os remove; não se conecta a servidores nem altera um serviço ou base DHCP real. Veja TESTING.pt-BR.md e EVIDENCE.json para resultados, ambientes e limites.

## 6. Local e remoto: onde ficam os arquivos

DhcpServer='.' significa o próprio computador. Um nome igual a COMPUTERNAME também usa o caminho local; outros nomes DNS usam Invoke-Command. Um FQDN do próprio servidor pode usar WinRM; prefira ponto para operação local. Não são aceitos IP literal, URI, lista de computadores ou caracteres de comando no nome do servidor.

**Todos os caminhos são locais ao servidor escolhido**, inclusive ExportPath, ImportFile, BackupPath, XML final, sidecar de hash, backups e relatórios. O arquivo não é copiado automaticamente para a estação de administração. Na operação remota, um worker completo é enviado ao alvo; os cmdlets DHCP e o eventual reinício executam localmente lá. Isso evita confusão entre caminhos do cliente, do servidor e de uma sessão de compatibilidade.

WinRM deve estar previamente configurado e autorizado. Uma sessão Plan faz a pré-validação e outra Apply executa após aprovação. Não há credencial adicional ou acesso a compartilhamentos pelo worker; caminhos UNC/unidades de rede não são aceitos. Para transferir o XML entre origem e destino, use um meio corporativo aprovado fora desse fluxo; acesso a compartilhamento dentro de uma sessão WinRM pode envolver restrições de segundo salto.

## 7. Exportação — caminho inicial

No servidor de origem, simule:

```powershell
.\Export-DHCP.ps1 -WhatIf
```

Para exportar após confirmação:

```powershell
.\Export-DHCP.ps1
```

O padrão é C:\DHCP-Backup e um FileName único DHCP-Export-UTC-ID.xml. O console mostra Computer, File, SHA256 e RunFolder. Como o nome padrão é gerado a cada chamada, a simulação e a execução podem mostrar nomes diferentes. Para um nome conhecido no laboratório:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

Se esse XML ou seu arquivo .sha256 já existir, escolha outro nome. Não há opção Force para sobrescrevê-los. Exportar não desliga o servidor de origem nem impede que novos leases ocorram depois do snapshot; planeje a janela de corte conforme a arquitetura.

## 8. Exportação remota

Na sessão Windows PowerShell de administração com WinRM autorizado:

```powershell
.\Export-DHCP.ps1 -DhcpServer DHCP-ORIGEM -ExportPath C:\DHCP-Backup -FileName `
    DHCP-Lab.xml -WhatIf
.\Export-DHCP.ps1 -DhcpServer DHCP-ORIGEM -ExportPath C:\DHCP-Backup -FileName DHCP-Lab.xml
```

Substitua DHCP-ORIGEM pelo nome real. C:\DHCP-Backup estará no DHCP-ORIGEM. Copie o XML e o hash para um local protegido no destino por um procedimento aprovado. Confirme o hash por um canal confiável antes da importação.

## 9. Importação — planejamento e execução

Prepare o destino e o corte da origem com a equipe de rede/AD. O serviço do destino deve estar Running para os cmdlets desta ferramenta; portanto, o ambiente deve estar isolado/preparado para evitar atendimento simultâneo ou entrega indevida de endereços. Este requisito não substitui o procedimento Microsoft de migração completo, que inclui etapas adicionais de parada/início e autorização.

Depois de colocar o XML no destino, simule no próprio destino:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Para importar com confirmação, sem sobrescrever escopos existentes nem reiniciar automaticamente:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

**Sem ScopeOverwrite não significa operação apenas aditiva:** o cmdlet ainda pode aplicar configurações globais do servidor. Escopos já existentes podem ser ignorados com aviso nativo; os avisos são preservados e o resultado passa a NeedsReview. Não considere a importação completa sem conferir o conteúdo aplicado.

## 10. Opções destrutivas explícitas

Somente quando o plano aprovado exigir substituir escopos existentes:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ScopeOverwrite -WhatIf
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ScopeOverwrite
```

ScopeOverwrite autoriza o comportamento nativo de substituir escopos presentes; não é um merge campo a campo. RestartService é uma opção separada e pode interromper temporariamente o atendimento:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -RestartService
```

Para remoto, acrescente -DhcpServer DHCP-DESTINO. A mesma confirmação mostra servidor, arquivo, leases, sobrescrita e reinício. Confirm:$false dispensa somente a pergunta externa em automação previamente aprovada; não é indicado como primeiro caminho para alunos. O Force interno do cmdlet Import-DhcpServer suprime sua pergunta depois dessa aprovação e não ativa ScopeOverwrite por conta própria.

## 11. Todos os parâmetros

### Export-DHCP.ps1

| Parâmetro | Padrão | Efeito |
|---|---|---|
| DhcpServer | . | Alvo local ou nome DNS remoto. |
| ExportPath | C:\DHCP-Backup | Diretório local no alvo para XML e pasta da execução. |
| FileName | Nome XML com UTC e ID aleatório | Nome simples, ASCII, até 150 caracteres, sem diretórios; recusa XML/hash existentes. |
| ConfigurationOnly | false | Omite leases; mantém configurações e todos os escopos IPv4/IPv6. |

### Import-DHCP.ps1

| Parâmetro | Padrão | Efeito |
|---|---|---|
| DhcpServer | . | Alvo local ou nome DNS remoto. |
| ImportFile | Obrigatório | XML já presente em caminho absoluto local no alvo. |
| BackupPath | C:\DHCP-Backup | Base para uma pasta única da importação e seus backups/logs. |
| ConfigurationOnly | false | Não importa leases; ainda importa configurações e escopos. |
| ScopeOverwrite | false | Autoriza substituir escopos existentes. |
| RestartService | false | Reinicia DHCPServer no destino após o retorno da importação. |
| ExpectedSha256 | Vazio | Se informado, exige 64 dígitos hexadecimais e coincidência do XML. |

ConfigurationOnly não equivale ao ServerConfigOnly do cmdlet Microsoft. Não há filtros ScopeId/Prefix nesta edição: a operação usa todo o conteúdo suportado do XML, IPv4 e IPv6. WhatIf/Confirm são parâmetros comuns de SupportsShouldProcess, com impacto High. ErrorAction/Verbose também são parâmetros da plataforma; operações verificadas usam Stop.

## 12. XML, hash e arquivo de entrada estável

O leitor XML é streaming, proíbe DTD e não resolve entidades externas. Exige arquivo não vazio, documento bem formado e raiz DHCPServer. Não é validação pelo XSD oficial nem garantia de compatibilidade entre versões: a validação semântica continua sendo responsabilidade do cmdlet nativo e do aceite. XML de origem não confiável não deve ser importado apenas porque passou nesses testes.

SHA256 é calculado sobre os bytes completos, não sobre XML normalizado. ExpectedSha256 pode ser preenchido com o valor obtido da exportação e confirmado por um canal confiável:

```powershell
$hash = (Get-FileHash C:\DHCP-Backup\DHCP-Lab.xml -Algorithm SHA256).Hash
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ExpectedSha256 $hash -WhatIf
```

Calcular hash do próprio arquivo recebido confirma identidade com esse mesmo arquivo, não autenticidade de sua origem. O script não lê automaticamente o sidecar .sha256 e não usa assinatura digital como prova do XML. Após aprovação, copia o XML para InputSnapshot.xml com CreateNew, recalcula o hash contra o plano aprovado e mantém um handle somente de leitura que nega escritores durante a importação. O original não é alterado.

## 13. Backups antes de importar

Na pasta Import-UTC-GUID, prepara PreImportNative com Backup-DhcpServer e exige ao menos um arquivo de tamanho positivo. Em seguida exporta DestinationBefore.xml com leases e valida sua estrutura XML. Falha nessas etapas impede chamar Import-DhcpServer. Registra BackupSaved no HTML/JSON antes de importar.

Depois cria ImportCmdletBackup e fornece esse caminho ao próprio Import-DhcpServer, que também realiza seu backup prévio. Esses caminhos são distintos para evitar misturar as etapas. Um conjunto não vazio não prova que o backup pode ser restaurado; restauração deve ser testada em laboratório. Espaço, permissões e conteúdo do backup são parte do aceite.

## 14. Fluxo interno e concorrência

Plan verifica ambiente/token, módulo, serviço, escopos v4/v6, failover e caminhos. Para importação, lê XML e hash. WhatIf ou recusa termina antes de criar diretórios, backups ou arquivos. As consultas e a conexão WinRM ainda ocorrem; não é simulação de atendimento DHCP e não prova permissões futuras de escrita.

Apply revalida alvo e arquivo aprovado, adquire o mutex local Global\FMODEL.DhcpTransfer e lê novamente o contexto. A identidade MachineGuid, caminhos e dados selecionados ajudam a detectar trocas. Antes da tentativa de importar, relê o contexto após os backups. Essas verificações não são transação distribuída: GPO, administradores e outras ferramentas não obedecem ao mutex; mudanças em opções não incluídas no inventário podem ocorrer sem serem detectadas. A identidade local registrada não é atestado criptográfico do hardware.

Na exportação, o XML primeiro vai para Export.partial.xml na pasta da execução. Após checagem de XML/hash, File.Move publica o nome final sem sobrescrever. Cria o sidecar também com CreateNew. Falha depois da publicação pode deixar XML final sem hash ou relatório completo; ExportFailed não significa ausência de arquivo. Não há limpeza automática que apague evidências.

## 15. Relatórios, journal e privacidade

Cada execução aprovada cria Export-UTC-GUID ou Import-UTC-GUID em ExportPath/BackupPath. O console retorna caminhos no servidor; abra Report.html no navegador depois de acessá-lo por procedimento autorizado. O HTML é offline, sem JavaScript ou recursos remotos, com codificação dos dados e resumo PT-BR/EN-US. report.json guarda estado, operador/SID, inventário anterior/posterior, opções, avisos, caminhos e erro.

actions.jsonl registra STARTED, INTENT e COMPLETED. Cada registro é gravado com Flush(true); INTENT precede etapas de exportação/backup/importação/reinício. Um INTENT sem COMPLETED indica resultado desconhecido ou falha, não ausência de alteração. Os arquivos HTML/JSON são sobrescritos diretamente, sem transação atômica; disco cheio/interrupção pode deixá-los incompletos. Falha final de relatório sai com 1, mesmo se o serviço já mudou.

XMLs e backups podem expor IPs, MACs, reservas, hostnames e arquitetura interna. A ferramenta não criptografa, não endurece ACLs, não faz upload, não envia e-mail e não remove arquivos por retenção. ACLs são herdadas; aplique controles corporativos. Não publique exportações reais, snapshots, backups ou relatórios no Git. O manifesto SHA256 do pacote não é assinatura dos scripts nem um mecanismo para contornar execução corporativa.

## 16. Estados e códigos de saída

| Estado | Código | Significado |
|---|---|---|
| NotApplied | 0 | WhatIf ou recusa; nenhuma pasta de execução criada. |
| Exported | 0 | Cmdlet de exportação retornou, XML foi validado estruturalmente e XML/hash foram publicados. |
| ImportedAwaitingValidation | 0 | Import retornou e inventário posterior foi lido; conferir resultados e clientes. |
| NeedsReview | 2 | Import retornou avisos, como escopos ignorados; analisar resultado parcial/esperado. |
| Blocked | 1 | Nenhuma tentativa de Import-DhcpServer começou; backups/logs podem existir. |
| ExportFailed | 1 | Exportação ou publicação falhou; arquivos parciais/finais podem existir. |
| FailedAfterImportPossible | 1 | Importação foi tentada; pode haver aplicação parcial ou falha posterior no reinício/diagnóstico. |

BackupSaved é intermediário. Falhas de plataforma, binding, preflight, mutex ou comunicação podem não gerar relatório. Se WinRM cair depois de enviar Apply, o cliente pode retornar 1 sem saber o resultado no servidor: examine a pasta e o estado do DHCP antes de repetir. Não há retry ou rollback automático. Execute como arquivo, não por dot-sourcing; para processo filho, consulte LASTEXITCODE na sessão chamadora.

## 17. Confirmação operacional

Depois da importação, examine relatórios e console DHCP, escopos v4/v6, estados, ranges, exclusões, reservas, opções de servidor/escopo, políticas e leases. Compare com o inventário e XML da origem, sem assumir igualdade por contagem. Confirme bindings, autorização AD, DNS dinâmico/credenciais, relays, firewall e rota. A ferramenta não valida cada opção, lease, reserva ou política e não compara semanticamente o XML com o destino.

Teste clientes em redes/VLANs autorizadas: endereço correto, gateway, DNS, duração de lease, renovação e eventos. Observar o serviço Running não prova entrega DHCP. Garanta que não existam dois servidores independentes servindo indevidamente o mesmo pool. A decisão de parar/desautorizar a origem e ativar o destino é parte do plano de corte, não um efeito automático do script.

## 18. Failover e compatibilidade

O exportador pode gerar cópia de um servidor que tenha failover, mas isso não migra a relação. O importador bloqueia um destino com relacionamentos IPv4 detectados. Não há bypass. O arquivo de origem não é certificado quanto a relações/estado failover; use o procedimento específico da Microsoft para origem com failover, clusters, split-scope ou ambientes de múltiplas funções.

Verifique versões, updates, idioma de interface, caminhos de base e requisitos do cenário. Não se presume compatibilidade bidirecional entre qualquer Windows Server, nem se corrige XML removendo tags que um destino não aceita. Credenciais de atualização DNS, autorização e configuração de parceiros podem exigir tratamento separado. Consulte o guia de migração e as referências antes de produção.

## 19. Erros frequentes e recuperação

Script não assinado: execute Get-ExecutionPolicy -List. MachinePolicy/UserPolicy podem exigir assinatura; não troque indiscriminadamente para Unrestricted/Bypass. Quando permitido por RemoteSigned e após revisar a origem, Unblock-File -LiteralPath .\Export-DHCP.ps1 remove a marca de download; isso não contorna AllSigned ou GPO. O importador e o teste seguem a mesma regra.

DhcpServer module/service ausente: revise a função instalada no alvo; a ferramenta não instala componentes. WinRM indisponível: confirme DNS, endpoint, autenticação e permissão com a equipe de domínio. Caminho não encontrado no remoto: lembre que é no servidor, não na estação. Backup Access Denied: revisar espaço, ACLs e identidade do serviço sem enfraquecer globalmente as permissões.

Hash divergente ou XML inválido: obtenha uma nova exportação aprovada e investigue transferência/integridade; não ignore ou edite o arquivo às cegas. Escopos já existem: veja os avisos e decida, em janela autorizada, se ScopeOverwrite é apropriado. Falha parcial: preserve logs/backup, compare estado atual e prepare recuperação; não repita automaticamente com overwrite.

Restauração nativa com Restore-DhcpServer ou reimportação do XML anterior exige análise e procedimento próprio, pode causar indisponibilidade e não desfaz efeitos externos no AD, DNS, relays ou clientes. Não há rollback universal seguro. Teste restauração isolada e documente quem autoriza a recuperação.

## 20. Aceite e referências

Antes de produção, faça laboratório isolado com a mesma combinação de versões/idiomas. Teste exportação local/remota, integridade após transferência, importação sem e com escopos preexistentes, avisos, overwrite aprovado, permissão de backup, perda de sessão e restauração. Registre validação de clientes e plano de corte. Os testes de desenvolvimento não exportaram/importaram uma base DHCP real nem fizeram conexão WinRM real.

Fontes primárias consultadas para arquitetura e parâmetros; o projeto não é certificado ou endossado pela Microsoft:

- Export-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/export-dhcpserver
- Import-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/import-dhcpserver
- Backup-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/backup-dhcpserver
- Migração DHCP: https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/migrate-dhcp-server
- Migração de failover existente: https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/migrate-existing-dhcp-failover

[Guias individuais](../README.md) · [Testes](TESTING.pt-BR.md) · [Evidências](EVIDENCE.json)
