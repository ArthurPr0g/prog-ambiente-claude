// Uso do Claude: print da página inteira no WebKit como iPhone + aviso de rolagem lateral.
// Uso: node print-iphone.mjs <url> <saida.png> ["iPhone 15"]
import { webkit, devices } from "playwright";

const [url, saida, aparelho = "iPhone 15"] = process.argv.slice(2);
const navegador = await webkit.launch();
const contexto = await navegador.newContext({ ...devices[aparelho], locale: "pt-BR" });
const pagina = await contexto.newPage();
await pagina.goto(url, { waitUntil: "networkidle" });
// Rola devagar para disparar as animações de entrada
const altura = await pagina.evaluate(() => document.documentElement.scrollHeight);
for (let y = 0; y < altura; y += 400) {
  await pagina.evaluate((v) => window.scrollTo(0, v), y);
  await pagina.waitForTimeout(100);
}
await pagina.evaluate(() => window.scrollTo(0, 0));
await pagina.waitForTimeout(1200);
const medidas = await pagina.evaluate(() => ({
  largura: document.documentElement.clientWidth,
  conteudo: document.documentElement.scrollWidth,
  altura: document.documentElement.scrollHeight,
}));
console.log(JSON.stringify({ aparelho, ...medidas, rolagemLateral: medidas.conteudo > medidas.largura }));
// Página longa: salva em partes de 2500 px (saida-01.png, saida-02.png…)
const base = saida.replace(/\.png$/i, "");
let n = 0;
for (let y = 0; y < medidas.altura; y += 2500) {
  const clip = { x: 0, y, width: medidas.largura, height: Math.min(2500, medidas.altura - y) };
  await pagina.screenshot({ path: `${base}-${String(++n).padStart(2, "0")}.png`, fullPage: true, clip, scale: "css" });
}
console.log("partes:", n);
await navegador.close();
