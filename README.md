# prog-ambiente-claude

O jeito de trabalhar do Arthur Prog com o **Claude Code dentro do Antigravity**, empacotado para qualquer pessoa usar em **Windows, Mac ou Linux**:

- **Regras de trabalho do Claude**: responde em português, não chuta, mantém backup local, facilita os passos manuais e leva cada alteração de projeto até o fim (build → commit → push → deploy conferido).
- **Antigravity pronto**: extensão do Claude Code no painel, configurações e extensões padrão (português, Python, PowerShell, GitHub Actions).
- **1 ou 2 contas do Claude** (ex.: pessoal + trabalho), cada uma no seu canto.
- **Microfone e Chrome funcionando**: confere o login de que o botão de ditado e o Chrome (`@browser`) dependem e avisa se faltar.
- **Simuladores de celular** (opcional): Android com o Chrome de verdade e iPhone com o WebKit, o motor do Safari, para conferir sites no celular.

Nada é apagado: as regras entram num bloco marcado do seu `CLAUDE.md`, as configurações do Antigravity são mescladas com as suas, e tudo que muda ganha uma cópia de segurança. Pode rodar de novo quantas vezes quiser.

## Como instalar

Abra o Claude Code (no Antigravity, no VS Code ou no terminal) e mande:

> instale esse plugin https://github.com/ArthurPr0g/prog-ambiente-claude

O Claude faz o resto e, no fim, passa uma lista curta do que só você pode fazer (entrar nas suas contas).

Se preferir à mão, no Claude Code digite:
```
/plugin marketplace add ArthurPr0g/prog-ambiente-claude
/plugin install ambiente-antigravity@prog-ambiente
```
Depois peça: **"configura meu ambiente"**. Para os simuladores: **"instala os simuladores de celular"**.

## O que precisa ter e o que é instalado

| Programa | Precisa? | Se não tiver |
|---|---|---|
| **Claude Code** | Sim (é por ele que você pede) | Windows: `irm https://claude.ai/install.ps1 \| iex` no PowerShell. Mac/Linux: `curl -fsSL https://claude.ai/install.sh \| bash` |
| **Git** | Sim (o Claude usa para baixar o plugin) | Windows: `winget install Git.Git`. Mac: `xcode-select --install`. Linux: pelo gerenciador de pacotes |
| **Antigravity** | Sim, para a parte do editor | Windows: o Claude **pergunta** e instala pelo winget. Mac/Linux: baixe em [antigravity.google](https://antigravity.google) e abra uma vez |
| **Node.js 18+** | Só para o iPhone simulado | Windows: o Claude pergunta e instala pelo winget. Mac/Linux: [nodejs.org](https://nodejs.org) |
| Python | Opcional (recorte da moldura Samsung) | Sem ele, a moldura fica com o fundo original |

O que **já existe** no seu computador é reaproveitado, não reinstalado: extensões já instaladas, um Android SDK do Android Studio, o Node.js, as suas configurações.

**Tempo:** 5 a 10 minutos (uns 15 se o Antigravity ainda não estiver instalado). Simuladores: iPhone em poucos minutos; Android de 20 a 30 minutos (~2,1 GB de download, ~12 GB no disco).

| | Windows 10/11 (64 bits) | Mac | Linux |
|---|---|---|---|
| Regras, contas, Antigravity, login | ✅ | ✅ | ✅ |
| iPhone simulado (WebKit) | ✅ | ✅ macOS recente | ✅ Ubuntu/Debian |
| Android | ✅ instalado pelo script (Intel/AMD) | Android Studio oficial | Android Studio oficial |

No Windows com processador ARM (Snapdragon), o Android deste pacote é pulado: use o Android Studio. O iPhone simulado usa o WebKit do Playwright, que segue os [requisitos de sistema do Playwright](https://playwright.dev/docs/intro#system-requirements) (em outras distribuições Linux ou num macOS antigo ele pode não abrir).

## 1 ou 2 contas do Claude
O Claude pergunta no começo.
- **1 conta**: tudo na sua conta. É o caso da maioria.
- **2 contas** (ex.: pessoal + trabalho): você diz o nome da 2ª conta e quais pastas de projeto abrem com ela. Essas pastas abrem num **perfil próprio do Antigravity** que usa a 2ª conta; as outras continuam na principal. No terminal ganha os comandos `claude-<nome>` (Claude na 2ª conta) e `claude-contas` (mostra o login das duas). O nome da conta aceita letras, números, espaço e hífen.

Saiu da empresa e quer voltar a 1 conta? Peça "configura meu ambiente com 1 conta". Nada é apagado; depois, se quiser, exclua o perfil da 2ª conta no Antigravity (engrenagem > Perfis).

## Personalizar
As regras são texto comum no seu `CLAUDE.md` (`~/.claude/CLAUDE.md`). Para mudar um comportamento, peça ao Claude ("a partir de agora, responda mais curto") ou escreva a regra **fora** do bloco `<!-- >>> ambiente-antigravity >>> -->`. Regras suas, fora do bloco, valem mais que as do plugin e nunca são apagadas. O que estiver **dentro** do bloco volta ao padrão quando o plugin é reaplicado.

## Se algo der errado
- **Microfone ou Chrome (`@browser`) sumiram**, mas o chat funciona: falta login na pasta padrão do Claude (`~/.claude`), que é onde a extensão procura. Num terminal novo rode `claude auth login` e, no Antigravity, `Reload Window` (Ctrl/Cmd+Shift+P). Ou peça "configura meu ambiente", que ele confere.
- **"settings.json tem comentários"**: o script não mexe em arquivo com comentários, para não apagá-los. Peça ao Claude para juntar as chaves à mão.
- **Android lento ou não liga**: ligue a "Plataforma do Hipervisor do Windows" (o instalador abre a tela) e a virtualização na BIOS, e reinicie.
- **Comandos `claude-<nome>` não aparecem**: feche e abra o terminal. No Windows eles são arquivos `.cmd` em `~\.local\bin` (no Git Bash, digite `claude-<nome>.cmd`); no Mac/Linux, funções no `~/.zshrc`, `~/.bashrc` ou `~/.bash_profile`. Eles precisam do Claude Code de terminal instalado.
- **"Bloco incompleto ou repetido"**: o `CLAUDE.md` tem só um dos marcadores do bloco (ou dois blocos). Deixe um início e um fim, ou apague os dois, e rode de novo. O script não mexe no arquivo assim, para não apagar regras suas.
- **Erro ao baixar**: internet, proxy ou antivírus bloqueando. Rode de novo: o que já foi feito é pulado.

## Desinstalar
1. Rode `/plugin uninstall ambiente-antigravity@prog-ambiente`.
2. No `~/.claude/CLAUDE.md`, apague o bloco entre `<!-- >>> ambiente-antigravity >>> -->` e `<!-- <<< ambiente-antigravity <<< -->` (ou volte a cópia `*.antes-ambiente-*`).
3. Se usou 2 contas: no Antigravity, exclua o perfil da 2ª conta (engrenagem > Perfis); apague `claude-<nome>.cmd` e `claude-contas.cmd` de `~\.local\bin` (Windows) ou o bloco `ambiente-antigravity-contas` do `~/.zshrc`/`~/.bashrc`/`~/.bash_profile` (Mac/Linux). A pasta `~/.claude-<nome>` tem o login e o histórico dessa conta: apague só se não for mais usar.
4. Simuladores:
   - pasta das ferramentas: `%LOCALAPPDATA%\simuladores-celular` (Windows) ou `~/.simuladores-celular` (Mac/Linux);
   - login guardado do iPhone: `%LOCALAPPDATA%\celular-ios` (Windows) ou `~/.celular-ios`;
   - Windows: atalhos em Menu Iniciar > "Simuladores de celular" e o aparelho `Galaxy_S26` em `~\.android\avd` (`Galaxy_S26.avd` e `Galaxy_S26.ini`).
   - **Não apague `%LOCALAPPDATA%\Android\Sdk` se você usa o Android Studio**: é o mesmo SDK dele. Se não usa, pode apagar a pasta `%LOCALAPPDATA%\Android` (ou `C:\Android`, se o seu nome de usuário do Windows tem acento).

---

## Para o Claude: como instalar este plugin

Siga na ordem. Fale com a pessoa em português, de forma simples, e não faça login nem aceite termos por ela sem perguntar.

1. **Ache o comando `claude`.** Teste `claude --version`. Se não existir no PATH (comum na extensão do Antigravity ou do VS Code), use o executável da extensão:
   - Windows (PowerShell):
     ```powershell
     $claude = (Get-ChildItem "$env:USERPROFILE\.antigravity-ide\extensions","$env:USERPROFILE\.antigravity\extensions","$env:USERPROFILE\.vscode\extensions" -Recurse -Filter claude.exe -ErrorAction SilentlyContinue | Where-Object FullName -like '*anthropic.claude-code*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
     ```
   - Mac/Linux: `claude="$(ls -t ~/.antigravity-ide/extensions/anthropic.claude-code-*/resources/native-binary/claude ~/.antigravity/extensions/anthropic.claude-code-*/resources/native-binary/claude ~/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude 2>/dev/null | head -1)"`
2. **Instale o plugin** (pode rodar de novo sem problema):
   ```
   <claude> plugin marketplace add ArthurPr0g/prog-ambiente-claude
   <claude> plugin install ambiente-antigravity@prog-ambiente
   ```
   Se falhar com "git" ou "Filename too long", veja a tabela de requisitos acima.
3. **Siga o `SKILL.md` da skill `configurar-ambiente`** (no cache de plugins da conta em uso: `$CLAUDE_CONFIG_DIR` ou `~/.claude`, em `plugins/cache/prog-ambiente/ambiente-antigravity/<versão>/skills/configurar-ambiente/`). Ele diz o que perguntar (1 ou 2 contas, simuladores), qual script rodar em cada sistema e como conferir.
4. **No fim**, diga à pessoa para recarregar o Antigravity (`Reload Window`). A partir daí, as regras valem em toda conversa, e "configura meu ambiente" reaplica tudo.

---

## English summary
A Claude Code plugin (Windows, macOS, Linux) that sets up a Portuguese-language working style for Claude inside the Antigravity editor: working rules in `CLAUDE.md` (in a marked block; your own rules outside it are kept), Antigravity settings and extensions (merged, with backups), optional second Claude account with its own Antigravity profile, a login check for the mic/Chrome features, and optional mobile simulators (Android emulator on Windows, WebKit-based iPhone on all systems). Install: `/plugin marketplace add ArthurPr0g/prog-ambiente-claude` then `/plugin install ambiente-antigravity@prog-ambiente`, and ask Claude to "configura meu ambiente".

## Licença
MIT.
