# Histórico

## 2026-11-13 — DHCP Transfer 1.0.0

- Adiciona scripts/dhcp-transfer com Export-DHCP.ps1 e Import-DHCP.ps1 independentes, confirmação e caminhos explícitos no alvo local/remoto.
- Exportação sem sobrescrita; importação com backups nativo/XML, snapshot, ScopeOverwrite/reinício opt-in, journal e HTML/JSON.
- Manuais PT-BR/EN-US/PDF, guias por script, testes offline, hash do pacote e instruções de aceite.
- CI: 26 cenários por ambiente; 227 verificações em cada Windows (5.1/7) e 225 em Linux. Sem DHCP/WinRM real ou teste de leases por clientes.

## 2026-11-13 — Windows Time 2.0.0

- Substitui a ferramenta NTP modular por PS1 independentes de PDC e DOMHIER, com fontes embutidas, confirmação, backup e HTML.
- Documentação PT-BR/EN-US, PDFs e pacote apresentam somente os scripts atuais de PDC e DOMHIER. Sem parâmetros passa a aplicar após confirmação: use -WhatIf para simular.
- Offline CI: 151 verificações e 19 fluxos por ambiente, em Windows PowerShell 5.1 e PowerShell 7 Windows/Linux. Sem teste de aplicação em PDC real.

## SNOW Edge Monitor 1.0.0 (fontes) — 13/11/2026

- Adicionada a aplicação Python na pasta `snow-edge-monitor`, conforme destino escolhido pelo proprietário.
- Monitoramento via Edge/Playwright, configurações genéricas, estados elegíveis, notificações locais e módulos separados.
- Guias detalhados EN-US/PT-BR, operação, arquitetura, dependências e instruções PyInstaller.
- 48 testes unitários e 18 testes de navegador com dados/HTML fictícios; a execução operacional no Windows continua pendente.
- Referência histórica sanitizada; original privado, configuração local e perfil de navegador excluídos da publicação.
- Workflows exclusivos do projeto e auditoria limitada à sua árvore/histórico, preservando as outras ferramentas.

## Estrutura inicial — 23/10/2026

- Identidade Scripts FMODEL e créditos/contato.
- Catálogo inicial, uma pasta por ferramenta e README individual.
- Modelos PowerShell PT-BR/EN-US/de-DE e orientações para iniciantes.
- Nenhum script privado, credencial ou dado real importado.
- Nenhum script executável publicado nesta etapa.




