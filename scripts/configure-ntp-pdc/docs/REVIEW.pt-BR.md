# Revisão do código recebido

Configure NTP PDC 1.0.0 · 23/10/2026 · F. Model / FMODEL

O objetivo original foi preservado: organizar o horário do AD a partir do PDC adequado. O script recebido não tinha versão explícita; 1.0.0 identifica esta primeira entrega revisada na biblioteca. A revisão usa referências Microsoft e controles próprios, sem alegar conformidade universal ou certificação.

| Ponto observado no original | Mudança na revisão |
|---|---|
| Usava GetCurrentDomain, ligado ao contexto do usuário. | Usa o domínio do computador e valida domínio/raiz/FQDN. |
| Qualquer PDC de domínio era aceito. | Apply exige o PDC do domínio raiz da floresta. |
| Host local era interpolado numa expressão regular. | Comparação explícita de nomes completos, sem regex interpolada. |
| Peers brasileiros e IPs em comentários eram uma escolha fixa. | Não há provider padrão; peers aprovados são parâmetro, sem IP presumido de um DNS antigo. |
| Comandos nativos não tinham códigos de saída verificados. | Processo com stdout/stderr, exit code e timeout; erro interrompe a sequência. |
| Aplicava imediatamente ao executar. | Audit padrão; Apply, ShouldProcess, WhatIf e confirmação de alto impacto. |
| Não conferia política administrada. | Presença do ramo W32Time de políticas bloqueia aplicação local, inclusive se vazio. |
| Não salvava estado antes das alterações. | Snapshot, exportação nativa, relatório anterior e diário antes de cada operação. |
| Anunciava /reliable:yes sem discutir o contexto. | AnnounceFlags automático 10 por padrão e Always 5 opcional, explicitando limites. |
| Ausência de Local CMOS Clock virava sucesso. | Fonte pedida, status reconhecido, idade, leap/stratum, configuração e exit codes participam da decisão. |
| Esperas fixas de três/cinco segundos. | Serviço aguardado em Running e polling com relógio monotônico. |
| Reinício com Force. | Sem forçar parada de dependentes. |
| Fabricante Microsoft podia ser tratado genericamente como VM. | Heurística por modelo/fabricantes reconhecidos; continua sendo indício, não prova. |
| Orientação geral para desligar sincronização do host. | Nenhuma integração é alterada automaticamente; documentos distinguem plataformas/cenários. |
| /monitor podia consultar amplamente o domínio. | Diagnóstico local e stripchart opcional dos peers pedidos. |
| Capturava erro sem propagar um resultado confiável para automação. | Estados documentados e exit codes 0/1/2. |
| Não havia testes e evidência separada. | Testes com mocks, processos CLI isolados e CI 5.1/7 em Windows/Linux. |
| Não havia documentação operacional individual. | README e manual completos PT-BR/EN-US, exemplos HTML e aceitação. |

## Decisões próprias do projeto

A opção de Audit padrão, recusa do ramo de política vazio, lock local, orçamento de timeout, limite de dez peers, saída HTML e journal são controles de engenharia deste projeto. Não são todos requisitos literais de uma receita Microsoft.

AnnounceFlags=10 não significa que todo ambiente deva usar a mesma política. Flags de peer 0x8/0xA são outro campo. Os limites de correção de fase e a integração VM permanecem sem alteração; dependem do ambiente.

Nenhum script força que um peer arbitrário seja confiável, autentica NTP externo ou mede precisão absoluta. DNS resolvido, stratum aceitável e status recente ainda são evidências parciais. Os relatórios deixam isso explícito.

## Limites não resolvidos automaticamente

Não há transação entre AD/Registro/serviço; transferência FSMO/GPO pode ocorrer entre verificações. O lock não impede ferramentas externas. Não há rollback do relógio, restauração de AD ou recuperação de VM. Backup local não é imutável, criptografado ou teste de restauração. Mudanças futuras de API/saída/idioma podem exigir revisão do parser.

A primeira validação CI detectou diferença de resolução do enum de serviço no Windows PowerShell 5.1. O código foi corrigido para usar a conversão do parâmetro do método WaitForStatus. A evidência final em EVIDENCE.json identifica a fonte revisada; não deve ser confundida com uma execução real em um domínio.

## Referências e rastreabilidade

[Manual](MANUAL.pt-BR.md) · [Evidência](EVIDENCE.json) · [Aceitação no ambiente](ACCEPTANCE.pt-BR.md). O hash do original foi registrado na evidência; o arquivo original inseguro não é publicado como alternativa operacional.
