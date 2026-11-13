# Validação e aceite — AD Health Report 1.1.0

Fonte validada: c8d0f20c276ee82abce9e16f5575c9a6221db55a. [GitHub Actions](https://github.com/fmodel7/scripts/actions/runs/43465971682). Windows PowerShell 5.1 e PowerShell 7/Linux passaram com 985 verificações cada; PowerShell 7/Windows passou com 981. Todos executaram 15 fluxos sintéticos completos. Os quatro testes de processo nativo usam um executável C# inofensivo no 5.1 e shell no Linux; são omitidos no 7/Windows. Nenhum dcdiag real foi executado.

```powershell
powershell.exe -NoProfile -File .	ests\Test-AdHealth.ps1
```

Também pode usar pwsh na suíte, mas a entrada operacional exige Windows PowerShell 5.1 de 64 bits/RSAT. Os testes extraem funções por AST, substituem consultas AD/CIM/nativas e criam arquivos temporários; não executam a entrada operacional nem acessam um domínio. Não faça dot-sourcing dos testes em uma sessão administrativa de trabalho.

Os 15 fluxos cobrem coleta padrão e sem achados, erro de leitura de usuários, exclusões intencionais, floresta completa e domínio filho indisponível, diagnósticos opcionais, falha CIM, timeout/erro nativo, schema inacessível, grupo privilegiado ausente, achados de replicação, WhatIf e bootstrap indisponível. Verificações adicionais cobrem datas, schema, OS desconhecido, DN com vírgula escapada, CSV Unicode/fórmulas/aspas/quebras de linha, cabeçalhos vazios, cap do HTML, dados maliciosos, CSP e manifestos de hash. O verificador de JSON foi ajustado para a diferença de enumeração de arrays do PowerShell 5.1.

O renderer foi testado em Chromium/Playwright com dados fictícios, nas larguras 1440 e 390 px: busca, navegação, expansão, limites, codificação de dados e ausência de requisições externas/erros JavaScript. Veja RENDERER-TESTS.json. O teste de volume do renderer usa referências repetidas à mesma linha sintética; não é benchmark de uma floresta real ou de coleta LDAP.

## Limites e aceite

Não houve consulta AD, CIM remoto ou dcdiag real. Não se comprova integração RSAT, permissões, topologia, replicação atual ou escala real de produção. Artifacts de CI guardam runtime, hash e logs com retenção de 30 dias. EVIDENCE.json preserva a identificação do código e os limites.

1. Usar laboratório e conta autorizados; revisar escopo Domain antes de Forest.
2. Comparar amostras com consoles AD e consultas Microsoft, inclusive null/zero e grupos diretos.
3. Testar permissão negada/domínio indisponível: resultado deve mostrar Partial e erros, nunca inventário completo.
4. Conferir CSV/JSON, codificação, hashes, cap do HTML e dados sensíveis.
5. Aprovar direitos/carga antes de habilitar CIM/dcdiag e examinar saídas nativas no idioma local.
6. Medir tempo/RAM em volume representativo; PageSize não limita o total de objetos ou a memória de JSON.
7. Registrar aceite técnico. Achados exigem análise humana; não são autorização para remediar automaticamente.

[Manual](MANUAL.pt-BR.md) · [Evidências](EVIDENCE.json)

## Suíte operacional 1.1

```powershell
powershell.exe -NoProfile -File .	ests\Test-AdOperations.ps1
```

353 verificações e 10 fluxos operacionais adicionais por ambiente. Com a regressão, são 25 cenários e 1338 verificações em Windows PowerShell 5.1/Linux ou 1334 em PowerShell 7/Windows. Cobrem FullAssessment, thresholds, DNS/ICMP bloqueado sem gate, boot/memória, mountpoints/registro negado, volumes ocultos, offsets negativos e parsing desconhecido, eventos vazios/truncados/negados, dashboard e duração real. Os adaptadores de rede/AD/CIM/eventos/horário são sintéticos; nenhuma chamada remota real ocorreu.

Aceite adicional: revisar mapeamento de volumes em NTDS/SYSVOL reais, comparar amostras de horário com referência aprovada, conferir relógio do coletor, testar direitos CIM/registro/Event Log e validar limites de eventos/carga. Navegador validado com exemplo completo fictício de 30 CSVs em RENDERER-TESTS.json.
