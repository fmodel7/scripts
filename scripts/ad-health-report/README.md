# FMODEL AD Health Report 1.2.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Revisão com assistência de Akira (ChatGPT)

Inventário e revisão assistida de Active Directory em um PS1, com **HTML interativo offline, 63 CSVs, JSON e evidências**. Coleta por consulta; nenhuma correção automática no ambiente.

[English](README.en-US.md) · [Manual PT-BR](docs/MANUAL.pt-BR.md) · [Fontes Microsoft](docs/MANUAL.pt-BR.md#45-fontes-microsoft-e-critérios) · [Campos CSV](docs/MANUAL.pt-BR.md#43-campos-adicionais-dos-csvs)

## Baixar e abrir

**[Baixar AD-Health-Report-v1.2.0.zip](AD-Health-Report-v1.2.0.zip?raw=true)**. Se abrir a página do arquivo, clique em **Download raw file**. Depois clique com o botão direito no ZIP → **Extrair Tudo** e abra a pasta `ad-health-report` extraída.

Não precisa instalar Git. Alternativa no GitHub: **Code → Download ZIP → Extrair Tudo → scripts/ad-health-report**. No VSCode: **File → Open Folder**, abra essa pasta e use **Terminal → New Terminal**. Não execute dentro da visualização do ZIP.

## Testar em casa, sem domínio

Na pasta da ferramenta:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

Os testes também funcionam com `pwsh`. Usam dados fictícios e arquivos locais; não exigem RSAT, credenciais de domínio ou Administrador. Para visualizar o resultado sem executar coleta, abra **examples/SYNTHETIC/Report.html**. O exemplo inteiro é fictício.

## Coletar em ambiente autorizado

Use **Windows PowerShell 5.1 de 64 bits**, RSAT ActiveDirectory e a conta de domínio autorizada. Não é obrigatório executar dentro de um DC. A coleta ampliada requer módulos/direitos/conectividade adicionais; confira o manual e execute primeiro no laboratório.

Inventário padrão:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1
```

Coleta abrangente do domínio, incluindo as novas categorias:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -CreateArchive
```

Para todos os domínios autorizados, acrescente `-Scope Forest`. Para fixar um DC, acrescente `-Server 'NOME-REAL-DO-DC'`, substituindo pelo nome real. `-FullAssessment` mantém o perfil 1.1; o novo perfil abrangente é `-ComprehensiveAssessment`.

## O que foi acrescentado

- Lixeira do AD, topologia, flags por conta, SPNs/UPNs, grupos adicionais por SID e revisão de ciclo de vida.
- GPOs, vínculos, metadados/configurações XML, permissões e RSoP/direitos por SID.
- DNS administrativo, zonas, aging, root hints e indícios InProgress.
- Inventário SYSVOL com limites, hardware/BIOS, software e QFE/KB.
- SMB, Spooler, firewall, W32Time, registro selecionado, auditoria e configuração dos logs.
- Eventos Security selecionados, evidências de backup, renderização offline e ZIP opcional.

Os 30 conjuntos 1.1 continuam, inclusive replicação, medições de horário, discos NTDS/SYSVOL, memória, serviços e 17 testes selecionados DCDiag. Há 33 conjuntos adicionais. Um CSV vazio pode significar não solicitado, nenhum resultado ou falha: **Coverage/CollectionErrors explicam a diferença**.

## Encontrar os resultados

O console mostra **RunFolder**. A saída padrão é uma pasta única sob `%LOCALAPPDATA%\FMODEL\ADHealth`. Abra **Report.html**. CSVs ficam na mesma pasta; no Excel PT-BR, use **Dados → De Texto/CSV → UTF-8 → vírgula**, se necessário.

`-CreateArchive` gera um ZIP ao lado da pasta e mostra **Archive**. Recriar HTML/CSV de JSON existente:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -FromReport 'C:\Caminho\Run-...\report.json' -OutputPath 'C:\ADHealth-Estudo'
```

Substitua os caminhos pelos reais. Esse modo aceita também PowerShell 7 e não faz novas consultas AD. XML/texto de evidência com manifesto são copiados apenas após verificar hashes/tamanhos; isso não autentica o autor do manifesto.

## Interpretação e validação

Revisão de valores selecionados **não é baseline SCT completa nem certificação de conformidade**. Última KB não prova atualização completa; evidência de backup não prova restauração; flag de criptografia não prova uso real; dados desconhecidos não viram sucesso. Limites são explícitos no manual.

[Testes e aceitação](docs/MANUAL.pt-BR.md#44-validação-e-aceite-em-laboratório) · [Evidências técnicas](tests/evidence/EVIDENCE.json) · [Changelog](CHANGELOG.md) · [CI](https://github.com/fmodel7/scripts/actions)

A validação automatizada usa dados fictícios. Não foi avaliada uma floresta real nesta entrega. Relatórios reais podem conter identidades, topologia e políticas sensíveis: não publique esses dados no GitHub.

A documentação está concentrada em **um manual por idioma**. Em `docs`, o único arquivo adicional é `baseline.example.json`, utilizado pelo script.
