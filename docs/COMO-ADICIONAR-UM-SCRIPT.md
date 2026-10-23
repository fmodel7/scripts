# Adicionar um script com README próprio

1. Enviar ou adicionar o código que você tem autorização para publicar. Não copiar projetos privados, históricos, dados de clientes ou credenciais para este repositório por consequência de ele ser público.
2. Escolher um nome curto para a pasta, em minúsculas e com hífens: `scripts/nome-da-ferramenta/`.
3. Incluir código e dependências de arquivo nessa pasta.
4. Copiar o [modelo PowerShell](../templates/powershell/README.md) para `scripts/nome-da-ferramenta/README.md`.
5. Analisar o script e preencher objetivo, funcionamento, parâmetros, permissões, dados, efeitos reais, erros e limites. Não adivinhar recursos pela aparência do código.
6. Validar os comandos descritos com testes pertinentes. Documentar ambiente e distinguir mocks de operações reais.
7. Atualizar o [catálogo](../scripts/README.md) com o link do README, plataforma e versão.
8. Adicionar traduções EN-US/de-DE quando revisadas. Os modelos correspondentes estão em [inglês](../templates/powershell/README.en-US.md) e [alemão](../templates/powershell/README.de-DE.md).
9. Registrar alterações em CHANGELOG.md, revisar o diff e publicar por pull request.

## Convenções

Uma ferramenta funcional por pasta, mesmo quando ela contém vários PS1 ou módulos. Um README próprio por ferramenta explica a relação entre seus arquivos. Se cada PS1 tiver propósito independente, cada um recebe sua própria pasta/README.

Nenhuma pasta deve parecer pronta para uso quando contém apenas documentação modelo. O catálogo inicial não inclui entradas fictícias.

Para entregas versionadas, usar tags com prefixo da ferramenta e Releases com o pacote completo. Não substituir silenciosamente um ZIP publicado por outro conteúdo com a mesma versão. Incluir checksum quando distribuir um pacote.

Antes de redistribuir ou relicenciar código de terceiros, verificar seus direitos e avisos. A biblioteca ainda não tem uma licença escolhida.
