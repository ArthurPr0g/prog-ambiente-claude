// mesclar-json.js - junta as configurações do pacote ao settings.json da pessoa, sem apagar as dela.
// Roda no Node (node mesclar-json.js ...) ou no JavaScript que vem no macOS (osascript -l JavaScript mesclar-json.js ...).
//
//   mesclar <settings.json da pessoa> <json com as nossas chaves> [CLAUDE_CONFIG_DIR para o perfil]
//       -> imprime "mudou", "igual" ou "invalido" (arquivo com comentários ou quebrado: não é alterado)
//   perfil <storage.json do Antigravity> <nome do perfil>
//       -> imprime a pasta (location) do perfil, ou nada
//
// Regras da junção: chave que a pessoa não tem entra; valor simples é trocado pelo nosso; lista de valores simples
// vira a soma das duas (nada dela some); em claudeCode.environmentVariables só a variável CLAUDE_CONFIG_DIR é
// trocada (as outras, como um proxy, ficam).

function temComentario(texto) {
  // fora de strings: // ou /* */ (o settings.json do editor aceita, mas JSON.parse não)
  var dentro = false, esc = false;
  for (var i = 0; i < texto.length; i++) {
    var c = texto[i];
    if (dentro) { if (esc) esc = false; else if (c === "\\") esc = true; else if (c === '"') dentro = false; continue; }
    if (c === '"') { dentro = true; continue; }
    if (c === "/" && (texto[i + 1] === "/" || texto[i + 1] === "*")) return true;
  }
  return false;
}

function simples(v) { return v === null || typeof v !== "object"; }

function juntar(dela, nossa, chave) {
  if (chave === "claudeCode.environmentVariables" && Array.isArray(dela) && Array.isArray(nossa)) {
    var nomes = {};
    nossa.forEach(function (x) { if (x && x.name) nomes[x.name] = true; });
    return dela.filter(function (x) { return !(x && nomes[x.name]); }).concat(nossa);
  }
  if (Array.isArray(dela) && Array.isArray(nossa) && dela.every(simples) && nossa.every(simples)) {
    var soma = dela.slice();
    nossa.forEach(function (x) { if (soma.indexOf(x) < 0) soma.push(x); });
    return soma;
  }
  return nossa;
}

function mesclar(ler, gravar, args) {
  var alvo = args[0], nossasArq = args[1], configDir = args[2];
  var nossas = JSON.parse(ler(nossasArq));
  if (configDir) nossas["claudeCode.environmentVariables"] = [{ name: "CLAUDE_CONFIG_DIR", value: configDir }];
  var texto = ler(alvo), dela = {};
  if (texto && texto.replace(/^﻿/, "").trim()) {
    texto = texto.replace(/^﻿/, "");
    if (temComentario(texto)) return "invalido";
    try { dela = JSON.parse(texto); } catch (e) { return "invalido"; }
    if (!dela || typeof dela !== "object" || Array.isArray(dela)) return "invalido";
  }
  var mudou = false;
  for (var k in nossas) {
    var novo = (k in dela) ? juntar(dela[k], nossas[k], k) : nossas[k];
    if (JSON.stringify(dela[k]) !== JSON.stringify(novo)) { dela[k] = novo; mudou = true; }
  }
  if (mudou) gravar(alvo, JSON.stringify(dela, null, 4) + "\n");
  return mudou ? "mudou" : "igual";
}

function perfil(ler, args) {
  try {
    var s = JSON.parse(ler(args[0]) || "{}");
    var p = (s.userDataProfiles || []).filter(function (x) { return x.name === args[1]; })[0];
    return p ? p.location : "";
  } catch (e) { return ""; }
}

function executar(ler, gravar, argv) {
  var modo = argv[0], resto = argv.slice(1);
  if (modo === "perfil") return perfil(ler, resto);
  return mesclar(ler, gravar, resto);
}

if (typeof require === "function" && typeof process !== "undefined") {
  var fs = require("fs"), path = require("path");
  var lerN = function (p) { return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : null; };
  var gravarN = function (p, t) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, t); };
  process.stdout.write(executar(lerN, gravarN, process.argv.slice(2)) + "\n");
}

// JavaScript do macOS (osascript): "run" recebe os argumentos e o que ele devolve é impresso
function run(argv) {
  ObjC.import("Foundation");
  var ler = function (p) {
    var s = $.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null);
    return s.isNil() ? null : ObjC.unwrap(s);
  };
  var gravar = function (p, t) {
    var dir = ObjC.unwrap($(p).stringByDeletingLastPathComponent);
    $.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(dir, true, $(), null);
    $(t).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null);
  };
  return executar(ler, gravar, argv);
}
