# Manual completo — FMODEL AD Health Report 1.1.0

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

Operação real: Windows de 64 bits, Windows PowerShell 5.1 e módulo ActiveDirectory/RSAT disponível. O computador precisa alcançar o AD selecionado e autenticar com uma conta autorizada. Pode ser uma estação de administração com RSAT; não é obrigatório executar o script dentro de um DC. O PowerShell 7 é usado somente nos testes offline desta entrega; a entrada operacional desta edição recusa PowerShell 7.

Não há exigência de elevação por padrão. Leituras de diretório podem funcionar com permissões delegadas; consultas adicionais de replicação, CIM ou DCDiag podem exigir direitos diferentes. A ferramenta não concede esses direitos nem tenta contornar ACLs. Não é necessário usar uma conta Domain Admin somente por conveniência para um inventário básico. Use o menor conjunto de permissões aprovado para o escopo.

O token atual é utilizado. Não há senha embutida, chave de API ou exportação de credenciais. A ferramenta não instala RSAT, habilita WinRM, configura TrustedHosts ou abre firewall. DNS, autenticação, AD Web Services e protocolos exigidos por cada diagnóstico devem estar disponíveis conforme a arquitetura. A coleta CIM opcional usa WSMan e depende de sua configuração existente.

## 4. Download, pasta e VSCode

No GitHub, abra scripts/ad-health-report, selecione AD-Health-Report-v1.1.0.zip e clique em Download raw file. Depois escolha Extrair Tudo. Alternativa: Code → Download ZIP na página principal, extrair e abrir scripts/ad-health-report. Git não é requisito para baixar.

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

Os 18 conjuntos anteriores permanecem e recebem 12 adicionais, totalizando 30 CSVs. Eventos são limitados pela janela/cap explícitos; todos os dados obtidos nessas condições são exportados para CSV/JSON e exibidos no HTML até MaxHtmlRows. Novos campos:

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
