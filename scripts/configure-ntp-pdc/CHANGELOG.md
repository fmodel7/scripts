# Histórico / Changelog

## 2.0.0 — 2026-11-13

- Dois PS1 independentes: PDC raiz com fontes embutidas e demais servidores com DOMHIER.
- Two standalone PS1 files: root PDC with embedded sources and other servers using DOMHIER.
- Sem parâmetros aplica após confirmação; -WhatIf faz pré-validação sem gravar arquivos. No -Apply or other custom parameters.
- Backup, journal, mutex local, verificação de configuração, timeout e relatório HTML/JSON.
- Manuais PT-BR/EN-US reescritos, PDFs, guias individuais e suíte offline nova.
- Política de saída: Configured não certifica sincronismo / does not certify synchronization.

Breaking change: replace old flags and automation. Do not combine source files or test counts from 1.0.0 with this version. The former parser-based time-status verdict is no longer exposed; diagnostics require operator review.

## 1.0.0 — histórico preservado / preserved history

[Código, manuais, PDFs e pacote anteriores / Previous code, manuals, PDFs and package](https://github.com/fmodel7/scripts/tree/14d2d2bdd1ba5986a4c4d741a34751b92a0a6b49/scripts/configure-ntp-pdc).

The new package replaces old files on main; Git history is retained. O repositório privado Infratech não é alterado.
