---
name: configurar-ambiente
description: Configura o ambiente de trabalho do Claude Code neste PC — grava as regras de trabalho (português, sem chute, backup local, facilitar passos manuais, fluxo de deploy até o fim) no CLAUDE.md do usuário e deixa o Antigravity pronto com a extensão do Claude, configurações e extensões padrão. Use quando pedirem "configura meu ambiente", "aplica as regras de trabalho", "configura o Antigravity", "deixa igual ao do Arthur", logo depois de instalar o plugin ambiente-antigravity, ou para reaplicar/atualizar as regras.
---

# Configurar o ambiente

O script faz tudo; o seu papel é conduzir a pessoa, pedir o que só ela pode decidir e conferir o resultado.

## Passos

1. **Conte o que vai acontecer** em 3 linhas: regras de trabalho no CLAUDE.md dela (num bloco marcado, sem apagar o que já existe), configurações do Claude no Antigravity e extensões padrão. Tudo que for alterado ganha cópia de segurança.
2. **Pergunte quantas contas do Claude ela usa neste PC** (use a ferramenta de perguntas, com estas opções):
   - **1 conta** (o mais comum): tudo na conta dela. Não precisa de mais nada.
   - **2 contas** (ex.: pessoal + trabalho): pergunte também o **nome da 2ª conta** (ex.: "Trabalho", vira a pasta `~\.claude-trabalho` e o comando `claude-trabalho`) e **quais pastas de projeto abrem com ela** (caminho completo; confira que existem). A conta 1 é a principal, na pasta padrão, e é ela que liga o microfone e o Chrome no painel.
   - Se a pessoa tinha 2 e agora quer 1 (saiu da empresa, por exemplo), rode com `-Contas 1`: nada é apagado. Diga como tirar o perfil antigo: engrenagem > Perfis > excluir o perfil da 2ª conta.
3. **Antigravity instalado?** Confira `%LOCALAPPDATA%\Programs\Antigravity IDE\bin\antigravity-ide.cmd`.
   - Se não existir, **pergunte antes** se pode instalar pelo winget (o comando aceita os termos de licença do Google e da Microsoft Store em nome dela). Só use `-InstalarAntigravity` com o "sim".
4. **Rode** (PowerShell; o caminho é o desta skill):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar.ps1" [-InstalarAntigravity]
   # 2 contas:
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar.ps1" -Contas 2 -NomeConta2 "Trabalho" -PastaConta2 "C:\caminho\pasta1","C:\caminho\pasta2"
   ```
   Opções: `-SoRegras` (só o CLAUDE.md) e `-SoAntigravity`. Com 2 contas, o script abre cada pasta da conta 2 numa janela do Antigravity com o perfil novo: é assim que o perfil é criado e fica ligado à pasta. Avise a pessoa antes.
5. **Confira de verdade**, não confie só na mensagem do script:
   - o CLAUDE.md de cada conta apontada na saída contém o bloco `<!-- >>> ambiente-antigravity >>> -->`;
   - `antigravity-ide.cmd --list-extensions` lista `anthropic.claude-code` (com 2 contas, também `--list-extensions --profile "<nome>"`);
   - com 2 contas: o `settings.json` do perfil (caminho na saída) tem `claudeCode.environmentVariables` com `CLAUDE_CONFIG_DIR` apontando para `~\.claude-<nome>`. A extensão só aceita essa configuração no perfil/usuário, não no `.vscode` da pasta.
6. **Entregue as pendências** que o script listou como passos numerados e curtos (login Google no Antigravity, login de cada conta do Claude, Reload Window). Não faça login nem aceite termos por ela. Se der, abra você mesmo o PowerShell do login (`Start-Process powershell -ArgumentList '-NoExit','-Command','claude auth login'`), para ela só entrar na conta.

## Se der errado
- **Microfone ou Chrome (`@browser`) sumiram do painel do Claude**, mas o chat funciona: a extensão lê o login de `~\.claude`, mesmo que o chat use outra pasta (`CLAUDE_CONFIG_DIR`). Confira com `claude auth status --json` **sem** `CLAUDE_CONFIG_DIR` (`loggedIn` precisa ser `true`). Se for `false`, peça à pessoa para rodar `claude auth login` num PowerShell novo e dar "Reload Window" no Antigravity. Nunca copie `.credentials.json` de uma pasta para outra: o token de renovação muda e derruba a outra.
- `settings.json` com comentários: o script não mexe nele. Junte à mão as chaves de `antigravity/settings.json` (desta skill), mantendo as dela, depois de copiar o arquivo para `settings.json.antes-ambiente-<data>`.
- Extensão que não instalou: costuma ser falta de internet ou o marketplace fora do ar; tente de novo uma vez e, se falhar, deixe como pendência.
- Mac ou Linux: o script é só para Windows. Faça os mesmos passos à mão: o CLAUDE.md fica em `~/.claude/CLAUDE.md` e as configurações do Antigravity em `~/Library/Application Support/Antigravity IDE/User/settings.json` (Mac). Confirme os caminhos antes de escrever.

## Personalizar
As regras estão em `regras-de-trabalho.md`. Para mudar só neste PC, edite o bloco no CLAUDE.md da pessoa; ao rodar o script de novo, o bloco volta ao padrão do plugin.
