# Referência interna — 1.0.0

As funções são detalhes internos, não uma API pública. Execute o PS1 como arquivo; os testes extraem funções somente em processos de teste.

## Get-AdField

Lê propriedade opcional sem converter ausência em falso/zero. [Source](../Export-ADHealthReport.ps1#L38).

## Convert-AdDate

Normaliza datas UTC; ausentes/inválidas ficam vazias. [Source](../Export-ADHealthReport.ps1#L44).

## Convert-AdSid

Normaliza SID em texto. [Source](../Export-ADHealthReport.ps1#L49).

## Get-AdParentDn

Obtém DN pai respeitando vírgulas escapadas. [Source](../Export-ADHealthReport.ps1#L56).

## Get-AdSchemaLabel

Mapeia versão de schema, preservando desconhecido. [Source](../Export-ADHealthReport.ps1#L65).

## Get-AdComputerClass

Classifica por UAC/OS como pista de inventário. [Source](../Export-ADHealthReport.ps1#L70).

## Invoke-AdQuery

Adaptador de comandos Get-AD com lista fechada e ErrorAction Stop. [Source](../Export-ADHealthReport.ps1#L80).

## Initialize-AdRuntime

Valida Windows/64 bits/5.1 e carrega ActiveDirectory. [Source](../Export-ADHealthReport.ps1#L84).

## Get-AdSchemas

Contrato dos 18 cabeçalhos CSV. [Source](../Export-ADHealthReport.ps1#L90).

## Add-AdRows

Acumula linhas normalizadas por conjunto. [Source](../Export-ADHealthReport.ps1#L112).

## Invoke-AdCollection

Registra sucesso, falha ou não solicitado, com cobertura e erros. [Source](../Export-ADHealthReport.ps1#L116).

## New-AdFinding

Acrescenta evidência e recomendação para revisão humana. [Source](../Export-ADHealthReport.ps1#L128).

## Convert-AdAccount

Seleciona campos de usuários/computadores sem segredos. [Source](../Export-ADHealthReport.ps1#L132).

## Convert-AdPolicy

Normaliza política e intervalos de tempo. [Source](../Export-ADHealthReport.ps1#L157).

## Get-AdServiceObservations

Consulta seis serviços por CIM, preservando NotObserved. [Source](../Export-ADHealthReport.ps1#L167).

## Get-AdNativePath

Seleciona dcdiag em SystemDirectory. [Source](../Export-ADHealthReport.ps1#L175).

## Invoke-AdDcdiag

Lista fechada de testes, sem shell, saída/erro e timeout por processo. [Source](../Export-ADHealthReport.ps1#L176).

## Resolve-AdOutputPath

Resolve diretório FileSystem local e bloqueia curingas/rede. [Source](../Export-ADHealthReport.ps1#L193).

## Convert-AdCsvValue

Neutraliza início de fórmula em CSV sem alterar JSON. [Source](../Export-ADHealthReport.ps1#L205).

## Write-AdCsv

Grava CSV com BOM UTF-8, aspas e cabeçalhos estáveis. [Source](../Export-ADHealthReport.ps1#L212).

## Complete-AdFindings

Executa regras documentadas sobre dados já coletados. [Source](../Export-ADHealthReport.ps1#L224).

## Invoke-AdAssessment

Coordena bootstrap, escopo, coletores, exportação e manifesto. [Source](../Export-ADHealthReport.ps1#L246).

## Write-AdHtmlReport

Gera dashboard offline com dados codificados, busca e CSP nonce. [Source](../Export-ADHealthReport.ps1#L381).

## Get-AdReportProperty

Lê propriedades do modelo de apresentação. [Source](../Export-ADHealthReport.ps1#L387).

## ConvertTo-AdReportText

Formata valores para apresentação. [Source](../Export-ADHealthReport.ps1#L396).

## ConvertTo-AdReportHtml

Codifica texto inserido em HTML. [Source](../Export-ADHealthReport.ps1#L405).

