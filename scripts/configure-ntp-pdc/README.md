# Configure NTP PDC — FMODEL

**Versão 1.0.0 · PowerShell 5.1 e 7 · Windows 64 bits**  
**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · revisão com assistência de Akira (ChatGPT) · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)

[English](README.en-US.md) · [Manual completo PT-BR](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf) · [Alterações da revisão](docs/REVIEW.pt-BR.md)

Consulta e configura o Windows Time (W32Time) **somente no PDC Emulator atual do domínio raiz da floresta** para o modo de fontes NTP manuais aprovadas. Os demais DCs e membros normalmente seguem a hierarquia do Active Directory.

**O padrão é consulta:** executar sem `-Apply` não altera W32Time, serviço ou relógio. Grava relatórios locais. Não existe servidor NTP escolhido automaticamente. Alterar a fonte de horário de um DC pode afetar a autenticação e aplicações; faça a aplicação real no ambiente e janela autorizados.

## 1. Baixar a ferramenta completa

[Baixar ZIP v1.0.0](Configure-NTP-PDC-v1.0.0.zip?raw=true). No GitHub, abra o arquivo e clique em **Download raw file**. Extraia tudo.

Alternativa: na página [Scripts FMODEL](https://github.com/fmodel7/scripts), **Code → Download ZIP → Extrair Tudo**, depois abra `scripts/configure-ntp-pdc`.

Baixe o PS1 **e** a pasta `src`. Não execute `tests/Mock-Adapters.ps1` por dot-sourcing em uma sessão de trabalho: os testes usam comandos falsos e processos separados.

## 2. Testar sem tocar no domínio

Estes testes não exigem elevação nem um domínio. Substituem alterações por operações sintéticas. Em Windows, a suíte do núcleo também faz leituras locais de Registro/CIM e exibe a ajuda real do w32tm, sem configurar o serviço.

No PowerShell 7, dentro da pasta da ferramenta, execute cada linha separadamente:

```powershell
pwsh -NoProfile -File .\tests\Test-Core.ps1
pwsh -NoProfile -File .\tests\Test-Workflow.ps1
pwsh -NoProfile -File .\tests\Test-EntryPoint.ps1
```

No Windows PowerShell 5.1, use `powershell.exe` no lugar de `pwsh`. Espere `PASS`. Os testes no Linux validam funções/fluxos simulados; **a ferramenta real é para Windows**.

Para ver o relatório sem executar PowerShell, abra [exemplo fictício PT-BR](examples/Report-SYNTHETIC.pt-BR.html) após baixá-lo. Não é evidência de um DC real.

## 3. Consultar o servidor — caminho inicial

No servidor Windows, abra **PowerShell como Administrador**. Também pode usar o VSCode elevado, com terminal PowerShell e a pasta da ferramenta aberta.

```powershell
Get-Location
Get-ChildItem
.\Configure-NTP-PDC.ps1
```

Se já estiver nessa pasta, não repita `cd configure-ntp-pdc`. O resultado mostra `RunFolder` e o caminho do HTML. O padrão de saída é `%LOCALAPPDATA%\FMODEL\NtpPdc\Run-...` da conta que executou o processo.

Abra `Report.pt-BR.html`. Confira o domínio, PDC raiz, serviço, política e dados anteriores. `AuditCompleted` significa que a consulta terminou, **não que o horário ou o alvo estejam aprovados para alteração**.

## 4. Planejar e simular

Defina fontes aprovadas para sua organização. Podem ser appliances internos confiáveis ou serviços externos autorizados. Não escolha servidores públicos apenas por estarem em um exemplo.

Os nomes abaixo vêm do script recebido, **não são defaults nem foram consultados por nós**. Verifique disponibilidade, uso permitido, localização, latência e adequação antes de utilizá-los:

```powershell
$peers = @('a.st1.ntp.br', 'c.st1.ntp.br', 'd.st1.ntp.br', 'e.st1.ntp.br')
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply -WhatIf
```

Informe apenas nomes/IPs; **não acrescente `,0x8`**. A ferramenta monta as flags. A simulação ainda faz consultas AD/DNS e grava relatórios, mas não exporta o backup `.reg`, não muda Registro e não reinicia/sincroniza o serviço.

Se houver política W32Time, o alvo não for o PDC raiz ou outra pré-condição falhar, a aplicação é bloqueada — inclusive na simulação. Não há opção para ignorar esses bloqueios.

## 5. Aplicar de verdade

**Só após revisar o relatório e as fontes aprovadas**, na mesma pasta e sessão elevada:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply
```

A confirmação informa o alvo e a operação. Após aprová-la, o script revalida o alvo/política, salva backup, configura peers, provedores e anúncio, reinicia/inicia W32Time e solicita ressincronização. **Não há rollback automático; backup de Registro não desfaz o ajuste do relógio.**

Quando aprovado pela rotina de automação, `-Confirm:$false` dispensa a pergunta do PowerShell; não elimina os demais controles. Não use para simplesmente evitar a revisão.

## 6. Entender o resultado

| Estado | Significado |
|---|---|
| `AuditCompleted` | Consulta finalizada; não aplicou configuração. |
| `WhatIf` / `Declined` | Aplicação simulada ou recusada; W32Time não foi alterado. |
| `AppliedVerified` | Configuração local e evidência de status atenderam aos critérios implementados. Não comprova precisão, autenticação do NTP ou sincronização de toda a floresta. |
| `AppliedNeedsReview` | Houve aplicação, mas nem todos os critérios foram confirmados. Não tratar como sucesso de sincronização. |
| `Blocked` | Nenhuma mutação W32Time foi iniciada pelo fluxo. Relatórios/backup podem ter sido criados. |
| `FailedAfterMutationPossible` | Uma alteração foi tentada; pode haver mudança parcial. Conferir diário, estado atual e backup antes de repetir. |

Saídas: HTML PT-BR/EN-US, JSON técnico, snapshot anterior, diagnósticos brutos, diário de ações e, em Apply aprovado, exportação anterior do Registro. Esses arquivos podem conter nomes internos, IPs e identidade do operador; não os publique no Git.

**Validação:** testes automatizados em Windows PowerShell 5.1, PowerShell 7 em Windows e mocks no Linux. Nenhum PDC real foi configurado durante o desenvolvimento. Veja [evidências](docs/EVIDENCE.json), [CI](https://github.com/fmodel7/scripts/actions/runs/40010481878), [manual detalhado](docs/MANUAL.pt-BR.md) e [aceitação no ambiente](docs/ACCEPTANCE.pt-BR.md).
