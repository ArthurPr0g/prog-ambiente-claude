#!/usr/bin/env bash
# instalar-simuladores.sh - simulador de iPhone (WebKit, o motor do Safari) no Mac ou no Linux. No Windows: instalar-simuladores.ps1.
#   bash instalar-simuladores.sh            -> instala/atualiza em ~/.simuladores-celular
# Android no Mac/Linux: use o emulador oficial do Android Studio (developer.android.com/studio) > Device Manager.
# Mac com Xcode: o Simulador oficial da Apple (Safari de verdade) é ainda melhor que esta aproximação.
set -u
ORIGEM="$(cd "$(dirname "$0")" && pwd)"
PASTA="${PASTA_SIMULADORES:-$HOME/.simuladores-celular}"
PEND=()
printf '\n\033[36m== iPhone (Node.js + Playwright + WebKit)\033[0m\n'
mkdir -p "$PASTA"
cp -R "$ORIGEM/celular-ios" "$PASTA/" 2>/dev/null || { echo "Não consegui copiar para $PASTA" >&2; exit 1; }
cp "$0" "$PASTA/" 2>/dev/null
V=0
command -v node >/dev/null 2>&1 && V="$(node --version | sed -e 's/^v//' -e 's/\..*//')"
if [ "$V" -lt 18 ]; then
  if [ "$(uname -s)" = Darwin ]; then PEND+=("Instale o Node.js 18 ou mais novo (nodejs.org, ou  brew install node  se usar Homebrew) e rode de novo.")
  else PEND+=("Instale o Node.js 18 ou mais novo (nodejs.org ou o gerenciador de pacotes da sua distribuição) e rode de novo."); fi
else
  cd "$PASTA/celular-ios" || exit 1
  if npm install --no-fund --no-audit --loglevel=error; then
    # No Linux o WebKit precisa de bibliotecas do sistema: o Playwright mostra o comando (com sudo) se faltar alguma
    if npx --no-install playwright install webkit; then echo OK; else PEND+=("O download do WebKit falhou (internet ou proxy?). Rode de novo."); fi
  else PEND+=("O \"npm install\" falhou (internet ou proxy?). Rode de novo."); fi
fi
printf '\n\033[32mPronto.\033[0m Abrir:  node "%s/celular-ios/abrir-iphone.mjs" "<url>"\n' "$PASTA"
if [ ${#PEND[@]} -gt 0 ]; then printf '\033[33mPENDENTE:\033[0m\n'; for p in "${PEND[@]}"; do printf '\033[33m - %s\033[0m\n' "$p"; done; fi
exit 0
