# Manual técnico e operacional — Configure NTP PDC 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · fmodel@fmodel.com.br · 23/10/2026

[Início](../README.md) · [English](MANUAL.en-US.md) · [Revisão do original](REVIEW.pt-BR.md) · [Aceitação](ACCEPTANCE.pt-BR.md)

Este manual descreve o código entregue, suas decisões de engenharia e os limites observados. As referências Microsoft ajudam a fundamentar a arquitetura; este projeto não é um produto Microsoft nem recebeu certificação ou endosso da empresa. Não houve configuração de um PDC real durante o desenvolvimento.

## 1. Objetivo, arquitetura e escopo

O script configura fontes NTP manuais no **PDC Emulator do domínio raiz da floresta AD DS**. PDC de domínio filho não é o mesmo alvo. Fontes aprovadas podem ser appliances internos ou serviços externos; “externo à hierarquia AD” não significa obrigatoriamente “público na Internet”.

A documentação Microsoft distingue o PDC da raiz dos demais membros da hierarquia. A ferramenta implementa esse recorte e não oferece modo de configurar todos os DCs, alterar FSMO, conceder permissões ou modificar políticas. [Referência de arquitetura](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

Fluxo implementado:

```text
Validar Windows/elevação -> capturar contexto e estado -> resolver peers pedidos
    -> Audit: relatórios, sem aplicação
    -> Apply: validar alvo/política -> ShouldProcess -> lock local
       -> revalidar -> snapshot + exportação -> persistir relatório
       -> revalidar novamente -> intenção durável -> alterações
       -> serviço + resync -> verificar configuração e status -> relatórios
```

Não faz varredura automática da floresta, não instala software, não muda fuso horário, não executa Set-Date, não altera firewall, hipervisor, provedores de VM ou limites de correção de fase. Também não registra/desregistra W32Time. Não é monitoramento contínuo ou correção automática após transferência de função PDC.

## 2. Arquivos, dependências e permissões

| Arquivo | Uso |
|---|---|
| Configure-NTP-PDC.ps1 | Entrada com parâmetros, confirmação e códigos de saída. |
| src/NtpPdc.Core.ps1 | Validações, processo nativo, backup, aplicação, verificação e relatórios. |
| tests/Test-Core.ps1 | Parser, normalização, estados, persistência e leituras locais opcionais no Windows. |
| tests/Test-Workflow.ps1 | 18 fluxos com adaptadores falsos. |
| tests/Test-EntryPoint.ps1 | Três processos reais de entrada com dependências substituídas. |
| tests/Mock-Adapters.ps1 | Auxiliar dos testes; não é uma ferramenta de uso operacional. |
| examples/Report-SYNTHETIC.*.html | Prévia fictícia do relatório, sem domínio real. |
| docs/EVIDENCE.json | Versão, hashes, ambientes e limites da validação. |
| MANIFEST-SHA256.txt | Hash dos arquivos distribuídos; não é assinatura digital. |

A entrada operacional requer Windows de 64 bits e sessão elevada, inclusive para seus diagnósticos w32tm. Apply exige Windows Server 2016 ou posterior e identificação como DC/PDC raiz. Windows PowerShell 5.1 e PowerShell 7 são cobertos pelos testes; o módulo AD do RSAT não é requerido. A consulta de domínio usa a API .NET System.DirectoryServices, carregada explicitamente no caminho DC.

Não há credencial ou segredo em parâmetros. As operações usam o token atual e o contexto do computador. Administrador local elevado e acesso funcional ao AD são pré-condições; o script não adiciona usuários a grupos nem contorna ACLs. Não exige uma conta de administrador global Microsoft 365, que é um sistema diferente.

DNS, AD e W32Time precisam estar operacionais. Se o problema de horário impedir a própria descoberta AD, o script bloqueia a aplicação. Esse caso exige procedimento de recuperação separado com a equipe AD; não existe opção de forçar uma função PDC não comprovada.

## 3. Todos os parâmetros

| Parâmetro | Padrão/faixa | Efeito |
|---|---|---|
| NtpServers | Array vazio; 0–10 entradas no binding | Nomes/IPs aprovados, sem flags, URL ou espaços. Apply exige ao menos um. |
| Apply | false | Habilita o caminho de alteração depois das pré-condições e confirmação. |
| ReliabilityMode | Automatic; Automatic/Always | AnnounceFlags 10 ou 5, respectivamente. |
| OutputPath | Vazio -> LocalApplicationData/FMODEL/NtpPdc | Diretório local de relatórios/backup; caminhos relativos seguem a localização PowerShell; não usar compartilhamento UNC ou unidade identificada como rede. |
| ProbePeers | false | Solicita stripchart de três amostras para cada peer pedido; exige NtpServers. |
| NativeTimeoutSeconds | 20; 5–120 | Tempo de espera por processo nativo. |
| VerificationTimeoutSeconds | 120; 10–600 | Janela de polling medida por Stopwatch; não é timeout global. |
| VerificationIntervalSeconds | 5; 1–30 | Espera entre tentativas de leitura de status. |
| MaxSyncAgeSeconds | 300; 30–86400 | Idade máxima reconhecida do último bom sincronismo. Não altera esse valor no W32Time. |
| WhatIf | false; parâmetro comum | Simula Apply após validação; permite consultas e relatórios, não mutações W32Time. |
| Confirm | Preferências PowerShell; impacto High | Pergunta antes do conjunto de alterações. Confirm:false dispensa só essa pergunta. |

Os nove parâmetros próprios acima são definidos na entrada; WhatIf/Confirm vêm de SupportsShouldProcess. Parâmetros comuns como Verbose/ErrorAction são da plataforma, não modos adicionais do produto. O corpo usa ErrorAction Stop para as operações verificadas.

## 4. Consulta, planejamento, simulação e aplicação

Consulta padrão, em PowerShell elevado na pasta completa:

```powershell
.\Configure-NTP-PDC.ps1
```

Planejar com nomes **reservados para exemplo**, que precisam ser substituídos por fontes reais aprovadas:

```powershell
$peers = @('ntp1.example.net', 'ntp2.example.net', 'ntp3.example.net')
.\Configure-NTP-PDC.ps1 -NtpServers $peers
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply -WhatIf
```

O primeiro comando com peers ainda é Audit: resolve os nomes e mostra o plano, sem aplicar. Os nomes example.net não são servidores operacionais. O README também mostra os quatro nomes brasileiros do script original, explicitamente como exemplos não validados e não como padrão recomendado pela Microsoft.

Aplicação autorizada com peers já substituídos:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply
```

Para processo separado no Windows PowerShell 5.1, uma alternativa é executar a entrada dentro de -Command e construir o array na expressão. O -File do host legado possui particularidades ao receber arrays/switches explícitos; os exemplos interativos acima evitam depender dessas conversões.

No VSCode, abra a pasta da ferramenta e um terminal elevado com a versão correta. Não faça dot-sourcing da entrada ou dos mocks. A pasta src é localizada por PSScriptRoot, independentemente do diretório de origem do processo.

WhatIf não equivale a zero I/O: há relatórios, leitura AD/Registro/serviço, resolução DNS quando peers são informados e tráfego NTP se ProbePeers for pedido. Não altera configuração, reinicia serviço, força resync ou exporta o backup .reg. Um alvo inválido continua inválido no WhatIf.

## 5. Como identifica o alvo e evita atuar no servidor errado

1. Confere Windows, processo 64 bits e token elevado.
2. Obtém Win32_ComputerSystem e Win32_OperatingSystem por CIM: associação a domínio, DomainRole, tipo de produto, build, fabricante e modelo.
3. Para um DC associado ao domínio, usa GetComputerDomain, não GetCurrentDomain do usuário. Compara o domínio CIM com o domínio da API.
4. Obtém Forest.RootDomain e seu PdcRoleOwner. Compara FQDNs completos, ignorando caixa e ponto final apropriado; não usa regex com o nome local interpolado.
5. Exige que domínio do computador e raiz da floresta sejam iguais, e que o computador seja o PDC dessa raiz.
6. Revalida após confirmação, novamente depois do backup e antes das alterações, e verifica função/política após a aplicação.

Não há transação distribuída entre o AD e o Registro. Uma transferência FSMO ou mudança de GPO concorrente ainda pode ocorrer entre leituras. A validação utiliza a visão do diretório obtida naquele momento; não é consenso entre todos os DCs. Se o alvo/política mudar ao final, o resultado não é promovido a AppliedVerified.

A aplicação tem mutex nomeado Global\FMODEL.ConfigureNtpPdc. Se outro processo detiver o lock, a execução não aplica. O lock é local ao computador e não impede alterações por GPO, outro software ou um administrador usando ferramentas diretamente.

## 6. Políticas e serviço

A presença de HKLM\SOFTWARE\Policies\Microsoft\W32Time bloqueia Apply, **mesmo se o ramo estiver vazio**. É uma escolha conservadora deste projeto, não prova de que uma GPO específica está ativa. Não enumera toda a RSOP/MDM, não faz gpupdate e não apaga a política.

Quando o ramo existe, revise gpresult/RSOP e a configuração administrada. Ajuste pela GPO que realmente governa o cenário, com o escopo adequado ao domínio raiz. Não remova a chave só para satisfazer o script. Uma política ou agente que escreva por outro caminho também pode alterar os valores depois da execução.

Serviço W32Time ausente, desabilitado ou com chaves essenciais faltantes impede Apply. Não muda StartMode. Se estiver apenas parado e não desabilitado, após backup e autorização o fluxo o inicia antes de configurar; depois reinicia para aplicar os provedores. Quando já está em execução, o reinício ocorre uma vez depois da configuração. Aguarda Running até 30 segundos, sem parada forçada de dependentes.

## 7. Peers, normalização, DNS e flags

Cada peer passa por validação de sintaxe. DNS é normalizado para minúsculas/IDNA e o ponto final é removido. IPv4/IPv6 válidos são aceitos, incluindo IP privado para um appliance aprovado. Endereços loopback, não especificados e multicast/broadcast são rejeitados; IPv4 mapeado em IPv6 é normalizado antes da checagem. Não aceita flags inseridas pelo usuário, URLs, aspas, quebras de linha ou IDs de zona IPv6.

Remove nomes repetidos sem diferenciar caixa. O limite é de dez entradas/distintos conforme binding e plano. Nome repetido não vira redundância. Resolve **todos** os peers solicitados; falha de DNS/endereço inválido bloqueia o caminho. Nomes/IPs que apontem para o próprio computador são rejeitados para evitar um loop local. Isso não detecta todos os loops possíveis em uma cadeia NTP.

Não valida propriedade do servidor, contrato do provedor, independência física, fonte de hardware ou assinatura criptográfica. Nomes diferentes podem representar o mesmo IP/relógio. DNS e IP podem mudar depois da resolução; correspondência posterior é conservadora e pode não reconhecer uma rotação legítima.

Plano do código:

| Quantidade de peers distintos | Flags |
|---|---|
| 1 | Primeiro ,0x8; avisa que há menos de três nomes. |
| 2 | Primeiro ,0x8; segundo ,0xA = cliente + fallback-only. |
| 3–10 | Todos ,0x8; não força polling fixo. |

As flags de peer e AnnounceFlags são campos diferentes, mesmo quando o número é igual. Aqui 0x8 no peer é modo cliente; 0x2 adiciona uso apenas como fallback. O projeto não usa SpecialPollInterval, não acrescenta 0x1 e não muda MinPollInterval/MaxPollInterval. [Referência de opções](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

## 8. Anúncio, provedores e limites de correção

O plano pede Type=NTP e a lista manual via w32tm. Habilita o provedor cliente NtpClient e o servidor NtpServer. Ajusta AnnounceFlags como DWORD:

- Automatic: 10/0xA, anúncio/confiabilidade automáticos. É a escolha padrão do projeto para evitar promover incondicionalmente uma fonte não sincronizada.
- Always: 5/0x5, anúncio/confiabilidade permanentes; opção explícita do operador, não prova de qualidade.

A Microsoft documenta condições em que 0xA deve ser preferido a 0x5. A escolha padrão deste projeto não transforma todo cenário de tempo em uma única receita universal. A orientação histórica com polling especial e a opção moderna de cliente adaptativo têm contextos distintos. [Discussão oficial de anúncio](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server).

MaxPosPhaseCorrection e MaxNegPhaseCorrection são capturados, **não alterados**. Analise sua adequação à organização, especialmente se o relógio estiver muito deslocado. O script não remove limites para forçar uma correção e não calcula um offset independente antes de aplicar. Não existe garantia de ajuste gradual em vez de salto: o comportamento efetivo é do Windows e da política existente.

## 9. Ordem exata das alterações e backup

Antes do primeiro comando que muda W32Time:

1. Confirmação, lock e leitura renovada do alvo/política/estado.
2. Grava before-settings.json com o snapshot renovado.
3. Executa reg.exe export do ramo inteiro HKLM\SYSTEM\CurrentControlSet\Services\W32Time para w32time-before.reg.
4. Exige processo sem timeout, código zero e arquivo não vazio.
5. Persiste report.json e os HTMLs com estado BackupSaved.
6. Revalida alvo/política e compara os cinco valores locais relevantes para detectar mudança durante a preparação.

Após isso, com intenção em disco antes de cada operação:

- Inicia W32Time se necessário.
- w32tm /config /manualpeerlist:<lista> /syncfromflags:manual /update.
- Define AnnounceFlags e Enabled dos dois provedores, como DWORD.
- w32tm /config /update.
- Reinicia W32Time e aguarda Running.
- w32tm /resync /rediscover, uma vez.

Os argumentos são enviados a processos fixos do SystemDirectory, sem shell. A lista manual é um argumento, incluindo seus espaços. Argumentos com aspas ou quebras são recusados pelo wrapper. Não é um executor genérico para comandos fornecidos pelo usuário.

A exportação é um backup de configuração, não backup do AD, do estado do relógio ou da VM. A checagem de arquivo não é um teste completo de restauração. Não importar automaticamente o ramo inteiro em outro computador ou após uma mudança FSMO/política.

## 10. Verificação: critérios e alcance real

ConfigurationVerified exige cinco configurações locais esperadas, lista de peers equivalente sem depender de ordem/caixa, W32Time Running e rechecagem final de função/política. Não é uma comprovação independente de todas as configurações efetivas da RSOP.

Time evidence exige simultaneamente:

- /query /source e /query /status /verbose sem timeout e com código zero.
- Fonte de uma única linha correspondente a um nome pedido ou IP resolvido previamente. Remove sufixo nativo ,0x... quando presente.
- Leap Indicator reconhecido em 0, 1 ou 2; 3 não confirma sincronização.
- Stratum reconhecido entre 1 e 15.
- Idade reconhecida desde o último bom sincronismo entre zero e MaxSyncAgeSeconds.

O parser reconhece rótulos EN-US/PT-BR explicitamente testados com textos sintéticos. Não presume sucesso em outros idiomas, saída alterada ou rótulos repetidos. Um Windows em outro idioma pode estar sincronizado e ainda receber AppliedNeedsReview por falta de evidência interpretável. Nessa situação, analisar a saída nativa.

A idade é relativa informada pelo serviço; não depende de converter uma data regional. Um status recente pode anteceder o início da execução, desde que esteja dentro da janela. Não comprova um pacote novo causado especificamente por aquele resync. Fonte, status e configuração são leituras separadas, não um snapshot atômico.

AppliedVerified significa somente que esses critérios foram observados. Não mede precisão absoluta, offset real independente, alinhamento de toda a floresta, segurança do upstream, ausência de spoofing ou autenticação NTP/NTS. Não há detecção de conteúdo malicioso ou integração com VirusTotal neste script.

## 11. Timeouts, falhas e códigos de saída

Cada processo nativo tem timeout. Stdout e stderr são lidos assincronamente para evitar bloqueio de buffers. Em timeout, o cliente é encerrado quando possível; isso **não cancela necessariamente o que o serviço Windows já fez**. Não há repetição automática de config/resync.

A espera de evidência usa Stopwatch para não depender de saltos do relógio sendo corrigido. A janela é verificada entre tentativas: leituras já iniciadas podem ultrapassá-la. DNS, descoberta AD, espera de confirmação, CIM e serviço têm seus próprios comportamentos; NativeTimeoutSeconds não é um timeout global.

| Estado | Exit | Interpretação |
|---|---|---|
| AuditCompleted | 0 | Consulta concluída, sem aplicar; saúde não certificada. |
| WhatIf / Declined | 0 | Sem mutação W32Time nesse fluxo. |
| AppliedVerified | 0 | Critérios observados; limites da seção 10 permanecem. |
| AppliedNeedsReview | 2 | Alterações realizadas com verificação incompleta/negativa. |
| Blocked | 1 | Não iniciou mutação W32Time; pode ter gravado relatórios/backup. |
| FailedAfterMutationPossible | 1 | Tentou alteração; investigar possível estado parcial. |

Erro de plataforma, privilégio, binding ou diretório antes de criar a pasta pode sair com 1 sem relatório. Falha ao salvar o relatório final propaga erro; usar o backup/diário já existentes. O script não promete que uma falha na auditoria final possa desfazer operações anteriores.

Em automação, conferir LASTEXITCODE imediatamente depois de um processo/script terminar. Zero em Audit/WhatIf não significa que houve configuração ou que NTP está saudável.

## 12. Arquivos gerados, campos e privacidade

Cada pasta Run-<UTC>-<sufixo> tem ID próprio. O horário UTC pode ser corrigido durante a execução; não ordenar uma investigação somente pelos timestamps. A ordem das linhas do diário e as fases ajudam a reconstruir o fluxo.

| Artefato | Conteúdo/condição |
|---|---|
| Report.pt-BR.html / Report.en-US.html | Resumo legível, plano, resultado e avisos; sem recursos externos/JavaScript. |
| report.json | SchemaVersion, Version, Operator, OperatorSid, RunId, datas, Mode, State, RunFolder, Context, Plan, Policy, Before/After, ResolvedPeers, Before/AfterDiagnostics, ConfigurationVerified, Verification, ProbeResults, MutationAttempted, Error e Warnings. |
| before-settings.json | Oito valores selecionados, caminho/nome/tipo/existência das chaves, estado/modo de início do serviço. |
| w32time-before.reg | Exportação anterior do ramo W32Time, apenas após aprovação Apply. |
| diagnostics-before-*.txt | Saída bruta de source/status/configuration/peers anteriores. |
| diagnostics-after-*.txt | Consultas posteriores, quando alcançadas pelo fluxo. |
| config-command.txt / resync-command.txt | Saídas dos comandos correspondentes, quando alcançados. |
| actions.jsonl | UTC, Action e Phase INTENT/COMPLETED por operação iniciada. |

Context inclui FQDN, domínio/raiz/PDC, OS/build, DomainRole, associação, fabricante/modelo, indício de VM e endereços locais. Plan contém Servers, PeerList, ReliabilityMode, AnnounceFlags, Type e Enabled dos provedores. ResolvedPeers registra nomes/IPs e hora da resolução. Cada resultado nativo guarda Executable, Arguments, ExitCode, TimedOut, Output e ObservedUtc.

Verification contém Evidence, Attempts, ElapsedSeconds e as duas últimas saídas nativas. Evidence expõe fonte, correspondência, reconhecimento numérico, leap, stratum, idade, limite e nota de alcance. Antes/Depois têm Values, Registry, ServiceState e ServiceStartMode. Registry distingue chave ausente de valor ausente e registra ValueKind; não tratar ausência como zero.

O diário recebe Flush(true) antes da operação. INTENT sem COMPLETED não prova que nada mudou. Não é armazenamento imutável, assinatura ou transação. JSON/HTML usam escrita temporária e substituição por arquivo, não uma transação envolvendo todos os relatórios. O HTML codifica texto dinâmico e aplica CSP restritiva.

Os arquivos herdam ACLs normais do diretório; não há nova criptografia, expurgo, envio de e-mail, telemetria ou upload ao GitHub. O relatório contém conta/SID e topologia potencialmente sensíveis. O .gitignore ajuda, mas não impede uma inclusão forçada nem limpa histórico.

Para ler JSON corretamente também no PowerShell 5.1:

```powershell
Get-Content -LiteralPath 'C:\CAMINHO-DO-RUN\report.json' -Raw -Encoding UTF8 | ConvertFrom-Json
```

## 13. Diagnóstico de rede e virtualização

Para testar peers sem aplicar, com peers reais aprovados:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -ProbePeers
```

ProbePeers usa stripchart, três amostras e intervalo de um segundo. Não define sozinho um sinal de sucesso: ver a saída. A porta de origem do stripchart é efêmera; a comunicação do cliente W32Time utiliza UDP 123 de origem. Portanto um probe funcionando não prova o mesmo caminho de firewall/NAT. Test-NetConnection -Port 123 testa TCP e não comprova NTP. [Descrição das ferramentas e portas](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

O indício de VM é heurístico. Captura o valor local VMICTimeProvider.Enabled quando existente, mas não consulta o host nem VMware Tools. Não muda Integration Services, serviço vmictimesync, Registro do provedor ou configuração da nuvem. As orientações Microsoft variam conforme plataforma e cenário; revisar a arquitetura do DC e possíveis ciclos host/domínio antes de alterar integração. [DC virtual](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service) · [Hyper-V Integration Services](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services) · [Cenário Azure AD DC](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration).

## 14. Demais DCs, membros e transferência de PDC

Esta ferramenta não aplica nos outros DCs/membros. Para um equipamento que deva retornar à hierarquia, um administrador pode avaliar, fora deste script:

```powershell
# OPERAÇÃO REAL, somente no alvo correto e conforme a política do ambiente.
w32tm /config /syncfromflags:DOMHIER /update
Restart-Service -Name W32Time
w32tm /resync /rediscover
```

Não copiar esse bloco para o PDC raiz que deve utilizar suas fontes aprovadas. O script não descobre nem executa essas operações remotamente. Em uma transferência FSMO, revisar novo PDC, antigo PDC, GPO e comportamento de inicialização; não presumir que uma execução anterior se adapta sozinha.

## 15. Recuperação e investigação

1. Guardar pasta Run, código/versão e logs do serviço. Verificar último INTENT/COMPLETED.
2. Confirmar novamente qual é o PDC raiz e qual política governa W32Time.
3. Consultar configuração, fonte e status atuais; não repetir resync/config às cegas após timeout.
4. Comparar before-settings.json com o estado atual. Restaurar seletivamente apenas os valores apropriados ao mesmo alvo e cenário, preservando tipos e ausências quando necessário.
5. Tratar importação completa de .reg como operação administrativa de impacto, não procedimento automático recomendado. Ela pode sobrescrever alterações legítimas posteriores e não restaura o relógio.
6. Revalidar serviço, configuração, sincronismo e consumidores conforme procedimento da organização.

Não existe -Restore, rollback de AD, restauração de VM ou ajuste reverso de hora nesta ferramenta. Alterações parciais podem exigir ação manual. Não usar Set-Date indiscriminadamente para “voltar ao antes”.

## 16. Perguntas frequentes

- **Por que não basta ser PDC?** Um domínio filho também tem PDC; o alvo desta receita é a raiz da floresta.
- **Por que não usa IPs fixos do arquivo original?** Os nomes são configuráveis; o código não promete que um mapeamento DNS antigo continue válido.
- **Por que não há defaults NTP?** Para exigir a escolha consciente de fontes aprovadas para o ambiente.
- **AppliedVerified garante precisão?** Não; apenas os critérios definidos da seção 10.
- **Resync retornou zero: acabou?** Não. O fluxo ainda verifica configuração e evidência de tempo.
- **Fonte correta, mas AppliedNeedsReview?** Pode ser idioma não reconhecido, idade, stratum/leap, leitura falha ou divergência local/política.
- **Posso usar num PC comum?** Audit pode coletar estado local quando suportado; Apply é bloqueado.
- **Precisa instalar módulo AD?** Não usa RSAT ActiveDirectory; depende das APIs Windows/.NET e do AD acessível.
- **Desliga integração da VM?** Não. Registra indícios e deixa a decisão da plataforma para o administrador.
- **Muda fuso ou horário de verão?** Não. Sincronização e apresentação do fuso são assuntos distintos.
- **E se o serviço estiver desabilitado?** Bloqueia; não muda StartMode ou política.
- **Há desfazer?** Não automático; exportação de Registro não reverte tempo nem efeitos em aplicações.
- **É um script oficial da Microsoft?** Não. É uma implementação FMODEL fundamentada em referências oficiais.
- **Ele contata Internet sem peers?** Não inicia probe NTP próprio no Audit padrão; pode consultar o AD. O serviço existente continua funcionando independentemente do script.
- **Posso publicar o relatório?** Pode revelar nomes internos e operador/SID. Revisar/redigir conforme autorização; exemplos incluídos são fictícios.

## 17. Testes e uso em produção

A evidência inclui testes de funções, 18 fluxos simulados e três execuções isoladas do comando de entrada com dependências falsas. O CI roda Windows PowerShell 5.1 e PowerShell 7 no Windows, e testes simulados no Linux. No Windows, há também leitura real local de Registro/CIM, disponibilidade da API DirectoryServices e ajuda nativa w32tm; não há vínculo a domínio ou NTP externo durante os testes.

Não foram validados um PDC real, LDAP da sua floresta, alterações reais de Registro/serviço/relógio, GPO empresarial, precisão, firewall, peers públicos ou eventos de migração/restore de VM. Não há cobertura percentual, avaliação de conformidade ou eficácia garantida. Execute a [aceitação](ACCEPTANCE.pt-BR.md) em ambiente controlado antes de adotar em operação.

## 18. Rastreabilidade e referências

Código desta revisão: `f680c67aa3ebd9d11950ef28431da9a27f8ef58b`. Hashes e ambiente estão em [EVIDENCE.json](EVIDENCE.json); [execução CI](https://github.com/fmodel7/scripts/actions/runs/40010481878). A comparação com o original está em [REVIEW.pt-BR.md](REVIEW.pt-BR.md). O manifesto identifica bytes distribuídos, não a identidade do autor.

Referências Microsoft consultadas em 23/10/2026:

- [Ferramentas e configurações W32Time](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings)
- [Funcionamento do serviço de tempo](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works)
- [Servidor de tempo autoritativo / KB 816042](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server)
- [Serviço de tempo e cenários virtuais](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service)
- [Hyper-V Integration Services](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services)
- [Tempo de AD DC em Azure](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration)

A documentação do provedor [NTP.br](https://ntp.br/guia/windows/) é uma referência adicional; não converte os peers do original em uma escolha universal. As fontes explicam tecnologias e cenários; o comportamento exato e os controles descritos neste manual são os do código FMODEL entregue.

[Function map / Mapa de funções](FUNCTIONS.pt-BR.md)
