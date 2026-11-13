# Testes e aceite — 2.0.0

151 verificações e 19 fluxos simulados por ambiente passaram na [CI](https://github.com/fmodel7/scripts/actions/runs/43437702532): Windows PowerShell 5.1, PowerShell 7 Windows e Linux. O teste local também passou em PowerShell 7.4.13/Linux. Consulte EVIDENCE.json para hashes e commit exato.

```powershell
powershell.exe -NoProfile -File .	ests\Test-WindowsTime.ps1
```

Use pwsh no PowerShell 7. Não exige domínio ou elevação. Aguarde mais de 30 s. AST carrega apenas funções, sem executar os arquivos operacionais. Testes usam nomes example.test e IPs de documentação. Operações mutantes de Registro/serviço/W32Time e leituras AD/DNS são substituídas. O runner nativo usa processos filhos PowerShell inofensivos para saída zero, stderr/exit 7 e timeout de 30 s. Os arquivos temporários são apagados.

Os 19 fluxos: PDC, membro DOMHIER, PDC filho DOMHIER, política, serviço desabilitado, PDC errado, DOMHIER no PDC raiz, WhatIf, recusa, backup com falha, mudança de papel após confirmação, mudança após backup, corrida de valores após backup, falha de mutação, mudança de papel após mutação, configuração divergente, falha de consulta, falha de ressync e serviço inicialmente parado. Asserções também cobrem parser, igualdade dos mecanismos, requisitos, flags, DNS inválido, fontes locais/proibidas, codificação HTML, journal e ShouldProcess real.

Limites: nenhum PDC real foi configurado, nenhum relógio foi alterado, nenhuma fonte NTP/DNS externa foi sondada; as APIs AD reais, o caminho UDP e a aplicação real de GPO/serviço/Registro não são validados pelos mocks. Não há teste de sincronismo ou certificação de precisão. A CI grava runtime, hashes e logs em artifacts com retenção de 30 dias.

## Aceite em laboratório autorizado

1. Identificar floresta/domínio/PDC raiz atual e fontes aprovadas; revisar GPO e política de VM.
2. Preservar estado/logs e plano de recuperação; aprovar janela e risco de ajuste de relógio.
3. Executar -WhatIf no PDC raiz e membro; verificar bloqueio do script cruzado.
4. Aplicar PDC, revisar backup/journal/HTML e Type=NTP; verificar source/status/eventos e estabilidade.
5. Aplicar DOMHIER num membro, verificar NT5DS e fonte da hierarquia; testar child-domain DC conforme topologia.
6. Simular problemas de DNS/rede apenas em laboratório controlado; confirmar que falhas exigem revisão.
7. Registrar aceite da equipe AD antes de expansão por GPO; replanejar após FSMO.

[Manual](MANUAL.pt-BR.md) · [Evidências](EVIDENCE.json)
