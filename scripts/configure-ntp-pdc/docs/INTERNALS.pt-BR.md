# Referência interna — 2.0.0

Os dois PS1 contêm as mesmas funções; não são uma API pública ou módulo. O script termina o processo ao concluir; não faça dot-sourcing. As funções são extraídas por AST apenas nos testes.

## Get-TimeNativePath

Seleciona binário em SystemDirectory, sem busca no PATH. [PDC source](../Configure-NTP-PDC.ps1#L36).

## Invoke-TimeNative

Executa processo sem shell, coleta stdout/stderr, exige exit zero e timeout 30 s. [PDC source](../Configure-NTP-PDC.ps1#L41).

## Get-TimeSettings

Lê Type, NtpServer, AnnounceFlags e Enabled de dois provedores. [PDC source](../Configure-NTP-PDC.ps1#L74).

## Get-TimeContext

Valida ambiente/token/servidor e captura domínio, PDC raiz, política, serviço, identidade, IPs e configuração. [PDC source](../Configure-NTP-PDC.ps1#L85).

## Assert-TimeTarget

Bloqueia política, serviço desabilitado e papel incompatível com PDC/DOMHIER. [PDC source](../Configure-NTP-PDC.ps1#L119).

## Resolve-TimeAddresses

Adaptador de resolução DNS via .NET; não prova NTP ou confiança. [PDC source](../Configure-NTP-PDC.ps1#L130).

## Get-TimePeerList

Normaliza/valida 1–10 nomes, resolve e rejeita endereços proibidos; monta 0x8/0xA. [PDC source](../Configure-NTP-PDC.ps1#L135).

## New-TimeRunFolder

Cria saída LocalApplicationData por UTC/GUID, com ACLs herdadas. [PDC source](../Configure-NTP-PDC.ps1#L166).

## Write-TimeJournal

Acrescenta JSONL em FileStream e chama Flush(true). [PDC source](../Configure-NTP-PDC.ps1#L174).

## Invoke-TimeMutation

Grava INTENT, executa uma etapa e grava COMPLETED se não houve erro. [PDC source](../Configure-NTP-PDC.ps1#L182).

## Backup-TimeRegistry

Exporta ramificação W32Time, exige sucesso nativo e arquivo não vazio. [PDC source](../Configure-NTP-PDC.ps1#L189).

## Set-TimeRegistry

Habilita cliente, define anúncio automático e habilita servidor só no PDC. [PDC source](../Configure-NTP-PDC.ps1#L197).

## Set-TimeService

Inicia/reinicia sem Force e espera Running até 30 s. [PDC source](../Configure-NTP-PDC.ps1#L207).

## Get-TimeDiagnostics

Consulta configuration/source/status verbose/peers, registrando erros por consulta. [PDC source](../Configure-NTP-PDC.ps1#L214).

## Test-TimeConfiguration

Verifica Running, DWORDs, Type e peers manuais quando PDC; não analisa saúde do horário. [PDC source](../Configure-NTP-PDC.ps1#L226).

## Write-TimeReport

Grava JSON técnico e HTML offline bilíngue com codificação de dados, sem JavaScript. [PDC source](../Configure-NTP-PDC.ps1#L236).

## Invoke-TimeSetup

Coordena pré-validação, confirmação, mutex, backup, revalidação, mutações e resultado final. [PDC source](../Configure-NTP-PDC.ps1#L268).

As operações reais de AD/serviço/Registro e o caminho UDP requerem aceite em laboratório.
