# Hyper-V Health Report — by FMODEL

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br) · **1.0.0**

[English](README.en-US.md) · [Manual completo PT-BR](docs/MANUAL.pt-BR.md) · [Complete EN-US manual](docs/MANUAL.en-US.md)

Inventário e revisão de hosts Hyper-V, VMs e clusters com **HTML offline pesquisável, 54 CSVs, JSON, manifesto SHA256 e ZIP opcional**. Inclui 23 regras de atenção contextualizadas com fontes Microsoft, sem correção automática.

## Baixar

**[⬇ BAIXAR PACOTE HYPER-V 1.0.0](https://github.com/fmodel7/scripts/raw/refs/heads/main/scripts/hyper-v-health-report/HyperV-Health-Report-v1.0.0.zip)**

Baixe, clique com o botão direito no ZIP e escolha **Extrair Tudo**. Abra a pasta que contém `Export-HyperVHealthReport.ps1`. Não precisa instalar Git.

## Testar primeiro, sem Hyper-V

No PowerShell ou terminal do VSCode, cole o caminho da pasta extraída quando solicitado:

```powershell
$pasta = Read-Host 'Cole o caminho da pasta extraída'
Set-Location -LiteralPath $pasta.Trim('"')
Get-ChildItem -LiteralPath .
```

Depois de revisar o arquivo e confiar na origem:

```powershell
Unblock-File -LiteralPath .\Export-HyperVHealthReport.ps1
$resultado = .\Export-HyperVHealthReport.ps1 -CreateExample -Language pt-BR
Invoke-Item -LiteralPath $resultado.Html
```

O HTML mostra dados **fictícios**, sem consultar servidores. Exemplo/renderização funcionam em PowerShell 5.1/7. Para executar a suíte offline:

```powershell
Unblock-File -LiteralPath .\tests\Test-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVCollectors.ps1
.\tests\Test-HyperVHealthReport.ps1
.\tests\Test-HyperVCollectors.ps1
```

Se uma GPO/AllSigned exigir assinatura, siga o processo corporativo. Desbloquear não assina um PS1. O script não altera políticas de execução.

## Coletar de verdade

Use **Windows PowerShell 5.1 de 64 bits**, conta autorizada e um host de laboratório. Em terminal PowerShell 7, entre antes em:

```powershell
powershell.exe -NoProfile
```

Já na pasta do script, escolha **um** dos comandos:

```powershell
# Próprio host Hyper-V
$resultado = .\Export-HyperVHealthReport.ps1 -OutputPath C:\Reports\HyperV -CreateZip

# Hosts remotos — substituir os nomes
$resultado = .\Export-HyperVHealthReport.ps1 -ComputerName HV01,HV02 -CreateZip

# Cluster — informar um nó membro real
$resultado = .\Export-HyperVHealthReport.ps1 -ClusterNode HV01 -CreateZip

Invoke-Item -LiteralPath $resultado.Html
```

Essas são consultas de leitura: não iniciam/reiniciam VMs, não removem checkpoints, não alteram rede, não executam Test-Cluster e não instalam recursos. Consultas ainda consomem recursos; comece com escopo pequeno. Módulos Hyper-V/FailoverClusters precisam existir nos alvos; consultas remotas dependem de WinRM, DNS e permissões já configurados. A conta atual é usada; credencial diferente é opcional: `-Credential (Get-Credential)` para alvos remotos.

No VSCode: **File → Open Folder → Terminal → New Terminal**. Confirme a pasta com `Get-ChildItem`; não repita `cd` se já estiver nela. O [manual](docs/MANUAL.pt-BR.md) detalha cada etapa.

## Informações coletadas

| Área | Exemplos |
|---|---|
| Hosts | SO/boot, CPU/memória, NUMA, serviços, QFE, versões de VM, configurações e indícios de reboot |
| VMs | Estado, geração/versão, CPU/memória, integração, discos e cadeia VHD, checkpoints, Replica e medição já habilitada |
| Rede | Adaptadores/IPs, vSwitch, SET, VLAN, guards, MAC, interfaces de gerenciamento, RDMA/VMQ/SR-IOV |
| Segurança | Secure Boot, vTPM/shielding, Device Guard, configuração/conexões SMB |
| Cluster | Nós, grupos, recursos, CSV, redes e quorum |
| Diagnóstico | Eventos limitados por período/canal, BPA existente opcional, achados, cobertura e erros |

Os CSVs contêm todos os registros **efetivamente exportados**, respeitando limites/permissões/timeouts. HTML mostra até 500 linhas por tabela por padrão; sua busca alcança somente as linhas exibidas. Ausência de dados não vira zero nem atestado de saúde. Os manuais explicam cada conjunto, campo, unidade, regra, parâmetro e limitação.

## Saídas e estudo

Cada execução cria uma pasta exclusiva com `report.html`, `report.json`, `csv/` e `MANIFEST-SHA256.txt`. Preserve a pasta completa ou use o ZIP para manter os links CSV. Dados reais podem conter nomes/IPs/caminhos/notas/eventos internos; escolha um diretório com ACL adequada e compartilhe somente por canais autorizados.

- [Manual PT-BR](docs/MANUAL.pt-BR.md): execução, permissões, 54 conjuntos, parâmetros, regras, interpretação, fontes Microsoft e perguntas de apresentação.
- [Manual EN-US](docs/MANUAL.en-US.md): conteúdo completo em inglês.
- [Exemplo PT-BR](examples/pt-BR/report.html) e [EN-US](examples/en-US/report.html): baixar e abrir localmente; o GitHub mostra o código HTML.
- [Evidências de validação](tests/evidence/VALIDATION.json) e [histórico](CHANGELOG.md).

Recriação offline, sem servidores:

```powershell
$arquivo = Read-Host 'Cole o caminho do report.json'
$resultado = .\Export-HyperVHealthReport.ps1 -InputJson $arquivo.Trim('"') -Language en-US -CreateZip
```

O idioma da interface muda; recomendações já armazenadas mantêm o idioma original. Para recomendações totalmente em inglês, colete com `-Language en-US`.

## Validação e autoria

Testes automatizados em Windows PowerShell 5.1 e PowerShell 7 Windows/Linux, com provedores sintéticos; também há teste de job local real com dados fictícios e revisão do HTML no Chromium. **Aceite em Hyper-V/WinRM/cluster/SMB reais permanece necessário.** Não houve consulta a infraestrutura real neste desenvolvimento. Checkpoint/Replica e ausência de alertas não comprovam backup ou conformidade.

Implementação independente FMODEL. Escopo comparado ao arquivo enviado `Get-HyperVReport.ps1 v1.5 (2015)`, atribuído a **Serhat AKINCI**; código legado não incluído. A biblioteca não possui licença geral de reutilização escolhida; ver [orientação do repositório](https://github.com/fmodel7/scripts#readme).
