#!/usr/bin/env bash
# configurar.sh - aplica o ambiente de trabalho do Claude Code no Mac (e no Linux). No Windows, use configurar.ps1.
#   1) Regras de trabalho no CLAUDE.md (num bloco marcado; o resto do arquivo fica intacto)
#   2) Antigravity: configurações do Claude Code (mescladas, sem apagar as da pessoa) e extensões padrão
#   3) Confere o login do Claude (a pasta padrão ~/.claude liga o microfone e o Chrome no painel)
# Pode rodar de novo quando quiser. Tudo que for alterado ganha uma cópia "<arquivo>.antes-ambiente-<data>".
#
#   bash configurar.sh                          -> regras + Antigravity
#   bash configurar.sh --so-regras | --so-antigravity
#   bash configurar.sh --contas 2 --nome-conta2 "Trabalho" --pasta-conta2 "$HOME/Projetos/Empresa" [--pasta-conta2 outra]
#     Conta 1 = ~/.claude (principal). Conta 2 = ~/.claude-<nome>, com perfil próprio no Antigravity ligado às pastas
#     da conta 2 e o comando  claude-<nome>  no terminal (zsh e bash). Para voltar a 1 conta: --contas 1 (nada é apagado).
# Compatível com o bash 3.2 que vem no macOS.

set -u
AQUI="$(cd "$(dirname "$0")/.." && pwd)"          # pasta da skill
DATA="$(date +%Y%m%d-%H%M%S)"
CONTAS=1; NOME2="Trabalho"; PASTAS2=(); SO_REGRAS=0; SO_AG=0
PENDENCIAS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --contas) CONTAS="$2"; shift 2 ;;
    --nome-conta2) NOME2="$2"; shift 2 ;;
    --pasta-conta2) PASTAS2+=("${2%/}"); shift 2 ;;
    --so-regras) SO_REGRAS=1; shift ;;
    --so-antigravity) SO_AG=1; shift ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done
[ "$CONTAS" = 1 ] || [ "$CONTAS" = 2 ] || { echo "--contas precisa ser 1 ou 2" >&2; exit 2; }

passo() { printf '\n\033[36m== %s\033[0m\n' "$1"; }
copia() { [ -f "$1" ] && cp "$1" "$1.antes-ambiente-$DATA" && echo "cópia de segurança: $1.antes-ambiente-$DATA"; return 0; }
pendente() { PENDENCIAS+=("$1"); }
SISTEMA="$(uname -s)"   # Darwin = Mac; Linux

# Contas: a 1 é sempre a pasta padrão; a 2 ganha uma pasta com o nome dela (sem acento/espaço)
# Nome só com letras, números, espaço, hífen e sublinhado: ele vai para dentro dos arquivos do terminal
if [ "$CONTAS" = 2 ] && { [ -z "$NOME2" ] || [ ${#NOME2} -gt 40 ] || printf '%s' "$NOME2" | grep -q "[][\"'\\\$\`;&|<>(){}*?!#~%=+/:,.@^]"; }; then
  echo "Nome da conta 2 inválido: \"$NOME2\". Use só letras, números, espaço, hífen ou sublinhado (até 40)." >&2; exit 2
fi
# iconv do macOS escreve "Sa'ude" para "Saúde": os sinais soltos saem antes de virar hífen (fica igual ao Windows: saude)
SLUG2="$(printf '%s' "$NOME2" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\`^~\"" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"
[ -n "$SLUG2" ] || SLUG2="trabalho"
PASTA1="$HOME/.claude"; PASTA2="$HOME/.claude-$SLUG2"; CMD2="claude-$SLUG2"
if [ "$CONTAS" = 2 ]; then
  for p in ${PASTAS2[@]+"${PASTAS2[@]}"}; do [ -d "$p" ] || { echo "A pasta da conta 2 não existe: $p" >&2; exit 1; }; done
  [ ${#PASTAS2[@]} -gt 0 ] || pendente "Nenhuma pasta foi ligada à conta $NOME2. Rode de novo com --pasta-conta2 \"/caminho/da/pasta\"."
fi

# ---------- 1) Regras ----------
if [ "$SO_AG" = 0 ]; then
  passo 'Regras de trabalho do Claude'
  if [ "$CONTAS" = 2 ]; then DESTINOS=("$PASTA1" "$PASTA2"); elif [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then DESTINOS=("$CLAUDE_CONFIG_DIR"); else DESTINOS=("$PASTA1"); fi
  INI='<!-- >>> ambiente-antigravity >>> -->'; FIM='<!-- <<< ambiente-antigravity <<< -->'
  BLOCO="$(printf '%s\n%s\n%s' "$INI" "$(cat "$AQUI/regras-de-trabalho.md")" "$FIM")"
  for d in "${DESTINOS[@]}"; do
    mkdir -p "$d"; arq="$d/CLAUDE.md"; [ -f "$arq" ] || : > "$arq"
    nI="$(grep -c -x -F "$INI" "$arq")"; nF="$(grep -c -x -F "$FIM" "$arq")"
    lI="$(grep -n -x -F "$INI" "$arq" | head -1 | cut -d: -f1)"; lF="$(grep -n -x -F "$FIM" "$arq" | head -1 | cut -d: -f1)"
    if ! { [ "$nI" = 0 ] && [ "$nF" = 0 ]; } && ! { [ "$nI" = 1 ] && [ "$nF" = 1 ] && [ "$lI" -lt "$lF" ]; }; then
      # Marcadores faltando ou repetidos (bloco apagado pela metade?): não arrisca apagar regras da pessoa
      pendente "Não mexi em $arq porque o bloco do ambiente-antigravity está incompleto ou repetido. Arrume à mão (deixe um início e um fim, ou apague os dois) e rode de novo."
      continue
    fi
    novo="$(BLOCO="$BLOCO" awk -v ini="$INI" -v fim="$FIM" 'BEGIN{bloco=ENVIRON["BLOCO"]}
      $0==ini {dentro=1; if(!feito){print bloco; feito=1}; next}
      $0==fim {dentro=0; next}
      !dentro {print}
      END {if(!feito){ if(NR>0) print ""; print bloco }}' "$arq")"
    if [ "$novo" != "$(cat "$arq")" ]; then copia "$arq"; printf '%s\n' "$novo" > "$arq"; echo "OK: regras em $arq"; else echo "OK: regras já estavam atualizadas em $arq"; fi
  done
fi

# Junta JSON com o que houver: Node, Python ou o JavaScript do próprio macOS
mesclar() {  # $1 settings da pessoa, $2 nossas chaves, $3 CLAUDE_CONFIG_DIR (opcional)
  local r bk="$1.antes-ambiente-$DATA"
  [ -f "$1" ] && cp "$1" "$bk"
  if command -v node >/dev/null 2>&1; then r="$(node "$AQUI/scripts/mesclar-json.js" mesclar "$1" "$2" "${3:-}")"
  elif [ "$SISTEMA" = Darwin ]; then r="$(osascript -l JavaScript "$AQUI/scripts/mesclar-json.js" mesclar "$1" "$2" "${3:-}")"
  elif command -v python3 >/dev/null 2>&1; then
    r="$(python3 - "$1" "$2" "${3:-}" <<'PY'
import json, os, sys
alvo, nossas_arq, cfg = sys.argv[1], sys.argv[2], sys.argv[3]
nossas = json.load(open(nossas_arq, encoding="utf-8"))
if cfg: nossas["claudeCode.environmentVariables"] = [{"name": "CLAUDE_CONFIG_DIR", "value": cfg}]
dela = {}
if os.path.exists(alvo) and open(alvo, encoding="utf-8-sig").read().strip():
    try: dela = json.load(open(alvo, encoding="utf-8-sig"))
    except Exception: print("invalido"); sys.exit(0)
mudou = False
for k, v in nossas.items():
    if dela.get(k) != v: dela[k] = v; mudou = True
if mudou:
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    json.dump(dela, open(alvo, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
print("mudou" if mudou else "igual")
PY
)"
  else r="semferramenta"; fi
  if [ "$r" = mudou ] && [ -f "$bk" ]; then echo "cópia de segurança: $bk"; else rm -f "$bk"; fi
  case "$r" in
    mudou) echo "OK: configurações em $1" ;;
    igual) echo "OK: configurações já estavam aplicadas em $1" ;;
    invalido) pendente "O arquivo $1 tem comentários ou vírgulas sobrando, então não mexi nele. Junte à mão as chaves de: $AQUI/antigravity/settings.json" ;;
    *) pendente "Não achei Node nem Python para juntar as configurações. Instale o Node.js (nodejs.org) e rode de novo." ;;
  esac
}

# ---------- 2) Antigravity ----------
if [ "$SO_REGRAS" = 0 ]; then
  passo 'Antigravity'
  CLI=""
  for c in antigravity-ide antigravity; do command -v "$c" >/dev/null 2>&1 && { CLI="$(command -v "$c")"; break; }; done
  if [ -z "$CLI" ] && [ "$SISTEMA" = Darwin ]; then
    for app in /Applications/Antigravity*.app "$HOME"/Applications/Antigravity*.app; do
      for b in "$app/Contents/Resources/app/bin/antigravity-ide" "$app/Contents/Resources/app/bin/antigravity"; do [ -x "$b" ] && { CLI="$b"; break 2; }; done
    done
  fi
  USERDIR=""
  if [ "$SISTEMA" = Darwin ]; then BASE="$HOME/Library/Application Support"; else BASE="${XDG_CONFIG_HOME:-$HOME/.config}"; fi
  for n in "Antigravity IDE" "Antigravity"; do [ -d "$BASE/$n/User" ] && { USERDIR="$BASE/$n/User"; break; }; done
  if [ -z "$CLI" ]; then
    pendente "Antigravity não encontrado. Instale por https://antigravity.google, abra uma vez e rode este script de novo."
  elif [ -z "$USERDIR" ]; then
    pendente "Abra o Antigravity uma vez (ele cria a pasta de configurações) e rode este script de novo."
  else
    ag() { "$CLI" "$@" 2>/dev/null; }
    lista() { ag --list-extensions "$@" | tr '[:upper:]' '[:lower:]'; }
    instalar_ext() {  # $1 = rótulo; resto = --profile X (opcional)
      local onde="$1"; shift
      local ja; ja="$(lista "$@")"
      while IFS= read -r e || [ -n "$e" ]; do
        e="$(printf '%s' "$e" | tr -d '\r' | tr -d ' ')"; [ -n "$e" ] || continue
        el="$(printf '%s' "$e" | tr '[:upper:]' '[:lower:]')"
        if printf '%s\n' "$ja" | grep -qx "$el"; then echo "$e : já instalada ($onde)"; continue; fi
        ag --install-extension "$e" "$@" >/dev/null
        if lista "$@" | grep -qx "$el"; then echo "$e : instalada ($onde)"; else pendente "Extensão $e não instalou ($onde). Instale pela aba Extensões do Antigravity."; fi
      done < "$AQUI/antigravity/extensoes.txt"
    }
    mesclar "$USERDIR/settings.json" "$AQUI/antigravity/settings.json"
    instalar_ext 'perfil padrão'
    if [ "$CONTAS" = 2 ]; then
      passo "Antigravity: perfil da conta $NOME2"
      # Em segundo plano: se o Antigravity estiver fechado, o comando só voltaria quando ele fechasse
      for p in ${PASTAS2[@]+"${PASTAS2[@]}"}; do ( "$CLI" "$p" --profile "$NOME2" </dev/null >/dev/null 2>&1 & ); echo "Pasta ligada ao perfil $NOME2: $p"; done
      ST="$USERDIR/globalStorage/storage.json"; LOC=""
      for _ in $(seq 1 30); do
        if [ -f "$ST" ]; then
          if command -v node >/dev/null 2>&1; then LOC="$(node "$AQUI/scripts/mesclar-json.js" perfil "$ST" "$NOME2")"
          elif [ "$SISTEMA" = Darwin ]; then LOC="$(osascript -l JavaScript "$AQUI/scripts/mesclar-json.js" perfil "$ST" "$NOME2")"
          elif command -v python3 >/dev/null 2>&1; then LOC="$(python3 -c 'import json,sys
try:
  s=json.load(open(sys.argv[1],encoding="utf-8")); print(next((p["location"] for p in s.get("userDataProfiles",[]) if p.get("name")==sys.argv[2]),""),end="")
except Exception: pass' "$ST" "$NOME2")"
          fi
        fi
        [ -n "$LOC" ] && break; sleep 1
      done
      if [ -z "$LOC" ]; then
        pendente "Não achei o perfil \"$NOME2\" no Antigravity. Crie pelo menu Perfis (engrenagem > Perfis > Novo perfil, vazio), abra a pasta da conta 2 com ele e rode de novo."
      else
        mesclar "$USERDIR/profiles/$LOC/settings.json" "$AQUI/antigravity/settings.json" "$PASTA2"
        instalar_ext "perfil $NOME2" --profile "$NOME2"
      fi
    fi
    pendente 'No Antigravity: Cmd+Shift+P (Ctrl+Shift+P no Linux) > "Reload Window" em cada janela aberta para as configurações valerem.'
  fi
fi

# ---------- 2b) Conta 2: comando no terminal (zsh e bash) ----------
if [ "$CONTAS" = 2 ] && [ "$SO_AG" = 0 ]; then
  passo "Conta $NOME2: comandos no terminal"
  INI_SH='# >>> ambiente-antigravity-contas >>>'; FIM_SH='# <<< ambiente-antigravity-contas <<<'
  BLOCO_SH="$INI_SH
# Duas contas do Claude Code: a principal usa ~/.claude; a \"$NOME2\" usa a própria pasta.
$CMD2() { CLAUDE_CONFIG_DIR=\"$PASTA2\" claude \"\$@\"; }
claude-contas() { echo '== principal (~/.claude)'; env -u CLAUDE_CONFIG_DIR claude auth status --text; echo '== $NOME2 ($PASTA2)'; CLAUDE_CONFIG_DIR=\"$PASTA2\" claude auth status --text; }
$FIM_SH"
  # Mac: zsh (padrão) e, se a pessoa usa bash, o .bash_profile (o Terminal do Mac abre shell de login).
  # Linux: bash (padrão) e o .zshrc se a pessoa usa zsh.
  ARQS_RC=()
  if [ "$SISTEMA" = Darwin ]; then
    ARQS_RC+=("$HOME/.zshrc")
    { [ -f "$HOME/.bash_profile" ] || [ "${SHELL##*/}" = bash ]; } && ARQS_RC+=("$HOME/.bash_profile")
  else
    ARQS_RC+=("$HOME/.bashrc")
    { [ -f "$HOME/.zshrc" ] || [ "${SHELL##*/}" = zsh ]; } && ARQS_RC+=("$HOME/.zshrc")
  fi
  for rc in "${ARQS_RC[@]}"; do
    [ -f "$rc" ] || : > "$rc"
    nI="$(grep -c -x -F "$INI_SH" "$rc")"; nF="$(grep -c -x -F "$FIM_SH" "$rc")"
    if [ "$nI" != "$nF" ] || [ "$nI" -gt 1 ]; then pendente "Não mexi em $rc: o bloco ambiente-antigravity-contas está incompleto ou repetido. Arrume à mão e rode de novo."; continue; fi
    novo="$(awk -v ini="$INI_SH" -v fim="$FIM_SH" '$0==ini{d=1;next} $0==fim{d=0;next} !d{print}' "$rc")"
    if [ -n "$(printf '%s' "$novo" | tr -d '[:space:]')" ]; then novo="$novo"$'\n\n'"$BLOCO_SH"; else novo="$BLOCO_SH"; fi
    if [ "$novo" != "$(cat "$rc")" ]; then copia "$rc"; printf '%s\n' "$novo" > "$rc"; echo "OK: comandos $CMD2 e claude-contas em $rc"; else echo "OK: comandos já estavam em $rc"; fi
  done
fi

# ---------- 3) Login (e o plugin na conta 2) ----------
passo 'Login do Claude (microfone e Chrome)'
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"; [ -n "$CLAUDE_BIN" ] || { [ -x "$HOME/.local/bin/claude" ] && CLAUDE_BIN="$HOME/.local/bin/claude"; }
if [ -z "$CLAUDE_BIN" ]; then
  echo 'Claude Code não encontrado no terminal: o login será feito pelo painel do Claude no Antigravity.'
else
  if [ "$CONTAS" = 2 ] && [ "$SO_AG" = 0 ]; then
    if ! CLAUDE_CONFIG_DIR="$PASTA2" "$CLAUDE_BIN" plugin list 2>/dev/null | grep -q 'ambiente-antigravity@prog-ambiente'; then
      CLAUDE_CONFIG_DIR="$PASTA2" "$CLAUDE_BIN" plugin marketplace add ArthurPr0g/prog-ambiente-claude >/dev/null 2>&1
      if CLAUDE_CONFIG_DIR="$PASTA2" "$CLAUDE_BIN" plugin install ambiente-antigravity@prog-ambiente >/dev/null 2>&1; then echo "OK: plugin instalado também na conta $NOME2"
      else pendente "Plugin não instalou na conta $NOME2: rode  $CMD2 plugin install ambiente-antigravity@prog-ambiente"; fi
    fi
  fi
  confere() {  # $1 rótulo, $2 pasta ("" = padrão), $3 comando de login
    local st
    if [ -n "$2" ]; then st="$(CLAUDE_CONFIG_DIR="$2" "$CLAUDE_BIN" auth status --json 2>/dev/null)"; else st="$(env -u CLAUDE_CONFIG_DIR "$CLAUDE_BIN" auth status --json 2>/dev/null)"; fi
    if printf '%s' "$st" | grep -q '"loggedIn": *true'; then echo "OK: $1 logada"
    elif printf '%s' "$st" | grep -q '"loggedIn"'; then pendente "Entre na $1: num terminal NOVO rode  $3  e depois, no Antigravity, \"Reload Window\"."
    else echo "Não deu para conferir o login da $1."; fi
  }
  confere 'conta principal (é ela que liga o microfone e o Chrome no painel)' '' 'claude auth login'
  [ "$CONTAS" = 2 ] && confere "conta $NOME2" "$PASTA2" "$CMD2 auth login"
fi

printf '\n\033[32mPronto.\033[0m\n'
if [ ${#PENDENCIAS[@]} -gt 0 ]; then
  printf '\033[33mPENDENTE (passos seus):\033[0m\n'
  for p in "${PENDENCIAS[@]}"; do printf '\033[33m - %s\033[0m\n' "$p"; done
fi
exit 0
