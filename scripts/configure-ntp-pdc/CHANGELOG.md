# Histórico / Changelog

## 1.0.0 — 2026-10-23

Primeira publicação revisada do Configure-NTP-PDC, originalmente sem número de versão.

- Audit padrão; Apply explícito com ShouldProcess/WhatIf.
- Identificação do PDC do domínio raiz pelo contexto do computador e revalidações.
- Guardas de política, serviço, peer local, persistência e concorrência.
- Peers configuráveis, client mode/fallback e AnnounceFlags automático por padrão.
- Backup anterior, identidade do operador, diário e relatórios HTML PT-BR/EN-US/JSON.
- Exit codes, timeouts, ausência de retry de mutações e critérios conservadores de evidência.
- Testes de funções, 18 fluxos simulados, três entradas CLI isoladas e CI 5.1/7.
- Nenhuma integração de VM, GPO, firewall, fuso ou limite de correção de fase alterado automaticamente.

First reviewed publication of the originally unversioned script. Audit by default; guarded forest-root PDC application, explicit peers, backup/journal/operator identity, bilingual reports/manuals and offline tests. No real PDC changes were performed during development.
