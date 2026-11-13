# FMODEL AD Health Report 1.1.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Revisão com assistência de Akira (ChatGPT)

Inventário e avaliação assistida do Active Directory, com **relatório HTML interativo offline, CSV e JSON**. O script faz consultas e grava relatórios locais; não corrige, remove, desabilita ou modifica objetos do domínio.

[English](README.en-US.md) · [Manual completo PT-BR](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf) · [Evidências de validação](docs/EVIDENCE.json)

## Coleta unificada ampliada — 1.1

Para reunir inventário e verificações operacionais em um único PS1:

```powershell
.\Export-ADHealthReport.ps1 -FullAssessment
```

FullAssessment habilita DNS A/AAAA/SRV, ICMP informativo, boot/memória, volumes e caminhos NTDS/SYSVOL, amostras/evidências W32Time, eventos recentes, serviços e os 17 testes selecionados do perfil estendido DCDiag. A coleta padrão continua mais leve. FullAssessment amplia a profundidade; o escopo continua Domain. Para todos os domínios autorizados, acrescente -Scope Forest.

O HTML inclui uma tabela consolidada por DC, com métricas e estados, e todos os conjuntos têm CSV. Dados desconhecidos e acessos negados não viram sucesso. Eventos têm janela/limite explícitos; os CSVs preservam tudo que foi obtido dentro desses limites. Consulte os novos parâmetros no manual antes de habilitar a coleta completa em produção.

## O que você recebe

- Inventário de floresta/domínios, DCs, OUs, computadores, usuários e grupos.
- Papéis FSMO, versão de schema, políticas de senha, trusts e membros diretos de grupos sensíveis selecionados por SID.
- Dados estruturados de replicação, cobertura das consultas, erros e achados que precisam de revisão.
- HTML com busca local; CSV completo por conjunto e JSON para análise técnica.
- Coletas opcionais de serviços por CIM/WSMan e diagnósticos nativos com lista restrita de testes.

**Concluir a coleta não comprova que o AD está saudável ou em conformidade.** Permissões, escopo e testes opcionais limitam a cobertura. Ausência de dado não é automaticamente uma contagem zero ou um resultado positivo.

## Baixar

[Baixar AD-Health-Report-v1.1.0.zip](AD-Health-Report-v1.1.0.zip?raw=true). Se abrir a página do arquivo, clique em **Download raw file**, depois **Extrair Tudo**.

Alternativa: no repositório, **Code → Download ZIP → Extrair Tudo → scripts/ad-health-report**. Não precisa instalar Git. Abra a pasta completa extraída, não a visualização do ZIP.

## Testar antes, sem domínio

Na pasta da ferramenta, em uma sessão normal do PowerShell:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
```

O teste também pode ser executado com `pwsh`. Usa dados e adaptadores sintéticos; não valida uma floresta real. Não exige RSAT, domínio ou execução como Administrador. Consulte [EVIDENCE.json](docs/EVIDENCE.json) para ambientes, resultados e limites efetivamente verificados.

## Executar a coleta real

Use **Windows PowerShell 5.1 de 64 bits (`powershell.exe`)**, módulo **ActiveDirectory/RSAT** disponível e uma conta com as permissões de leitura necessárias no ambiente. Administrador elevado não é exigido por padrão; alguns diagnósticos opcionais podem precisar de acesso adicional.

Na pasta extraída, execute:

```powershell
.\Export-ADHealthReport.ps1
```

Isso coleta o **domínio selecionado**, com os padrões implementados. Para escolher explicitamente um DC:

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com
```

Substitua `dc01.example.com` por um servidor real autorizado. O script fixa o contexto ao DC identificado por RootDSE; não usa o endereço de exemplo como um servidor padrão.

## Ampliar a coleta quando necessário

Coletar os domínios da floresta:

```powershell
.\Export-ADHealthReport.ps1 -Scope Forest
```

Acrescentar serviços e diagnósticos opcionais:

```powershell
.\Export-ADHealthReport.ps1 -IncludeServiceChecks -IncludeDcDiagnostics
```

Essas opções fazem mais consultas e podem exigir permissões e conectividade diferentes. Não habilitam WinRM nem alteram firewall ou serviços. Nenhum teste é condicionado a um ping bem-sucedido; falhas de acesso/timeout precisam ser interpretadas como limitações da consulta, não prova isolada de que um DC caiu.

## Abrir HTML e CSV

A saída padrão fica em uma pasta única sob `%LOCALAPPDATA%\FMODEL\ADHealth`, na conta que executou o processo. Abra **Report.html** pelo caminho exibido no console.

`MaxHtmlRows` limita apenas a apresentação do HTML. Os CSV/JSON mantêm os dados coletados, inclusive quando a tabela no navegador é reduzida. Isso não recupera consultas que falharam ou foram puladas: confira `coverage.csv` e `collectionerrors.csv`.

Os CSV usam vírgula e UTF-8 com BOM. No Excel em PT-BR, se necessário use **Dados → De Texto/CSV**, selecione UTF-8 e delimitador vírgula. Células potencialmente interpretadas como fórmulas recebem apóstrofo de proteção; o JSON não recebe essa neutralização de planilha.

## Documentação e limites

O [manual PT-BR](docs/MANUAL.pt-BR.md) e o [manual EN-US](docs/MANUAL.en-US.md) explicam todos os parâmetros, conjuntos, estados, permissões, regras de achados, limitações e aceitação em laboratório. Há versões em PDF na pasta `docs`.

O relatório não lê senhas, hashes, segredos LAPS ou chaves de gMSA. Também não é auditoria completa de ACLs, privilégios efetivos, GPO, patches ou segurança do AD. Dados como nomes, SIDs, grupos e topologia são sensíveis: **não publique relatórios reais no GitHub**.

Não foi validada uma floresta de produção nesta entrega. Os testes automatizados e suas evidências não substituem o aceite no ambiente autorizado.

## Prévia e validação

Após extrair o ZIP, abra [examples/SYNTHETIC/Report.html](examples/SYNTHETIC/Report.html) para explorar dados fictícios sem domínio. O exemplo inclui os 30 CSVs e JSON correspondentes; não é evidência de ambiente real.

[CI](https://github.com/fmodel7/scripts/actions/runs/43465971682) · [Testing](docs/TESTING.pt-BR.md) · [Internal reference](docs/INTERNALS.pt-BR.md)
