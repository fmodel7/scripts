# Validação — AD Health Report 1.2.0

FMODEL · F. Model · fmodel@fmodel.com.br

O código operacional passou no [CI](https://github.com/fmodel7/scripts/actions/runs/43498148487), commit `7d037054f9917e465610c4ba845d14376323fd0d`. Os arquivos operacionais entregues correspondem a esse conteúdo. EVIDENCE.json e MANIFEST-SHA256.txt registram os hashes.

| Ambiente | Regressão | Operacional | Abrangente | Cenários completos |
|---|---|---|---|---|
| Windows PowerShell 5.1 | 1843 | 650 | 699 | 36 |
| PowerShell 7 Windows | 1839 | 650 | 699 | 36 |
| PowerShell 7 Linux | 1843 | 650 | 699 | 36 |

As três colunas de testes são asserções. Quatro verificações auxiliares de processos nativos são omitidas em PowerShell 7 Windows. São 36 cenários por ambiente, não 36 DCs reais. Não há certificação de conformidade.

## Executar sem domínio

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

Também pode usar pwsh. As suítes carregam funções por AST, sem executar a entrada operacional. Não exigem domínio, RSAT ou Administrador. Adaptadores fictícios substituem AD, DNS, CIM/remoting, GPO, eventos e diagnósticos. Arquivos locais e processos auxiliares inofensivos exercitam as fronteiras locais.

## Cobertura

- Inventário, domínios/floresta, descoberta, SIDs, skips, atributos ausentes, replicação, achados e códigos de saída.
- ICMP sem bloquear outros coletores, DNS, volumes/mount points/NTDS, memória/boot, offsets positivos/negativos, eventos limitados e cobertura/erros.
- Flags UAC, SPNs/UPNs e proprietários em dois domínios, GPO negada/com identidade divergente, GPO sem extensão com versões não zero, links e flags, RSoP/direitos por SID.
- DNS administrativo, inventário do host/software/QFE, evidências de backup e comparação de valores de registro com Unknown/NotConfigured distintos de sucesso.
- XML com namespaces/nós repetidos, DTD/XXE bloqueado, XML inválido/excessivo e limite de normalização.
- Travessia SYSVOL usa arquivos fictícios locais, sem conectar a share; limites e truncamento são exercitados. Jobs são adaptados para conferir propriedade/limpeza, sem parar jobs alheios.
- Arrays JSON em Windows PowerShell 5.1, renderização offline, nomes/caminhos permitidos, cópia de evidências por manifesto, hash alterado e ZIP fora da pasta original.
- Todos os 63 CSVs, neutralização de fórmulas, UTF-8, JSON e codificação HTML de nomes/mensagens com marcação.

Os módulos reais GroupPolicy/DnsServer e endpoints de remoting não foram acessados. O worker remoto foi revisado estaticamente, sem sessão real de remoting. Os testes não demonstram compatibilidade dos módulos instalados/permissões do seu ambiente.

## HTML e pacote

O exemplo SYNTHETIC reúne dados fictícios das 63 tabelas em dois domínios/DCs. O navegador verifica busca, expansão, links CSV, codificação, ausência de requisições externas/diálogos/erros JS e layout móvel; veja RENDERER-TESTS.json. Links locais, PDFs, manifesto recursivo e conteúdo do ZIP são conferidos no empacotamento.

## Aceitação em laboratório autorizado

1. Verifique Windows PowerShell 5.1 x64, módulos necessários e uma conta de leitura aprovada. Comece pelo inventário básico.
2. Teste opções individualmente e valide direitos/protocolos ADWS/LDAP, SMB, WSMan/remoting, eventos/RPC e DNS. A ferramenta não habilita esses recursos.
3. Compare amostras com ADUC/ADAC, GPMC, Event Viewer, DNS e solução de backup. Confira domínio/DC, origem e timestamps.
4. Exercite vários domínios, RODC/DNS separado se disponíveis, idiomas PT-BR/EN-US, acesso negado e um coletor indisponível. Confira tratamento de resultados parciais.
5. Revise a baseline aprovada por SO/papel e valores diferentes/ausentes/tipos inesperados. O perfil fornecido é parcial, não SCT completo.
6. Ajuste limites e revise Coverage/GPOCoverage/DirectoryCoverage/EventLogCoverage, duração e truncamentos.
7. Abra HTML/CSV, confira hashes, recrie offline e gere ZIP. Restrinja acesso aos dados reais e não os publique no GitHub.

Não foi usado um AD real nesta entrega. Transporte, permissões e versões dos módulos contra DCs reais precisam de aceitação no laboratório.
