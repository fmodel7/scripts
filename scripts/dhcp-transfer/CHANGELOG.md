# Histórico / Changelog

## 1.0.0 — 2026-11-13

- Export-DHCP.ps1 e Import-DHCP.ps1 independentes; importador removido do comentário de bloco.
- Exportação com leases por padrão, nome único e recusa de sobrescrita de XML/hash.
- Importação com backups nativo/XML prévios, snapshot estável e ScopeOverwrite/reinício explícitos.
- Execução local ou worker remoto por WinRM, com todos os caminhos no alvo; sem Restart-Service -ComputerName.
- WhatIf/Confirm, journal, relatório HTML/JSON, validação de caminhos/XML e SHA256 opcional.
- PT-BR/EN-US: guias individuais, manuais completos/PDF, testes e limites de aceite documentados.
- Operação real requer Windows PowerShell 5.1; PowerShell 7 usado somente nos testes offline.
- No real DHCP or WinRM migration tested; native cmdlet return does not prove client service.
