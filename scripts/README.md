# Catálogo — Scripts FMODEL

Cada ferramenta tem pasta e README próprios. Leia os requisitos, permissões e efeitos antes de executar.

| Script | O que faz | Plataforma | Versão | Documentação |
|---|---|---|---|---|
| Configure NTP PDC | Consulta e configura W32Time no PDC do domínio raiz, com aplicação explícita, backup e relatórios | Windows 64 bits; Apply em Server 2016+ | 1.0.0 | [PT-BR](configure-ntp-pdc/README.md) · [EN-US](configure-ntp-pdc/README.en-US.md) |

## Para adicionar outra ferramenta

1. Criar uma pasta `scripts/nome-do-script/`.
2. Incluir o código e seus arquivos auxiliares.
3. Criar o README próprio usando o [modelo PowerShell](../templates/powershell/README.md).
4. Documentar as verificações que realmente foram executadas.
5. Adicionar uma linha neste catálogo com link para o README da ferramenta.

Não listar os modelos como ferramentas operacionais. [Passo a passo completo](../docs/COMO-ADICIONAR-UM-SCRIPT.md) · [Página inicial](../README.md).

