---
name: configurar-ambiente
description: Configura o ambiente de trabalho do Claude Code neste computador (Windows, Mac ou Linux) — grava as regras de trabalho (português, sem chute, backup local, facilitar passos manuais, fluxo de deploy até o fim) no CLAUDE.md, deixa o Antigravity pronto com a extensão do Claude, configurações e extensões padrão, configura 1 ou 2 contas do Claude e confere o login de que o microfone e o Chrome dependem. Use quando pedirem "configura meu ambiente", "aplica as regras de trabalho", "configura o Antigravity", "deixa igual ao do Arthur", "quero usar 2 contas do Claude", "voltar a 1 conta", logo depois de instalar o plugin ambiente-antigravity, ou para reaplicar/atualizar as regras.
---

# Configurar o ambiente

O script faz tudo; o seu papel é conduzir a pessoa, pedir o que só ela pode decidir e conferir o resultado.
Fale em português simples. Nunca faça login nem aceite termos por ela sem perguntar.

## Passos

1. **Descubra o sistema**: Windows usa `scripts/configurar.ps1` (PowerShell); Mac e Linux usam `scripts/configurar.sh` (bash).
2. **Conte o que vai acontecer** em 3 linhas: regras de trabalho no CLAUDE.md dela (num bloco marcado, sem apagar o que já existe), configurações do Claude no Antigravity e extensões padrão. Tudo que for alterado ganha cópia de segurança.
3. **Pergunte** (use a ferramenta de perguntas):
   - **Quantas contas do Claude ela usa neste computador.**
     - **1 conta** (o mais comum): tudo na conta dela.
     - **2 contas** (ex.: pessoal + trabalho): pergunte o **nome da 2ª conta** (ex.: "Trabalho" vira a pasta `~/.claude-trabalho` e o comando `claude-trabalho`) e **quais pastas de projeto abrem com ela** (caminho completo; confira que existem). A conta 1 é a principal, na pasta padrão, e é ela que liga o microfone e o Chrome no painel.
     - Tinha 2 e agora quer 1 (saiu da empresa, por exemplo): rode com 1 conta; nada é apagado. Ensine a tirar o perfil antigo: engrenagem > Perfis > excluir o perfil da 2ª conta.
   - **Se quer os simuladores de celular** (Android e iPhone para testar sites). Se sim, depois deste passo a passo siga a skill `testar-no-celular`.
4. **Antigravity instalado?**
   - Windows: `%LOCALAPPDATA%\Programs\Antigravity IDE\bin\antigravity-ide.cmd`, `%ProgramFiles%\Antigravity IDE\bin\antigravity-ide.cmd` ou `antigravity-ide` no PATH. Se não houver, **pergunte antes** se pode instalar pelo winget (o comando aceita os termos de licença em nome dela). Só use `-InstalarAntigravity` com o "sim".
   - Mac/Linux: se não houver, peça para baixar em https://antigravity.google e abrir uma vez (abra a página para ela).
5. **Rode** (o caminho é o desta skill):
   ```
   # Windows
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar.ps1" [-InstalarAntigravity]
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar.ps1" -Contas 2 -NomeConta2 "Trabalho" -PastaConta2 "C:\caminho\pasta1|C:\caminho\pasta2"
   # Mac / Linux
   bash "<pasta desta skill>/scripts/configurar.sh"
   bash "<pasta desta skill>/scripts/configurar.sh" --contas 2 --nome-conta2 "Trabalho" --pasta-conta2 "/caminho/pasta1" --pasta-conta2 "/caminho/pasta2"
   ```
   No Windows, várias pastas da conta 2 vão numa string só, separadas por `|`, sem `\` no fim de cada pasta.
   Opções: só as regras (`-SoRegras` / `--so-regras`) ou só o Antigravity (`-SoAntigravity` / `--so-antigravity`). Com 2 contas, o script abre cada pasta da conta 2 numa janela do Antigravity com o perfil novo: é assim que o perfil é criado e fica ligado à pasta. Avise a pessoa antes.
6. **Confira de verdade**, não confie só na mensagem do script:
   - o CLAUDE.md de cada conta apontada na saída contém o bloco `<!-- >>> ambiente-antigravity >>> -->`;
   - a lista de extensões do Antigravity (`--list-extensions`, e com 2 contas também `--list-extensions --profile "<nome>"`) tem `anthropic.claude-code`;
   - com 2 contas: o `settings.json` do perfil (caminho na saída) tem `claudeCode.environmentVariables` com `CLAUDE_CONFIG_DIR` apontando para `~/.claude-<nome>`. A extensão só aceita essa configuração no perfil/usuário, não no `.vscode` da pasta.
7. **Entregue as pendências** que o script listou, como passos numerados e curtos. Facilite: abra você mesmo o terminal do login, para ela só entrar na conta (Windows: `Start-Process powershell -ArgumentList '-NoExit','-Command','claude auth login'`).

## Se der errado
- **Microfone ou Chrome (`@browser`) sumiram do painel do Claude**, mas o chat funciona: a extensão lê o login de `~/.claude`, mesmo que o chat use outra pasta (`CLAUDE_CONFIG_DIR`). Confira com `claude auth status --json` **sem** `CLAUDE_CONFIG_DIR` (`loggedIn` precisa ser `true`). Se for `false`, peça à pessoa para rodar `claude auth login` num terminal novo e dar "Reload Window". Nunca copie `.credentials.json` de uma pasta para outra: o token de renovação muda e derruba a outra.
- **`settings.json` com comentários**: o script não mexe nele, para não apagar os comentários. Junte à mão as chaves de `antigravity/settings.json` (desta skill), mantendo as dela e os comentários, depois de copiar o arquivo para `settings.json.antes-ambiente-<data>`.
- **Perfil da 2ª conta não encontrado**: crie pelo Antigravity (engrenagem > Perfis > Novo perfil, vazio, com o nome combinado), abra a pasta da conta 2 com ele e rode o script de novo.
- **Extensão que não instalou**: costuma ser internet ou o marketplace fora do ar; tente de novo uma vez e, se falhar, deixe como pendência.
- **Comandos `claude-<nome>` não aparecem**: peça para fechar e abrir o terminal. No Windows eles são `.cmd` em `~\.local\bin` (o script põe essa pasta no PATH do usuário; no Git Bash use `claude-<nome>.cmd`). Precisam do Claude Code de terminal: se o script avisar que falta, **pergunte** se pode instalar (`irm https://claude.ai/install.ps1 | iex` no Windows; `curl -fsSL https://claude.ai/install.sh | bash` no Mac/Linux).
- **Nome da 2ª conta**: só letras, números, espaço, hífen e sublinhado (o script recusa outros caracteres).
- **"Bloco incompleto ou repetido"**: o CLAUDE.md tem só um dos marcadores do bloco, ou dois blocos. Mostre à pessoa e arrume junto com ela (um início e um fim), depois rode de novo.
- **Plugin não instala ("Filename too long")**: a pasta de configuração do Claude está num caminho muito comprido; o Windows limita a 260 caracteres.

## Personalizar
As regras padrão estão em `regras-de-trabalho.md` e vão para dentro do bloco marcado do CLAUDE.md. Quando a pessoa pedir para mudar um comportamento, escreva a regra nova **fora** do bloco (logo abaixo dele): regras dela fora do bloco valem mais e nunca são apagadas. O que está dentro do bloco volta ao padrão quando o script roda de novo.
