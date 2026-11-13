# FMODEL Windows Time 2.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · Akira (ChatGPT)

**Dois scripts independentes para o horário do Windows.** Windows Server 2016+ · Windows PowerShell 5.1 / PowerShell 7 · 64 bits.

[Português](README.md) · [English](README.en-US.md) · [Manual](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf)

## Escolha o script

| Arquivo | Onde executar | Guia próprio |
|---|---|---|
| Configure-NTP-PDC.ps1 | PDC Emulator do domínio raiz da floresta | [PDC](docs/PDC.pt-BR.md) |
| Configure-Time-DOMHIER.ps1 | Demais servidores do domínio, inclusive DCs de domínios filhos | [DOMHIER](docs/DOMHIER.pt-BR.md) |

**Cada PS1 funciona sozinho.** O do PDC já contém os quatro nomes NTP do arquivo original. O de DOMHIER descobre fontes pela hierarquia AD, sem fixar endereço do PDC.

## Baixar

[Baixar pacote Windows-Time-v2.0.0.zip](Windows-Time-v2.0.0.zip?raw=true). Se abrir a página do arquivo, clique em **Download raw file**. Depois escolha **Extrair Tudo**.

Alternativa: na página principal do repositório, **Code → Download ZIP → Extrair Tudo → scripts/configure-ntp-pdc**. Não precisa instalar Git nem PowerShell 7: o Windows PowerShell 5.1 de 64 bits também é suportado.

## Simular primeiro

Abra PowerShell ou VSCode **como Administrador**, abra a pasta extraída e execute somente o comando correspondente ao alvo:

```powershell
# No PDC raiz:
.\Configure-NTP-PDC.ps1 -WhatIf

# Em outro servidor do domínio:
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

A simulação faz consultas AD/DNS/Registro/serviço, mas não altera o W32Time nem cria relatórios. Ela não comprova conectividade NTP ou sucesso futuro das alterações.

## Aplicar

No servidor correto e em janela autorizada, remova -WhatIf:

```powershell
# Escolha apenas UM, de acordo com o alvo:
.\Configure-NTP-PDC.ps1
.\Configure-Time-DOMHIER.ps1
```

**Haverá confirmação antes de aplicar.** A execução real pode ajustar o relógio via W32Time. O PDC raiz aceita somente o primeiro script e é bloqueado pelo segundo. Uma chave de política W32Time presente bloqueia ambos: revise a GPO.

No início do primeiro arquivo, o bloco NtpServers contém a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br e e.st1.ntp.br. Revise fontes aprovadas pela empresa antes de aplicar. Não são endereços obrigatórios Microsoft nem tiveram disponibilidade atual verificada. Use nomes, sem IPs, URLs ou flags.

## Ver o resultado

Abra o caminho Report.html exibido no console. A pasta fica no LocalApplicationData da conta elevada, em FMODEL/WindowsTime/Run-.... Inclui backup do Registro, relatório HTML/JSON e diário das alterações tentadas. Não publique esses arquivos reais.

Configured confirma configuração local, aceitação do pedido de ressync e retorno das consultas. **Não certifica sincronismo, precisão ou saúde de toda a floresta.** ConfiguredNeedsReview exige análise; FailedAfterMutationPossible pode indicar aplicação parcial. Não há rollback automático, e backup não desfaz ajuste de relógio.

## Testar sem domínio ou alterações reais

```powershell
powershell.exe -NoProfile -File .	ests\Test-WindowsTime.ps1
```

No PowerShell 7, troque powershell.exe por pwsh. Pode usar estação comum/VSCode, sem elevação. Aguarde mais de 30 segundos; a suíte testa o timeout de um processo filho inofensivo.

## Documentação

- [Manual completo](docs/MANUAL.pt-BR.md) · [PDF](docs/MANUAL.pt-BR.pdf).
- [Guia PDC](docs/PDC.pt-BR.md) · [Guia DOMHIER](docs/DOMHIER.pt-BR.md).
- [Validação e aceite](docs/TESTING.pt-BR.md) · [Funções internas](docs/INTERNALS.pt-BR.md).
- [Histórico e migração](CHANGELOG.md) · [Evidências](docs/EVIDENCE.json).

**Mudança de comportamento:** substitui 1.0.0 na mesma pasta. Sem parâmetros agora aplica após confirmação; não existe -Apply. Use -WhatIf para não aplicar. Os antigos arquivos auxiliares não são necessários.

[CI](https://github.com/fmodel7/scripts/actions/runs/43437702532): 151 assertions / 19 simulated workflows per environment: Windows PowerShell 5.1, PowerShell 7 Windows and Linux mocks. No real PDC or clock was changed.
