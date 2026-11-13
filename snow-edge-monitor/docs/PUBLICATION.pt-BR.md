# Publicação autorizada no repositório Scripts FMODEL

Em 13 de novembro de 2026, o proprietário autorizou a publicação das fontes e escolheu `fmodel7/scripts`, na pasta `snow-edge-monitor` da raiz. Essa escolha explícita prevalece sobre a convenção geral de colocar ferramentas sob `scripts/`.

A publicação usa uma branch separada, `refactor/snow-edge-monitor`, e pull request, conforme o fluxo de contribuição do repositório. O conteúdo existente é mantido; o catálogo recebe um link para a ferramenta e o changelog registra a adição. A publicação de fontes não representa validação operacional em Windows nem disponibilização de um `.exe` já aprovado.

## Conteúdo e documentação

Incluídos: aplicação modular, configuração de exemplo, dependências, testes com dados fictícios, referência histórica sanitizada, README em inglês, guia de objetivos e funcionamento em inglês e português, operação, arquitetura e checklist Windows.

O original recebido permanece fora do Git e não integra a publicação. Não são enviados configuração local, cookies, tokens, perfil do navegador, captura corporativa ou incidentes reais. O relatório de revisão inicial permanece como registro do que foi inspecionado antes da autorização.

## Adaptação ao repositório compartilhado

Os workflows ativos ficam na `.github/workflows` da raiz, com nomes exclusivos e execução dentro de `snow-edge-monitor`. O empacotamento aponta para o diretório de distribuição desse projeto. Não há substituição dos workflows de outras ferramentas.

O auditor de publicação examina a árvore e o histórico deste projeto, sem incluir arquivos de ferramentas não relacionadas. Quatro testes adicionais criam repositórios Git inteiramente fictícios para verificar o isolamento da auditoria, sua invocação a partir da raiz e a detecção de configurações locais, inclusive depois de removidas do histórico atual.

## Evidência e limites

A preparação inicial aprovou 44 testes unitários e 18 testes de navegador em Linux. A adaptação ao repositório compartilhado acrescentou quatro testes da auditoria; a suíte completa passou a conter 48 unitários e 18 de navegador. As verificações locais desta publicação são registradas após a execução; resultados do GitHub Actions devem ser consultados separadamente no pull request.

Continuam pendentes os testes manuais de áudio, pop-up, bandeja, Edge e executável no Windows, além da validação do adaptador em uma instância de teste ServiceNow. Nenhuma licença de reutilização foi escolhida automaticamente. A visibilidade pública das fontes não concede, por si só, uma licença de software livre.
