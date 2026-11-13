# SNOW Edge Monitor: objetivos e funcionamento

Este documento explica o problema que a aplicação resolve, o caminho de uma leitura até um alerta e os limites da detecção. O [README em inglês](../README.md) contém os comandos de instalação, configuração, testes e empacotamento. O [guia operacional](OPERATIONS.md) complementa o uso diário.

## 1. Objetivo principal

O SNOW Edge Monitor ajuda uma pessoa que trabalha no Windows a perceber mudanças relevantes na fila de incidentes de um grupo do ServiceNow. Ele abre o Microsoft Edge instalado, permite que o usuário entre normalmente em sua conta e acompanha a lista Classic acessível naquela sessão.

O aviso é local: sirene, janela de alerta e acesso pelo ícone na bandeja. A aplicação observa a lista com as permissões que o usuário já possui. Ela não concede acesso ao ServiceNow nem altera os incidentes.

Um incidente “novo” para o monitor é um número ainda desconhecido na base daquela execução. Isso pode significar que ele acabou de entrar no grupo; não é uma afirmação de que acabou de ser criado no banco do ServiceNow.

## 2. Objetivos específicos e critérios

| Objetivo | Como foi implementado | Como conferir |
| --- | --- | --- |
| Preservar Edge e Playwright | Canal `msedge`, com navegador visível e perfil próprio. | Inicialização em Windows e validação do adaptador. |
| Reutilizar em outras instâncias | Configuração JSON para instância, grupo, estados, intervalos e seletores. | Alterar apenas a configuração local e validar o layout. |
| Alertar apenas estados elegíveis | Comparação do estado lido com `eligible_states`. | Testes de estados elegíveis e inelegíveis. |
| Evitar alertas causados pela navegação | Validar contexto, grupo e total completo antes da detecção. | Testes de filtros, seleção, paginação, iframes e refresh. |
| Manter a interface utilizável | Navegador em thread de trabalho, Tk na thread principal e fila de eventos. | Testes do worker e checklist manual Windows. |
| Facilitar manutenção | Módulos de configuração, navegador, detecção, interface e notificações. | Arquitetura e testes independentes. |
| Permitir revisão pública das fontes | Exemplos fictícios, referência sanitizada e exclusão de arquivos locais. | Auditoria das fontes e do histórico. |

## 3. O que precisa existir antes de iniciar

Use Windows 10/11 com sessão gráfica, Microsoft Edge e Python 3.11 ou superior com Tcl/Tk para executar as fontes. Para a distribuição empacotada, Edge continua sendo necessário.

O usuário deve ter acesso à lista Classic de incidentes e ao grupo configurado. A lista precisa expor número, estado e grupo de atribuição, além dos metadados que identificam o filtro, a primeira linha e o total de registros. Alguns layouts exigirão ajuste dos seletores no arquivo local.

A implementação atual precisa enxergar a lista completa do grupo em uma página. Se o servidor dividir os registros em páginas, a detecção pausa. Não há leitura automática de várias páginas nem integração com Workspace ou listas virtualizadas.

## 4. Configuração local

Copie `config.example.json` para `config.json`, seguindo o README. Os valores fornecidos são fictícios: o domínio de exemplo não é uma instância preparada para uso e o identificador composto por zeros não representa um grupo real.

| Campo | Papel na operação |
| --- | --- |
| `instance_url` | Origem HTTPS da instância, sem caminho, senha ou parâmetros. |
| `assignment_group` | `sys_id` de 32 caracteres do grupo, não seu nome de exibição. |
| `eligible_states` | Valores ou rótulos de estados que podem gerar alerta. |
| `poll_seconds` | Espera entre as iterações de leitura. |
| `refresh_seconds` | Intervalo para solicitar recarregamento da página. |
| `failure_seconds` | Tempo de indisponibilidade antes de registrar um aviso. |
| `confirmation_reads` | Quantidade de leituras válidas consecutivas; mínimo de duas. |
| `page_limit` | Tamanho de página solicitado, sujeito ao limite do servidor. |
| Seletores e aliases de colunas | Adaptação ao DOM da versão Classic utilizada. |
| `siren_enabled` / `popup_enabled` | Ativação independente de áudio e janela de alerta. |

O programa lê `data-value` do estado quando disponível. Caso contrário, usa o texto da célula. Por isso, não presuma que `1` e `2` têm o mesmo significado em todas as instâncias. Confirme a representação usada no seu layout. O filtro do navegador inclui o grupo inteiro; a escolha dos estados que alertam acontece na aplicação.

Alterações na configuração exigem reiniciar a aplicação. As fontes procuram `config.json` no diretório de execução; o executável empacotado procura ao lado do próprio executável. `--config` define um caminho explícito.

## 5. Caminho completo de uma execução

1. A entrada do programa verifica a plataforma e valida a configuração.
2. O painel Tk e o menu da bandeja são criados. O monitor permanece parado até **Start**.
3. A thread de trabalho inicia Playwright e abre o Edge com perfil dedicado.
4. O Edge navega para a lista do grupo. O usuário faz login manualmente quando necessário.
5. O adaptador percorre os frames da aba controlada e procura uma única lista válida.
6. A captura é validada quanto à origem, filtro, cabeçalhos, grupo de cada linha, números e total completo.
7. O detector forma uma base silenciosa ou confirma mudanças em uma base já existente.
8. Mudanças elegíveis confirmadas entram na fila de eventos.
9. A interface recebe os números e aciona áudio e/ou pop-up, conforme configuração.
10. O ciclo aguarda o próximo intervalo. **Stop** solicita encerramento do contexto; **Exit** aguarda a thread e fecha o aplicativo.

Apenas fechar a janela oculta o painel. O programa continua acessível pelo ícone da bandeja. Para encerrar, use **Exit**.

## 6. Quando uma leitura pode ser usada

O navegador não entrega uma captura parcial ao detector como se fosse uma lista vazia. São exigidos:

- Uma única tabela visível compatível por frame e uma única lista válida entre os frames da aba.
- Documento carregado, sem indicador `aria-busy="true"`, e uma leitura de rede quieta após atividade document/XHR/fetch.
- Origem HTTPS e caminho de lista previstos.
- Filtro contendo apenas o grupo configurado, com diretivas de ordenação/`EQ` permitidas.
- Cabeçalhos reconhecíveis e não ambíguos para número, estado e grupo.
- Identificadores de incidentes válidos e únicos, estados preenchidos e sys_id correto em todas as linhas.
- Primeira página e quantidade capturada igual ao total anunciado pela lista.

Colunas de seleção não são tratadas como número ou estado: o mapeamento usa cabeçalhos. Iframes são percorridos, incluindo frames aninhados. O grupo pode ser identificado pelo valor da célula ou pelo sys_id de um link de referência; o nome visível, sozinho, não comprova a identidade.

O adaptador prefere os metadados de GlideList2 e usa seletores configurados como alternativa. APIs e elementos variam entre versões do ServiceNow. A ausência de metadados interrompe a avaliação; ela não autoriza estimar o total.

## 7. Base inicial e memória

A base contém o último estado confirmado de cada número conhecido. Ela existe somente na memória do detector durante a execução.

Ao iniciar, o monitor exige que a mesma lista completa, com os mesmos números e estados, seja observada consecutivamente pelo número de confirmações configurado. Esses registros tornam-se a base sem disparar alertas, mesmo que já estejam em estados elegíveis.

Uma lista realmente vazia pode formar uma base válida quando o total anunciado também é zero. Um tbody temporariamente vazio durante recarregamento, com total não zero, é uma leitura inválida.

O contexto inclui a URL do frame, o filtro efetivo e os cabeçalhos, representados por um resumo SHA-256. Se um novo contexto aceito for observado, o detector forma outra base silenciosa. Filtros fora do escopo configurado são rejeitados antes dessa etapa.

Parar e iniciar novamente cria outra base. Não existe recuperação de alertas ocorridos enquanto o monitor esteve parado.

## 8. Regras de alerta

| Situação após a formação da base | Resultado após confirmação |
| --- | --- |
| Número ainda desconhecido aparece em estado elegível | Alerta. |
| Número desconhecido aparece em estado inelegível | Apenas memoriza o estado. |
| Incidente conhecido passa de inelegível para elegível | Alerta. |
| Incidente conhecido passa entre dois estados elegíveis | Atualiza a memória sem novo alerta. |
| Incidente passa para estado inelegível | Atualiza a memória sem alerta. |
| Incidente anteriormente confirmado como inelegível retorna à elegibilidade | Pode alertar novamente. |
| Linha desaparece e volta com o mesmo estado conhecido | Não alerta apenas pelo reaparecimento. |
| Leitura parcial, carregando, sem sessão ou com grupo/filtro inválido | Suspende a detecção. |

Cada mudança precisa aparecer em leituras válidas consecutivas. Com duas confirmações, a primeira leitura cria um candidato e a segunda confirma. Se houver uma falha entre elas, o candidato é descartado e precisa ser confirmado novamente. A confirmação de um incidente não depende de todas as outras linhas permanecerem iguais depois de a base estar formada.

### Exemplo inteiramente fictício

Considere `1` e `2` elegíveis e `6` inelegível:

1. `INC0000001` em `6` aparece em duas leituras iguais: forma-se a base sem alerta.
2. `INC0000004` em `1` aparece uma vez: candidato.
3. O mesmo número e estado aparecem na leitura seguinte: um alerta.
4. A lista permanece igual: nenhum alerta repetido.
5. `INC0000001` muda para `2` e permanece assim por duas leituras válidas: outro alerta.
6. `INC0000004` muda de `1` para `2`: não há novo alerta, pois ambos os estados são elegíveis.

## 9. Filtros, paginação e refresh

No refresh agendado, os candidatos ainda não confirmados são descartados antes de solicitar a recarga. A base já confirmada é mantida quando o contexto aceito continua o mesmo. Assim, o retorno das linhas após refresh não é tratado automaticamente como a chegada de vários incidentes.

Na paginação, a diferença entre “linha antes invisível” e “incidente que acabou de entrar no grupo” é ambígua. Esta versão evita essa ambiguidade exigindo uma lista inteira em uma página. Aumentar `page_limit` só ajuda quando o servidor aceita o tamanho solicitado. Não altere artificialmente o total para contornar essa proteção.

Ordenação ou layout que mudem o contexto aceito levam à formação de nova base. Filtros adicionais, como mostrar apenas um estado, são recusados porque impedem acompanhar o conjunto do grupo e suas transições com o contrato atual.

## 10. Notificações e controles

A sirene gerada é um WAV de três segundos reproduzido de forma assíncrona. O pop-up fica em primeiro plano e reúne números pendentes até o reconhecimento. **Acknowledge** fecha a janela, limpa os pendentes e interrompe o som em reprodução.

**Test alert** usa `INC9999999`, um número fictício, para testar o caminho visual e sonoro. Ele não consulta o ServiceNow e não comprova que a extração da lista funciona.

O menu da bandeja oferece **Show**, **Start**, **Stop**, **Test alert** e **Exit**. O painel mostra a disponibilidade e a contagem da última captura aceita. Se áudio e pop-up forem desabilitados, esses canais de aviso de incidentes ficam desativados.

## 11. Privacidade e arquivos locais

Configuração local e perfil não fazem parte do repositório. O perfil em `%LOCALAPPDATA%\SNOWEdgeMonitor\edge-profile` mantém os dados normais de sessão do Edge e pode conter cookies e autenticação. Ele deve permanecer no computador do usuário. O WAV é gerado no mesmo diretório de dados do aplicativo.

A extração usa somente as células necessárias de número, estado e grupo. Campos adicionais, como responsável e descrição, são esvaziados antes de saírem do JavaScript. Os logs da aplicação mostram mensagens genéricas e tipos de erro, sem URL da instância, valores da configuração ou números dos incidentes. Os números aparecem na memória e no pop-up.

O original recebido foi preservado fora do Git. Apenas a cópia histórica sanitizada integra as fontes. O relatório inicial explica as duas ocorrências de domínio corporativo removidas, sem reproduzir o valor.

## 12. Organização para manutenção

| Arquivo | Responsabilidade |
| --- | --- |
| `config.py` | Ler/validar parâmetros e definir os diretórios locais. |
| `models.py` | Representar incidentes e snapshots imutáveis. |
| `browser.py` / `extract.js` | Controlar Edge, ler o DOM e validar o contrato da captura. |
| `monitor.py` | Aplicar as regras determinísticas de base e confirmação. |
| `worker.py` | Coordenar leituras, refresh, indisponibilidade e encerramento. |
| `ui.py` | Manter Tk na thread principal e processar comandos/eventos. |
| `notifications.py` | Gerar WAV, mostrar/reconhecer pop-up e desenhar ícone. |
| `tests/` | Exercitar lógica e HTML fictícios, sem ambiente corporativo. |
| `tools/audit_release.py` | Revisar heurísticamente arquivos versionados e histórico. |

Uma alteração de layout do ServiceNow deve ser resolvida no adaptador e acompanhada de fixture fictícia. Uma alteração de regra de negócio deve ser validada no detector, sem depender de um navegador real. Não remova as validações de completude ou grupo para fazer uma tabela incompatível parecer válida.

## 13. Limites e evidência disponível

As verificações iniciais aprovaram 44 testes unitários e 18 testes de navegador em Linux com HTML fictício. O build PyInstaller de verificação também foi feito em Linux. Isso não equivale à execução de um `.exe` Windows nem à validação de áudio, pop-up, bandeja, Edge Windows ou uma instância real.

A latência depende de leitura, carga da página, refresh e confirmações. Mudanças que existam somente entre leituras, durante indisponibilidade ou durante a formação da base podem ser perdidas. Atividade contínua de rede pode impedir leituras aceitas. A aplicação não oferece garantia de entrega de eventos nem substitui alertas oficiais do processo de atendimento.

Consulte o [relatório de revisão](REVIEW_REPORT.pt-BR.md), a [arquitetura](ARCHITECTURE.md) e o [checklist Windows](WINDOWS_VALIDATION.md) para distinguir o que já foi automatizado do que precisa ser verificado no ambiente de uso.
