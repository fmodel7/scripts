# Hyper-V Health Report 1.0.0 — Manual completo

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
Criado e mantido por **F. Model** · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)  
[English](MANUAL.en-US.md) · [Início](../README.md)

## 1. Objetivo e resultado

O `Export-HyperVHealthReport.ps1` reúne inventário e evidências operacionais dos hosts Hyper-V, das máquinas virtuais e, quando solicitado, de um cluster de failover. A finalidade é ajudar a equipe a entender capacidade, identificar situações que merecem investigação e preparar uma revisão técnica com dados exportáveis.

Cada execução cria uma pasta exclusiva com **HTML offline, 54 CSVs, JSON e manifesto SHA256**. O ZIP é opcional. O HTML tem identificação FMODEL, indicadores, achados com recomendações, tabelas recolhíveis, busca geral, busca por tabela, filtro de severidade, navegação, links para CSV e impressão pelo navegador. Textos e recomendações podem ser apresentados em PT-BR ou EN-US.

É uma fotografia de consultas de leitura, não um monitor contínuo, benchmark, scanner de vulnerabilidades, teste de restauração ou certificação de conformidade. “Nenhum achado” só descreve as regras que puderam ser aplicadas aos dados coletados. Primeiro confira cobertura e erros.

## 2. O que mudou em relação ao arquivo enviado

O arquivo de referência se identifica como **Get-HyperVReport.ps1 v1.5, de 05/03/2015, de Serhat AKINCI**. Ele foi analisado estaticamente e não foi executado neste trabalho. A entrega FMODEL é uma implementação independente, organizada em um único PS1 operacional; o arquivo antigo não está incluído nem foi simplesmente renomeado com novos créditos.

| Tema | Entrega atual |
|---|---|
| Plataformas e consultas | Windows PowerShell 5.1 x64; cmdlets Hyper-V/FailoverClusters e CIM; sem montagem de comandos WMI com `Invoke-Expression` |
| Instalação e configuração | Não instala recursos, não altera política de execução, firewall, remoting ou configurações de VMs |
| Saídas | HTML e CSVs normalizados, JSON com valores anteriores à proteção de planilha, manifesto e ZIP opcional |
| Falhas | Cobertura por sondagem, erro por alvo, limites explícitos e preservação de pacotes concluídos antes de timeout |
| Armazenamento | Cadeias VHD com limite e detecção de ciclos; arquivo físico, capacidade virtual e espaço do volume separados |
| Segurança | Secure Boot, vTPM/shielding, Device Guard, SMB e configuração de rede como evidências, sem impor alterações |
| Estudo | Exemplo fictício integrado, testes offline e um manual completo por idioma |
| Envio por e-mail | Não incluído; relatórios não são enviados automaticamente e senhas SMTP não são solicitadas |

O repositório não possui licença geral de reutilização escolhida. Visibilidade pública não resolve direitos de código de terceiros. Referências e autoria do material comparado são preservadas nesta documentação; o original não é distribuído neste pacote.

## 3. Requisitos e compatibilidade

| Uso | Requisitos |
|---|---|
| Coleta real | Windows de 64 bits, **Windows PowerShell 5.1 Desktop**, `powershell.exe`, acesso aos hosts e permissões para as consultas |
| Alvos planejados | Hyper-V no Windows Server 2016, 2019, 2022 e 2025, conforme disponibilidade dos cmdlets/propriedades; aceite real por versão ainda necessário |
| Host local | Módulo Hyper-V instalado previamente no próprio host; não depende de WinRM para consultar a própria máquina |
| Hosts remotos | WinRM/PowerShell Remoting já configurado, DNS, autenticação e endpoint Windows PowerShell compatível; módulos executados no alvo |
| Cluster | `-ClusterNode` recebe o nome de **um nó real**, que precisa ter FailoverClusters disponível; a descoberta acontece nesse nó |
| Exemplo, HTML offline e testes | Windows PowerShell 5.1 ou PowerShell 7; modo de exemplo/renderização também funciona no Linux |
| HTML | Navegador moderno, sem internet; JavaScript local é usado para busca e controles |

PowerShell 7 é recusado para coleta real nesta versão para evitar assumir compatibilidade dos módulos Windows por importação implícita. Não é necessário instalar PowerShell 7 para coletar. Em Windows cliente com Hyper-V, informações específicas de servidor/cluster/Replica podem não existir; esse cenário não foi homologado como plataforma operacional completa.

As verificações automatizadas usam provedores simulados. Não houve acesso a um host Hyper-V, SAN, SOFS, storage spaces, cluster ou VM reais. A aprovação dos testes não representa homologação em produção.

## 4. Permissões: qual conta utilizar

O script usa a identidade da sessão atual. Não solicita senha por padrão. Para uma conta diferente em consultas remotas, passe `-Credential (Get-Credential)`. A credencial não é gravada nos relatórios, não é incluída no JSON e não é enviada para dentro do scriptblock do coletor como parâmetro.

| Área | Dependência de acesso |
|---|---|
| Inventário Hyper-V | Permissões de gerenciamento/leitura nos hosts; Hyper-V Administrators pode atender parte do escopo |
| Conexão remota | Direito ao endpoint WinRM escolhido pela configuração do Windows; pertencer somente ao grupo Hyper-V Administrators não garante isso |
| CIM, serviços e Registro | Acesso aos provedores e às chaves consultadas |
| Eventos | Permissões de leitura nos canais; administradores/grupos delegados conforme a política da empresa |
| Cluster | Permissões no cluster e acesso a cada nó descoberto |
| VHD em uso | Consultar no host proprietário; SMB e segundo salto podem exigir arquitetura de autenticação apropriada |
| Saídas | Criar arquivos no diretório local informado |

Comece em laboratório com uma conta autorizada e delegue o mínimo necessário conforme o ambiente. O script não cria delegação, não habilita CredSSP e não modifica TrustedHosts. `-Credential` não corrige automaticamente segundo salto para compartilhamentos SMB. A referência S19 explica esse limite.

Uma credencial explícita não pode ser aplicada ao job local: nesse caso, abra a sessão local com a identidade pretendida ou use um alvo remoto explícito. Nomes locais reconhecidos incluem `.`, `localhost`, loopback e o nome curto da máquina; um FQDN da própria máquina pode ser tratado como remoto.

## 5. Caminho mais simples: baixar, extrair e testar

1. Use [Baixar pacote Hyper-V](https://github.com/fmodel7/scripts/raw/refs/heads/main/scripts/hyper-v-health-report/HyperV-Health-Report-v1.0.0.zip).
2. No Explorador de Arquivos, clique no ZIP e escolha **Extrair Tudo**.
3. Abra a pasta extraída que contém `Export-HyperVHealthReport.ps1` e `README.md`.
4. Copie o caminho dessa pasta na barra de endereços do Explorador.
5. Abra PowerShell ou o terminal integrado do VSCode e execute os comandos abaixo. Cole somente o caminho quando solicitado, sem acrescentar novamente o nome da pasta.

```powershell
$pasta = Read-Host 'Cole o caminho da pasta extraída'
Set-Location -LiteralPath $pasta.Trim('"')
Get-ChildItem -LiteralPath .
```

Confirme que o PS1 está listado. Depois de revisar o arquivo e confiar na origem, desbloqueie somente os arquivos que vai executar:

```powershell
Unblock-File -LiteralPath .\Export-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVCollectors.ps1
```

O desbloqueio remove a marca de download; não cria assinatura digital. Se houver `AllSigned` ou política de grupo exigindo assinatura, peça o procedimento de assinatura/aprovação da organização. Não altere a política global para `Unrestricted` ou `Bypass`.

Teste sem Hyper-V e sem acesso a servidores:

```powershell
$resultado = .\Export-HyperVHealthReport.ps1 -CreateExample -Language pt-BR
Invoke-Item -LiteralPath $resultado.Html
```

O navegador deve abrir um exemplo com **HV-LAB01**, **HV-LAB02**, **APP-LAB01** e **DB-LAB01**, claramente marcado como fictício. Esse comando somente cria os arquivos locais do exemplo.

## 6. Executar os testes offline

```powershell
.\tests\Test-HyperVHealthReport.ps1
.\tests\Test-HyperVCollectors.ps1
```

O primeiro verifica parsing, regras, serialização, fórmulas em CSV, HTML seguro, manifestos, recriação offline e comandos do programa. O segundo simula consultas a hosts/cluster e comportamento dos jobs. As mensagens finais começam com `PASS:`. Falhas interrompem o teste com uma mensagem descritiva.

Esses testes não se conectam ao seu Hyper-V. Eles não substituem a comparação com Hyper-V Manager/Failover Cluster Manager em laboratório.

## 7. Coleta real no próprio host Hyper-V

No servidor de laboratório, abra **Windows PowerShell** de 64 bits com a conta autorizada. Se estiver em um terminal PowerShell 7, inicie o Windows PowerShell:

```powershell
powershell.exe -NoProfile
```

Entre na pasta do script usando o procedimento da seção 5. Confira o runtime:

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition
[Environment]::Is64BitProcess
Get-Module -ListAvailable Hyper-V
```

Espere versão 5.1, edição Desktop e `True`. Então:

```powershell
$resultado = .\Export-HyperVHealthReport.ps1 -OutputPath C:\Reports\HyperV -CreateZip
Invoke-Item -LiteralPath $resultado.Html
```

Sem `-ComputerName`, o alvo é a máquina atual. O job local executa as consultas no host; não instala nada nem inicia jobs dentro das VMs. A coleta pode consumir CPU, I/O e acessos a metadados, embora seja de leitura.

## 8. Um host remoto ou vários hosts

Substitua os nomes abaixo pelos hosts autorizados:

```powershell
$resultado = .\Export-HyperVHealthReport.ps1 -ComputerName HV01 -OutputPath C:\Reports\HyperV

$resultado = .\Export-HyperVHealthReport.ps1 -ComputerName HV01,HV02 -Language en-US -CreateZip

# Solicita a credencial somente porque este exemplo a pede explicitamente.
$credencial = Get-Credential
$resultado = .\Export-HyperVHealthReport.ps1 -ComputerName HV01 -Credential $credencial
Invoke-Item -LiteralPath $resultado.Html
```

Não há teste de ping bloqueando as consultas. DNS, WinRM e permissões têm efeitos diferentes e precisam ser investigados individualmente. Os hosts são consultados sequencialmente; o script não dispara centenas de consultas simultâneas.

## 9. Coletar um cluster

Informe **um nó membro**, e não dependa do nome virtual do cluster ter um endpoint WinRM:

```powershell
$resultado = .\Export-HyperVHealthReport.ps1 -ClusterNode HV01 -CreateZip -HostTimeoutSeconds 900
Invoke-Item -LiteralPath $resultado.Html
```

O script conecta ao nó informado, consulta cluster, nós, grupos, recursos, volumes CSV, redes e quorum, e depois consulta cada nó descoberto, inclusive nós que podem estar Down. Falha ao acessar um nó fica explícita. `-ComputerName` e `-ClusterNode` pertencem a modos diferentes e não devem ser combinados.

`-MaxHosts` limita os nós processados. A descoberta e cada host possuem orçamento de tempo separado. O nome/estado das VMs pode mudar durante Live Migration; o relatório não é um snapshot transacional do cluster e não garante contagem única de VMs entre momentos distintos.

Não executa `Test-Cluster`, failover, drain, Live Migration ou mudança de quorum. Não calcula garantia N+1/HA: capacidade real de failover também depende de reservas, placement, compatibilidade, afinidade, NUMA e carga.

## 10. Usar o VSCode

Abra a pasta da ferramenta em **File → Open Folder**. Abra **Terminal → New Terminal**. O terminal deve estar na pasta que contém o PS1; use `Get-ChildItem` para confirmar. Se já estiver nessa pasta, não repita `cd .\hyper-v-health-report`.

Para o exemplo, execute diretamente o comando da seção 5. Para coleta real, execute `powershell.exe -NoProfile` no terminal e siga as seções 7–9. A extensão PowerShell ajuda a ler e editar, mas não é requisito para rodar pelo terminal. Preferir o terminal aos botões Run Code evita escolher o runtime/pasta errados sem perceber.

## 11. Arquivos produzidos e compartilhamento

```text
HyperV-Reports/
└── HyperV-AAAAMMDD-HHMMSS-identificador/
    ├── report.html
    ├── report.json
    ├── MANIFEST-SHA256.txt
    └── csv/
        ├── Hosts.csv
        ├── VMs.csv
        ├── Findings.csv
        ├── Coverage.csv
        ├── Errors.csv
        └── ... todos os 54 conjuntos
```

`-CreateZip` cria também um ZIP ao lado da pasta. Cada execução usa um diretório novo; relatórios anteriores não são sobrescritos. `OutputPath` é um diretório local no computador que executa o script, mesmo quando os alvos são remotos. UNC e caminhos que atravessam reparse points/symlinks são recusados. A proteção é uma validação de caminho, não isolamento contra alterações concorrentes feitas por outro processo.

Compartilhe o ZIP ou a pasta completa para preservar os links CSV. Abrir um HTML pelo GitHub não equivale a abrir o relatório no navegador: baixe e extraia os arquivos. Em Server Core, copie o pacote para uma estação autorizada para visualizar.

Os arquivos usam as permissões herdadas do diretório de saída; o script não impõe uma ACL privada. Escolha uma pasta apropriada. Não publique relatórios reais neste repositório público: nomes, IPs, caminhos, notas e mensagens de eventos podem revelar informações internas. Exemplos publicados aqui são fictícios.

## 12. Como ler o HTML

Comece pelos indicadores e pelo resumo de hosts. Indicadores contam registros observados: em coleta parcial ou durante migração, eles não representam um censo garantido do ambiente. Depois leia `Findings`, `Coverage` e `Errors` antes de decidir qualquer correção.

Uma linha em `Findings` informa severidade, regra, host, alvo, evidência, recomendação e `SourceId`. As fontes correspondentes estão ao final deste manual. **Critical** prioriza investigação de um sinal relevante, **Warning** pede revisão e **Info** fornece contexto; nenhuma delas autoriza ação destrutiva automática.

Use a busca global ou a busca da seção para localizar uma VM, caminho ou evento. O filtro de severidade afeta a tabela de achados. Setas/abas de cada seção expandem as tabelas; os botões superiores expandem/recolhem todas. A impressão usa o navegador e permite salvar em PDF; ela não cria um segundo manual PDF no repositório. Os filtros ativos também afetam as linhas visíveis na impressão.

O padrão mostra até **500 linhas por conjunto** no HTML. O aviso da seção explica o limite. A busca pesquisa somente as linhas renderizadas. Os CSVs e o JSON contêm todos os registros que foram efetivamente exportados, respeitando os limites de coleta. Um CSV “completo” não recupera registros que ficaram fora por timeout, cap ou falta de permissão.

`—` indica desconhecido/não informado, não zero. Identificadores e alguns nomes de propriedades permanecem técnicos para facilitar correlação com cmdlets e CSVs. As explicações e unidades estão nas seções de dados deste manual.

## 13. CSV, Excel, JSON e integridade

Os CSVs usam vírgula, campos entre aspas, aspas internas duplicadas e **UTF-8 com BOM**. Se o Excel PT-BR abrir tudo em uma coluna, use **Dados → De Texto/CSV**, escolha UTF-8 e delimitador vírgula. Importação PowerShell:

```powershell
$vms = Import-Csv -LiteralPath (Join-Path $resultado.CsvDirectory 'VMs.csv')
$vms | Select-Object Host,VMName,State,ProcessorCount

$achados = Import-Csv -LiteralPath (Join-Path $resultado.CsvDirectory 'Findings.csv')
$achados | Where-Object Severity -eq 'Critical'
```

Texto que começa com caracteres de fórmula (`=`, `+`, `-`, `@`, incluindo certos prefixos de espaço/controle) recebe apóstrofo no CSV para reduzir execução de fórmulas em planilhas. Números negativos tipados continuam numéricos. O JSON preserva o valor original normalizado anterior a essa proteção de apresentação; não armazena objetos nativos completos nem credenciais.

Datas calculadas são ISO8601 UTC; campos nativos de data/duração são preservados como texto quando o provedor não expõe uma data tipada. Arrays tornam-se valores separados por `; `, não registros independentes. Campos ausentes tornam-se `null` no JSON e vazios no CSV. `SchemaVersion=1`, `Version=1.0.0`, `RunId`, parâmetros e timestamps ajudam a rastrear a coleta.

O manifesto lista SHA256 dos arquivos HTML, JSON e CSVs, com caminhos relativos. Não inclui ele próprio nem o ZIP externo. Hash detecta alteração em relação a um manifesto confiável; **não autentica o autor e não é assinatura digital**.

## 14. Recriar HTML e CSVs de uma coleta sem reconectar

```powershell
$arquivo = Read-Host 'Cole o caminho completo do report.json'
$novaSaida = .\Export-HyperVHealthReport.ps1 -InputJson $arquivo.Trim('"') -Language en-US -CreateZip
Invoke-Item -LiteralPath $novaSaida.Html
```

Esse modo lê o JSON local, valida a estrutura e reexporta os dados. Não consulta servidores e não reavalia regras ou muda thresholds. O idioma da interface é atualizado; recomendações já armazenadas no JSON permanecem no idioma da coleta original. Para obter todas as recomendações em outro idioma, faça a coleta ou o exemplo com esse idioma desde o início.

São aceitos somente relatórios concluídos deste programa e schema 1, em arquivo regular local de até 100 MiB. Campos aninhados nos conjuntos são recusados. O limite por conjunto na leitura offline é 200.000 registros; um relatório de coleta muito grande pode exigir processamento externo em vez desse modo. Não use JSON arbitrário como configuração de comandos.

## 15. Cobertura, falhas e tempos

| Status por sondagem | Interpretação |
|---|---|
| Collected | A consulta/projeção retornou registros; não significa saudável |
| Empty | A consulta terminou sem registros; não confundir com falha |
| Failed | A leitura/projeção não terminou normalmente; conferir Errors |
| Unsupported | Cmdlet indisponível no alvo; funcionalidade não avaliada |
| NotRequested | Recurso não solicitado, por exemplo BPA ou dados de cluster em modo hosts |
| NotApplicable | Exemplo: firmware/vTPM de geração 2 para VM de geração 1 ou VHD para disco pass-through |
| NotEnabled | Replica ou medição de recursos já desabilitados; o script não habilita |
| Truncated | Havia mais registros que o limite; os restantes não foram exportados |
| Partial | Cadeia VHD não pôde ser lida por completo, ciclo ou limite de profundidade |
| TimedOut | O job do host/descoberta excedeu o orçamento; sondagens posteriores são desconhecidas |
| Disabled | Canal de eventos desabilitado; não significa ausência de eventos relevantes |

`Completed` descreve a conclusão sem os avisos que o código encontrou; `CompletedWithIssues` inclui achados de atenção e/ou cobertura incompleta; `SyntheticExample` é somente demonstração. Erros do runtime, parâmetros, JSON ou gravação interrompem a execução com exceção. Um relatório `CompletedWithIssues` continua sendo uma execução bem-sucedida do programa para fins de saída do processo: automações devem inspecionar `Status`, Coverage e Findings, não apenas `$LASTEXITCODE`.

O orçamento padrão é de 600 segundos por job. Hosts são sequenciais e a descoberta do cluster tem seu próprio orçamento; não é um prazo máximo global. A abertura remota usa OpenTimeout de 30 segundos e OperationTimeout de 120 segundos no mecanismo WinRM. Um job travado perde a sondagem em andamento; pacotes já emitidos são recebidos e preservados.

Somente o job retornado ao script é parado/removido, por referência. Não usa limpeza global de jobs de outras tarefas. `DurationSeconds` cobre cada sondagem; para eventos, a busca é feita antes do pacote, portanto a duração de `Events` mede projeção/publicação e não toda a busca nativa. `StartedUtc/EndedUtc` da execução delimitam a coleta/avaliação, antes da finalização dos arquivos.

## 16. Limites de capacidade e interpretação

CPU: soma de vCPU configurada não é CPU efetivamente consumida. A razão considera vCPU de registros em execução e processadores lógicos do host. Não há uma proporção Microsoft universal de 8:1: o valor padrão é um gatilho local de observação e deve ser ajustado ao workload. `CPUUsage`/`LoadPercentage` são fotografias, não série histórica, fila de CPU ou prova de latência aceitável.

Memória: a informação do SO vem de `TotalVisibleMemorySize`/`FreePhysicalMemory` em KiB, convertidos para bytes. Não é inventário de DIMMs. Memória de startup, atribuída, demandada, mínimo e máximo têm significados diferentes; não somar máximos dinâmicos como consumo atual. Percentuais de memória livre são gatilhos de revisão, não diagnóstico automático de falta de RAM.

Discos: `FileSizeBytes` é tamanho do arquivo informado pelo Hyper-V; `VirtualSizeBytes` é a capacidade virtual apresentada ao convidado. Nenhum deles é, isoladamente, uso físico real da SAN/S2D/SOFS ou espaço livre dentro da VM. ReFS, block cloning, deduplicação e thin provisioning mudam a relação física. O programa não entra no guest para medir sistemas de arquivos.

`StorageCapacity` agrupa somente caminhos lidos que puderam ser associados a um volume do host. Deduplica caminho por host e inclui pais das cadeias; a soma de capacidades virtuais de filhos e pais **não é capacidade útil única**. `NominalGrowthBytes = max(0, soma virtual − soma de arquivos)` é apenas diferença nominal observada, não forecast/overcommit certificado. SMB e caminhos não associados ficam fora. Nunca somar o mesmo CSV/volume compartilhado entre hosts para obter total físico do cluster.

Checkpoints: o limiar padrão de 7 dias é política inicial FMODEL, não prazo universal Microsoft. Pode haver checkpoints de backup/recovery, checkpoints intencionais e merges em andamento. Não apagar `.avhdx` manualmente. O script não procura “discos órfãos” por varredura irrestrita e não monta/testa/repara VHDs.

Replica: `Normal` é saúde reportada pelo mecanismo naquele momento; não prova RPO atendido, capacidade no site secundário ou restauração. Backup e Replica são controles diferentes. Nenhum backup novo, exportação de VM, checkpoint, teste de failover ou teste de restauração é iniciado.

## 17. Segurança e boas práticas: como aplicar os resultados

Os dados de Secure Boot, vTPM, shielded VM, criptografia de estado/tráfego de migração e Device Guard devem ser confrontados com a política da organização e compatibilidade dos convidados. Não há regra que torne todas as VMs sem vTPM “inseguras”. Geração 1 não oferece o mesmo conjunto de firmware de geração 2.

Rede inclui vSwitch, SET, VLAN, interfaces, MAC, IPs reportados pelo mecanismo Hyper-V, guards e offloads. IP guest reportado não comprova conectividade, DNS ou validade atual. Nome de interface Down não é falha por si só. MAC repetido pede revisão de identidade e isolamento: réplicas e redes distintas podem justificar repetição. Capacidade RDMA/VMQ/SR-IOV configurada não prova caminho de dados ativo, redundância ou throughput.

SMB mostra configuração local e conexões visíveis à identidade de coleta. Conexão vazia não significa que o Hyper-V nunca usa SMB; contexto de serviço/autenticação importa. SMB1 habilitado gera aviso. QFE não é catálogo completo de atualizações; não há comparação com baseline, advisories, firmware suportado ou vulnerabilidades.

BPA é **opt-in** e consulta somente resultados já existentes de `Microsoft/Windows/Hyper-V`. Não inicia um scan novo nem garante atualidade desses resultados; quando usados, confirme a data/escopo diretamente no BPA da organização. Regras FMODEL não são apresentadas como regras oficiais do BPA.

O HTML aplica encoding ao conteúdo e CSP com nonce para seus próprios estilos/scripts; não carrega bibliotecas ou imagens externas. As saídas continuam sendo documentos com informações internas, e não dados anonimizados. O programa não coleta chaves privadas, protetores de VM ou conteúdo de discos.

## 18. Eventos e reinicialização

Por padrão, consulta últimos 7 dias, níveis **1 Critical, 2 Error e 3 Warning**, até 200 registros por canal. Canais: System, Application, Microsoft-Windows-Hyper-V-VMMS-Admin, Microsoft-Windows-Hyper-V-Worker-Admin, Microsoft-Windows-Hyper-V-Hypervisor-Admin e Microsoft-Windows-FailoverClustering/Operational. Falta de canal/permissão e canal desabilitado aparecem na cobertura. Em host standalone, o canal de cluster pode não existir.

Contagem de eventos não é veredito de incidente atual. Não analisa texto traduzido para adivinhar sucesso ou falha. Para reduzir volume, use `-EventDays 1 -MaxEventsPerLog 100`; para não ler logs, `-SkipEvents`.

Reinicialização usa indícios do Registro: CBS RebootPending, WindowsUpdate RebootRequired e PendingFileRenameOperations. Os dois primeiros geram aviso de revisão quando presentes. Fila de renomeação gera apenas informação: ela pode persistir e não confirma sozinha necessidade atual de reiniciar. As chaves não cobrem todos os produtos/instaladores. S10 descreve uma API Windows Update distinta, que **não é chamada** pelo script; não confundir os indícios desta ferramenta com o estado oficial dessa API.

## 19. Problemas comuns

| Sintoma | Próximo passo |
|---|---|
| Pasta duplicada no `cd` | Use `Get-Location` e `Get-ChildItem`; não entre novamente numa pasta onde já está |
| Arquivo não assinado | Revise a origem, desbloqueie o arquivo específico; se AllSigned/GPO, seguir assinatura/aprovação corporativa |
| Coleta recusada no PowerShell 7 | Inicie `powershell.exe -NoProfile`; confirme 5.1 Desktop x64 |
| Hyper-V não encontrado | Execute no host correto e confirme módulo previamente instalado; o programa não instala recursos |
| WinRM/DNS/Access denied | Confirme nome, endpoint e permissões com o administrador; não abrir firewall ou TrustedHosts indiscriminadamente |
| VHD inacessível | Verifique host proprietário, migração, permissões e segundo salto SMB; não concluir que o arquivo sumiu |
| Cluster sem nós | Use nome de nó real, confirme FailoverClusters e acesso; confira Coverage/Errors |
| Parte das tabelas vazia | Confira Empty, Unsupported, NotRequested, NotApplicable e Failed |
| Muitos registros/truncamento | Aumente limites conscientemente ou reduza escopo e período; CSV não recupera registros não coletados |
| Timeout | Comece com um host, reduza eventos/escopo ou ajuste HostTimeoutSeconds após entender a lentidão |
| HTML não abre no servidor | Copie a pasta/ZIP para estação com navegador; comum em Server Core |
| CSV com uma coluna | Importar com delimitador vírgula e UTF-8, sem depender do separador regional |
| Não consigo ler a pasta de saída | Escolha diretório com permissões adequadas; o script usa ACL herdada |

## 20. Validação recomendada em laboratório

Faça primeiro o exemplo e os testes offline. Depois colete um host não crítico autorizado, compare quantidade/IDs/estados de VMs com Hyper-V Manager e compare volumes/checkpoints/VLANs/Replica com os respectivos cmdlets. Confirme que o script apenas criou relatórios locais e não alterou configurações.

Teste em seguida um host remoto e um pequeno cluster, conferindo cobertura de cada nó. Inclua uma VM desligada, uma geração 1 quando disponível, uma com metering desabilitado e um cenário de acesso insuficiente em conta delegada. Não provoque falhas nem falta de espaço para testar em produção. Simulações de discos com ciclo/profundidade são testes de código, não instruções para criar discos inválidos.

Confirme casos da sua arquitetura: VHD em uso no proprietário, CSV com ownership/migração, armazenamento SMB com autenticação, VLAN trunk/private, réplica estendida, convidados Linux e propriedades ausentes na versão de Windows usada. Compare os CSVs com consultas diretas autorizadas. Registre versão, runtime, hosts, resultados esperados e limitações aceitas.

## 21. Roteiro de apresentação ao time

“Esta ferramenta FMODEL coleta evidências de leitura do Hyper-V. Ela separa hosts, VMs, armazenamento, redes, cluster e eventos em conjuntos exportáveis. O resumo indica onde investigar, e a cobertura mostra quais consultas funcionaram, falharam ou ficaram limitadas. Nenhuma recomendação vira correção automática. A decisão depende do workload, da política da empresa e da validação da equipe.”

Perguntas úteis:

| Pergunta | Resposta de estudo |
|---|---|
| Altera VMs ou reinicia hosts? | Não; grava relatórios locais e administra somente seus próprios jobs de coleta |
| Precisa de agente no guest? | Não instala agente nem executa comandos no convidado; alguns IPs/estados dependem de dados de integração já disponíveis |
| Campo vazio é problema? | Não necessariamente; pode ser propriedade ausente, versão diferente, recurso desligado ou falha; conferir cobertura |
| Sinal verde/Collected garante saúde? | Não; descreve coleta, não um certificado de disponibilidade ou segurança |
| Ele verifica backup? | Não consulta produtos de backup nem executa restauração; checkpoints/Replica não comprovam backup |
| Por que Windows PowerShell 5.1? | É a plataforma operacional escolhida para os módulos Windows; PS7 foi validado para caminhos offline |
| As regras são Microsoft oficiais? | Não; são regras de revisão FMODEL contextualizadas com documentação Microsoft, incluindo thresholds locais |
| Qual o risco de impacto? | Consultas consomem recursos; começar em laboratório, escopo pequeno e período apropriado |
| Pode rodar agendado? | Sim como invocação do PS1 com conta/ambiente aprovados; o script não cria tarefa agendada |
| Como provar que o arquivo não mudou? | Comparar SHA256 com manifesto de origem confiável; isso não substitui assinatura digital |
| Está 100% validado no meu ambiente? | Não; testes sintéticos e renderização foram verificados, o aceite na infraestrutura real é separado |

## 22. Arquitetura interna para manutenção

O PS1 é independente: funções de schema, normalização, coleta, avaliação e HTML estão dentro do mesmo arquivo. A entrada principal é executada ao chamar o arquivo; dot-sourcing carrega funções para inspeção/testes sem iniciar coleta, mas configura StrictMode e ErrorActionPreference no escopo onde foi carregado. Para uso normal, execute com `&`/`.\`, não faça dot-source.

`Invoke-HvMain` escolhe o modo, valida runtime/thresholds e prepara alvos. `Invoke-HvBoundedWorker` cria um job local ou remoto com scriptblock fixo. `Invoke-HvWorker` usa sondagens independentes e devolve pacotes normalizados. `Add-HvPacket` registra linhas, cobertura e erros. `Invoke-HvAssessment` aplica regras e calcula resumos. `Write-HvDeliverables` grava CSVs/JSON/HTML, manifesto e ZIP opcional.

Nomes de servidores não são código: recebem validação e são argumentos de cmdlets. A recriação de scriptblock vem da função interna fixa, nunca de um JSON ou campo coletado. Capturas de objetos nativos só existem dentro do worker; o relatório contém propriedades selecionadas e valores normalizados. A leitura offline não executa comandos vindos do JSON.

Na manutenção, atualize o schema antes de adicionar colunas, revise a compatibilidade 5.1, preserve desconhecido versus zero, acrescente teste relevante do novo comportamento e sincronize ambos os manuais. Não reutilize contagens do exemplo como prova operacional.


## 23. Parâmetros completos

Modos: Hosts (padrão), Cluster, Example e Offline. Parâmetros de coleta/thresholds não alteram a recriação de JSON. CreateExample usa dados fixos sem consultas reais.

| Parâmetro | Tipo / intervalo | Padrão | Efeito |
|---|---|---|---|
| `-ComputerName` | string[] | máquina atual | Hosts explícitos; nomes/IPs IPv4, localhost ou ::1. Sem curingas. |
| `-ClusterNode` | string | — | Nó real do cluster; modo exclusivo. |
| `-InputJson` | string | — | Relatório local para recriação offline; não reavalia. |
| `-CreateExample` | switch | False | Demonstração fictícia, sem servidores. |
| `-Credential` | PSCredential | identidade atual | Somente modos hosts/cluster remotos; não persistida. |
| `-OutputPath` | string | ./HyperV-Reports | Diretório local de saída; pasta única por execução. |
| `-Language` | pt-BR / en-US | pt-BR | Idioma da nova avaliação/interface. |
| `-CreateZip` | switch | False | Compacta a pasta de resultados. |
| `-MaxHtmlRows` | int 1–5000 | 500 | Linhas renderizadas por tabela, não limite de CSV. |
| `-HostTimeoutSeconds` | int 30–7200 | 600 | Orçamento por job de host ou descoberta. |
| `-MaxHosts` | int 1–512 | 128 | Máximo de alvos processados; extras explícitos como truncamento. |
| `-MaxVMsPerHost` | int 1–20000 | 2000 | Inventário de VMs por host; truncamento visível. |
| `-MaxRowsPerProbe` | int 1–50000 | 5000 | Cap por sondagem, não por execução/conjunto inteiro. |
| `-MaxVhdDepth` | int 1–128 | 32 | Máximo de discos lidos em uma cadeia; marcador extra documenta limite. |
| `-EventDays` | int 1–90 | 7 | Janela recente por canal, nível 1/2/3. |
| `-MaxEventsPerLog` | int 1–5000 | 200 | Máximo exportado por canal/host; busca um extra para detectar truncamento. |
| `-SkipEvents` | switch | False | Não lê logs; registra NotRequested. |
| `-IncludeBpaResults` | switch | False | Lê resultados BPA existentes; não inicia scan. |
| `-VolumeWarningPercent` | double 1–99 | 15 | Aviso quando percentual livre fica abaixo; política local. |
| `-VolumeCriticalPercent` | double 0.1–98 | 5 | Crítico abaixo, menor que Warning. |
| `-MemoryWarningPercent` | double 1–99 | 10 | Revisão de memória livre do host abaixo. |
| `-MemoryCriticalPercent` | double 0.1–98 | 5 | Crítico abaixo, menor que Warning. |
| `-CheckpointWarningDays` | double 0–3650 | 7 | Aviso quando idade excede, não quando igual. |
| `-VcpuRatioWarning` | double 1–128 | 8 | Info quando razão configurada excede; não diagnostica contenção. |

Thresholds usam comparações estritas (`<`/`>`); igualdade não dispara regra. `-Verbose` é parâmetro comum. Não há WhatIf/reparo: a coleta real já é de leitura. Erros de parâmetros/runtime/gravação encerram com exceção; coleta parcial pode gerar CompletedWithIssues.

## 24. Todos os conjuntos, origens e campos

Cada conjunto existe como CSV mesmo vazio. Propriedades ausentes permanecem desconhecidas. O schema processável está em `../tests/evidence/CSV-SCHEMAS.json`. A lista é a seleção contratada, não todas as propriedades possíveis de cada objeto Windows.

### 24.1. Hosts — `Hosts.csv`

**Origem:** `Get-CimInstance: Win32_OperatingSystem / Win32_ComputerSystem`.

Uma linha por host com SO, fabricante/modelo, domínio, boot, memória visível e processadores. Memória CIM em KiB é convertida para bytes; uptime vem do boot.

**Campos, na ordem do CSV:**

```text
Host, CollectedUtc, Manufacturer, Model, Domain, OSCaption, OSVersion, Build, LastBootUtc, UptimeHours, MemoryTotalBytes, MemoryFreeBytes, MemoryFreePercent, LogicalProcessors, PhysicalProcessors, HypervisorPresent
```

### 24.2. Configuração dos hosts — `HostSettings.csv`

**Origem:** `Get-VMHost`.

Diretórios padrão, NUMA spanning, Live Migration, autenticação, concorrência e faixa MAC. Configuração de migração não comprova que uma migração funcionará.

**Campos, na ordem do CSV:**

```text
Host, VirtualMachinePath, VirtualHardDiskPath, NumaSpanningEnabled, VirtualMachineMigrationEnabled, VirtualMachineMigrationAuthenticationType, VirtualMachineMigrationPerformanceOption, MaximumVirtualMachineMigrations, MaximumStorageMigrations, UseAnyNetworkForMigration, MacAddressMinimum, MacAddressMaximum, EnableEnhancedSessionMode
```

### 24.3. Processadores — `Processors.csv`

**Origem:** `Get-CimInstance: Win32_Processor`.

Uma linha por processador físico reportado. MaxClockSpeed em MHz; LoadPercentage é amostra do provedor, não utilização total garantida do hypervisor. Flags de virtualização podem variar com hypervisor ativo.

**Campos, na ordem do CSV:**

```text
Host, DeviceID, Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, LoadPercentage, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions
```

### 24.4. NUMA — `NumaNodes.csv`

**Origem:** `Get-VMHostNumaNode`.

Topologia de nós e memória total/disponível em MiB do cmdlet. Não altera NUMA nem define automaticamente a melhor topologia das VMs.

**Campos, na ordem do CSV:**

```text
Host, NodeId, ProcessorCount, MemoryTotal, MemoryAvailable
```

### 24.5. Versões de VM aceitas — `SupportedVersions.csv`

**Origem:** `Get-VMHostSupportedVersion`.

Versões de configuração aceitas pelo host. Versão da VM é distinta da versão do Windows e da geração da VM; não executa upgrade de configuração.

**Campos, na ordem do CSV:**

```text
Host, Name, Version, IsDefault
```

### 24.6. Serviços — `Services.csv`

**Origem:** `Get-CimInstance: Win32_Service`.

Somente vmms, vmcompute, ClusSvc, WinRM, VSS, swprv e W32Time quando presentes. Serviços sob demanda parados não são falha automática; regra específica observa vmms.

**Campos, na ordem do CSV:**

```text
Host, Name, State, StartMode, Status
```

### 24.7. Atualizações QFE — `Hotfixes.csv`

**Origem:** `Get-CimInstance: Win32_QuickFixEngineering`.

Inventário QFE/HotFixID e data disponibilizada pelo provedor. Não é lista completa de atualizações nem auditoria de CVEs; InstalledOn pode ser texto nativo.

**Campos, na ordem do CSV:**

```text
Host, HotFixID, Description, InstalledOn
```

### 24.8. Indícios de reinicialização — `RebootSignals.csv`

**Origem:** `Get-Item / Get-ItemProperty: Registry`.

Três sinais do Registro, consultados no host. Falha de permissão não é tratada como chave ausente. PendingFileRenameOperations permanece informativo.

**Campos, na ordem do CSV:**

```text
Host, Signal, Present, Detail
```

### 24.9. Volumes — `Volumes.csv`

**Origem:** `Get-Volume`.

Volumes visíveis ao host, inclusive sem letra. SizeBytes/FreeBytes vêm de Size/SizeRemaining; FreePercent só é calculado com denominador positivo. Regra de espaço avalia volumes Fixed com tamanho conhecido.

**Campos, na ordem do CSV:**

```text
Host, Path, UniqueId, DriveLetter, FileSystemLabel, FileSystemType, HealthStatus, OperationalStatus, DriveType, SizeBytes, FreeBytes, FreePercent
```

### 24.10. Discos físicos — `PhysicalDisks.csv`

**Origem:** `Get-PhysicalDisk`.

Discos apresentados pelo subsistema Storage. RAID/SAN pode expor abstrações e não todas as unidades físicas. Não coleta SMART completo ou diagnóstico do fabricante.

**Campos, na ordem do CSV:**

```text
Host, FriendlyName, UniqueId, MediaType, BusType, HealthStatus, OperationalStatus, Size, CanPool, Usage
```

### 24.11. Pools de armazenamento — `StoragePools.csv`

**Origem:** `Get-StoragePool`.

Pools apresentados pelo Windows, incluindo primordial se retornado. Size/AllocatedSize em bytes; não equivale a um inventário completo da SAN ou topologia S2D.

**Campos, na ordem do CSV:**

```text
Host, FriendlyName, UniqueId, IsPrimordial, HealthStatus, OperationalStatus, Size, AllocatedSize
```

### 24.12. Interfaces do host — `NetworkAdapters.csv`

**Origem:** `Get-NetAdapter -IncludeHidden`.

Interfaces físicas/virtuais/ocultas com estado, MAC, link e dados de driver quando expostos. Down em interface não usada não gera alerta automático.

**Campos, na ordem do CSV:**

```text
Host, Name, InterfaceDescription, InterfaceIndex, Status, MacAddress, LinkSpeed, DriverInformation, DriverVersion, DriverDate, NdisVersion, Virtual, HardwareInterface
```

### 24.13. Endereços do host — `NetworkIPs.csv`

**Origem:** `Get-NetIPAddress`.

Endereços e prefixos das interfaces do host. Não resolve DNS, testa gateway ou identifica automaticamente rede de gerenciamento versus storage.

**Campos, na ordem do CSV:**

```text
Host, InterfaceAlias, InterfaceIndex, AddressFamily, IPAddress, PrefixLength, AddressState, PrefixOrigin, SuffixOrigin
```

### 24.14. Switches virtuais — `Switches.csv`

**Origem:** `Get-VMSwitch`.

Switches e tipo External/Internal/Private, interface associada e flags SET/SR-IOV. Disponibilidade depende da versão e do hardware.

**Campos, na ordem do CSV:**

```text
Host, Name, Id, SwitchType, NetAdapterInterfaceDescription, AllowManagementOS, EmbeddedTeamingEnabled, IovEnabled, IovSupport, BandwidthReservationMode
```

### 24.15. Switch Embedded Teaming — `SwitchTeams.csv`

**Origem:** `Get-VMSwitchTeam`.

Consulta somente switches com EmbeddedTeamingEnabled=True. Registra modo/algoritmo; não testa failover de cabos nem substitui inventário completo LBFO.

**Campos, na ordem do CSV:**

```text
Host, Name, NetAdapterInterfaceDescription, TeamingMode, LoadBalancingAlgorithm
```

### 24.16. Redes de Live Migration — `MigrationNetworks.csv`

**Origem:** `Get-VMMigrationNetwork`.

Sub-redes e prioridade permitidas para Live Migration, quando disponíveis. Não inicia migração nem valida autenticação ponta a ponta.

**Campos, na ordem do CSV:**

```text
Host, Subnet, Priority
```

### 24.17. Serviço Hyper-V Replica — `HostReplica.csv`

**Origem:** `Get-VMReplicationServer`.

Configuração de recebimento Replica do host, autenticação/portas/destino. Não coleta certificados/chaves privadas nem testa conectividade Replica.

**Campos, na ordem do CSV:**

```text
Host, ReplicationEnabled, AllowedAuthenticationType, KerberosAuthenticationPort, CertificateAuthenticationPort, DefaultStorageLocation, ReplicationAllowedFromAnyServer
```

### 24.18. Máquinas virtuais — `VMs.csv`

**Origem:** `Get-VM`.

Inventário base por host. VMId identifica a VM; nomes podem repetir. Inclui estado, versão, geração, CPU/memória instantâneas, ações automáticas, paths e notas. Flags/versões de integração antigas podem estar vazias.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Generation, Version, State, Status, OperationalStatus, UptimeHours, CPUUsage, ProcessorCount, MemoryAssigned, MemoryDemand, MemoryStatus, DynamicMemoryEnabled, MemoryStartup, AutomaticStartAction, AutomaticStopAction, AutomaticStartDelay, CheckpointType, AutomaticCheckpointsEnabled, ReplicationState, ReplicationHealth, IntegrationServicesState, IntegrationServicesVersion, ResourceMeteringEnabled, IsClustered, ConfigurationLocation, SnapshotFileLocation, SmartPagingFilePath, Notes
```

### 24.19. CPU das VMs — `VMProcessors.csv`

**Origem:** `Get-VMProcessor -VM`.

vCPU, limites/reservas/peso, compatibilidade de migração, virtualização aninhada e limites NUMA. Count não representa consumo efetivo.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Count, Reserve, Maximum, RelativeWeight, CompatibilityForMigrationEnabled, CompatibilityForOlderOperatingSystemsEnabled, ExposeVirtualizationExtensions, HwThreadCountPerCore, MaximumCountPerNumaNode, MaximumCountPerNumaSocket, EnableHostResourceProtection
```

### 24.20. Memória das VMs — `VMMemory.csv`

**Origem:** `Get-VMMemory -VM`.

Startup/Minimum/Maximum em bytes; Buffer em percentual e Priority em peso do Hyper-V. DynamicMemoryEnabled determina a aplicação dos limites.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, DynamicMemoryEnabled, Startup, Minimum, Maximum, Buffer, Priority, MaximumAmountPerNumaNode
```

### 24.21. Discos conectados — `VMDisks.csv`

**Origem:** `Get-VMHardDiskDrive -VM`.

Uma linha por conexão de disco com controlador/localização, Path ou DiskNumber pass-through, reservas persistentes e QoS se disponível. Não presume que Path vazio é disco ausente.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, ControllerType, ControllerNumber, ControllerLocation, Path, DiskNumber, SupportPersistentReservations, MaximumIOPS, MinimumIOPS, QoSPolicyID
```

### 24.22. VHD e cadeia de pais — `VHDChains.csv`

**Origem:** `Get-VHD -Path, cadeia limitada`.

Uma linha por nível a partir de cada disco conectado. Depth=0 é o arquivo raiz da consulta. ReadStatus separa Read, Error, DepthLimit e CycleDetected. Não visita toda árvore de discos no armazenamento.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, RootPath, Depth, Path, ParentPath, VhdFormat, VhdType, FileSizeBytes, VirtualSizeBytes, MinimumSizeBytes, FragmentationPercentage, LogicalSectorSize, PhysicalSectorSize, BlockSize, Attached, DiskIdentifier, ReadStatus, Error
```

### 24.23. Rede das VMs — `VMNetworkAdapters.csv`

**Origem:** `Get-VMNetworkAdapter -VM`.

Interfaces por VM, associação ao switch, MAC/IPs reportados, spoofing/guards/port mirroring/proteção/QoS/offload. IPs são informativos, não sondagens de conectividade.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Name, Id, IsLegacy, SwitchName, SwitchId, Status, MacAddress, DynamicMacAddressEnabled, IPAddresses, MacAddressSpoofing, DhcpGuard, RouterGuard, PortMirroring, ProtectedNetwork, IovWeight, VmqWeight, MinimumBandwidthAbsolute, MinimumBandwidthWeight, MaximumBandwidth
```

### 24.24. VLAN das VMs — `VMVlans.csv`

**Origem:** `Get-VMNetworkAdapterVlan -VMNetworkAdapter`.

Uma configuração por interface consultada. OperationMode contextualiza AccessVlanId, NativeVlanId, trunk e private VLAN; campos de outros modos podem ser vazios ou zero nativo.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, AdapterName, OperationMode, AccessVlanId, NativeVlanId, AllowedVlanIdList, PrimaryVlanId, SecondaryVlanId, SecondaryVlanIdList
```

### 24.25. Serviços de integração — `IntegrationServices.csv`

**Origem:** `Get-VMIntegrationService -VM`.

Serviços de integração por VM com ID, Enabled e status nativos. Nomes/status podem ser localizados. VM parada não gera falha automática de heartbeat; Guest Service Interface pode estar desabilitado intencionalmente.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Name, Id, Enabled, PrimaryStatusDescription, SecondaryStatusDescription, PrimaryOperationalStatus, SecondaryOperationalStatus
```

### 24.26. Checkpoints — `Checkpoints.csv`

**Origem:** `Get-VMSnapshot -VM`.

Checkpoints expostos ao cmdlet, incluindo os tipos que ele retornar. CreationTimeUtc e AgeDays calculados; ParentSnapshot* descrevem hierarquia. Não enumera arquivos órfãos nem garante ver todo estado transitório de backup.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Name, Id, ParentSnapshotId, ParentSnapshotName, CreationTimeUtc, AgeDays, SnapshotType
```

### 24.27. Replicação — `Replication.csv`

**Origem:** `Get-VMReplication -VM`.

Relacionamentos de replicação retornados, incluindo estendidos quando expostos. VM com ReplicationState=Disabled recebe NotEnabled. Saúde/tempo reportados não comprovam recuperação.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, State, Health, Mode, RelationshipType, PrimaryServer, ReplicaServer, ReplicaPort, AuthenticationType, FrequencySec, LastReplicationTimeUtc, RecoveryHistory, AutoResynchronizeEnabled, ResynchronizeStartTime, ResynchronizeEndTime
```

### 24.28. Estatísticas Replica — `ReplicationStats.csv`

**Origem:** `Measure-VMReplication -VM`.

Estatísticas do intervalo de monitoramento já existente do Replica. Valores/nomes dependem da versão; intervalos não são uniformes entre hosts. Não altera nem reseta o monitoramento.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, ReplicationHealth, ReplicationState, LastReplicationTime, LastApplyTime, AverageReplicationLatency, AverageReplicationSize, PendingReplicationSize, MissedReplicationCount, SuccessfulReplicationCount, MonitoringStartTime, MonitoringInterval
```

### 24.29. Firmware das VMs — `VMFirmware.csv`

**Origem:** `Get-VMFirmware -VM`.

Somente geração 2. SecureBoot, template e boot de rede/console quando disponíveis. Secure Boot Off é observação contextual, não declaração de malware.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, SecureBoot, SecureBootTemplate, PreferredNetworkBootProtocol, ConsoleMode
```

### 24.30. Segurança das VMs — `VMSecurity.csv`

**Origem:** `Get-VMSecurity -VM`.

Somente geração 2 neste programa: vTPM, Shielded e criptografia de estado/tráfego. Não lê Get-VMKeyProtector nem valida Host Guardian Service.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, TpmEnabled, Shielded, EncryptStateAndVmMigrationTraffic, VirtualizationBasedSecurityOptOut, KsdEnabled
```

### 24.31. Medição já habilitada — `VMResources.csv`

**Origem:** `Measure-VM -VM`.

Somente se ResourceMeteringEnabled já for True. CPU média em MHz; memórias da medição em MB nativos do cmdlet; duração e dados agregados conforme o intervalo existente. Não habilita medição.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, MeteringDuration, AverageProcessorUsage, AverageMemoryUsage, MaximumMemoryUsage, MinimumMemoryUsage, TotalDiskAllocation, AggregatedAverageNormalizedIOPS, AggregatedAverageLatency, AggregatedDiskDataRead, AggregatedDiskDataWritten
```

### 24.32. Mídia óptica — `DVDDrives.csv`

**Origem:** `Get-VMDvdDrive -VM`.

Controlador e mídia óptica/ISO anexada. Path vazio pode significar unidade sem mídia. Não ejeta mídia nem acessa conteúdo da ISO.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, ControllerNumber, ControllerLocation, Path, DvdMediaType
```

### 24.33. Dispositivos DDA — `AssignedDevices.csv`

**Origem:** `Get-VMAssignableDevice -VM`.

Dispositivos DDA anexados às VMs quando o cmdlet existir. Não enumera tudo que o host poderia atribuir nem testa drivers/capacidade de failover.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Name, InstanceID, LocationPath
```

### 24.34. Fibre Channel virtual — `FibreChannel.csv`

**Origem:** `Get-VMFibreChannelHba -VM`.

HBAs Fibre Channel virtuais e WWNs dos conjuntos A/B. Não consulta switches SAN, zoning ou LUNs dentro do convidado.

**Campos, na ordem do CSV:**

```text
Host, VMId, VMName, Name, SanName, WorldWideNodeNameSetA, WorldWideNodeNameSetB, WorldWidePortNameSetA, WorldWidePortNameSetB
```

### 24.35. Cluster — `Cluster.csv`

**Origem:** `Get-Cluster`.

Uma linha de configuração a partir do nó semente, com nível funcional, quorum dinâmico e parâmetros de comunicação/quarentena expostos. Não modifica tolerância a falhas.

**Campos, na ordem do CSV:**

```text
Host, Name, Domain, ClusterFunctionalLevel, DynamicQuorum, DynamicWitness, QuarantineThreshold, QuarantineDuration, SameSubnetDelay, SameSubnetThreshold, CrossSubnetDelay, CrossSubnetThreshold
```

### 24.36. Nós do cluster — `ClusterNodes.csv`

**Origem:** `Get-ClusterNode`.

Lista de membros usada para construir o escopo de hosts. State/DrainStatus/NodeWeight/DynamicWeight são fotografia do cluster; a conectividade de consulta é avaliada depois.

**Campos, na ordem do CSV:**

```text
Host, Name, Id, State, NodeWeight, DynamicWeight, DrainStatus, FaultDomain
```

### 24.37. Grupos do cluster — `ClusterGroups.csv`

**Origem:** `Get-ClusterGroup`.

Roles/grupos com estado e nó proprietário. Nem todo grupo é VM e um grupo Offline pode ser intencional. Não correlaciona automaticamente todas as dependências com VMId.

**Campos, na ordem do CSV:**

```text
Host, Name, Id, State, OwnerNode, GroupType, Priority, FailoverThreshold, FailoverPeriod
```

### 24.38. Recursos do cluster — `ClusterResources.csv`

**Origem:** `Get-ClusterResource`.

Recursos e tipo, grupo/nó proprietário, core resource e estado. A regra automática destaca Failed, sem transformar todo Offline em falha.

**Campos, na ordem do CSV:**

```text
Host, Name, Id, State, OwnerGroup, OwnerNode, ResourceType, IsCoreResource
```

### 24.39. CSV do cluster — `ClusterVolumes.csv`

**Origem:** `Get-ClusterSharedVolume / SharedVolumeInfo.Partition`.

Uma linha por SharedVolumeInfo com caminho CSV, partição, capacidade, redirecionamento e FaultState. CSV aqui é Cluster Shared Volume; é diferente de arquivo .csv de dados.

**Campos, na ordem do CSV:**

```text
Host, Name, OwnerNode, State, Path, PartitionName, FileSystem, SizeBytes, FreeBytes, FreePercent, RedirectedAccess, FaultState
```

### 24.40. Redes do cluster — `ClusterNetworks.csv`

**Origem:** `Get-ClusterNetwork`.

Endereços, função e métricas das redes de cluster. Não testa cabos, redundância ou isolamento físico.

**Campos, na ordem do CSV:**

```text
Host, Name, Address, AddressMask, Role, State, Metric, AutoMetric
```

### 24.41. Quorum — `ClusterQuorum.csv`

**Origem:** `Get-ClusterQuorum`.

Tipo de quorum e recurso witness reportados. A existência do witness não prova disponibilidade ou desenho apropriado.

**Campos, na ordem do CSV:**

```text
Host, Cluster, QuorumType, QuorumResource
```

### 24.42. Eventos recentes — `Events.csv`

**Origem:** `Get-WinEvent`.

Registros nos canais/período/níveis definidos. EventId/Provider/RecordId/time/message permitem correlação. Falha ao obter mensagem localizada não autoriza inferir texto de sucesso.

**Campos, na ordem do CSV:**

```text
Host, LogName, TimeCreatedUtc, EventId, Level, Provider, RecordId, Message
```

### 24.43. Cobertura dos eventos — `EventCoverage.csv`

**Origem:** `Derivado da busca Get-WinEvent`.

Uma linha por canal com janela UTC, status, cap e truncamento. Rows conta exportados, não total de eventos do canal/período.

**Campos, na ordem do CSV:**

```text
Host, LogName, StartUtc, EndUtc, Status, Rows, Truncated, Limit, Error
```

### 24.44. Resultados BPA existentes — `BpaResults.csv`

**Origem:** `Get-BpaResult -ModelId Microsoft/Windows/Hyper-V`.

Somente com IncludeBpaResults. Resultados previamente existentes; Compliance/Excluded e recomendações nativas não atestam que um scan novo foi feito ou que são recentes.

**Campos, na ordem do CSV:**

```text
Host, ModelId, ResultNumber, Severity, Category, Title, Problem, Impact, Resolution, Compliance, Excluded
```

### 24.45. Segurança baseada em virtualização — `DeviceGuard.csv`

**Origem:** `Get-CimInstance root/Microsoft/Windows/DeviceGuard: Win32_DeviceGuard`.

Status VBS e listas numéricas de serviços/propriedades. Para VirtualizationBasedSecurityStatus: 0 desabilitado, 1 configurado mas não em execução, 2 configurado e em execução; decodificar outras listas conforme a documentação da versão.

**Campos, na ordem do CSV:**

```text
Host, VirtualizationBasedSecurityStatus, SecurityServicesConfigured, SecurityServicesRunning, RequiredSecurityProperties, AvailableSecurityProperties
```

### 24.46. Configuração SMB — `SmbSettings.csv`

**Origem:** `Get-SmbClientConfiguration / Get-SmbServerConfiguration`.

Uma linha Client e outra Server quando disponíveis. Campos somente de um componente ficam nulos no outro. Preferências de assinatura não equivalem à negociação de cada conexão.

**Campos, na ordem do CSV:**

```text
Host, Component, EnableSecuritySignature, RequireSecuritySignature, EnableSMB1Protocol, EnableSMB2Protocol, EncryptData, RejectUnencryptedAccess, EnableMultiChannel
```

### 24.47. Conexões SMB — `SmbConnections.csv`

**Origem:** `Get-SmbConnection`.

Conexões SMB visíveis no contexto da consulta, com dialeto, criptografia/assinatura quando expostos. UserName e Credential são deliberadamente excluídos da seleção.

**Campos, na ordem do CSV:**

```text
Host, ServerName, ShareName, Dialect, Encrypted, Signed, ContinuouslyAvailable, NumOpens
```

### 24.48. Offloads de rede — `AdapterOffloads.csv`

**Origem:** `Get-NetAdapterRdma / Get-NetAdapterVmq / Get-NetAdapterSriov`.

Kind separa RDMA, VMQ e SRIOV. Propriedades não disponíveis em determinada família ficam nulas; não são convertidas para False/0.

**Campos, na ordem do CSV:**

```text
Host, Kind, Name, InterfaceDescription, Enabled, OperationalState, SriovSupport, NumberOfReceiveQueues, NumberOfVMQs, BaseProcessorNumber, MaxProcessors
```

### 24.49. Rede do sistema de gerenciamento — `ManagementAdapters.csv`

**Origem:** `Get-VMNetworkAdapter -ManagementOS`.

Interfaces virtuais do sistema de gerenciamento, separadas das interfaces das VMs. Não garante que IPAddresses seja preenchido pelo cmdlet.

**Campos, na ordem do CSV:**

```text
Host, Name, SwitchName, SwitchId, Status, MacAddress, IPAddresses, ManagementOS
```

### 24.50. Resumo dos hosts — `HostSummary.csv`

**Origem:** `Derivado de Hosts/VMs/Checkpoints/Findings/Coverage`.

Totais e razão por host, com InventoryStatus. Falha/truncamento do inventário mantém somas de execução/CPU/memória como desconhecidas; CollectedVMRows é sempre quantidade efetivamente exportada.

**Campos, na ordem do CSV:**

```text
Host, CollectedVMRows, RunningVMRows, LogicalProcessors, ConfiguredVcpu, RunningVcpu, RunningVcpuPerLogicalProcessor, AssignedMemoryBytes, ConfiguredStartupMemoryBytes, HostFreeMemoryPercent, OldCheckpointRows, WarningFindings, CriticalFindings, CollectionProblems, InventoryStatus, Observation
```

### 24.51. Capacidade de VHD por volume — `StorageCapacity.csv`

**Origem:** `Derivado de Volumes/ClusterVolumes/VHDChains`.

Soma de caminhos VHD únicos por host/volume reconhecido, incluindo pais; ver limites na seção de capacidade. Não totaliza SMB, provisionamento físico ou espaço dentro das VMs.

**Campos, na ordem do CSV:**

```text
Host, VolumePath, VolumeSizeBytes, VolumeFreeBytes, UniqueVhdPaths, ObservedFileSizeBytes, ObservedVirtualSizeBytes, NominalGrowthBytes, Observation
```

### 24.52. Achados para revisão — `Findings.csv`

**Origem:** `Invoke-HvAssessment`.

Regras HV001–HV023, evidência e recomendação no idioma original da avaliação. Regras pedem revisão, não executam remediação.

**Campos, na ordem do CSV:**

```text
Severity, RuleId, Host, Target, Evidence, Recommendation, SourceId
```

### 24.53. Cobertura da coleta — `Coverage.csv`

**Origem:** `Pacotes do worker e controle de execução`.

Uma linha por sondagem/escopo. Para detalhes de VM, Scope normalmente contém VMId; cadeias incluem caminho e eventos incluem canal. Não há percentual artificial de saúde.

**Campos, na ordem do CSV:**

```text
Host, Dataset, Scope, Status, Rows, StartedUtc, EndedUtc, DurationSeconds, Detail
```

### 24.54. Falhas de coleta — `Errors.csv`

**Origem:** `Exceções de sondagem/worker`.

Tipo e mensagem por host/conjunto/escopo. Pode conter caminhos e nomes internos; proteja como informação de infraestrutura. Nem todo Unsupported/Truncated gera exceção.

**Campos, na ordem do CSV:**

```text
Host, Dataset, Scope, ErrorType, Message
```

## 25. Dicionário e unidades essenciais

| Campo | Significado / unidade |
|---|---|
| `Host` | Host que produziu o pacote; na falha de transporte pode ser o alvo informado. |
| `VMId / VMName` | GUID e nome; nome de VM não é chave única. |
| `State / Status / HealthStatus` | Estados nativos; não inferir diagnóstico universal de texto traduzido. |
| `*Utc` | Data ISO8601 UTC normalizada/calculada; nulo se indisponível. |
| `*Bytes` | Bytes; alguns campos HTML também mostram GiB (1 GiB = 1.073.741.824 bytes). |
| `MemoryTotal / MemoryAvailable (NumaNodes)` | MiB do cmdlet NUMA, distintos de campos terminados em Bytes. |
| `MemoryAssigned / MemoryDemand / MemoryStartup` | Bytes da VM no inventário base; não memória de um processo guest. |
| `Startup / Minimum / Maximum (VMMemory)` | Bytes; aplicabilidade depende do modo de memória. |
| `AverageProcessorUsage (VMResources)` | MHz da medição existente, não percentual de CPU. |
| `Average/Maximum/MinimumMemoryUsage (VMResources)` | MB reportados por Measure-VM conforme S18; não convertidos para bytes. |
| `CPUUsage / LoadPercentage` | Percentual instantâneo/provider; não série histórica nem fila. |
| `FileSizeBytes / VirtualSizeBytes` | Arquivo VHD versus capacidade virtual; não alocação física garantida de SAN. |
| `RootPath / Path / ParentPath / Depth` | Disco conectado de origem, arquivo atual, pai e profundidade zero-based. |
| `ReadStatus` | Read, Error, DepthLimit ou CycleDetected; Error não significa Missing/Corrupt. |
| `NominalGrowthBytes` | Diferença nominal não negativa entre somas virtuais/de arquivos, não previsão. |
| `CollectedVMRows / RunningVMRows` | Registros efetivamente coletados; execução pode ser desconhecida com inventário incompleto. |
| `RunningVcpuPerLogicalProcessor` | vCPU configuradas de registros Running / processadores lógicos do host. |
| `InventoryStatus` | Status da sondagem VMs; falha final de worker invalida totais como censo completo. |
| `OldCheckpointRows` | Linhas observadas acima da idade; zero não prova ausência se coleta falhou. |
| `EventId / Provider / RecordId` | Identidade do evento/provedor e sequência no canal; correlacionar com log/tempo. |
| `Level` | Neste filtro: 1 Critical, 2 Error, 3 Warning. |
| `FrequencySec` | Intervalo Replica reportado em segundos; não RPO medido. |
| `ReplicationStats` | Intervalo/propriedades/unidades nativas do objeto VMReplicationHealth; ausentes são nulos. Não gera alerta automático por latência/tamanho. |
| `MeteringDuration / MonitoringInterval` | Período acumulado nativo, não janela uniforme escolhida pela ferramenta. |
| `SourceId` | Chave para fontes oficiais, não selo de conformidade. |
| `Scope` | Host, VMId, caminho, canal ou controle da sondagem. |
| `Rows / DurationSeconds` | Linhas exportadas e duração da sondagem; ver ressalva de eventos. |
| `Empty / null / 0 / False` | Sem registros, dado desconhecido, zero e booleano falso são distintos. |

## 26. Catálogo completo de regras

Regras de revisão FMODEL, não execução do BPA nem baseline universal Microsoft. O código contém recomendação em PT-BR/EN-US para cada gatilho. Fontes contextualizam a interpretação; thresholds são política inicial local.

| RuleId | Severidade | Fonte | Gatilho |
|---|---|---|---|
| HV001 | Warning/Critical | S03 | Espaço livre abaixo dos limites em volume Fixed conhecido. |
| HV002 | Warning | S04 | Volume com HealthStatus informado diferente de Healthy. |
| HV003 | Warning/Critical | S05 | Memória livre do host abaixo dos limites. |
| HV004 | Critical | S01 | State da VM contém Critical ou Failed. |
| HV005 | Warning | S01 | VM em Paused; confirmar intenção. |
| HV006 | Info | S02 | CheckpointType Standard: avaliar adequação. |
| HV007 | Warning/Critical | S06 | ReplicationHealth da VM é Warning/Critical. |
| HV008 | Warning | S05 | MemoryStatus da VM é Low/Warning. |
| HV009 | Warning | S03 | Idade de checkpoint maior que o limiar. |
| HV010 | Warning | S07 | VHD ReadStatus não é Read: erro, ciclo ou profundidade. |
| HV011 | Warning | S08 | VM Running com adaptador sem SwitchName. |
| HV012 | Warning | S08 | MAC não zero repetido entre VMIds distintos, com ou sem isolamento. |
| HV013 | Info | S09 | Secure Boot conhecido como Off/False/0 em firmware coletado. |
| HV014 | Critical | S01 | Serviço vmms retornado com State diferente de Running. |
| HV015 | Warning | S10 | Indício CBS ou Windows Update de reinicialização presente. |
| HV016 | Info | S10 | PendingFileRenameOperations presente; não confirma reinício. |
| HV017 | Warning | S11 | Nó do cluster em Down ou Joining. |
| HV018 | Critical | S11 | Recurso do cluster em Failed. |
| HV019 | Warning | S12 | CSV em acesso redirecionado ou FaultState conhecido diferente de NoFaults. |
| HV020 | Warning | S13 | SMB Server informa EnableSMB1Protocol=True. |
| HV021 | Info | S14 | Eventos exportados contêm níveis Critical/Error; correlacionar. |
| HV022 | Warning | S01 | Há Failed, TimedOut, Partial, Truncated ou Unsupported na cobertura do host. |
| HV023 | Info | S15 | Razão vCPU em execução/processadores lógicos excede limiar. |

## 27. Fontes oficiais e rastreabilidade

Referências Microsoft consultadas em **13/11/2026**. Aplicabilidade depende de versão/edição/cenário. Referenciar configuração não significa executar os comandos de alteração descritos na fonte.

| SourceId | Referência |
|---|---|
| S01 | [Hyper-V module](https://learn.microsoft.com/en-us/powershell/module/hyper-v) |
| S02 | [Hyper-V checkpoints](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/checkpoints) |
| S03 | [Checkpoint and differencing disk troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/hyper-v-snapshots-checkpoints-differencing-disks) |
| S04 | [Get-Volume](https://learn.microsoft.com/en-us/powershell/module/storage/get-volume?view=windowsserver2025-ps) |
| S05 | [Hyper-V memory performance](https://learn.microsoft.com/en-us/windows-server/administration/performance-tuning/role/hyper-v-server/memory-performance) |
| S06 | [Hyper-V Replica overview](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/replication-overview) |
| S07 | [Get-VHD and in-use disk ownership](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vhd?view=windowsserver2025-ps) |
| S08 | [Hyper-V Virtual Switch](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/virtual-switch) |
| S09 | [Plan for Hyper-V security](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-hyper-v-security-in-windows-server) |
| S10 | [Windows Update RebootRequired API (not called by this script)](https://learn.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-isysteminformation-get_rebootrequired) |
| S11 | [Get-ClusterResource](https://learn.microsoft.com/en-us/powershell/module/failoverclusters/get-clusterresource?view=windowsserver2025-ps) |
| S12 | [Cluster Shared Volumes overview](https://learn.microsoft.com/en-us/windows-server/failover-clustering/failover-cluster-csvs) |
| S13 | [Detect and manage SMB versions](https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3) |
| S14 | [Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent) |
| S15 | [Hyper-V processor performance](https://learn.microsoft.com/en-us/windows-server/administration/performance-tuning/role/hyper-v-server/processor-performance) |
| S16 | [Manage Hyper-V integration services](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services) |
| S17 | [Get-VMHostNumaNode](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmhostnumanode?view=windowsserver2025-ps) |
| S18 | [Measure-VM and resource-metering requirements/units](https://learn.microsoft.com/en-us/powershell/module/hyper-v/measure-vm?view=windowsserver2025-ps) |
| S19 | [PowerShell Remoting second hop](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ps-remoting-second-hop) |
| S20 | [Get-BpaResult: reads an existing scan](https://learn.microsoft.com/en-us/powershell/module/bestpractices/get-bparesult?view=windowsserver2025-ps) |
| S21 | [Get-VMHostSupportedVersion](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmhostsupportedversion?view=windowsserver2025-ps) |
| S22 | [Win32_DeviceGuard and VBS status](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity) |
| S23 | [Get-SmbConnection and logon context](https://learn.microsoft.com/en-us/powershell/module/smbshare/get-smbconnection?view=windowsserver2025-ps) |
| S24 | [PowerShell execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1) |
| S25 | [Get-VMSecurity](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmsecurity?view=windowsserver2025-ps) |
| S26 | [Measure-VMReplication monitoring interval](https://learn.microsoft.com/en-us/powershell/module/hyper-v/measure-vmreplication?view=windowsserver2025-ps) |
| S27 | [Replicate a virtual machine](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/replication-virtual-machines) |

## 28. Validação executada e aceite pendente

Testes: `tests/Test-HyperVHealthReport.ps1` e `tests/Test-HyperVCollectors.ps1`. Execução local Linux PowerShell 7.4.13 e GitHub Actions em Windows PowerShell 5.1, PowerShell 7 Windows e PowerShell 7 Linux. Código/resultado final: `tests/evidence/VALIDATION.json`; workflow no repositório: `.github/workflows/hyper-v-health-validation.yml`.

A suíte verifica regras e não-achados contextuais, mapeamento CIM/unidades, cadeia VHD normal/ciclo/profundidade/acesso negado, inventário vazio/negado/truncado, geração 1, Replica/metering desligados, falhas independentes, eventos vazios/negados/truncados, cluster, timeout/limpeza por referência, arquivos e CLI. Um job local real retorna dados sintéticos e confirma que um job não relacionado continua disponível. WinRM/Hyper-V seguem simulados.

HTML verificado no Chromium: **16 verificações**, em 1920, 1366 e 390 px, incluindo seções, links CSV, overflow da página, buscas/filtros, navegação, expansão/recolhimento, impressão e ausência de erros JS/requisições externas. Isso não valida todos os navegadores/leitores de tela.

**Ainda necessário:** aceite em Hyper-V/WinRM/cluster/SMB reais, permissões delegadas, propriedades por versão, workloads/horários e segurança operacional da empresa. Nenhum host/guest real foi consultado, nenhum failover/migração executado e nenhum restore validado neste trabalho.
