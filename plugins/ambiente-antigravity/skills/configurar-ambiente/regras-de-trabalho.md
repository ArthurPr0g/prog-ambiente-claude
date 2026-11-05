# Regras de trabalho

> Estas são as regras padrão do plugin ambiente-antigravity. **Para mudar um comportamento, escreva a sua regra fora deste bloco** (por exemplo, logo abaixo dele): o que está aqui dentro volta ao padrão quando o plugin é reaplicado. Regras do usuário escritas fora do bloco valem mais do que estas.

## Jeito de trabalhar
- Responda sempre em português do Brasil.
- Prefira editar arquivos existentes em vez de reescrevê-los inteiros, para economizar tokens.
- Quando eu fizer novas solicitações, não desfaça o que já construímos nem as decisões tomadas; só faça isso se o novo pedido exigir.
- Tudo que eu fizer deve ter um backup local (da construção), para eu conseguir acessar os projetos mesmo se mudar de conta.
- Sempre se pergunte: "o que posso fazer para facilitar ainda mais os passos manuais?". Ex.: abrir o navegador já na tela do que preciso fazer e, se conseguir, fazer os passos por mim.
- Nunca chute respostas; sempre se baseie em pesquisas confiáveis e dados.
- Antes de dizer "pronto", confira de verdade: rode, abra a tela, olhe o resultado. Se algo falhou ou foi pulado, diga.
- Se os simuladores de celular estiverem instalados (skill testar-no-celular), confira no Android e no iPhone toda tela que aparece no celular e foi mexida, antes do deploy e de novo no link publicado.
- Quando eu pedir para mudar o seu comportamento, grave a regra nova no meu CLAUDE.md **fora** do bloco do ambiente-antigravity.

## Fluxo de alteração em projeto (siga até o fim, sem esperar eu pedir cada etapa)
1. **Projeto**: identifique a pasta do projeto. Se não souber qual é, pergunte.
2. **Código**: faça a alteração dentro da pasta do projeto.
3. **Banco (só se a alteração mexer no banco)**: crie um arquivo de migration versionado no projeto e aplique essa mesma migration. Prefira mudanças aditivas (novas tabelas/colunas) que não quebrem a versão que está no ar. Nunca rode SQL destrutivo (DROP, TRUNCATE, DELETE/UPDATE sem WHERE) sem me pedir confirmação antes.
4. **Verificação local**: se o package.json tiver script de build, rode `npm run build` e só continue se passar.
5. **Git**: `git add` só dos arquivos que você mudou (evite `git add -A` às cegas: pode levar junto arquivos de outra tarefa ou segredos), `git commit -m "<descrição clara em português>"` e `git push`. Nunca use `--force` nem commite `.env` ou senhas. Se a branch atual não for a de produção (normalmente `main`), me avise antes do push. **Na primeira vez em cada projeto, me pergunte antes do push** (ele pode publicar o site); depois que eu confirmar, siga sozinho nesse projeto.
6. **Deploy**: se o projeto publica sozinho a cada push (ex.: Vercel), acompanhe até ficar pronto; se der erro, leia o log, corrija e volte ao passo 4. Depois abra o link publicado e confira a alteração e o console de erros da página.
7. **Resumo**: me responda com o que mudou, a migration aplicada (se houve) e o link do deploy.
