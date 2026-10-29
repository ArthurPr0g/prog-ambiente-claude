---
name: configurar-ambiente
description: Configura o ambiente de trabalho do Claude Code neste PC — grava as regras de trabalho (português, sem chute, backup local, facilitar passos manuais, fluxo de deploy até o fim) no CLAUDE.md do usuário e deixa o Antigravity pronto com a extensão do Claude, configurações e extensões padrão. Use quando pedirem "configura meu ambiente", "aplica as regras de trabalho", "configura o Antigravity", "deixa igual ao do Arthur", logo depois de instalar o plugin ambiente-antigravity, ou para reaplicar/atualizar as regras.
---

# Configurar o ambiente

O script faz tudo; o seu papel é conduzir a pessoa, pedir o que só ela pode decidir e conferir o resultado.

## Passos

1. **Conte o que vai acontecer** em 3 linhas: regras de trabalho no CLAUDE.md dela (num bloco marcado, sem apagar o que já existe), configurações do Claude no Antigravity e extensões padrão. Tudo que for alterado ganha cópia de segurança.
2. **Antigravity instalado?** Confira `%LOCALAPPDATA%\Programs\Antigravity IDE\bin\antigravity-ide.cmd`.
   - Se não existir, **pergunte antes** se pode instalar pelo winget (o comando aceita os termos de licença do Google e da Microsoft Store em nome dela). Só use `-InstalarAntigravity` com o "sim".
3. **Rode** (PowerShell; o caminho é o desta skill):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar.ps1" [-InstalarAntigravity]
   ```
   Opções: `-SoRegras` (só o CLAUDE.md) e `-SoAntigravity`.
4. **Confira de verdade**, não confie só na mensagem do script:
   - o CLAUDE.md apontado na saída contém o bloco `<!-- >>> ambiente-antigravity >>> -->`;
   - `antigravity-ide.cmd --list-extensions` lista `anthropic.claude-code`.
5. **Entregue as pendências** que o script listou como passos numerados e curtos (login Google no Antigravity, login no Claude pelo painel, reabrir o Antigravity). Não faça login nem aceite termos por ela.

## Se der errado
- `settings.json` com comentários: o script não mexe nele. Junte à mão as chaves de `antigravity/settings.json` (desta skill), mantendo as dela, depois de copiar o arquivo para `settings.json.antes-ambiente-<data>`.
- Extensão que não instalou: costuma ser falta de internet ou o marketplace fora do ar; tente de novo uma vez e, se falhar, deixe como pendência.
- Mac ou Linux: o script é só para Windows. Faça os mesmos passos à mão: o CLAUDE.md fica em `~/.claude/CLAUDE.md` e as configurações do Antigravity em `~/Library/Application Support/Antigravity IDE/User/settings.json` (Mac). Confirme os caminhos antes de escrever.

## Personalizar
As regras estão em `regras-de-trabalho.md`. Para mudar só neste PC, edite o bloco no CLAUDE.md da pessoa; ao rodar o script de novo, o bloco volta ao padrão do plugin.
