// "iPhone" local: abre o site no WebKit (motor do Safari) dentro de uma moldura de
// iPhone 15 com barra de status e barra do Safari (iOS 26). Feche a janela para sair.
// Uso: node abrir-iphone.mjs [url] [densidade]
//   densidade 1 (padrão) = rolagem fluida; 2 ou 3 = mais nítido, porém bem mais lento.
// Limite: é o WebKit (do Playwright), não o Safari do iOS. Pega problemas de layout;
// detalhes do sistema (campos de data, teclado) só no iPhone real.
import { webkit, devices } from "playwright";
import { spawn } from "node:child_process";
import { pathToFileURL, fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
import os from "node:os";

const url = process.argv[2] || "https://www.google.com";
const densidade = Number(process.argv[3] || 1);
const iphone = devices["iPhone 15"];
const aqui = path.dirname(fileURLToPath(import.meta.url));

// Sessão guardada: você faz o login uma vez e o "iPhone" lembra nas próximas aberturas, para o
// Claude conferir as telas com login. Fica só neste computador (Windows: %LOCALAPPDATA%/celular-ios;
// Mac/Linux: ~/.celular-ios), fora de qualquer repositório.
// SEM_SESSAO=1 abre limpo (como um visitante novo), sem ler nem gravar a sessão.
const pastaSessao = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "celular-ios") : path.join(os.homedir(), ".celular-ios");
const arquivoSessao = path.join(pastaSessao, "sessao.json");
const usarSessao = !process.env.SEM_SESSAO;

const navegador = await webkit.launch({ headless: false });
// Sem isMobile: no Windows o modo "mobile" do WebKit ignora a roda do mouse.
// O site recebe 393 px de largura e o user agent de iPhone, como no aparelho.
const contexto = await navegador.newContext({
  viewport: { width: 440, height: 900 },
  deviceScaleFactor: densidade,
  userAgent: iphone.userAgent,
  locale: "pt-BR",
  ...(usarSessao && fs.existsSync(arquivoSessao) ? { storageState: arquivoSessao } : {}),
});
let gravando = null;
const guardarSessao = () => {
  if (!usarSessao || gravando) return;
  gravando = setTimeout(async () => {
    gravando = null;
    try {
      fs.mkdirSync(pastaSessao, { recursive: true });
      await contexto.storageState({ path: arquivoSessao });
    } catch {}
  }, 1500);
};
const pagina = await contexto.newPage();

// Alguns sites proíbem abrir dentro de moldura (X-Frame-Options). Só neste teste
// local, tiramos esse bloqueio do documento que vai dentro do iPhone.
await contexto.route("**/*", async (rota) => {
  const req = rota.request();
  if (req.resourceType() !== "document" || req.frame() === pagina.mainFrame()) return rota.continue();
  try {
    const resp = await rota.fetch();
    const h = { ...resp.headers() };
    delete h["x-frame-options"];
    if (h["content-security-policy"]) h["content-security-policy"] = h["content-security-policy"].replace(/frame-ancestors[^;]*;?/gi, "");
    await rota.fulfill({ response: resp, headers: h });
  } catch {
    await rota.continue();
  }
});

// No iPhone a barra de rolagem não ocupa espaço; no Windows ela roubaria ~15 px do site.
await contexto.addInitScript(() => {
  const css = "::-webkit-scrollbar{width:0!important;height:0!important;background:transparent}";
  const por = () => { const s = document.createElement("style"); s.textContent = css; (document.head || document.documentElement).appendChild(s); };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", por); else por();
});

const site = () => pagina.frames().find((f) => f.parentFrame() === pagina.mainFrame());
await pagina.exposeFunction("safariVoltar", async () => { try { await site()?.evaluate(() => history.back()); } catch {} });
await pagina.exposeFunction("safariAvancar", async () => { try { await site()?.evaluate(() => history.forward()); } catch {} });
await pagina.exposeFunction("safariRecarregar", async () => { try { await site()?.evaluate(() => location.reload()); } catch {} });
await pagina.exposeFunction("safariAbrirNoPc", async () => {
  const u = site()?.url() || "";
  if (!/^https?:\/\//.test(u)) return;
  const [cmd, args] = process.platform === "win32" ? ["rundll32", ["url.dll,FileProtocolHandler", u]] : [process.platform === "darwin" ? "open" : "xdg-open", [u]];
  spawn(cmd, args, { detached: true, stdio: "ignore" }).unref();
});

// A cada página nova: endereço na barra e cor da barra de status igual à do site.
async function atualizar(f) {
  if (f.parentFrame() !== pagina.mainFrame()) return;
  try {
    await f.waitForLoadState("domcontentloaded");
    const info = await f.evaluate(() => {
      const meta = document.querySelector('meta[name="theme-color"]')?.content;
      const bg = (el) => getComputedStyle(el).backgroundColor;
      let cor = meta || bg(document.body);
      if (!meta && (cor === "rgba(0, 0, 0, 0)" || cor === "transparent")) cor = bg(document.documentElement);
      if (cor === "rgba(0, 0, 0, 0)" || cor === "transparent") cor = "#ffffff";
      const c = document.createElement("canvas").getContext("2d");
      c.fillStyle = cor;
      const hex = c.fillStyle.startsWith("#") ? c.fillStyle : "#ffffff";
      const n = parseInt(hex.slice(1), 16);
      const lum = (0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255;
      return { host: location.hostname.replace(/^www\./, ""), cor: hex, escuro: lum < 0.5 };
    });
    await pagina.evaluate((i) => window.atualizarSafari(i.host, i.cor, i.escuro), info);
  } catch {}
}
pagina.on("framenavigated", atualizar);
pagina.on("framenavigated", guardarSessao);

// A moldura é servida NO MESMO ENDEREÇO do site. Aberta como arquivo local, o site ficava "de fora"
// dela e o WebKit bloqueava os cookies ("The operation is insecure"): login nenhum funcionava no iPhone.
let moldura = pathToFileURL(path.join(aqui, "moldura-iphone.html")).href + "?url=" + encodeURIComponent(url);
if (/^https?:\/\//.test(url)) {
  const caminho = "/__moldura-iphone__";
  const html = fs.readFileSync(path.join(aqui, "moldura-iphone.html"), "utf8");
  moldura = new URL(url).origin + caminho + "?url=" + encodeURIComponent(url);
  // Registrada depois da rota geral: a do Playwright que vale é a última.
  await contexto.route((u) => u.pathname === caminho, (rota) => rota.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: html }));
}
await pagina.goto(moldura);
// Modo do Claude: PRINT=<arquivo.png> tira um print da janela e fecha.
if (process.env.PRINT) {
  await pagina.waitForTimeout(5000);
  await pagina.screenshot({ path: process.env.PRINT });
  await navegador.close();
  process.exit(0);
}
await pagina.exposeFunction("fecharIphone", async () => { await navegador.close().catch(() => {}); });
// Mac e Linux: a janela fica normal (o recorte no formato do aparelho usa APIs do Windows).
if (process.platform !== "win32") {
  await pagina.exposeFunction("arrastarInicio", () => {});
  console.log(`iPhone 15 aberto em ${url} (densidade ${densidade}x). Feche a janela para encerrar.`);
  await new Promise((r) => pagina.on("close", r));
  if (usarSessao) await contexto.storageState({ path: arquivoSessao }).catch(() => {});
  await navegador.close();
  process.exit(0);
}
// Só o iPhone na tela: o ajudante tira menu/barras/título, posiciona e recorta a janela
// no formato do aparelho (fundo transparente). Ele fica rodando para o "arrastar".
const ajudante = spawn("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(aqui, "ajustar-janela.ps1")], { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
const log = fs.createWriteStream(path.join(os.tmpdir(), "iphone-ajudante.log"));
ajudante.stdout.pipe(log);
ajudante.stderr.pipe(log);
await new Promise((r) => {
  ajudante.stdout.on("data", (d) => { if (String(d).includes("pronto")) r(); });
  ajudante.on("exit", r);
  setTimeout(r, 25000);
});
const mandar = (cmd) => { try { ajudante.stdin.write(cmd + "\n"); } catch {} };
await pagina.exposeFunction("arrastarInicio", () => mandar("inicio"));
await pagina.waitForTimeout(400);
mandar(await pagina.evaluate(() => window.formaDoAparelho()));
navegador.on("disconnected", () => { try { ajudante.kill(); } catch {} });
console.log(`iPhone 15 aberto em ${url} (densidade ${densidade}x). Feche a janela para encerrar.`);
await new Promise((r) => pagina.on("close", r));
if (usarSessao) await contexto.storageState({ path: arquivoSessao }).catch(() => {});
await navegador.close();
