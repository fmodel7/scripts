# Manual completo — FMODEL AD Health Report 1.2.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · fmodel@fmodel.com.br · Revisão com assistência de Akira (ChatGPT)  
[English](MANUAL.en-US.md) · [Início](../README.md) · [Evidências](EVIDENCE.json)

## 1. Objetivo e alcance

Export-ADHealthReport.ps1 transforma o levantamento de inventário e diagnóstico do AD em uma coleta estruturada, com relatório HTML offline, CSV e JSON. O objetivo é apoiar entendimento do ambiente, preparação de apresentação técnica e revisão de condições que merecem investigação. Não é uma certificação de segurança, conformidade, disponibilidade ou funcionamento integral do Active Directory.

A ferramenta consulta dados e grava arquivos locais. Não remove contas, redefine senhas, muda grupos, força replicação, transfere FSMO, altera schema/GPO, inicia ou reinicia serviços, corrige DNS ou executa remediação automática. Consultas podem gerar tráfego e eventos normais de autenticação/auditoria. “Somente leitura do AD” não significa ausência de I/O: os relatórios são escritos no computador que executa o script.

## 2. Melhorias sobre o script recebido

O original fazia consultas repetidas para contagens, classificava como estação todo computador cujo sistema operacional não contivesse “server” e escrevia quase tudo apenas no console. Também convertia resultados de schema em texto formatado e reconhecia testes DCDiag por expressões em inglês, o que podia produzir interpretações incorretas em outros idiomas.

A nova estrutura preserva dados utilizáveis em CSV/JSON, identifica o escopo e DC usados nas consultas, separa dados ausentes de contagens zero e registra cobertura/erros por coleta. Computadores sem informação de sistema operacional não são automaticamente declarados estações. Os papéis FSMO são obtidos como propriedades dos objetos AD, em vez de depender da análise textual de netdom.

As verificações independentes não dependem de ping bem-sucedido. Serviços e DCDiag são opcionais e suas falhas não são tratadas como prova isolada de que um DC caiu. Dados estruturados de replicação complementam o diagnóstico nativo, cujo retorno é apresentado para revisão, sem procurar uma frase inglesa para declarar sucesso.

## 3. Requisitos e permissões

Operação real: Windows de 64 bits, Windows PowerShell 5.1 e módulo ActiveDirectory/RSAT disponível. O computador precisa alcançar o AD selecionado e autenticar com uma conta autorizada. Pode ser uma estação de administração com RSAT; não é obrigatório executar o script dentro de um DC. A coleta real recusa PowerShell 7; testes e FromReport offline também podem usar PowerShell 7.

Não há exigência de elevação por padrão. Leituras de diretório podem funcionar com permissões delegadas; consultas adicionais de replicação, CIM ou DCDiag podem exigir direitos diferentes. A ferramenta não concede esses direitos nem tenta contornar ACLs. Não é necessário usar uma conta Domain Admin somente por conveniência para um inventário básico. Use o menor conjunto de permissões aprovado para o escopo.

O token atual é utilizado. Não há senha embutida, chave de API ou exportação de credenciais. A ferramenta não instala RSAT, habilita WinRM, configura TrustedHosts ou abre firewall. DNS, autenticação, AD Web Services e protocolos exigidos por cada diagnóstico devem estar disponíveis conforme a arquitetura. A coleta CIM opcional usa WSMan e depende de sua configuração existente.

## 4. Download, pasta e VSCode

No GitHub, abra scripts/ad-health-report, selecione AD-Health-Report-v1.2.0.zip e clique em Download raw file. Depois escolha Extrair Tudo. Alternativa: Code → Download ZIP na página principal, extrair e abrir scripts/ad-health-report. Git não é requisito para baixar.

Abra a pasta extraída no VSCode com File → Open Folder e um terminal Windows PowerShell. Confie somente em código cuja origem e conteúdo você revisou. Não execute dentro do ZIP nem faça dot-sourcing do arquivo. O script deve ser executado pelo nome. Preserve UTF-8 com BOM ao editar arquivos destinados ao Windows PowerShell 5.1.

```powershell
Get-Location
Get-ChildItem
$PSVersionTable
Get-Module -ListAvailable ActiveDirectory
```

Se já estiver na pasta correta, não repita cd adicionando novamente seu nome. Se ActiveDirectory não estiver disponível, solicite/instale o componente RSAT correspondente pelo procedimento de TI aprovado; o script não fará isso automaticamente.

## 5. Testar sem acessar um domínio

Na pasta da ferramenta, em uma sessão normal:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
```

Também pode usar pwsh para a suíte offline. Ela usa dados e adaptadores sintéticos; não precisa de domínio, RSAT ou Administrador. Os testes automatizados verificam o comportamento implementado, inclusive tratamento de dados e geração de artefatos, mas não comprovam a integração com uma floresta real.

Consulte EVIDENCE.json para ambientes efetivamente testados, versão/hash do código e limites de validação. Não confunda a aprovação da suíte com um aceite operacional no AD da empresa. Testes e dados sintéticos não devem ser carregados como substitutos de comandos em uma sessão administrativa de produção.

## 6. Primeira coleta real

No Windows PowerShell 5.1, com módulo AD e permissão de leitura:

```powershell
.\Export-ADHealthReport.ps1
```

O padrão é Scope=Domain, inicialmente descoberto pelo domínio do computador que executa o script. Se precisar indicar o contexto inicial, use um DC autorizado:

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com
```

Os nomes example.com são exemplos e precisam ser substituídos. O script resolve o contexto por RootDSE e fixa o DC usando dnsHostName. Assim, as contagens e consultas do domínio não dependem de escolher implicitamente servidores diferentes para cada comando.

A execução grava relatórios. Não existe uma etapa de “aplicar correções” nesta ferramenta. Não acrescente parâmetros de outros projetos, como -Apply ou -ScopeOverwrite: eles não pertencem a este script.

## 7. Domínio e floresta

Domain coleta o domínio selecionado; Forest enumera os domínios da floresta e fixa um DC para cada conjunto de consultas. As contagens devem ser interpretadas junto de Domain, Server e Coverage. Em uma coleta Domain, metadados da floresta, como schema e papéis FSMO da floresta, ainda podem aparecer, mas não representam inventário completo de contas de todos os domínios.

```powershell
.\Export-ADHealthReport.ps1 -Scope Forest
```

Falhas em um domínio não tornam os números restantes uma contagem total confiável de toda a floresta. Confira quais domínios e coletores concluíram. Uma consulta fixada em um DC também representa a visão desse DC naquele momento; o relatório não é um snapshot transacional consistente de todos os servidores.

## 8. Todos os parâmetros

| Parâmetro | Padrão/faixa | Efeito |
|---|---|---|
| Server | Não informado | Contexto inicial; o DC é fixado pelo dnsHostName de RootDSE. |
| Scope | Domain; Domain/Forest | Define o escopo do inventário de domínios. |
| OutputPath | LocalApplicationData/FMODEL/ADHealth | Base local para uma pasta única Run-UTC-GUID. |
| InactiveDays | 90; 1–3650 | Limiar de revisão de atividade, sujeito às limitações de lastLogonTimestamp. |
| IncludeServiceChecks | false | Inclui leitura opcional de serviços por CIM/WSMan. |
| IncludeDcDiagnostics | false | Inclui testes DCDiag nativos permitidos. |
| TimeoutSeconds | 60; 5–600 | Limite do processo nativo e de operação CIM, não timeout global. |
| MaxHtmlRows | 1000; 10–10000 | Limita linhas apresentadas no HTML, não CSV/JSON. |
| PageSize | 500; 1–1000 | Tamanho de página das consultas de inventário compatíveis. |
| SkipUserInventory | false | Não coleta inventário de usuários; a cobertura registra a omissão. |
| SkipPrivilegedMembers | false | Não enumera membros diretos dos grupos sensíveis selecionados. |
| WhatIf | false; parâmetro comum | Faz apenas a descoberta inicial e validação da saída, sem inventário completo ou arquivos. |
| Confirm | Preferência PowerShell; impacto Low | Pode solicitar confirmação para a coleta/gravação; não há aplicação de correções. |

SupportsShouldProcess tem impacto Low: a execução padrão não exige uma confirmação interativa. -WhatIf faz somente o bootstrap (ambiente, contexto AD e caminho), sem criar pasta ou executar a coleta completa; retorna NotCollected. Ainda há consultas AD de descoberta.

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com -WhatIf
```

São opções de coleta e apresentação, não de remediação. Um PageSize menor não estabelece um limite total de objetos; o servidor continua paginando resultados. TimeoutSeconds não limita o tempo total de descoberta, importação de módulo, LDAP/ADWS, DNS, gravação de arquivos ou todas as chamadas da execução.

## 9. Coleta opcional de serviços e DCDiag

```powershell
.\Export-ADHealthReport.ps1 -IncludeServiceChecks -IncludeDcDiagnostics
```

Os serviços NTDS, Netlogon, DNS, KDC, W32Time e DFSR são consultados por CIM/WSMan, sem início, parada ou reinício. Observation=Observed indica um registro retornado; NotObserved indica que nenhum registro correspondente foi observado, não um erro de transporte ou um estado Stopped confirmado. Status ausente, permissão negada, transporte indisponível ou timeout precisam ser investigados; não representam automaticamente serviço parado ou DC offline. A necessidade de um serviço DNS local depende do papel e da topologia do DC; a ferramenta não deve substituir essa análise pelo nome do serviço isoladamente.

No perfil Baseline, DCDiag é executado com lista restrita de testes: NetLogons, Replications, Services, Advertising e KnowsOfRoleHolders, usando /q. Não são usados /fix, testes de atualização dinâmica de DNS ou uma varredura completa que inclua testes com efeitos adicionais. O processo tem timeout próprio, registra saída e código e salva os logs brutos na pasta native. No timeout, grava um marcador informando a interrupção; a saída parcial daquele processo não é preservada. A tentativa de terminar o processo não converte o resultado em um teste concluído.

/q produz principalmente mensagens de erro; ausência de texto, saída zero ou término do processo não provam saúde completa. As linhas são classificadas para revisão, como CompletedReviewRequired, Timeout ou CommandError. O script não depende de frases “passed test” em inglês. O próprio DCDiag possui um teste de conectividade que depende de ICMP; o fato de outras consultas do relatório funcionarem não elimina essa limitação do diagnóstico nativo.

## 10. Arquivos gerados

A saída fica no computador que executa o script, sob OutputPath. O padrão usa o LocalApplicationData da conta atual. OutputPath é uma base local do provider FileSystem: caminhos relativos seguem a localização PowerShell atual; UNC, unidades identificadas como rede e curingas são recusados. Cada execução recebe pasta própria Run-UTC-GUID para evitar misturar relatórios.

- Report.html: painel navegável offline, busca local e apresentação dos conjuntos coletados.
- report.json: metadados e dados técnicos, preservando os valores coletados sem a neutralização específica de planilha.
- Arquivos CSV por conjunto, em UTF-8 com BOM e delimitador vírgula.
- run-manifest.json: hashes SHA256 dos artefatos incluídos no manifesto da execução.
- native/: saídas brutas dos diagnósticos opcionais quando executados.

O manifesto é gerado após os demais artefatos e não contém o hash dele próprio. Arquivos adicionados depois, como uma impressão em PDF do navegador, não entram automaticamente nesse manifesto. Um manifesto ajuda a detectar alterações posteriores; não é assinatura digital, atestado de autenticidade da origem ou prova de que a coleta foi completa. As pastas podem crescer bastante em ambientes grandes. A ferramenta não define retenção, compactação automática, criptografia ou expurgo de relatórios reais.

## 11. Conjuntos e nomes CSV

| Conjunto | CSV | Conteúdo principal |
|---|---|---|
| Forest | forest.csv | Metadados da floresta, schema e funções de floresta. |
| Domains | domains.csv | Domínios selecionados, modo funcional e metadados. |
| DomainControllers | domaincontrollers.csv | DCs descobertos, domínio, site e dados disponíveis. |
| OrganizationalUnits | organizationalunits.csv | OUs e propriedades selecionadas. |
| ComputerSummary | computersummary.csv | Resumo do inventário de computadores. |
| Computers | computers.csv | Computadores e indicadores de revisão selecionados. |
| Users | users.csv | Usuários e atributos selecionados, quando habilitado. |
| Groups | groups.csv | Grupos e propriedades selecionadas. |
| PrivilegedMembers | privilegedmembers.csv | Associações diretas aos grupos sensíveis selecionados. |
| PasswordPolicies | passwordpolicies.csv | Políticas de senha padrão e finas coletadas. |
| Trusts | trusts.csv | Relações de confiança e propriedades disponíveis. |
| Replication | replication.csv | Metadados estruturados de parceiros/partições. |
| ReplicationFailures | replicationfailures.csv | Falhas de replicação retornadas pela consulta. |
| Services | services.csv | Resultados da coleta opcional de serviços. |
| NativeDiagnostics | nativediagnostics.csv | Estado, código e referência ao diagnóstico nativo. |
| Findings | findings.csv | Achados e recomendações que exigem revisão. |
| Coverage | coverage.csv | O que concluiu, foi pulado ou ficou indisponível. |
| CollectionErrors | collectionerrors.csv | Erros e limitações por etapa/consulta. |

Um CSV com somente cabeçalho não diferencia, sozinho, “nenhum objeto encontrado” de “não coletado”. Coverage e CollectionErrors fornecem essa distinção. Não preencha automaticamente dados ausentes com zero ao criar gráficos ou apresentações posteriores.

## 12. HTML, busca e limites de apresentação

Abra Report.html em um navegador local. O relatório não precisa de CDN, Internet ou bibliotecas externas. A busca funciona no próprio navegador; não envia consultas ou dados a um servidor. O HTML codifica conteúdo proveniente do AD e de erros/diagnósticos para não tratá-lo como marcação executável.

MaxHtmlRows limita apenas as linhas apresentadas. A busca no HTML alcança o conteúdo que foi incorporado ao HTML, não um banco de dados externo com todas as linhas. Se uma tabela tiver sido reduzida, use o CSV/JSON para investigação completa dos dados efetivamente coletados. Os controles permitem expandir/recolher seções e imprimir pelo navegador. A impressão não transforma o relatório em um diagnóstico mais completo. Aumentar o limite pode consumir mais memória e tornar a página lenta; não torna consultas falhas completas.

## 13. CSV e proteção contra fórmulas

Os CSV usam vírgula e UTF-8 com BOM para facilitar interoperabilidade. Em Excel com configuração regional PT-BR, use Dados → De Texto/CSV quando a detecção automática não separar colunas. Selecione UTF-8 e vírgula; não assuma que o delimitador é ponto e vírgula por causa do idioma do Windows.

Valores que possam ser interpretados como fórmulas de planilha recebem prefixo de apóstrofo. Colocar uma expressão entre aspas CSV não basta para impedir interpretação por Excel e programas semelhantes. Essa proteção pode alterar a representação visível de um valor exportado; use JSON para verificar o valor coletado sem essa transformação específica.

O JSON preserva os valores do modelo de dados coletado, não uma cópia integral de todos os objetos/atributos .NET do diretório. Não o trate como backup do AD ou formato de restauração. Não há importação de dados nem função de replay de objetos nesta ferramenta.

## 14. Schema, níveis funcionais e sistema operacional

Schema, modo funcional de domínio/floresta e sistema operacional dos DCs são conceitos diferentes. O número do schema não comprova o sistema operacional atual de cada servidor nem o nível de atualização do ambiente.

O mapeamento reconhece que 88 corresponde ao schema introduzido no Windows Server 2019 e também usado pelo Windows Server 2022; 91 corresponde ao Windows Server 2025. Versões desconhecidas precisam ser mantidas como valor numérico e revisadas, sem inventar uma classificação. Também não se deve concluir que um domínio em nível funcional Windows2016Domain esteja necessariamente executando somente DCs com Windows Server 2016.

OperatingSystem e atributos relacionados são informações do diretório. Podem estar ausentes ou desatualizados; não comprovam inventário de patches, suporte contratado ou estado atual do endpoint. Computadores sem informação de sistema não devem ser classificados automaticamente como estações.

## 15. Atividade de contas e flags de segurança

InactiveDays fornece um limiar para revisar contas. lastLogonTimestamp é replicado com granularidade controlada por msDS-LogonTimeSyncInterval e pode ficar atrasado em relação a um logon real. LastLogonDate é uma representação conveniente desse tipo de dado, não evidência precisa de todos os logons.

O atributo lastLogon é mantido separadamente em cada DC e não é replicado; um valor exato de último logon no domínio exigiria consultar todos os DCs e avaliar os valores. Esse custo e esse resultado não devem ser presumidos nesta coleta. Um valor ausente/zero significa desconhecido, não prova de que a conta nunca foi usada.

PasswordNotRequired é uma flag, não evidência de senha em branco. PasswordNeverExpires, preautenticação desabilitada, delegação e outras condições, quando presentes nos dados/achados, são sinais de revisão contextual. Contas de serviço, exceções aprovadas e proteções alternativas precisam ser considerados. A ferramenta não lê senha, hash, segredo LAPS ou material de chave gMSA e nunca desabilita uma conta por idade automaticamente.

## 16. Grupos sensíveis, políticas e trusts

Os grupos sensíveis são selecionados por SID, evitando depender de nomes traduzidos. A seleção inclui Domain Admins do domínio; Schema Admins e Enterprise Admins no domínio raiz da floresta; e grupos builtin como Administrators, Account Operators, Server Operators e Backup Operators.

A enumeração PrivilegedMembers é somente de membros diretos. Um grupo aninhado pode aparecer como grupo, mas seus usuários não são expandidos automaticamente. Não é auditoria completa de privilégios efetivos. Grupos primários, SIDHistory, ACLs delegadas, contas externas e falhas de resolução/cross-forest também limitam a análise. adminCount=1 não comprova associação privilegiada atual.

O inventário de políticas de senha não equivale à política efetiva de cada usuário. Fine-grained password policies podem ter precedência sobre a política padrão; uma investigação individual pode exigir Get-ADUserResultantPasswordPolicy e análise de contexto. Trusts listados não comprovam segurança de todos os caminhos de acesso entre florestas. Não há teste ativo de exploração ou alteração de trust.

## 17. Replicação e limitações das verificações

Get-ADReplicationPartnerMetadata consulta parceiros de entrada para todas as partições hospedadas selecionadas pela consulta, com Partition='*'. Get-ADReplicationFailure complementa a visão com falhas associadas ao DC. O relatório preserva resultados e erros para revisão; não força sincronização, recalcula topologia ou remove conexões.

Uma coleta bem-sucedida sem falhas retornadas descreve a visão consultada naquele momento, não disponibilidade futura. Uma topologia de DC único pode não ter parceiros de replicação e precisa de interpretação própria. Permissão insuficiente ou erro de rede não deve ser convertido em “zero falhas”. Datas antigas e códigos de resultado precisam ser avaliados com frequência de replicação, site, partição e manutenção do ambiente.

## 18. Estados, saída e cobertura

| Estado | Código | Interpretação |
|---|---|---|
| NotCollected | 0 | WhatIf ou confirmação recusada; sem pasta de execução. |
| Completed | 0 | Coleta concluída segundo os critérios implementados; não comprova saúde ou conformidade. |
| CompletedWithFindings | 2 | Há achados de prioridade alta/média para revisão. |
| Partial | 2 | Uma ou mais coletas tiveram erro/limitação; dados restantes podem existir. |
| Falha fatal | 1 | O processo não concluiu; não pressupõe um relatório persistido com Status=Failed. |

Coverage usa Collected, Failed e NotRequested. Collected com zero linhas significa consulta concluída sem registros naquele escopo; Failed/NotRequested não autoriza essa conclusão. Partial tem prioridade sobre CompletedWithFindings quando existem erros de coleta. Falhas iniciais podem ocorrer antes de uma pasta ou relatório ser criado. Falha de disco/permissão durante a exportação também pode deixar arquivos incompletos; preserve mensagens e examine a integridade do conjunto antes de utilizá-lo como evidência. Não existe garantia de transação atômica entre todos os arquivos.

NotRequested em Coverage indica escolha explícita, como SkipUserInventory ou diagnósticos opcionais não solicitados; não é uma execução bem-sucedida daquele teste. Para avaliar o resultado, leia o estado geral, Findings, Coverage e CollectionErrors em conjunto. Uma execução parcial não deve ser apresentada como inventário completo da floresta.

## 19. Execução de menor volume e uso em apresentação

Para reduzir o inventário, pode omitir usuários ou membros sensíveis:

```powershell
.\Export-ADHealthReport.ps1 -SkipUserInventory -SkipPrivilegedMembers
```

Para mudar a base de saída e o limite do HTML:

```powershell
.\Export-ADHealthReport.ps1 -OutputPath C:\AD-Reports -MaxHtmlRows 500
```

Reveja a cobertura ao compartilhar números. Não transforme ausência de coleta em ausência de risco. Antes de apresentar à equipe, registre data, escopo, DCs consultados, opções, conta/permissões e limitações. Use achados como pauta de revisão e vincule recomendações ao processo de mudança da empresa, sem tratá-las como autorização de correção automática.

## 20. Segurança dos arquivos e problemas frequentes

Relatórios podem conter nomes de pessoas, contas, SIDs, filiações, nomes internos, topologia e condições sensíveis. Não os publique no repositório público. Defina armazenamento, ACL, retenção e destinatários conforme a empresa. A ferramenta não criptografa, endurece ACLs, anonimiza automaticamente ou envia arquivos por e-mail/upload.

Script não assinado: consulte Get-ExecutionPolicy -List. AllSigned por MachinePolicy/UserPolicy exige o procedimento corporativo de assinatura. Quando RemoteSigned permitir e você tiver revisado a origem, Unblock-File -LiteralPath .\Export-ADHealthReport.ps1 remove a marca de download; isso não contorna GPO nem uma exigência de assinatura. Não mude indiscriminadamente para Unrestricted/Bypass.

Módulo ausente: confira RSAT e a versão do terminal. Falha AD: revise servidor, DNS, autenticação e permissões. Serviços/CIM falham: revise WSMan e as permissões específicas, sem concluir que o DC está offline. DCDiag não encontrado ou bloqueado: confira ferramentas administrativas e leia CollectionErrors. Nenhum desses componentes é instalado ou habilitado pelo script.

## 21. Aceite, perguntas e referências

Antes de usar em produção, execute em laboratório autorizado representativo, compare amostras com os consoles AD e teste ausência de permissão, coletores opcionais, domínios inacessíveis, dados vazios e conjuntos grandes. Confira CSV/JSON/HTML, proteção de fórmulas, limites de tabelas e integridade dos arquivos. Valide com a equipe AD quais permissões e diagnósticos serão usados; os testes sintéticos não substituem essa etapa.

Pergunta: “Completed significa que está tudo saudável?” Não. Significa que o fluxo concluiu conforme os critérios implementados. Há limites de cobertura e análises que a ferramenta não realiza.

Pergunta: “Preciso ser Domain Admin?” Não por padrão para inventário básico. Cada conjunto pode exigir direitos próprios; acesso negado precisa permanecer visível no relatório.

Pergunta: “O script corrige as recomendações?” Não. Ele apresenta evidências e pontos de revisão; qualquer mudança exige seu procedimento autorizado.

Pergunta: “O CSV contém tudo mesmo quando o HTML é reduzido?” Contém todos os dados que aquele conjunto conseguiu coletar; não recupera consultas puladas ou com erro.

Referências primárias que fundamentam interpretação e uso dos cmdlets. O projeto não é certificado ou endossado pela Microsoft:

- Schema: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/find-active-directory-schema
- Replicação: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adreplicationpartnermetadata
- Falhas de replicação: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adreplicationfailure
- DCDiag: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dcdiag
- lastLogon: https://learn.microsoft.com/en-us/windows/win32/adschema/a-lastlogon
- lastLogonTimestamp: https://learn.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp
- Membros de grupos: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroupmember
- Política efetiva de senha: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduserresultantpasswordpolicy

[Início](../README.md) · [Evidências da versão](EVIDENCE.json)

## 22. Regras de achados implementadas

Os níveis High/Medium são prioridades de revisão do projeto, não uma classificação oficial de conformidade Microsoft ou prova de comprometimento. Vários achados podem se referir à mesma conta. Não existe pontuação universal de segurança.

| RuleId | Nível | Condição observada |
|---|---|---|
| ACCOUNT-STALE-HINT | Medium | Conta habilitada com LastLogonUtc e CreatedUtc ambos anteriores ao corte InactiveDays. |
| UNCONSTRAINED-DELEGATION | High | TrustedForDelegation em conta habilitada; computadores classificados como DomainController são excluídos dessa regra. |
| KERBEROS-PREAUTH | High | Usuário habilitado com DoesNotRequirePreAuth=True. |
| PASSWORD-NOT-REQUIRED | High | Usuário habilitado com PasswordNotRequired=True. |
| PASSWORD-NEVER-EXPIRES | Medium | Usuário habilitado com PasswordNeverExpires=True. |
| REVERSIBLE-PASSWORD-POLICY | High | Política coletada com ReversibleEncryptionEnabled=True. |
| REPLICATION-ERROR | High | Resultado de replicação não zero ou ConsecutiveReplicationFailures positivo. |
| REPLICATION-FAILURE-REPORTED | High | Registro de falha com FailureCount positivo. |
| SERVICE-NOT-RUNNING | Medium | Serviço observado com State diferente de Running; requer análise do papel esperado. |

Não gerar um achado não significa que todas as propriedades foram avaliadas. Por exemplo, a ferramenta não emite uma conclusão universal de suporte do SO, qualidade de senha efetiva de cada conta, delegações completas ou privilégio efetivo. Políticas e exceções devem ser avaliadas pela equipe responsável.

## 23. Convenções e campos dos conjuntos

Datas normalizadas usam texto UTC ISO 8601. Datas ausentes ou não convertíveis ficam vazias; isso não é uma data zero ou evidência de inexistência de atividade. Propriedades ausentes podem ser null no JSON e vazias no CSV. SIDs/GUIDs são representados como texto. Listas selecionadas são apresentadas como texto separado por ponto e vírgula, não como objetos AD restauráveis.

Categorias de Computers: DomainController pelo bit de conta de DC; ServerHint quando o texto de SO contém server; WindowsClientHint para outro texto iniciado por Windows; Unknown para SO ausente; Other nos demais casos. São indicadores de inventário, não sondagens do sistema operacional em execução.

SPNCount é somente contagem dos SPNs retornados para usuário; os valores SPN completos não são exportados nessa coluna. SupportedEncryptionTypes registra o valor do atributo coletado e não demonstra quais algoritmos foram negociados em sessões reais. ParentDN é derivado do distinguishedName, respeitando vírgulas escapadas; não implica que o pai seja sempre uma OU.

Os cabeçalhos abaixo são os contratos de exportação desta edição:

### Forest

Name, RootDomain, ForestMode, SchemaVersion, SchemaLabel, SchemaMaster, DomainNamingMaster, Domains, Sites

### Domains

Domain, QueryServer, DistinguishedName, DomainMode, DomainSid, PDCEmulator, RIDMaster, InfrastructureMaster, Computers, Users, Groups

### DomainControllers

Domain, HostName, Site, OperatingSystem, OperatingSystemVersion, IsGlobalCatalog, IsReadOnly, OperationMasterRoles

### OrganizationalUnits

Domain, Name, DistinguishedName, ParentDN, ProtectedFromAccidentalDeletion, CreatedUtc, ChangedUtc

### ComputerSummary

Domain, Category, OperatingSystem, Count

### Computers

Domain, Name, DNSHostName, DistinguishedName, ParentDN, SID, ObjectGuid, Category, OperatingSystem, OperatingSystemVersion, Enabled, LastLogonUtc, PasswordLastSetUtc, CreatedUtc, ChangedUtc, TrustedForDelegation, TrustedToAuthForDelegation, SupportedEncryptionTypes

### Users

Domain, SamAccountName, UserPrincipalName, DistinguishedName, ParentDN, SID, ObjectGuid, Enabled, LockedOut, LastLogonUtc, PasswordLastSetUtc, AccountExpirationUtc, CreatedUtc, ChangedUtc, PasswordNeverExpires, PasswordNotRequired, DoesNotRequirePreAuth, TrustedForDelegation, AdminCount, SPNCount, SupportedEncryptionTypes

### Groups

Domain, Name, SamAccountName, SID, DistinguishedName, GroupCategory, GroupScope, AdminCount, CreatedUtc, ChangedUtc

### PrivilegedMembers

Domain, GroupName, GroupSID, MemberName, MemberSID, MemberClass, MemberDN, MembershipType

### PasswordPolicies

Domain, PolicyType, Name, Precedence, MinPasswordLength, ComplexityEnabled, ReversibleEncryptionEnabled, PasswordHistoryCount, MaxPasswordAgeDays, MinPasswordAgeDays, LockoutThreshold, LockoutDurationMinutes, AppliesTo

### Trusts

Domain, Name, Direction, TrustType, ForestTransitive, SelectiveAuthentication, SIDFilteringQuarantined, SIDFilteringForestAware

### Replication

Domain, DC, Partition, Partner, LastReplicationAttemptUtc, LastReplicationSuccessUtc, LastReplicationResult, ConsecutiveReplicationFailures

### ReplicationFailures

Domain, DC, Partner, FailureType, FailureCount, FirstFailureUtc, LastError

### Services

Domain, DC, Name, State, StartMode, Observation

### NativeDiagnostics

Domain, DC, Test, Status, ExitCode, TimedOut, OutputFile

### Findings

Severity, RuleId, Category, Domain, Target, Evidence, Recommendation

### Coverage

Dataset, Scope, Status, Rows, StartedUtc, EndedUtc, DurationSeconds

### CollectionErrors

Dataset, Scope, ErrorType, Message

## 24. Perfil completo e escopo

FullAssessment reúne as verificações num único comando, habilitando IncludeOperationalChecks, IncludeEventLogs, IncludeServiceChecks e IncludeDcDiagnostics, e selecionando DiagnosticProfile=Extended. Esse preset sempre escolhe Extended, mesmo se Baseline também for informado. Sem FullAssessment, cada opção pode ser ligada separadamente. Scope continua Domain por padrão; a profundidade não muda automaticamente o número de domínios.

```powershell
.\Export-ADHealthReport.ps1 -FullAssessment
.\Export-ADHealthReport.ps1 -FullAssessment -Scope Forest -WhatIf
```

WhatIf faz somente o bootstrap já documentado e não executa as novas sondagens. A coleta ampliada exige direitos e conectividade adicionais: WSMan/CIM e leitura de registro, consultas DNS, RPC/Event Log e diagnósticos administrativos. Uma leitura AD permitida não concede automaticamente esses acessos. Falha num coletor não bloqueia os independentes.

## 25. Novos parâmetros

| Parâmetro | Padrão/faixa | Efeito |
|---|---|---|
| FullAssessment | false | Preset completo descrito acima; mantém o escopo escolhido. |
| IncludeOperationalChecks | false | DNS, ICMP informativo, host/volumes/registro e horário. |
| IncludeEventLogs | false | Eventos críticos/erros/avisos dos quatro logs selecionados. |
| DiagnosticProfile | Baseline; Baseline/Extended | Seleciona 5 ou 17 testes, quando IncludeDcDiagnostics está habilitado. |
| DnsServer | Vazio | Usa os resolvedores configurados no coletor; opcionalmente informa outro servidor DNS. |
| TimeSamples | 3; 3–10 | Quantidade solicitada de amostras stripchart por DC. |
| TimeWarningSeconds | 1; 0.001–3600 | Limite de revisão médio para mediana dos módulos dos offsets. |
| TimeCriticalSeconds | 5; 0.002–86400 | Limite alto; deve ser maior que TimeWarningSeconds. |
| DiskWarningPercent | 15; 0.01–100 | Percentual livre de aviso. |
| DiskCriticalPercent | 5; 0–99 | Percentual crítico, menor que o de aviso. |
| DiskWarningGiB | 10; 0.01–1000000 | Espaço livre de aviso em GiB. |
| DiskCriticalGiB | 5; 0–999999 | Espaço crítico, menor que o de aviso. |
| EventHours | 24; 1–168 | Janela retrospectiva de eventos. |
| MaxEventsPerLog | 100; 1–1000 | Limite por log e DC; cap é registrado explicitamente. |

Limites de disco são avaliados pelos valores não arredondados: crítico se percentual OU GiB forem menores/iguais ao respectivo limite crítico; aviso se um dos limites de aviso for atingido. São critérios operacionais configuráveis do projeto, não uma norma universal Microsoft.

## 26. DNS, ICMP, host e armazenamento

DNS consulta A/AAAA de cada DC e SRV de _ldap._tcp.dc._msdcs.DOMINIO e _kerberos._tcp.DOMINIO. Registra resolvedor, TTL e, para SRV, destino/porta/prioridade/peso. Resolver padrão é o do computador de coleta, não necessariamente o serviço DNS daquele DC. Essas consultas não verificam todos os registros DNS ou todos os resolvedores do ambiente. Ausência somente de AAAA não é falha; erro de transporte/permissão é separado de NotPresent. A ausência de ambos os endereços ou de SRV gera revisão.

ICMP usa uma tentativa com até cinco segundos no envio; resolução do nome pode ter duração própria. NoReply não comprova DC offline e não impede CIM, AD, horário ou DCDiag. DCDiag pode depender de ICMP internamente, independentemente deste controle.

O bundle CIM consulta o sistema operacional uma vez e os volumes fixos uma vez. Uma sessão é reutilizada e removida em finally. Obtém último boot UTC, uptime em horas e memória total/livre em bytes. Uptime recente (até 24 h) é Info para correlacionar manutenção, não incidente automático; uptime com relógio inconsistente permanece desconhecido.

Lê pelo provedor de registro CIM os valores DSA Database file e Database log files path de NTDS/Parameters e SysVol de Netlogon/Parameters. Não altera o registro. Caminhos são associados ao volume pelo prefixo mais longo, incluindo volumes montados em pastas. Leitura negada, variável não expandida ou mapeamento desconhecido ficam explícitos. Não se presume que NTDS/SYSVOL estejam em C:.

Todos os volumes fixos retornados são exportados. Alertas de capacidade consideram os volumes com letra, caminho montado visível ou papel identificado; volumes ocultos sem esses vínculos ficam UnmappedSystemVolume e não recebem o limiar genérico em GiB. Isso não substitui avaliação de partições de recuperação/sistema. Bytes são mantidos; GiB usa 1024³. Espaço/memória são fotografias do momento, sem limpeza ou medição contínua de pressão de RAM.

## 27. Horário, eventos e DCDiag estendido

Horário solicita w32tm /stripchart com várias amostras, preserva sinal e calcula mediana assinada, mediana dos módulos e maior módulo. Não avalia apenas offsets positivos e não arredonda a medição antes da comparação. O parser exige linhas de amostra reconhecidas e conversão numérica invariante; saída desconhecida, amostras insuficientes, erro e timeout não viram zero.

A referência é sempre CollectorLocalClock: o relógio do computador de coleta. Não é certificação de UTC ou sincronismo NTP. Um coletor com horário incorreto pode gerar alertas em todos os DCs. Verifique referência, atraso/jitter e a fonte do DC antes de agir. Stripchart usa caminho/porta de origem diferentes do cliente W32Time; sua resposta não comprova o caminho do serviço. A ferramenta também salva as saídas de /query source, status /verbose e configuration para revisão, sem depender de rótulos traduzidos e sem /resync, /config ou ajuste do relógio.

Eventos consultam System, Directory Service, DFS Replication e DNS Server para níveis 1/2/3 na janela escolhida. Busca no máximo limite+1 para detectar truncamento, exporta até o limite e preserva EventLogCoverage. São eventos mais recentes obtidos dentro da janela, não todo o histórico. Ausência de correspondências é consulta vazia bem-sucedida; log DNS inexistente pode ser não aplicável; outros logs ausentes e erros de acesso ficam como limitações. Se uma mensagem não puder ser formatada, os metadados do evento são preservados com MessageStatus=Unavailable. Eventos históricos não provam falha atual.

Extended mantém os cinco testes Baseline e acrescenta DFSREvent, SysVolCheck, KccEvent, MachineAccount, NCSecDesc, ObjectsReplicated, RidManager, SystemLog, VerifyReferences, CheckSDRefDom, CrossRefValidation e LocatorCheck. Connectivity é executado pelo próprio framework. FrsEvent legado não é selecionado automaticamente. Intersite, /fix, /c, /e e testes de atualização dinâmica DNS não são utilizados. Todos os resultados nativos continuam exigindo revisão; retorno zero não certifica saúde.

TimeoutSeconds continua por processo nativo/operação CIM, não global. DNS usa QuickTimeout; Event Log RPC não recebe esse parâmetro de timeout. Descoberta, consultas AD, eventos e disco podem exceder o tempo configurado. Processamento é sequencial para controlar carga; planeje a janela para número de DCs, testes e amostras.

## 28. Resumo, durações e achados adicionais

DCSummary reúne endereços observados em DNS, uptime, menor espaço livre em GiB/percentual entre volumes avaliados, mediana do módulo do offset, número de eventos, truncamento e duração. Os mínimos de GiB e percentual podem vir de volumes diferentes; use Disks para identificar cada um. Ausência de coleta deixa valores desconhecidos, sem fabricar zero. Estados por seção significam cobertura de evidência, não aprovação de saúde. Observation pode ser Incomplete, ReviewRequired ou CollectedEvidenceOnly.

Coverage inclui DurationSeconds; Timings.csv registra duração por coletor. HostBundle mede a consulta compartilhada CIM/registro; HostMetrics/Disks/StoragePaths medem a extração dos dados desse bundle. DCProcessing mede a etapa completa do DC, incluindo replicação e verificações, mas não a exportação final de toda a execução. Não some DCProcessing aos filhos como se fossem trabalhos independentes. Stopwatch.TotalSeconds não perde os minutos como o componente Seconds.

Novas regras: DC-DISK-SPACE (High/Medium), DC-TIME-OFFSET (High/Medium), DC-EVENTS-REVIEW (Medium), DC-DNS-SRV-NOT-PRESENT e DC-DNS-HOST-NOT-PRESENT (Medium) e DC-RECENT-BOOT (Info). Regras de disco usam volumes avaliáveis e limites configurados; horário exige amostragem reconhecida. Achados são revisão assistida, sem reparo, exclusão ou alteração automática.

## 29. Integração e novas saídas

Esta edição integra funcionalidades operacionais identificadas na comparação com Get-ADHealth.ps1, cujo cabeçalho atribui autoria a ALI TAJRAN: https://www.alitajran.com/active-directory-health-check-powershell-script/ . A implementação dos coletores e tratamento de dados desta ferramenta é própria; não incorporamos o parser em inglês, SMTP obsoleto ou testes ativos de replicação do arquivo comparado. Nenhum envio de e-mail é executado; os relatórios permanecem locais.

Referências adicionais: https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname ; https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent ; https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings . Não houve validação de DC real no desenvolvimento; consulta ao registro, WinRM/RPC, DNS e interpretação do horário exigem aceite autorizado.

Os 30 conjuntos estabelecidos na 1.1 permanecem; a seção 30 descreve os 33 adicionais da 1.2, totalizando 63 CSVs. Eventos são limitados pela janela/cap explícitos; todos os dados obtidos nessas condições são exportados para CSV/JSON e exibidos no HTML até MaxHtmlRows. Novos campos:

### Connectivity — connectivity.csv

Domain, DC, Probe, Status, RoundtripMs, Address, Error

### DNS — dns.csv

Domain, DC, QueryName, QueryType, Resolver, Status, Address, Target, Port, Priority, Weight, TTL, Error

### HostMetrics — hostmetrics.csv

Domain, DC, CollectedUtc, OSName, OSVersion, Build, SystemDrive, LastBootUtc, UptimeHours, MemoryTotalBytes, MemoryFreeBytes, MemoryFreePercent, Observation

### Disks — disks.csv

Domain, DC, Volume, DriveLetter, Label, Roles, CapacityBytes, FreeBytes, FreeGiB, FreePercent, AssessmentScope, Observation

### StoragePaths — storagepaths.csv

Domain, DC, Component, Path, Status, Volume, Error

### TimeSamples — timesamples.csv

Domain, DC, Sample, CollectedUtc, Reference, OffsetSeconds, AbsoluteOffsetSeconds, RawLine

### TimeSummary — timesummary.csv

Domain, DC, Reference, RequestedSamples, ParsedSamples, Status, MedianOffsetSeconds, MedianAbsoluteOffsetSeconds, MaximumAbsoluteOffsetSeconds, ExitCode, TimedOut, RawText

### TimeConfiguration — timeconfiguration.csv

Domain, DC, Query, Status, ExitCode, TimedOut, RawText

### Events — events.csv

Domain, DC, LogName, TimeCreatedUtc, EventId, Level, Provider, RecordId, Message, MessageStatus

### EventLogCoverage — eventlogcoverage.csv

Domain, DC, LogName, StartUtc, EndUtc, Status, Exported, Truncated, Limit, Error

### DCSummary — dcsummary.csv

Domain, DC, Site, DnsAddresses, UptimeHours, LowestAssessedFreeGiB, LowestAssessedFreePercent, MedianAbsoluteOffsetSeconds, RecentEventRows, RecentEventsTruncated, ProcessingSeconds, Observation, CollectionErrors, Findings, Replication, Connectivity, DNS, HostMetrics, Disks, StoragePaths, TimeSummary, Services, EventLogCoverage, NativeDiagnostics

### Timings — timings.csv

Dataset, Scope, Status, Rows, DurationSeconds

DCSummary: Domain, DC, Site, DnsAddresses, UptimeHours, LowestAssessedFreeGiB, LowestAssessedFreePercent, MedianAbsoluteOffsetSeconds, RecentEventRows, RecentEventsTruncated, ProcessingSeconds, Observation, CollectionErrors, Findings, Replication, Connectivity, DNS, HostMetrics, Disks, StoragePaths, TimeSummary, Services, EventLogCoverage, NativeDiagnostics

## 30. Perfil abrangente 1.2 e comandos de execução

A versão 1.2 mantém o inventário e o perfil FullAssessment da 1.1 e acrescenta 33 conjuntos normalizados: **63 CSVs em cada execução**, além de HTML, JSON, evidências brutas e manifesto SHA-256. Os arquivos de conjuntos não solicitados ficam com cabeçalhos; consulte Coverage para saber se houve coleta. As funcionalidades foram implementadas de forma independente a partir das APIs oficiais, tendo o ADxRay como referência de requisitos; não há código ou HTML dele incorporado.

Comando para o domínio selecionado, na pasta extraída, em Windows PowerShell 5.1 x64 com as permissões necessárias:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -CreateArchive
```

Para todos os domínios autorizados da floresta:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -Scope Forest -CreateArchive
```

ComprehensiveAssessment habilita FullAssessment e os dez coletores novos controlados pelas opções IncludeDirectorySecurity, IncludeTopology, IncludeGpoInventory, IncludeSysvolInventory, IncludeDnsConfiguration, IncludeBackupEvidence, IncludeHostInventory, IncludeSecurityConfiguration, IncludeRsop e IncludeSecurityEvents. O escopo padrão continua Domain. Sites, sub-redes, site links, recursos opcionais e vínculos de sites são metadados da floresta de referência e são identificados como tal mesmo em escopo Domain.

As opções individuais podem ser combinadas sem ComprehensiveAssessment. FullAssessment mantém o comportamento 1.1: sondagens operacionais, eventos operacionais, serviços e DCDiag Extended; não habilita silenciosamente inventário de GPO/software ou consultas Security. Execute primeiro em laboratório. Consultas podem gerar carga e eventos de auditoria; a ferramenta não altera AD, GPO, Registro, DNS, firewall, serviços ou relógio.

## 31. Novos parâmetros, limites e custo

| Parâmetro | Padrão | Comportamento |
|---|---|---|
| ComprehensiveAssessment | false | Habilita o perfil completo descrito acima; mantém Domain como escopo padrão. |
| IncludeDirectorySecurity | false | Lixeira do AD, atributos de segurança de contas, SPNs, UPNs e duplicidades dentro da cobertura obtida. |
| IncludeTopology | false | Sites, sub-redes e site links da floresta. |
| IncludeGpoInventory | false | GPOs, XML, links por LDAP e permissões por domínio/servidor explícitos. |
| IncludeSysvolInventory | false | Metadados dos arquivos por UNC de cada DC; não executa nem lê o conteúdo dos scripts. |
| IncludeDnsConfiguration | false | Configuração administrativa DNS, zonas, aging, root hints e indícios InProgress nas partições consultáveis. |
| IncludeBackupEvidence | false | Saída repadmin /showbackup e eventos de apoio Windows Backup, quando disponíveis. |
| IncludeHostInventory | false | CPU/BIOS/modelo, registro Uninstall e entradas QFE via uma sessão remota por DC. |
| IncludeSecurityConfiguration | false | SMB, Spooler, firewall ActiveStore, W32Time, registro selecionado, auditoria e configuração dos logs. |
| IncludeRsop | false | XML RSoP por computador, normalização de valores e atribuições de direitos. |
| IncludeSecurityEvents | false | EventIDs selecionados em Security e logon 4624 tipos 4/8, dentro da janela e do limite. |
| MaxDirectoryObjects | 100000 | 100–10000000; objetos adicionais por domínio; pede limite+1 para detectar truncamento. Não limita os inventários Users/Computers antigos. |
| MaxSpnValues | 500000 | 100–10000000; valores SPN exportados por domínio. |
| MaxGpos | 5000 | 1–100000; GPOs detalhadas por domínio. Get-GPO -All ainda descobre o inventário antes do corte. |
| MaxXmlCharacters | 25000000 | 1000–100000000; caracteres por XML de GPO/RSoP/evento. DTD e entidades externas são proibidas. |
| MaxPolicySettings | 100000 | 1–1000000; linhas normalizadas de GPO por domínio e de RSoP por DC. O XML bruto dos itens processados é preservado. |
| MaxSysvolFiles | 20000 | 1–1000000; arquivos por DC. |
| SysvolTimeoutSeconds | 120 | 5–1800; orçamento de travessia. Uma chamada bloqueante ao filesystem pode excedê-lo. |
| MaxSoftwareEntries | 5000 | 1–100000; entradas Uninstall combinadas por DC, preservando a visão Registry32/Registry64. |
| BackupWarningDays | 7 | 1–365; revisão informativa da idade de eventos de apoio; não define o RPO nem prova ausência de backup. A busca cobre ao menos 30 dias ou o dobro desse valor. |
| BaselineFile | vazio | JSON local até 1 MiB, com regras do catálogo permitido. Habilita IncludeSecurityConfiguration; detalhes abaixo. |
| FromReport | vazio | Recria HTML/CSV a partir de JSON existente, sem inicializar AD. Aceita Windows PowerShell 5.1 ou PowerShell 7. |
| CreateArchive | false | Compacta a pasta concluída em ZIP ao lado dela. Não põe o ZIP dentro da pasta que é objeto do manifesto. |

TimeoutSeconds também limita a espera dos jobs de módulo GroupPolicy/DnsServer e da sessão remota. Apenas os jobs criados pela própria chamada são recebidos, cancelados e removidos. Cancelamento/fechamento de transporte pode levar tempo adicional. Consultas AD, descoberta e I/O de filesystem têm seus próprios comportamentos; este parâmetro não é um prazo global de toda a execução. A coleta é serial por domínio/DC; uma floresta grande com muitas GPOs pode levar bastante tempo. A ferramenta não promete uma duração fixa.

## 32. Contas, SPNs, UPNs e recursos opcionais

Get-ADObject consulta contas com sAMAccountName e objetos com servicePrincipalName no domínio selecionado, com propriedades explícitas e paginação. Inclui contas de computador e de serviço quando presentes. Os bits UAC são convertidos em Enabled, ReversibleEncryptionAllowed, UseDESKeyOnly, PasswordNotRequired, PasswordNeverExpires, DoesNotRequirePreAuth, TrustedForDelegation, TrustedToAuthForDelegation, NotDelegated e SmartcardRequired. UAC ausente produz UnknownUAC e valores nulos; não vira false.

ReversibleEncryptionAllowed indica uma permissão/configuração da conta; não confirma conteúdo de senhas armazenadas. UseDESKeyOnly não prova que DES foi usado numa autenticação. PasswordNotRequired não prova que há senha vazia. Nenhuma senha, hash, segredo LAPS ou senha gerenciada é solicitado. SupportedEncryptionTypes continua sendo uma configuração observada.

SPNInventory exporta um valor por proprietário. DuplicateSPNs compara SPNs sem distinção de caixa e exige mais de um proprietário distinto por DN. DuplicateUPNs faz comparação análoga para UPNs não vazios. São comparações entre os dados coletados, não buscas em florestas externas nem certificação de unicidade. Um domínio não consultado, replicação atrasada, falhas ou limites reduzem a conclusão possível. DirectoryCoverage registra objetos, valores, limites e truncamento; atingir o limite gera Partial.

SkipUserInventory também restringe o novo coletor de contas a computadores. Nesse caso, a cobertura dos identificadores é ComputersOnlyByRequest e as duplicidades são parciais por definição. A opção não remove nomes de usuários eventualmente presentes em grupos, eventos, GPOs ou outras evidências.

A Lixeira do AD é consultada pelo FeatureGUID documentado 766ddcd8-acd0-445e-f3b9-a7f9b6744f2a, com servidor explícito e EnabledScopes. Não é ativada automaticamente. Sites/Subnets/SiteLinks registram a topologia observada, custo e frequência de replicação configurados; não simulam rotas nem medem conectividade entre todos os sites.

## 33. GPOs, vínculos, valores e permissões

Get-GPO, Get-GPOReport e Get-GPPermission recebem o domínio e servidor específicos da iteração. O relatório de cada GUID é guardado em native/GPO-*.xml. Se GUID/domínio estiverem expostos no XML, são comparados com o alvo solicitado. Divergências ou XML inválido geram erro de coleta e preservam os demais coletores.

GroupPolicies contém identidade, status, dono, filtro WMI exposto pelo provedor, datas, versões AD/SYSVOL, contagem dos nós de extensão User/Computer e vínculos observados. ComputerSettings/UserSettings representam nós de extensão do XML, não uma contagem garantida de todas as configurações efetivas. A ausência desses nós é observação de revisão, inclusive em GPO com versões maiores que zero. Versão AD/SYSVOL diferente gera revisão de replicação/timing, não reparo.

GPOLinks lê gPLink/gPOptions dos domínios/OUs e dos sites de configuração da floresta. Preserva o DN da GPO, StoredPosition, flags enabled/enforced e bloqueio de herança do escopo retornado. StoredPosition é a posição no atributo bruto; não é apresentada como ordem efetiva de aplicação no cliente. Não há cálculo completo de LSDOU, filtros WMI, security filtering, loopback, negações ou conflitos efetivos. Escopos sem gPLink não são um inventário completo de todos os bloqueios de herança.

GPOSettings normaliza folhas e atributos XML em SettingPath/Value/Attributes com índices de nós repetidos. Namespace e texto bruto permanecem no XML original. GPOPermissions registra trustees/SIDs, permissões e inherited expostos pelo cmdlet; grupos aninhados não são expandidos para calcular acesso efetivo. Segurança/filtering/delegação e demais metadados também permanecem no XML e nas folhas normalizadas.

GPO sem vínculo observado e GPO sem nós de extensão geram observações informativas. Vínculo no domínio, vínculo desabilitado, GPO reserva ou configuração User/Computer habilitada não são erros universais e não resultam em remoção automática. Cross-domain links, acesso parcial e mudanças durante a coleta afetam LinkCount. GPOCoverage explicita quantidade descoberta/processada e limites por domínio.

## 34. Host, aplicativos, QFE e configuração de segurança

Uma execução remota fixa por DC reúne apenas as categorias solicitadas. Usa CIM para ComputerSystem/OperatingSystem/BIOS/Processor/QFE, leitura do registro Uninstall para software, SmbShare, NetSecurity ActiveStore, Win32_Service e leituras limitadas de registro. Não usa Win32_Product, evitando o comportamento de validação/reparo associado a esse provedor. Não instala módulos nem habilita remoting no destino.

HostHardware separa LogicalProcessors, PhysicalCores e Sockets. Contém fabricante/modelo, RAM em bytes, OSBuild/UBR quando expostos, instalação e BIOS. Idade da BIOS não é prova de que existe atualização aplicável. InstalledSoftware preserva as entradas das visões Registry32 e Registry64; a visão do registro não prova arquitetura do binário, nem enumera todos os aplicativos por usuário, portáveis ou todos os pacotes possíveis. Valores ausentes permanecem ausentes. Publisher não é validação de assinatura.

Hotfixes contém as entradas de Win32_QuickFixEngineering. InstalledOnRaw é preservado; InstalledUtc só é preenchido quando o provedor realmente devolve DateTime tipado. Datas textuais ambíguas não são adivinhadas. O inventário QFE não cobre todas as atualizações e não cruza catálogo/CVEs: KB recente não comprova que o sistema está atualizado ou livre de vulnerabilidades. Nenhum dado de aplicativos é enviado para sites externos.

HostSecurity contém valores observados de SMB cliente/servidor, estado/modo do Spooler, perfis de firewall ActiveStore e W32Time de máquina/política. As leituras W32Time preservam Type, NtpServer, AnnounceFlags e habilitação de providers quando disponíveis; não recalculam toda a precedência das políticas nem comprovam sincronismo. As saídas w32tm existentes e as medições de diferença continuam disponíveis em TimeConfiguration/TimeSummary. Textos de status nativos não são convertidos em sucesso por parsing inglês.

Spooler tem interpretação própria: Stopped e Disabled são os valores de revisão esperados nesta avaliação de infraestrutura de identidade; não entra na regra genérica dos serviços centrais que devem estar Running. SMB/registro desconhecidos não viram Disabled. Firewall em ActiveStore é observação de configuração, não teste de todos os caminhos de rede.

LogConfiguration guarda enabled, MaximumBytes, modo, contagem, registro mais antigo e data quando expostos. Não presume um tamanho universal obrigatório. AuditPolicy guarda CSV auditpol /get /category:* /r por GUID de subcategoria, com os campos localizados preservados em JSON e saída bruta vinculada. Não compara palavras inglesas como Success/Failure para emitir conformidade.

## 35. Revisão de segurança e perfis fornecidos pelo usuário

RegistryEvidence guarda valor, tipo, caminho, estado e erro de cada regra. O catálogo padrão possui 12 leituras selecionadas de LDAP signing/CBT, NoLMHash, nível de autenticação NTLM, restrições de contas locais/anonimato, UAC, auditoria avançada, Script Block Logging e segurança mínima NTLM cliente/servidor. O catálogo e os links de cada regra estão em SOURCES.json e no próprio PS1.

SecurityReview compara valores observados e tipos DWORD com valores selecionados, usando EqualsAny ou ContainsBits. Acrescenta oito observações de SMB/Spooler/firewall e, quando RSoP é solicitado, quatro observações de direitos do Administrador RID 500. Este é um conjunto de revisão fundamentado em orientação Microsoft; **não é o pacote completo SCT, CIS, auditoria de conformidade nem certificado Microsoft**. LDAP CBT/signing/NTLM também exigem avaliação de compatibilidade e exceções aprovadas antes de qualquer mudança externa à ferramenta.

MatchesSelectedValue significa apenas que o valor lido coincide com a regra selecionada. ReviewValueDifference é um item de revisão. NotExplicitlyConfigured não significa default seguro ou inseguro. Unknown, UnknownTypeOrValue e UnknownOSBuild não são sucesso. RestrictAnonymousSAM é mantido como evidência, com NotApplicableToDomainControllers, pois a política referenciada não tem efeito em DCs. Valores de contas locais não comprovam políticas de senha do domínio.

O exemplo baseline.example.json demonstra uma comparação **parcial**, para builds 20348/26100. Revise e adapte à baseline aprovada para seu SO/papel. O arquivo permite somente RuleIds já presentes no catálogo; não aceita comandos, scriptblocks ou caminhos arbitrários de registro. Expected deve ser inteiro DWORD, Comparison EqualsAny/ContainsBits, Role DomainController e ApplicableBuilds explícitos. Um hash do perfil aparece nas observações. Build fora da lista produz NotApplicableOSBuild; sem build observado, UnknownOSBuild.

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -BaselineFile .\docs\baseline.example.json
```

Baselines de Windows cliente não devem ser transplantadas para DCs. Os valores de direitos do RID 500 são inventariados por SID, inclusive se a conta foi renomeada. A orientação citada sobre negar logon ao Administrador interno se refere a workstations/member servers; o script não transforma essa orientação numa regra de bloqueio para DCs. RSoP não expande grupos nem calcula direitos efetivos.

## 36. DNS administrativo e conteúdo do SYSVOL

DnsServerConfiguration lê componentes expostos por Get-DnsServer; guarda também JSON bruto em native. DnsZones inclui integração AD, tipo, atualização dinâmica, escopo e aging nas zonas primárias consultáveis. DnsRootHints preserva NS/IPs expostos. Falta de serviço DNS observada numa consulta de serviços bem-sucedida é NotApplicableNoDnsServiceObserved; falha de transporte/permissão na consulta DNS não é convertida em ausência de papel.

Recursão habilitada, menos de três forwarders, root hints customizados ou scavenging desabilitado não são classificados automaticamente como erro. A interpretação depende da arquitetura. Desabilitar recursão no DNS do Windows também desabilita forwarders. DnsZoneIndicators consulta nomes InProgress em partições DNS expostas nos namingContexts dos DCs de referência de cada domínio; registra um indício, sem afirmar que toda ocorrência é uma zona duplicada nem que todas as partições customizadas foram verificadas.

SYSVOL é acessado por \\DC\SYSVOL\DOMINIO, mantendo o alvo do DC explícito. Coleta metadados, tamanho em bytes, datas UTC e agregados por extensão. Não executa scripts, não abre o conteúdo dos arquivos e não faz antimalware nem comparação byte a byte entre réplicas. Reparse points são excluídos e registrados como limitação; arquivos indisponíveis, limite e orçamento vencido geram Partial. Extensão, tamanho elevado ou presença de EXE não provam arquivo malicioso.

## 37. Evidências de backup e eventos Security

BackupEvidence guarda native/ADBackup-*.txt com repadmin /showbackup e o resultado do processo. A ferramenta não escolhe arbitrariamente uma linha nem converte datas nativas localizadas em LastBackupUtc. Partições e timestamps ficam disponíveis na evidência bruta para revisão. Saída exit 0 é EvidenceReviewRequired, não “backup validado”. Nenhum backup ou restauração é iniciado.

Como apoio, descobre os canais expostos pelo provider Microsoft-Windows-Backup e consulta até 16 eventos ID 4 recentes. Data UTC do evento pode preencher LastBackupUtc para essa fonte, mas não estabelece que houve backup System State/AD, que todas as partições estão incluídas ou que o backup é restaurável. A ausência de provider/log pode ser NotPresent, comum com soluções de terceiros. Falha de acesso é erro; ausência de evento na janela não prova ausência de backup. Confirme jobs, componentes, retenção e teste de restauração na solução responsável.

SecurityEvents consulta IDs 1102, 4618, 4649, 4719, 4765, 4766, 4794, 4897, 4964 e 5124, além de 4624 com LogonType 4/8, filtrados por XML/EventData. Usa EventHours e MaxEventsPerLog; há limite+1 e cobertura de truncamento. Eventos selecionados não constituem detecção completa de incidentes nem análise SIEM.

Os campos XML são preservados em EventDataJson. LogonType=4 indica batch e pode ser esperado; LogonType=8, NetworkCleartext, não prova por si só transmissão de senha em texto claro pela rede. Mensagens localizadas não são usadas para inferir esses tipos. Acesso negado a Security produz erro/Partial, sem impedir outros coletores. Logs reais contêm identidades e podem conter informações adicionais sensíveis.

## 38. RSoP, normalização e limites das inferências

Get-GPResultantSetOfPolicy recebe Computer=DC explícito e grava XML local único. RSoPSettings normaliza folhas/atributos, incluindo opções de segurança, políticas, auditoria, registro e perfis expostos. UserRightsAssignments guarda nome interno do direito, SID/nome de principal e origem quando expostos pelo XML. O arquivo bruto permite revisar dados além do limite de linhas normalizadas.

Um direito ausente do XML é NotExposedInRSoP, não prova de que não existe configuração efetiva. Presença do nome da política/chave não comprova seu valor. Os nomes localizados ficam preservados; não são comparados com uma lista rígida de nomes em inglês. Não se conclui configuração completa de GPO, ausência de conflitos ou privilégio efetivo a partir da contagem de nós.

## 39. Recriar relatórios offline e gerar ZIP

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -FromReport 'C:\Caminho\Run-...\report.json' -OutputPath 'C:\ADHealth-Estudo' -CreateArchive
```

Substitua os caminhos pelos reais. FromReport funciona também com pwsh: não inicializa RSAT/AD e não faz novas consultas. Lê JSON SchemaVersion=1, aceita apenas nomes de conjuntos conhecidos e recria todos os CSVs/HTML numa pasta Rendered-*. Dados novos ausentes em um JSON 1.0/1.1 permanecem ausentes; renderizar não os coleta. A versão da coleta original é preservada, com RendererVersion=1.2.0 e hash do JSON importado.

Se run-manifest.json estiver ao lado do JSON, evidências native/*.txt/xml/json com nomes permitidos são copiadas após verificar SHA-256 e tamanho. Reparse points, UNC, nomes de caminho arbitrários, arquivo maior que 100 MiB ou evidência total maior que 500 MiB são recusados. O manifesto pode ter até 10 MiB. Sem manifesto, recria o conteúdo do JSON, sem copiar evidências externas. Hashes detectam diferenças frente ao manifesto fornecido; não autenticam o autor nem comprovam que o manifesto é confiável.

CreateArchive usa ZIP nativo .NET e mantém a pasta original. O ZIP fica ao lado da pasta e seu caminho aparece no console. Não é upload nem envio de e-mail. Pode conter dados reais sensíveis; publique somente exemplos fictícios no GitHub. A opção não é incluída silenciosamente pelo perfil completo.

## 40. Permissões, diagnóstico e aceitação

O inventário de diretório usa ADWS/LDAP do módulo ActiveDirectory. GPO/RSoP usa GroupPolicy, SYSVOL usa SMB/DFS, host usa WinRM/PowerShell Remoting e CIM, DNS administrativo usa DnsServer e eventos usam acesso remoto a logs. Cada componente requer conectividade e permissões próprias. Instalar RSAT de AD não instala necessariamente GroupPolicy/DnsServer nem concede acesso ao destino.

Não há elevação obrigatória na entrada; o perfil completo pode exigir execução elevada e direitos adicionais/delegados, especialmente para repadmin, RSoP, registro, remoting e Security. Não use Domain Admin indiscriminadamente para fazer um teste passar. Consulte Coverage/CollectionErrors, verifique o cmdlet/fonte específico e o escopo aprovado. A ferramenta não fornece direitos nem altera política de execução.

No VSCode, abra a pasta completa e use o terminal; os comandos com powershell.exe escolhem Windows PowerShell 5.1 mesmo se o terminal atual for PowerShell 7. Para testes em casa sem domínio, execute as três suítes ou abra examples/SYNTHETIC/Report.html. Não é necessário instalar AD, simular credenciais ou apontar um servidor da empresa.

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

A cobertura automatizada usa dados/adaptadores fictícios, arquivos locais e processos auxiliares inofensivos. Valida regressão, XML/XXE, flags, identidade de GPO, limites, jobs próprios, valores desconhecidos, exportação, renderização e hashes. Não executa AD, remoting, DCDiag ou repadmin reais contra uma infraestrutura. Consulte TESTING.pt-BR.md e EVIDENCE.json para as execuções efetivamente aprovadas. Faça aceitação em laboratório com permissões reais, idiomas, RODC/DNS separado e múltiplos domínios antes do uso operacional.

## 41. Fontes e dicionário de dados

CSV-SCHEMAS.json lista todos os 63 arquivos e cada coluna extraídos do código. DATA-DICTIONARY.pt-BR.md relaciona conjuntos e semântica. SOURCES.pt-BR.md e SOURCES.json relacionam a documentação oficial consultada e os valores selecionados do catálogo. AssessmentSources também acompanha os relatórios HTML/CSV/JSON. Links são referências de leitura; a coleta não acessa esses sites automaticamente.

## 42. Ciclo de vida e grupos adicionais por SID

Findings também inclui OS-LIFECYCLE-REVIEW para famílias antigas selecionadas e Windows 10 comum que exige confirmação de edição/build/ESU. São observações Info, não um veredito universal de sistema sem suporte. Referências diretas Microsoft Lifecycle e datas do catálogo, conferidas em 13/11/2026, acompanham a evidência. Windows 10 LTSC/LTSB não recebe automaticamente a data de Home/Pro; sistemas modernos ou famílias desconhecidas não são classificados por exclusão.

As referências de fim de suporte regular incluem [Server 2012 R2](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2012-r2), [Server 2012](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2012), [Server 2008 R2](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2008-r2), [Windows 7](https://learn.microsoft.com/en-us/lifecycle/products/windows-7) e [Windows 10 Home/Pro](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro). Regular support end não avalia sozinho extensão contratual/ESU nem comprova o SO atual do host: o atributo no AD pode estar desatualizado. Os alertas não mudam com uma consulta de Internet automática; revise o catálogo a cada manutenção da ferramenta.

IncludeDirectorySecurity complementa PrivilegedMembers com os SIDs de Domain Controllers (516), Read-only Domain Controllers (521), Group Policy Creator Owners (520), Print Operators (S-1-5-32-550), Distributed COM Users (S-1-5-32-562) e Cryptographic Operators (S-1-5-32-569), quando encontrados no inventário do domínio. Somados aos grupos base, cobrem os 13 grupos de referência na raiz; Schema/Enterprise Admins continuam próprios da raiz. SkipPrivilegedMembers suprime também essas consultas adicionais.

MembershipType continua DirectOnly. São membros diretos, sem expansão de grupos, SIDHistory ou cálculo de direitos efetivos. Grupos de DC contêm legitimamente contas de DC: a presença desses membros não dispara uma regra de contagem insegura. Nomes localizados/renomeados não são usados para localizar os grupos.
