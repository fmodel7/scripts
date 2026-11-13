# Relatório de revisão — SNOW Edge Monitor

Data: 13 de novembro de 2026. Trabalho local, sem publicação ou acesso a uma instância corporativa.

## Resultado e organização

O monólito foi refatorado em uma aplicação Windows com módulos separados para configurações (`config.py`), modelos (`models.py`), navegador e extração (`browser.py`, `extract.js`), detecção (`monitor.py`), agendamento (`worker.py`), interface (`ui.py`) e notificações (`notifications.py`). Foram mantidos Microsoft Edge via Playwright, atualização configurável, detecção de incidentes, sirene WAV, pop-up e comandos na bandeja do Windows.

O usuário configura localmente a origem HTTPS da instância, o sys_id do grupo, os estados elegíveis, os intervalos e os seletores/nomes de colunas. A autenticação permanece manual no Edge, com perfil dedicado fora da árvore de fontes. O programa não solicita senha nem exporta cookies ou tokens.

Foram incluídos README em inglês, requirements.txt, requirements-dev.txt, .gitignore, configuração de exemplo, metadados de pacote Python, arquitetura, checklist Windows e workflows de testes/empacotamento. Os workflows foram preparados; não foram acionados no GitHub. Nenhuma licença foi escolhida em nome do proprietário.

## Controle de falsos alertas

A leitura identifica colunas por campo/cabeçalho, tolera colunas de seleção e percorre iframes. A captura aceita apenas a origem configurada, o filtro do grupo esperado, identificadores de grupo verificáveis, números únicos e uma lista completa cuja contagem de linhas coincide com o total anunciado. Valores dos estados são avaliados localmente.

O monitor estabelece uma base silenciosa após leituras completas idênticas; uma mudança precisa de pelo menos duas confirmações consecutivas. Um incidente novo elegível ou uma transição confirmada de inelegível para elegível pode alertar. Incidentes elegíveis já existentes na base e mudanças entre estados elegíveis não alertam. Sair e retornar à elegibilidade pode gerar outro alerta.

Mudanças no contexto válido estabelecem nova base silenciosa. Refresh e leituras indisponíveis/incompletas eliminam candidatos pendentes, preservando a base confirmada do mesmo contexto. Reaparecimento de uma linha conhecida, sozinho, não gera alerta. Requisições document/XHR/fetch em andamento, frames destacados, carga incompleta e ambiguidades suspendem a avaliação.

Decisão conservadora: a aplicação não agrega páginas. Se a primeira página não contiver a lista inteira do grupo, a detecção pausa e apresenta aviso após o limite configurado. Isso impede alertas por incidentes antigos que entram na janela de paginação. `page_limit` é uma solicitação; o servidor pode limitar o tamanho. Eventos que existam apenas durante indisponibilidade, entre leituras ou durante formação de base podem não ser notificados. A adaptação DOM exige validação na versão de ServiceNow utilizada.

## Testes e verificações executados

Ambiente: Linux, Python 3.12.14, Playwright 1.62.0, Pillow 12.3.0, PyInstaller 6.22.3 e pystray 0.19.5 instalado para inspeção/empacotamento. A suíte de navegador utilizou `/usr/bin/chromium` em modo headless, com todas as requisições atendidas por HTML fictício local.

| Verificação | Resultado |
| --- | --- |
| `python -m unittest discover -s tests -v` | 44 testes aprovados. |
| `TEST_CHROMIUM_EXECUTABLE=/usr/bin/chromium python -m unittest discover -s tests -p 'browser_*.py' -v` | 18 testes de navegador aprovados. |
| `python -m compileall -q snow_edge_monitor tests run_monitor.py` | Aprovado. |
| CLI `--help` e recusa da interface em plataforma diferente de Windows | Comportamento esperado; a recusa retorna código 2. |
| Criação de wheel com pip e inspeção do conteúdo | Aprovada; `extract.js` incluído. |
| PyInstaller `--onedir` no Linux, inclusão de `extract.js` e driver Playwright, execução de `--help` | Aprovado como verificação de empacotamento Linux. Não é um executável Windows. |
| `git diff --check` | Sem erros de whitespace. |
| Auditoria de arquivos versionados e versões históricas | Sem achados adicionais; domínios e credenciais fictícios dos testes negativos são intencionais. |

Os 62 testes cobrem base inicial e vazia, novos incidentes, diferentes estados, confirmação por incidente, retorno à elegibilidade, leituras interrompidas, refresh, desaparecimento/reaparecimento, mudança de contexto, paginação, validação de origem/grupo, colunas extras/reordenadas, iframes, ambiguidade, referência de grupo, metadados GlideList2, requisições pendentes, privacidade da captura, encerramento do worker e geração de WAV. Dois testes de navegador combinam extração real e detecção até o evento esperado.

Não foram executados: interface Tk no Windows, reprodução efetiva de áudio, pop-up/tray no Windows, execução com Edge Windows, build de `.exe` Windows, autenticação real ou testes em ServiceNow real. `docs/WINDOWS_VALIDATION.md` detalha a validação manual ainda pendente. Não existe alegação de aprovação operacional no Windows.

## Dados potencialmente sensíveis encontrados

No arquivo original, havia um domínio corporativo com duas ocorrências: a constante da URL da instância (linha 18) e uma condição de localização de aba (linha 88). O valor não é reproduzido neste relatório nem no material versionado. Ambas as ocorrências foram substituídas por `example.service-now.com` na referência sanitizada; a aplicação nova lê apenas a configuração local.

A inspeção do arquivo fornecido não identificou credenciais, tokens, cookies incorporados, nomes de funcionários ou incidentes reais. O identificador de teste presente era fictício. Os caminhos originais usavam `Path.home()` e nomes genéricos de perfil/áudio, sem nome de usuário explícito. Essa revisão é baseada no conteúdo recebido; não garante a inexistência de toda informação sensível possível.

A nova extração transmite apenas número, estado e identificador do grupo, além de metadados mínimos da lista. Células adicionais, como responsável e descrição, recebem valores vazios antes de sair do JavaScript. Logs da aplicação não incluem valores da configuração, URLs, números de incidentes ou texto de exceções. Os números aparecem no pop-up e na memória durante a execução.

Arquivos locais de configuração e perfis são excluídos pelo .gitignore. O perfil criado durante o uso contém sessões/cookies reais do usuário, permanece em `%LOCALAPPDATA%\SNOWEdgeMonitor\edge-profile` e não deve integrar um repositório ou distribuição. Nenhum perfil corporativo foi utilizado neste trabalho.

## Preservação, branches e publicação

A cópia original recebida permanece intacta na área privada de trabalho, fora do repositório e dos pacotes de revisão. SHA-256 do original:

```text
23490a337497057aa1e04f868dce1d926a33bad024a973652ad74143eaf8f515
```

A branch `main` contém apenas a referência histórica sanitizada em `reference/`. A refatoração está na branch local `refactor/generic-windows-app`. O original com domínio corporativo nunca foi adicionado ao histórico Git. O bundle de revisão preserva as duas branches; o ZIP de fontes não inclui `.git`, configurações locais, perfil de navegador, builds ou a cópia original privada.

O utilitário `python tools/audit_release.py` revisa os arquivos versionados e blobs das branches locais, reportando nomes de arquivos e categorias sem imprimir os valores encontrados. É uma verificação heurística que complementa a revisão manual.

Não foi configurado remote Git, criado repositório no GitHub, enviado push, aberta PR, publicado site ou criada release. Publicação depende de aprovação explícita do proprietário, conforme solicitado.
