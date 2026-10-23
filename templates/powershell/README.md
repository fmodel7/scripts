# [NOME DO SCRIPT]

> MODELO PARA PREENCHER. Este arquivo não descreve um script já implementado. Substitua os campos entre colchetes depois de revisar o código. Remova os exemplos que não se aplicam.

**Versão:** [versão real] · **Revisão:** [data]  
**Autor:** F. Model · **FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
**Contato:** [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)

## 1. O que faz

[Descreva o problema e o resultado em linguagem simples. Informe também os limites do escopo.]

## 2. Como funciona

[Explique o fluxo de dados e as etapas. Identifique cmdlets, APIs, arquivos, consultas, verificações e critérios utilizados. Diferencie evidência consultada de verificação executada pelo próprio script.]

## 3. Requisitos

| Item | Requisito real |
|---|---|
| Sistema operacional | [Windows/Linux/macOS e versões verificadas] |
| PowerShell | [versão mínima do código e versão efetivamente testada] |
| Módulos/dependências | [nomes e versões; informar instalação quando necessária] |
| Conexão de rede | [serviços externos utilizados ou nenhuma] |
| Arquivos auxiliares | [pastas/arquivos que precisam ser baixados junto] |

## 4. Permissões e credenciais

[Informar se exige administrador local, papéis no serviço, consentimento, chave ou login. Não confundir privilégios do Windows com RBAC de um serviço.]

[Explicar como fornecer credenciais sem gravar segredo no código ou no histórico. Nunca preencher este modelo com uma chave real.]

## 5. Baixar e preparar

[Indicar a pasta correta, dependências e preparação. Se usar cd, explicar que o usuário não deve repetir o comando se já estiver nessa pasta.]

## 6. Testar antes de usar

[Informar o método real de validação e seu efeito. Se houver mocks, dizer isso. Se não houver modo de simulação, declarar a ausência.]

Não inventar suporte a WhatIf, Preview, DryRun ou SelfTest. Só mostrar parâmetros presentes no código e verificar que o caminho não causa alterações reais.

## 7. Executar no PowerShell e no VSCode

[Fornecer o comando exato após analisar o código. Identificar claramente comandos de consulta e comandos que alteram o sistema.]

Exemplo de formato, **não executável sem substituir e validar**:

```powershell
# MODELO: substituir o arquivo e os parâmetros pelos nomes reais.
pwsh -NoProfile -File .\Nome-Do-Script.ps1
```

[Explicar o que será solicitado ao usuário, como reconhecer conclusão e onde conferir o resultado.]

## 8. Parâmetros

| Parâmetro | Padrão | Obrigatório? | O que faz / efeito |
|---|---|---|---|
| [nome real] | [valor] | [sim/não] | [descrição e limites] |

## 9. O que pode mudar

[Informar arquivos criados/removidos, serviços, registros, destinatários e ações remotas. Informar confirmações e abrangência.]

[Descrever o que ocorre em falhas e se existe recuperação real. Não prometer desfazer, backup ou transação sem implementação.]

## 10. Resultados e relatórios

| Saída | Local/formato | Como interpretar |
|---|---|---|
| [nome real] | [caminho real] | [campos, limites e dados sensíveis] |

## 11. Problemas comuns

| Sintoma | Causa provável | Como verificar/corrigir |
|---|---|---|
| [erro observado] | [causa] | [ação compatível com o código] |

## 12. Evidências e limitações

- Testado em: [ambiente e data].
- Verificações executadas: [comandos e resultados reais].
- Não validado: [cenários pendentes].
- Dependências externas: [limites, cotas e licenças aplicáveis].
- Dados enviados/armazenados: [origem, destino e proteção efetiva].

Teste com mocks não comprova comportamento no serviço real. Evite alegações de 100% de segurança ou eficácia.

## 13. Histórico e créditos

[Registrar mudanças por versão, autoria e referências. Manter avisos/licenças de terceiros quando aplicáveis. Informar a licença efetivamente escolhida, sem presumir que público significa uso irrestrito.]
