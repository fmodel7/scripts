# Catálogo — Scripts FMODEL

Cada ferramenta tem pasta e README próprios. Leia os requisitos, permissões e efeitos antes de executar.

| Script | O que faz | Plataforma | Versão | Documentação |
|---|---|---|---|---|
| Windows Time — PDC / DOMHIER | Dois PS1 independentes com confirmação: NTP no PDC raiz ou hierarquia AD nos demais servidores; backup e HTML | Windows Server 2016+; PowerShell 5.1/7 de 64 bits | 2.0.0 | [PT-BR](configure-ntp-pdc/README.md) · [EN-US](configure-ntp-pdc/README.en-US.md) |
| SNOW Edge Monitor | Monitora lista Classic do ServiceNow via Edge, com confirmação de estados, sirene e pop-up; validação Windows pendente | Windows 10/11; Python 3.11+ | 1.0.0 (fontes) | [EN-US](../snow-edge-monitor/README.md) · [PT-BR](../snow-edge-monitor/docs/GUIA_DO_PROJETO.pt-BR.md) |

## Para adicionar outra ferramenta

1. Criar uma pasta `scripts/nome-do-script/`.
2. Incluir o código e seus arquivos auxiliares.
3. Criar o README próprio usando o [modelo PowerShell](../templates/powershell/README.md).
4. Documentar as verificações que realmente foram executadas.
5. Adicionar uma linha neste catálogo com link para o README da ferramenta.

Não listar os modelos como ferramentas operacionais. [Passo a passo completo](../docs/COMO-ADICIONAR-UM-SCRIPT.md) · [Página inicial](../README.md).



