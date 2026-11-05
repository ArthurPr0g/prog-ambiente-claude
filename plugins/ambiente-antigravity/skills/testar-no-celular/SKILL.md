---
name: testar-no-celular
description: Instala e usa os simuladores de celular (Android com o Chrome de verdade e iPhone aproximado com WebKit, o motor do Safari) para conferir se um site ficou bom no celular, com prints e checagem de rolagem lateral. Use quando pedirem "instala os simuladores", "testa no celular", "como fica no iPhone/Android", "confere no mobile", ou sempre que você alterar algo que aparece no celular e os simuladores estiverem instalados (confira antes do deploy e de novo no link publicado).
---

# Testar no celular

As ferramentas ficam numa pasta fixa depois de instaladas (chamada de `<sim>` abaixo): Windows `%LOCALAPPDATA%\simuladores-celular`; Mac/Linux `~/.simuladores-celular`.
Se essa pasta não existir, os simuladores ainda não foram instalados.

## Instalar (uma vez)
**Windows (64 bits, Intel/AMD):** Android e iPhone.
1. Explique em 2 linhas: Android (~2,1 GB de download, 20 a 30 min, uns 12 GB no disco) e iPhone (~150 MB, poucos minutos). Pergunte quais ela quer.
2. Se faltar o Node.js (iPhone), **pergunte antes** se pode instalar pelo winget (aceita os termos em nome dela). Só passe `-InstalarFaltantes` com o "sim".
3. Rode (o caminho é o desta skill), de preferência numa janela visível, porque demora:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\ferramentas\instalar-simuladores.ps1" [-SoIphone | -SoAndroid] [-InstalarFaltantes]
   ```
4. Entregue as pendências que o script listar. A mais comum é ligar a **Plataforma do Hipervisor do Windows** (o script abre a tela; pede reiniciar o PC). Moldura da Samsung é opcional. O que já existe (ex.: Android SDK do Android Studio) é reaproveitado.

**Mac e Linux:** iPhone pelo script; Android pelo Android Studio.
1. `bash "<pasta desta skill>/ferramentas/instalar-simuladores.sh"` (precisa do Node.js 18+; se faltar, o script diz como instalar).
2. Android: oriente a instalar o Android Studio oficial (developer.android.com/studio) e criar um aparelho no Device Manager (ex.: Pixel, Android 15 com Google Play). No Mac com Xcode, o Simulador oficial da Apple (Safari de verdade) é ainda melhor que o iPhone aproximado.
3. Windows com processador ARM: mesmo caminho do Android Studio; o script pula o Android.

## Abrir
- **Android (Windows):** `powershell -NoProfile -ExecutionPolicy Bypass -File "<sim>\celular-android\abrir-celular.ps1" "<url>"`. Se já estiver aberto, só abre a URL no Chrome. Na primeira vez leva de 1 a 3 min para ligar.
- **iPhone:** `node "<sim>\celular-ios\abrir-iphone.mjs" "<url>"` (rode dentro de `<sim>\celular-ios`). Área do site 393 × 659, como o Safari do iPhone 15. Clique no endereço para digitar outro site.
- Windows: atalhos no Menu Iniciar, pasta "Simuladores de celular". No Mac/Linux a janela do iPhone fica com a borda normal do sistema (o recorte no formato do aparelho é só no Windows).

## Conferir (uso do Claude)
- **Print da página inteira no iPhone + aviso de rolagem lateral:** `node "<sim>\celular-ios\print-iphone.mjs" <url> <saida.png>` (salva em partes de 2500 px).
- **Print da janela do iPhone:** `$env:PRINT="<arquivo.png>"; node abrir-iphone.mjs "<url>"; $env:PRINT=""`.
- **Android pelo adb** (`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`; se o nome do usuário do Windows tiver acento, `C:\Android\Sdk\platform-tools\adb.exe`):
  - sempre com `-e` (só o emulador; com um celular de verdade no cabo, sem `-e` dá "more than one device");
  - print: `adb -e shell screencap -p /sdcard/c.png` e depois `adb -e pull /sdcard/c.png <arquivo>` (nunca `adb exec-out screencap > arquivo` no PowerShell: corrompe o PNG);
  - tocar: `adb -e shell input tap X Y`; rolar: `adb -e shell input swipe 540 1800 540 600 300`;
  - abrir URL: `adb -e shell am start -a android.intent.action.VIEW -d <url> com.android.chrome`.
- Para print com moldura, use só a janela `qemu-system-x86_64`, nunca a tela inteira: ela pega outras janelas da pessoa.

## O que olhar em cada tela
- Nada passa da largura (sem rolagem para os lados).
- Margens laterais de ~16 a 20 px; nenhuma palavra cortada; botões fáceis de tocar (mínimo 44 px).
- Botões fixos (WhatsApp, menus) não cobrem conteúdo importante.
- Rolagem fluida no Android. No iPhone simulado a fluidez não vale como medida.

## Telas com login
- A pessoa faz o login **uma vez** em cada simulador; você não digita senha nem código, e não mexe em telas de conta.
- Android: o Chrome do emulador guarda a sessão sozinho. Na **primeira abertura**, o Chrome mostra boas-vindas e termos: isso é da pessoa (você não aceita termos por ela); peça para ela passar por essas telas uma vez.
- iPhone: a sessão fica em `%LOCALAPPDATA%\celular-ios\sessao.json` (só neste PC). Para abrir como visitante novo: `SEM_SESSAO=1`.
- "Entrar com Google" não funciona no iPhone simulado: o Google bloqueia navegador automatizado. Use e-mail e senha ali, ou teste esse login no Android.

## Limites
O iPhone é o WebKit do Windows, não o Safari do iOS: serve para layout. Campos de data, teclado e fontes do sistema só num iPhone de verdade.
