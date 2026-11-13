# Changelog

## 2026-11-13 — Hyper-V Health Report 1.0.0

- Adiciona scripts/hyper-v-health-report: inventário/revisão de leitura local/remota e descoberta de cluster por nó real.
- 54 CSVs, HTML offline pesquisável, JSON/manifesto/ZIP opcional; 23 regras contextuais, cobertura/erros, limites e jobs próprios.
- Host/VM/NUMA, storage/cadeias VHD, checkpoints/Replica, redes/SET/VLAN/offloads, segurança/SMB, eventos e BPA existente opcional.
- Exemplos fictícios PT-BR/EN-US, dois manuais completos e 27 fontes Microsoft. Testes sintéticos em Windows PowerShell 5.1 e PS7 Windows/Linux; aceite em Hyper-V real pendente.

## 2026-11-13 — AD Health Report 1.2.0

- Perfil ComprehensiveAssessment: 33 conjuntos novos, 63 CSVs totais, GPO/RSoP, SPNs/UPNs, Lixeira/topologia, DNS administrativo, SYSVOL, host/software/QFE, segurança/eventos/auditoria e evidências de backup.
- Recriação offline, ZIP opcional, jobs próprios limitados, parsing XML seguro, correção de arrays JSON no Windows PowerShell 5.1, fontes oficiais e manuais PT-BR/EN-US atualizados.
- Validação sintética separada da aceitação em infraestrutura real; sem alterações automáticas no ambiente.

# Histórico

## 2026-11-13 — AD Health Report 1.1.0

- Integra em um PS1 os coletores AD e operacionais: DNS/ICMP, boot/memória, discos/NTDS/SYSVOL, amostras/evidências de horário, eventos e duração real.
- FullAssessment habilita o conjunto ampliado com 17 testes DCDiag selecionados; preserva leitura e escopo explícito.
- 30 CSVs, HTML/JSON, resumo numérico por DC, documentação PT-BR/EN-US e exemplo fictício atualizados. Sem SMTP obsoleto ou operações de reparo.
- CI: 25 cenários por ambiente; 1338 verificações em Windows PowerShell 5.1/Linux e 1334 em PowerShell 7 Windows; infraestrutura real permanece sem validação.

## 2026-11-13 — AD Health Report 1.0.0

- Adiciona scripts/ad-health-report com PS1 independente, coleta de leitura por domínio/floresta, FSMO/schema, inventário, políticas/trusts e replicação.
- HTML offline com busca, 18 CSVs completos protegidos contra fórmulas, JSON e manifesto; erros/ausência separados de contagens zero.
- Serviços CIM e DCDiag opcionais e sem reparo; manuais PT-BR/EN-US/PDF, exemplo fictício e testes.
- CI: 15 cenários; 673 verificações no Windows PowerShell 5.1 e Linux, 669 no PowerShell 7/Windows. Sem consulta AD/CIM/dcdiag real ou alteração de diretório.

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







