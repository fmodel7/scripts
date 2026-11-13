# Manual completo — FMODEL Windows Time 2.0.0

FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO  
F. Model · fmodel@fmodel.com.br · Revisão com assistência de Akira (ChatGPT)  
Edição: 13/11/2026 · [English](MANUAL.en-US.md) · [Início](../README.md)

## 1. Objetivo e arquitetura

Dois scripts independentes configuram o serviço Windows Time (W32Time). Configure-NTP-PDC.ps1 usa fontes NTP manuais no PDC Emulator do domínio raiz da floresta. Configure-Time-DOMHIER.ps1 usa a hierarquia AD nos demais servidores ingressados no domínio, inclusive DCs e PDCs de domínios filhos. Um PDC de domínio filho não é o PDC da raiz da floresta.

DOMHIER é o argumento de w32tm que seleciona a hierarquia do domínio; Type=NT5DS é o modo correspondente observado no Registro. Não significa que todos os computadores consultarão diretamente o PDC raiz. O AD seleciona fontes conforme funções, domínio e topologia.

O script do PDC já contém a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br e e.st1.ntp.br. São fontes solicitadas pelo autor, herdadas do arquivo original, não uma escolha obrigatória ou certificação Microsoft. A disponibilidade atual, termos de uso, latência, localização, adequação e independência dessas fontes não foram verificados. Para redes fora do Brasil, fontes internas aprovadas ou serviços geograficamente adequados podem ser preferíveis.

## 2. Qual arquivo usar

- PDC raiz atual: Configure-NTP-PDC.ps1.
- Outro DC, PDC de domínio filho ou servidor membro: Configure-Time-DOMHIER.ps1.
- Estação Windows 10/11 ou Linux: apenas os testes offline; os scripts operacionais são exclusivos para Windows Server 2016+.
- Workgroup, AD inacessível ou função PDC não identificável: a aplicação é bloqueada, sem opção de forçar.

Cada PS1 contém todo seu mecanismo. Não exige src, módulo ActiveDirectory/RSAT, instalação de módulos, credenciais embutidas ou chave de API. A pasta tests é só para desenvolvimento. A duplicação interna permite distribuir um único PS1; os testes verificam que os mecanismos embutidos são idênticos.

## 3. Requisitos e permissões

Windows Server 2016 ou posterior, processo 64 bits, Windows PowerShell 5.1 ou PowerShell 7, sessão elevada e domínio AD funcional. O serviço W32Time e suas chaves padrão devem existir. O serviço não pode estar desabilitado; o script não muda seu tipo de inicialização.

A execução usa o token atual. Não solicita senha, não concede privilégios e não exige uma função Microsoft 365. Administrador elevado no servidor e permissões de leitura AD, Registro e serviço são necessários. Execute no próprio alvo; não há parâmetro de execução remota ou varredura de servidores.

No PDC, DNS deve resolver todas as fontes. W32Time precisa alcançar as fontes pela rede, normalmente UDP 123; a resolução DNS não testa essa conectividade. Para o cliente W32Time, considere também a porta de origem UDP 123 e as regras de retorno. Regras corporativas, GPO e arquitetura de horário têm precedência sobre um exemplo de laboratório.

## 4. Baixar sem Git

Abra a pasta no GitHub, clique em Windows-Time-v2.0.0.zip e escolha Download raw file. Extraia Tudo. Alternativamente, na página principal fmodel7/scripts, use Code → Download ZIP → Extrair Tudo e abra scripts/configure-ntp-pdc.

Não execute dentro da visualização do ZIP. Um PS1 isolado funciona, mas baixar o pacote também fornece os manuais. Verifique a origem e compare o SHA256 com MANIFEST-SHA256.txt. O manifesto detecta diferenças; não é assinatura digital nem prova independente de autenticidade. Modificar o bloco NTP altera legitimamente o hash.

## 5. Abrir no PowerShell ou VSCode

No Explorador, abra a pasta extraída, clique na barra de endereço, digite powershell e pressione Enter. Para aplicar, a sessão precisa estar elevada: abra PowerShell como Administrador e use Set-Location com o caminho real da pasta. Não repita o nome da pasta se já estiver dentro dela.

```powershell
Get-Location
Get-ChildItem
```

No VSCode: abra como Administrador, File → Open Folder → pasta extraída; confie somente no código que revisou e abra Terminal → New Terminal com perfil PowerShell. A extensão Microsoft PowerShell é útil para edição, mas não é requisito para executar. O terminal herda a elevação do VSCode. Não use dot-sourcing e não selecione um trecho para executar: execute o arquivo pelo nome. No PowerShell 5.1, preserve UTF-8 com BOM ao editar os PS1.

## 6. Testar sem alterar horário

Em PowerShell normal, na pasta da ferramenta:

```powershell
powershell.exe -NoProfile -File .\tests\Test-WindowsTime.ps1
```

Ou, com PowerShell 7 instalado:

```powershell
pwsh -NoProfile -File .\tests\Test-WindowsTime.ps1
```

A suíte analisa a AST e carrega apenas funções; não executa as entradas operacionais. Substitui AD, DNS, Registro, serviço e comandos W32Time por adaptadores sintéticos. Testa também processos PowerShell filhos inofensivos para stdout, falha e timeout real de 30 segundos. Por isso leva mais de 30 segundos. Cria arquivos temporários de relatório/journal e os remove ao terminar. Não exige domínio nem elevação e não altera um PDC ou relógio real.

## 7. Simular no alvo

No PDC raiz, na sessão elevada:

```powershell
.\Configure-NTP-PDC.ps1 -WhatIf
```

Nos outros servidores:

```powershell
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

WhatIf faz pré-validação, incluindo consultas CIM/AD/Registro/serviço e DNS no PDC. Não comprova UDP/NTP, permissões futuras de escrita, backup ou reinício. Não cria pasta de execução, relatório ou backup, não muda W32Time e não solicita ressync. Um alvo incorreto continua bloqueado no WhatIf.

## 8. Executar de verdade

Após revisar o alvo e a janela de alteração, execute apenas o script correspondente:

```powershell
.\Configure-NTP-PDC.ps1
```

```powershell
.\Configure-Time-DOMHIER.ps1
```

Sem parâmetros significa aplicação depois da confirmação. As opções de execução são as apresentadas neste manual. Leia a confirmação e responda Yes somente no alvo e janela corretos. Recusar ou usar WhatIf retorna NotApplied e código 0, indicando nenhuma aplicação, não saúde do horário.

Para automação previamente autorizada, -Confirm:$false dispensa somente a pergunta. Não contorna validações, GPO ou backup. Não é o caminho inicial para alunos. O script é executável local e pode ajustar o relógio por meio do W32Time; não é um agendador ou tarefa recorrente.

## 9. Editar os servidores NTP

No início de Configure-NTP-PDC.ps1, altere somente o array NtpServers para nomes aprovados:

```powershell
$NtpServers = @(
    'a.st1.ntp.br'
    'c.st1.ntp.br'
    'd.st1.ntp.br'
    'e.st1.ntp.br'
)
```

Use 1 a 10 nomes DNS ASCII; nomes internacionais precisam estar em formato punycode. Não informe IP literal, URL, porta, flags ou comandos. O mecanismo normaliza espaços externos e caixa e remove duplicatas. Bloqueia nomes/endereços locais, loopback, não especificados e multicast/broadcast identificados; exige resolução de todos os nomes.

Uma fonte usa 0x8 (cliente NTP); duas usam 0x8 e 0xA (segunda como fallback-only); três ou mais usam 0x8 em todas. O polling permanece adaptativo, sem SpecialPollInterval fixo. Três ou mais fontes adequadas costumam ser preferíveis, mas a contagem não garante independência, confiança ou exatidão. Não há autenticação NTS implementada.

## 10. Todas as opções e constantes

Não há parâmetros próprios. WhatIf e Confirm vêm de SupportsShouldProcess, com impacto High. Parâmetros comuns como Verbose e ErrorAction são da plataforma; o corpo usa tratamento Stop. Há um único conjunto de alterações por confirmação.

Constantes internas: versão 2.0.0; timeout nativo 30 s por processo; espera pelo serviço Running até 30 s; mutex local Global\FMODEL.WindowsTime.Setup; saída LocalApplicationData/FMODEL/WindowsTime/Run-UTC-GUID. Essas esperas não são timeout global: AD, CIM, DNS, confirmação, controle de serviço e gravação em disco podem demorar mais. Não há repetição automática, agendamento, lista remota, senha ou modo de forçar a execução.

## 11. Validação do alvo e política

Get-TimeContext verifica Windows/64 bits, token elevado, ingresso no domínio, Windows Server e build mínimo. CIM fornece o estado local; System.DirectoryServices consulta GetComputerDomain().Forest.RootDomain.PdcRoleOwner. A floresta vem do domínio do computador, e não do usuário interativo. O FQDN local é comparado ao proprietário da função, sem correspondência por regex ou apenas nome curto.

PDC exige DC e coincidência com o PDC raiz; DOMHIER bloqueia esse alvo e aceita outros servidores do domínio. Qualquer chave HKLM:\SOFTWARE\Policies\Microsoft\W32Time, inclusive vazia, bloqueia a aplicação por decisão conservadora do projeto. Isso não prova cobertura de todas as formas de política: uma GPO pode ser aplicada mais tarde. Não apague a chave para contornar o bloqueio; ajuste com a equipe de domínio.

Depois da confirmação, o processo adquire exclusão local, relê o contexto, exporta backup e coleta diagnósticos. Antes da primeira mutação, verifica novamente papel/política e cinco valores selecionados do Registro. Após a aplicação, verifica alvo e configuração. Esses controles reduzem corrida, mas não são transação AD/Registro: FSMO, GPO e outros administradores ainda podem mudar estado entre verificações. O mutex não bloqueia ferramentas externas ou outro computador.

## 12. Alterações realizadas

Primeiro exporta toda a ramificação HKLM\SYSTEM\CurrentControlSet\Services\W32Time com reg.exe. Exige saída zero e arquivo não vazio. Salva HTML/JSON de BackupSaved antes de alterar W32Time. Um registro INTENT é gravado e Flush(true) é chamado antes de cada etapa; COMPLETED só após retorno sem erro. Um INTENT sem COMPLETED significa etapa iniciada ou de resultado desconhecido, não necessariamente que nenhuma mudança ocorreu.

Se W32Time estava parado, inicia-o depois do backup. Nos dois modos define NtpClient.Enabled=1 e AnnounceFlags=10 (0xA, anúncio automático). No PDC também define NtpServer.Enabled=1. Os valores são DWORD. DOMHIER preserva NtpServer.Enabled; não transforma automaticamente um membro em servidor NTP. O serviço mantém o tipo de inicialização anterior.

PDC executa w32tm /config /manualpeerlist:"lista" /syncfromflags:manual /update. DOMHIER executa w32tm /config /syncfromflags:domhier /update. Nomes manuais antigos podem continuar no campo NtpServer após DOMHIER; Type=NT5DS é o modo relevante, e o script não usa essa lista para sincronizar manualmente.

Depois reinicia o serviço sem -Force e espera Running. Executa uma vez w32tm /resync /rediscover e consulta configuration, source, status /verbose e peers. Não usa /monitor de todo o domínio, /reliable:yes incondicional ou /unregister. Não muda firewall, fuso, limites de correção de fase, configuração do hipervisor, ACL ou GPO.

## 13. Processos e tratamento de erros

Os binários vêm de Environment.SystemDirectory, com UseShellExecute=false, argumentos separados por aspas e rejeição de aspas, quebras de linha, NUL e barra final nos argumentos. stdout/stderr são lidos assincronamente. Saída diferente de zero ou timeout gera erro. Após timeout é feita tentativa de terminar o processo; uma operação já entregue ao serviço pode ter ocorrido.

Não há retry automático ou rollback automático. Erro antes de iniciar etapas W32Time é Blocked; depois da fronteira de mutação é FailedAfterMutationPossible. Essa classificação é conservadora: uma falha ao registrar a intenção pode ocorrer antes de uma mudança efetiva. Falha final na gravação do relatório também resulta em código 1; o relatório anterior, backup e journal podem ser os únicos arquivos disponíveis.

## 14. Resultados e códigos de saída

| Resultado | Código | Interpretação |
|---|---|---|
| NotApplied | 0 | WhatIf ou confirmação recusada; sem pasta de execução. |
| Configured | 0 | Configuração local esperada, serviço Running, pedido de ressync aceito e quatro consultas retornaram sem erro nativo. |
| ConfiguredNeedsReview | 2 | Configuração/diagnóstico não confirmou todos os critérios ou ressync falhou/ficou desconhecido. Houve aplicação. |
| Blocked | 1 | Fluxo não iniciou mutação W32Time; pode haver backup/relatório. |
| FailedAfterMutationPossible | 1 | Pode haver mudança parcial; analisar antes de repetir. |

BackupSaved é um estado intermediário persistido, não sucesso final. Falhas iniciais de plataforma, AD, permissão ou parâmetro podem terminar com 1 sem relatório. O processo encerrará com o código: execute como arquivo, não por dot-sourcing. Em um processo filho, consulte LASTEXITCODE na sessão chamadora.

Configured não analisa rótulos localizados, leap indicator, stratum, offset ou idade do sincronismo. O script não certifica saúde, autenticação das fontes, precisão, sincronização recente ou propagação para toda a floresta. Essa simplificação é deliberada; a validação operacional é feita com os diagnósticos e aceite no laboratório. Saída zero de /resync é aceitação do pedido, não prova de precisão.

## 15. Relatórios e proteção dos dados

Após aprovação e criação da pasta, a saída fica no LocalApplicationData da conta elevada que executou o processo, não necessariamente da conta que abriu o Explorador:

- Report.html: leitura no navegador, mensagens PT-BR/EN-US e detalhes expansíveis.
- report.json: contexto anterior/posterior, operador/SID, plano, backup, status e diagnósticos brutos.
- W32Time-before.reg: exportação anterior, somente no caminho aprovado.
- actions.jsonl: intenção/conclusão por etapa, quando a aplicação é iniciada.

O HTML é offline, sem JavaScript ou recursos remotos, e codifica os dados inseridos. As gravações HTML/JSON sobrescrevem os arquivos e não são uma transação atômica; interrupção ou disco cheio pode deixar arquivos incompletos. O journal é gravado separadamente. Abra o caminho exibido no console; a ferramenta não abre um navegador elevado automaticamente.

Os arquivos podem conter domínio, host, IPs, política e identidade. Herdam ACLs da pasta local, sem endurecimento, criptografia ou expurgo automático. Não há telemetria/upload. Não publique relatórios reais nem backups no repositório. Cada execução aprovada cria uma pasta diferente; defina retenção e acesso conforme a empresa.

## 16. Conferência operacional e perguntas frequentes

```powershell
w32tm /query /configuration
w32tm /query /source
w32tm /query /status /verbose
w32tm /query /peers
```

No PDC, confira Type=NTP e a lista aprovada. Em DOMHIER, confira Type=NT5DS. Avalie fonte esperada, último sincronismo bem-sucedido recente, leap indicator sem aviso de não sincronizado, stratum utilizável e logs Windows Time. Rótulos variam com o idioma. CMOS/local clock, VM IC Time Synchronization Provider ou saída sem dados exigem investigação, conforme a arquitetura. A ausência da expressão Local CMOS Clock não demonstra sucesso.

Pergunta: posso usar o DOMHIER em todos os DCs? Nos demais DCs, sim, mas o PDC da raiz deve manter sua fonte externa à hierarquia AD. Não se refere necessariamente à Internet: pode ser um appliance NTP interno aprovado.

Pergunta: vou interromper autenticação? O reinício é do W32Time, mas ajustes de horário podem afetar Kerberos, certificados, logs e aplicações. Planeje janela e aceite com a equipe AD. O script não garante impacto zero.

Pergunta: preciso desativar sincronismo com o host em toda VM? Não. A decisão depende do papel do servidor, plataforma, provedor e orientações do fornecedor/Microsoft. O script registra fabricante/modelo, mas não altera integração de VM nem decide uma política universal.

Pergunta: posso fixar o IP do PDC nos outros servidores? Não é necessário para DOMHIER e isso perde a descoberta pela hierarquia. Alterações de função FSMO devem ser acompanhadas por um procedimento que configure o novo PDC raiz; estes scripts não fazem migração contínua.

## 17. Problemas e recuperação

ExecutionPolicy bloqueia: consulte Get-ExecutionPolicy -List e a política corporativa. Para arquivos baixados e revisados, Unblock-File -LiteralPath .\Configure-NTP-PDC.ps1 ou o equivalente DOMHIER remove a marca de origem; não ignora assinatura exigida ou GPO. Não altere a política global para Unrestricted nem desabilite proteções como solução automática.

Alvo errado: execute no servidor indicado como PDC raiz ou use DOMHIER no servidor adequado. AD/DNS inacessível: investigue descoberta, DNS e autenticação; o script não força um papel não comprovado. Política presente: administre W32Time por GPO com escopo correto. Serviço desabilitado: confirme a configuração com a equipe responsável, sem alterar o startup type indiscriminadamente.

Ressync sem dados ou fonte inesperada: examine DNS, caminho UDP 123, fontes aprovadas, eventos W32Time, provedor de VM e limites de correção de fase. Um stripchart pode ajudar no diagnóstico, mas usa porta de origem efêmera e não prova o mesmo caminho UDP do serviço; não conclua conectividade a partir de ping. Não há ressync repetido automático.

Falha parcial: preserve pasta, backup e journal, consulte o estado atual e coordene recuperação autorizada. O backup contém toda a ramificação e pode incluir valores adicionais de provedores. Não importe cegamente. Uma importação aprovada por reg.exe import requer análise de GPO/ACL/valores, aplicação ao serviço e nova verificação; não restaura automaticamente estado do serviço, FSMO, GPO ou horário anterior. Não há comando de rollback universal seguro. Antes de repetir, determine qual etapa foi concluída e se a função PDC mudou.

## 18. Testes e aceite

O pacote contém dois scripts operacionais independentes e sua documentação. Use Configure-NTP-PDC.ps1 no PDC raiz e Configure-Time-DOMHIER.ps1 nos demais servidores. A consulta sem aplicação é feita com -WhatIf. Cada PS1 contém todo o mecanismo necessário.

Os testes verificam parser PS5.1+, requisitos, mecanismos iguais, alvos, GPO, serviço, normalização/flags de peers, endereços proibidos, corrida de estado, backup obrigatório, confirmação, journal, HTML, verificação local, falhas de comando e timeout real de processo filho. As 19 simulações não substituem um laboratório AD real. Veja TESTING.pt-BR.md e EVIDENCE.json para resultados e limites exatos.

Aceite autorizado: identificar papéis atuais; salvar configuração/logs e ponto de recuperação adequado; revisar peers e GPO; testar WhatIf no PDC raiz e num membro; confirmar bloqueio cruzado; aplicar primeiro no PDC em janela aprovada; verificar dados atuais e eventos; aplicar DOMHIER num membro de laboratório; verificar NT5DS e fonte; observar estabilidade antes de expandir por GPO. Repita o planejamento após transferência FSMO. Nenhum teste de desenvolvimento configurou um PDC real.

## 19. Referências

As orientações embasam arquitetura e decisões, mas o projeto não é certificado ou endossado pela Microsoft.

- Windows Time tools and settings: https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings
- Authoritative time server e AnnounceFlags: https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server
- Funcionamento da hierarquia: https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works
- Hyper-V integration services: https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services
- Azure e fontes externas: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration
- Guia do provedor ntp.br: https://ntp.br/guia/windows/
