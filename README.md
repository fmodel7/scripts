# Scripts FMODEL

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
Criado e mantido por **F. Model** · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)

Biblioteca de scripts e automações para compartilhar conhecimento e facilitar tarefas de tecnologia da informação.

[English](README.en-US.md) · [Deutsch](README.de-DE.md)

## Comece aqui

- **Quero usar um script:** abra o [catálogo](scripts/README.md), escolha uma ferramenta e leia o README da pasta antes de executar.
- **Quero publicar um script:** siga o [passo a passo para adicionar](docs/COMO-ADICIONAR-UM-SCRIPT.md).
- **Sou iniciante:** consulte [como baixar e executar](docs/COMO-BAIXAR-E-EXECUTAR.md).
- **Quero padronizar a documentação:** use o [modelo PowerShell](templates/powershell/README.md), também em [inglês](templates/powershell/README.en-US.md) e [alemão](templates/powershell/README.de-DE.md).

**Status inicial:** a estrutura está pronta para receber scripts. Ainda não há scripts de execução publicados neste catálogo. Os modelos são documentação para preencher, não programas prontos para executar.

## Como cada script será organizado

```text
scripts/
└── nome-do-script/
    ├── README.md             # objetivo, requisitos, teste e execução em PT-BR
    ├── README.en-US.md       # quando a tradução estiver revisada
    ├── README.de-DE.md       # quando a tradução estiver revisada
    ├── Nome-Do-Script.ps1
    ├── docs/                 # explicações adicionais, quando necessárias
    └── tests/                # validação pertinente, quando necessária
```

Cada script terá sua pasta e seu próprio README. Os detalhes devem refletir a análise do código: não presumir que todo programa tem simulação, desfazer ou execução sem privilégios.

## O que você encontrará no README de cada script

Objetivo, funcionamento, requisitos, permissões, instalação, comandos de teste e execução, parâmetros, efeitos reais, relatórios/saídas, erros conhecidos, limitações, versão e créditos.

Os comandos devem ser copiáveis e corresponder ao código entregue. Exemplos que alteram o sistema precisam deixar esse efeito explícito. Quando houver simulação implementada, mostrar esse caminho primeiro.

## Baixar e compartilhar

[Baixar ZIP do repositório](https://github.com/fmodel7/scripts/archive/refs/heads/main.zip) · [Catálogo](scripts/README.md)

No GitHub: **Code → Download ZIP**. Depois escolha **Extrair Tudo** e abra a pasta do script desejado. Baixe os arquivos auxiliares junto; um PS1 isolado pode não funcionar.

Este repositório já é **público**. Qualquer pessoa pode ler e baixar o conteúdo publicado; alterações dependem de permissão ou de um pull request aceito. Não é necessário conceder acesso ao Infratech para compartilhar esta biblioteca.

A visibilidade pública, por si só, não define uma licença de reutilização. A licença ainda não foi escolhida para esta biblioteca. Não presumir autorização para relicenciar ou redistribuir código de terceiros.

## Colaborar

[Como contribuir](CONTRIBUTING.md) · [Dados e credenciais](SECURITY.md) · [Histórico](CHANGELOG.md)

Só publicar conteúdo que você tenha direito de compartilhar. Os scripts privados do Infratech e dados de clientes não são transferidos automaticamente para esta biblioteca.
