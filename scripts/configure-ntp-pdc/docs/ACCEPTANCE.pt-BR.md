# Aceitação em laboratório e no ambiente autorizado

Os testes automatizados não substituem esta aceitação. Registrar evidência sem publicar dados reais no repositório público.

## Antes de aplicar

1. Identificar domínio raiz, PDC atual, OS, runtime e operador autorizado por uma fonte independente.
2. Confirmar contexto de execução: token elevado, cópia completa, versão/hashes e pasta de saída local protegida conforme a política.
3. Revisar GPO/MDM/automação que gerenciam W32Time. Se houver ramo de política, usar o mecanismo administrado; não forçar remoção.
4. Selecionar fontes aprovadas, conferir uso permitido, diversidade real e adequação geográfica/latência.
5. Medir/descrever o deslocamento atual por ferramentas autorizadas. Conferir MaxPosPhaseCorrection/MaxNegPhaseCorrection e o risco de saltos de relógio. O script não valida precisão por medição independente.
6. Revisar DNS, firewall/NAT UDP 123, inclusive origem 123 do serviço. Um stripchart isolado não comprova esse caminho.
7. Para VM, revisar host, provedor convidado, reinício, suspensão/restore e migração. Nenhuma integração será alterada pelo script.
8. Definir janela, responsáveis, acesso de recuperação e procedimento para alteração parcial. Backup .reg não desfaz hora.

## Exercícios recomendados

- Executar as três suítes offline em processos separados; guardar resultados.
- Fazer Audit e conferir que não houve alteração pelo script.
- Fazer Apply -WhatIf com peers aprovados; confirmar ausência de mudanças e de exportação .reg.
- Em uma floresta de teste isolada e apropriada, confirmar bloqueio em membro, DC comum e PDC de domínio filho.
- Conferir bloqueio com política/serviço desabilitado, sem tentar burlar os controles.
- Revisar snapshot/exportação e relatórios antes de uma aplicação real autorizada.
- Aplicar no PDC raiz de teste; conferir os cinco valores, estado do serviço, fonte, leap/stratum e idade por ferramentas independentes.
- Observar consumidores/DCs e autenticação conforme os procedimentos da equipe. Não limitar a aceitação ao estado AppliedVerified.
- Verificar idioma local. Saída não reconhecida deve permanecer sem confirmação, mesmo se aparentemente saudável.
- Avaliar persistência após reinício/mudança de função no laboratório, com políticas e topologia corretas.

## Critério de encerramento

Registrar versão, hashes, ambiente, fontes, achados, pendências e decisão do responsável. Se houver timeout ou estado parcial, investigar antes de repetir; não induzir falhas de rede, disco ou FSMO em produção só para testar o script.

Casos de falha são reproduzidos pelos mocks. Testes adicionais reais precisam de ambiente e procedimento próprios, sem comprometer o AD operacional. [Manual](MANUAL.pt-BR.md).
