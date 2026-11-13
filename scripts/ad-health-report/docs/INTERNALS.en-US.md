# Internal reference — 1.0.0

Functions are implementation details, not a public API. Run the PS1 as a file; tests extract functions only in test processes.

## Get-AdField

Reads optional properties without converting absence to false/zero. [Source](../Export-ADHealthReport.ps1#L38).

## Convert-AdDate

Normalizes dates to UTC; missing/invalid dates stay empty. [Source](../Export-ADHealthReport.ps1#L44).

## Convert-AdSid

Normalizes SID to text. [Source](../Export-ADHealthReport.ps1#L49).

## Get-AdParentDn

Extracts parent DN while respecting escaped commas. [Source](../Export-ADHealthReport.ps1#L56).

## Get-AdSchemaLabel

Maps schema version while retaining unknown versions. [Source](../Export-ADHealthReport.ps1#L65).

## Get-AdComputerClass

Classifies by UAC/OS as an inventory hint. [Source](../Export-ADHealthReport.ps1#L70).

## Invoke-AdQuery

Allowlisted Get-AD adapter using ErrorAction Stop. [Source](../Export-ADHealthReport.ps1#L80).

## Initialize-AdRuntime

Checks Windows/64-bit/5.1 and loads ActiveDirectory. [Source](../Export-ADHealthReport.ps1#L84).

## Get-AdSchemas

Defines the 18 CSV header contracts. [Source](../Export-ADHealthReport.ps1#L90).

## Add-AdRows

Accumulates normalized rows by dataset. [Source](../Export-ADHealthReport.ps1#L112).

## Invoke-AdCollection

Records collection, failure or deliberate skip with coverage/errors. [Source](../Export-ADHealthReport.ps1#L116).

## New-AdFinding

Appends evidence/recommendations for human review. [Source](../Export-ADHealthReport.ps1#L128).

## Convert-AdAccount

Selects user/computer inventory fields without secrets. [Source](../Export-ADHealthReport.ps1#L132).

## Convert-AdPolicy

Normalizes policies and time intervals. [Source](../Export-ADHealthReport.ps1#L157).

## Get-AdServiceObservations

Queries six services through CIM, preserving NotObserved. [Source](../Export-ADHealthReport.ps1#L167).

## Get-AdNativePath

Selects dcdiag from SystemDirectory. [Source](../Export-ADHealthReport.ps1#L175).

## Invoke-AdDcdiag

Allowlisted tests without shell; captures output/error and per-process timeout. [Source](../Export-ADHealthReport.ps1#L176).

## Resolve-AdOutputPath

Resolves local FileSystem output and rejects wildcards/network paths. [Source](../Export-ADHealthReport.ps1#L193).

## Convert-AdCsvValue

Neutralizes spreadsheet formula prefixes without changing JSON. [Source](../Export-ADHealthReport.ps1#L205).

## Write-AdCsv

Writes BOM UTF-8 CSV with quoting and stable headers. [Source](../Export-ADHealthReport.ps1#L212).

## Complete-AdFindings

Applies documented rules to collected data. [Source](../Export-ADHealthReport.ps1#L224).

## Invoke-AdAssessment

Coordinates bootstrap, scope, collectors, exports and manifest. [Source](../Export-ADHealthReport.ps1#L246).

## Write-AdHtmlReport

Builds encoded offline dashboard with search and CSP nonce. [Source](../Export-ADHealthReport.ps1#L381).

## Get-AdReportProperty

Reads presentation-model properties. [Source](../Export-ADHealthReport.ps1#L387).

## ConvertTo-AdReportText

Formats values for presentation. [Source](../Export-ADHealthReport.ps1#L396).

## ConvertTo-AdReportHtml

Encodes text inserted into HTML. [Source](../Export-ADHealthReport.ps1#L405).

