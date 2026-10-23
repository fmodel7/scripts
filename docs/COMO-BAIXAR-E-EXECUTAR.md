# Baixar e executar — para iniciantes

A biblioteca já contém [Configure NTP PDC](../scripts/configure-ntp-pdc/README.md). Cada ferramenta tem suas próprias instruções; os passos abaixo explicam como chegar à pasta e ao README corretos.

## Baixar

1. Abrir [Scripts FMODEL](https://github.com/fmodel7/scripts).
2. Clicar no botão verde **Code**.
3. Escolher **Download ZIP**.
4. No Windows, clicar com o botão direito no ZIP e escolher **Extrair Tudo**.
5. Abrir a pasta extraída e entrar em `scripts`.
6. Escolher a pasta da ferramenta e ler o README dela.

Os scripts públicos podem ser baixados sem dar acesso ao Infratech. Uma chave/API, conta de serviço ou licença eventualmente necessária para executar uma ferramenta continua sendo responsabilidade de quem a utiliza.

## Executar

O README de cada script terá o comando exato. Dependendo da ferramenta, pode ser necessário PowerShell 7, módulos ou permissões adicionais. Não existe um comando único que execute toda a biblioteca.

No VSCode: **File → Open Folder**, escolha a pasta da ferramenta e depois **Terminal → New Terminal**. Use a versão de PowerShell informada pelo README. Se já estiver na pasta correta, não repita o cd para a mesma pasta.

Não cole a chave de API em texto literal no comando nem altere políticas corporativas para contornar um bloqueio. Não execute o modelo `templates/powershell`: ele não é uma ferramenta.

Para PowerShell, quando o script realmente aceitar SecureString, seu README pode usar Read-Host -AsSecureString para receber uma chave. Não presumir que esse parâmetro existe em todos os scripts.

