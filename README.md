# prog-ambiente-claude

O jeito de trabalhar do Arthur Prog com o **Claude Code dentro do Antigravity**, empacotado para qualquer pessoa usar:

- **Regras de trabalho do Claude**: responde em português, não chuta, mantém backup local, facilita os passos manuais e leva cada alteração de projeto até o fim (build → commit → push → deploy conferido).
- **Antigravity pronto**: extensão do Claude Code no painel, configurações e extensões padrão (português, Python, PowerShell, GitHub Actions).

Nada é apagado: as regras entram num bloco marcado do seu `CLAUDE.md`, as configurações do Antigravity são mescladas com as suas, e tudo que muda ganha uma cópia de segurança.

## Como instalar (jeito fácil)

Abra o Claude Code (no Antigravity, no VS Code ou no terminal) e mande:

> instale esse plugin https://github.com/ArthurPr0g/prog-ambiente-claude

O Claude lê as instruções abaixo e faz o resto. No fim, ele te passa uma lista curta do que só você pode fazer (entrar na sua conta Google e na sua conta do Claude).

Se preferir fazer à mão, no Claude Code digite:
```
/plugin marketplace add ArthurPr0g/prog-ambiente-claude
/plugin install ambiente-antigravity@prog-ambiente
```
Depois peça: **"configura meu ambiente"**.

Requisitos: Windows 10/11 e o Claude Code. Se o Antigravity ainda não estiver instalado, o Claude pergunta antes e instala pelo winget.

---

## Para o Claude: como instalar este plugin

Siga na ordem. Fale com a pessoa em português, de forma simples, e não faça login nem aceite termos por ela sem perguntar.

1. **Ache o comando `claude`.** Teste `claude --version`. Se não existir no PATH (comum na extensão do Antigravity ou do VS Code), use o executável da extensão:
   ```powershell
   $claude = (Get-ChildItem "$env:USERPROFILE\.antigravity-ide\extensions","$env:USERPROFILE\.antigravity\extensions","$env:USERPROFILE\.vscode\extensions" -Recurse -Filter claude.exe -ErrorAction SilentlyContinue | Where-Object FullName -like '*anthropic.claude-code*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
   ```
2. **Instale o plugin** (é o mesmo que os comandos `/plugin` acima; pode rodar de novo sem problema):
   ```powershell
   & $claude plugin marketplace add ArthurPr0g/prog-ambiente-claude
   & $claude plugin install ambiente-antigravity@prog-ambiente
   ```
3. **Ache o script instalado**: procure `configurar.ps1` dentro da pasta de plugins da conta em uso (`$env:CLAUDE_CONFIG_DIR` se existir, senão `~\.claude`), em `plugins\cache\prog-ambiente\ambiente-antigravity\<versão>\skills\configurar-ambiente\scripts\`.
4. **Siga o `SKILL.md` que está ao lado do script** (`skills/configurar-ambiente/SKILL.md`): ele diz o que perguntar, como rodar o `configurar.ps1` e como conferir.
5. **No fim**, diga à pessoa para **fechar e abrir o Antigravity** (ou o Claude Code). A partir daí, as regras valem em toda conversa, e "configura meu ambiente" reaplica tudo.

---

## O que fica no seu PC

| O quê | Onde |
|---|---|
| Regras de trabalho | `~\.claude\CLAUDE.md`, entre `<!-- >>> ambiente-antigravity >>> -->` e `<!-- <<< ambiente-antigravity <<< -->` |
| Configurações do Antigravity | `%APPDATA%\Antigravity IDE\User\settings.json` (só as chaves do pacote) |
| Cópias de segurança | ao lado de cada arquivo, como `*.antes-ambiente-<data>` |

**Desfazer:** apague o bloco do `CLAUDE.md` (ou volte a cópia de segurança) e rode `/plugin uninstall ambiente-antigravity@prog-ambiente`.

## Licença
MIT.
