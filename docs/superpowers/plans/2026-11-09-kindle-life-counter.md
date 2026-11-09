# Contador de vidas de Magic para Kindle — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um plugin do KOReader (Lua) que serve de placar de vida de commander para 2 a 6 jogadores num Kindle, com botão "Atualizar" que puxa versões novas de um Cloudflare Worker.

**Architecture:** A lógica (regras do jogo, gravação em disco, geometria dos painéis, atualizador) fica em módulos Lua puros em `core/`, sem depender do KOReader e testados no PC. A interface (`ui/`) é fina e só desenha e traduz toques em chamadas ao `core/`. O servidor é um Worker de arquivos estáticos protegido por token; uma ferramenta Python gera o manifesto com hashes.

**Tech Stack:** Lua (LuaJIT, como no KOReader v2025.10), widgets/Blitbuffer do KOReader, Python 3 para a ferramenta de release, Cloudflare Worker (JavaScript) com `wrangler`.

**Spec:** `docs/superpowers/specs/2026-11-09-kindle-life-counter-design.md`

## Global Constraints

- Aparelho: Kindle básico 11ª geração (`KindleBasic4`), firmware 5.18.2, jailbreak AdBreak. Não atualizar o firmware.
- Plataforma: plugin do KOReader v2025.10 em Lua. Nada de toolchain nova.
- Jogadores: de 2 a 6. Vida inicial 40, configurável.
- Por jogador: vida, veneno (letal em 10), dano de comandante recebido de cada oponente (letal em 21 de um mesmo comandante).
- Toque = 1; segurar = 10 (um passo por segurada, não repetição).
- Dano de comandante também tira vida, com o mesmo valor.
- Painéis só em 0° e 180° (jogadores só nos dois lados compridos). Fileira de cima virada a 180°.
- Fora do escopo: Treasure, Experience, Commander tax, Monarch, Initiative, Energy, Dia/Noite, City's Blessing, dados, moeda, perfis, histórico, mais de 6 jogadores.
- O jogo funciona offline; a rede só é usada na atualização, e só a partir da tela inicial.
- Atualização: só HTTPS, endereço fixo, token no cabeçalho `Authorization` (nunca na URL), hash de cada arquivo, rollback automático. O token fica num arquivo de configuração no Kindle, nunca no repositório.
- Não tocar nos outros Workers da conta. Criar o Worker novo e fazer deploy só com o OK explícito do Tales.
- Baixar o emulador do KOReader: confirmar com o Tales o arquivo, a origem e o tamanho antes.
- Commits: identidade local `do dono (repo pessoal)`, sem linha de coautoria nem atribuição a Claude/IA. Conferir a identidade antes do primeiro commit.
- Passos "(com o Tales)" precisam do Kindle na mão: ele tira do modo USB, liga o Wi-Fi etc.

## Review Focus

1. Toques em sequência rápida: cada toque registrado conta uma vez, e um "segurar" não conta também como toque de 1.
2. Arquivo de estado cortado ou corrompido (bateria acabou durante a gravação): o app abre normalmente em "Nova partida", sem travar.
3. Números grandes ou negativos (por exemplo −100 ou 1000): continuam legíveis e dentro do painel.
4. Manifesto ruim, arquivo truncado, caminho com `..`, servidor fora do ar ou Wi-Fi caído: nada é trocado, aparece uma mensagem clara e a partida salva continua intacta.
5. Toque na linha entre painéis, na barra central ou na borda de um painel girado a 180°: vai para o painel e o botão corretos, ou para nenhum.

---

## Estrutura de arquivos

```
kindle-life-counter/
  lifecounter.koplugin/
    _meta.lua                 -- nome e descrição do plugin
    main.lua                  -- entrada: menu, ciclo de vida, liga as telas
    config.example.lua        -- modelo de {url, token}; o config.lua real não vai ao git
    core/game.lua             -- estado e regras da partida
    core/store.lua            -- gravar/ler estado (atômico)
    core/layout.lua           -- geometria dos painéis, zonas e toque
    core/fs.lua               -- acesso a arquivos (real, via lfs)
    core/updater.lua          -- checar, instalar, reverter
    ui/panel.lua              -- desenho de um painel (com rotação)
    ui/board.lua              -- tela de jogo e gestos
    ui/commander.lua          -- tela de dano de comandante
    ui/start.lua              -- tela inicial
  tests/run.lua, tests/helper.lua, tests/test_*.lua
  tools/build_release.py, tools/test_build_release.py, tools/push_to_kindle.sh
  worker/wrangler.toml, worker/src/index.js, worker/test/index.test.js, worker/package.json
  docs/spike-findings.md
```

---

### Task 1: Esqueleto, executor de testes e git

**Files:**
- Create: `tests/run.lua`, `tests/helper.lua`, `tests/test_smoke.lua`, `lifecounter.koplugin/_meta.lua`, `.gitignore`

**Interfaces:**
- Produces: `helper.test(name, fn)` e `helper.eq(actual, expected)` (falha com diff legível); `luajit tests/run.lua` roda todos os `tests/test_*.lua` e sai com código ≠ 0 se algum falhar.

- [ ] **Step 1: Conferir o interpretador.** Run: `which luajit lua5.1`. Expected: pelo menos um caminho. Se nenhum, parar e pedir ao Tales o OK para `sudo apt install luajit`.
- [ ] **Step 2: Escrever `tests/test_smoke.lua`** com o teste `smoke passes` (`eq(1+1, 2)`) e um teste que prova que `helper.eq` falha em tabelas diferentes (via `pcall`).
- [ ] **Step 3: Implementar `tests/helper.lua` e `tests/run.lua`** (descobrir arquivos com `ls`, rodar cada um em `pcall`, imprimir `ok`/`FAIL nome: motivo`, resumo no fim).
- [ ] **Step 4: Rodar.** Run: `luajit tests/run.lua`. Expected: todos `ok`, exit 0. Alterar um valor para confirmar que sai com ≠ 0 e desfazer.
- [ ] **Step 5: `_meta.lua`** com `name = "lifecounter"`, `fullname = "Contador de vidas MTG"`, `description`. `.gitignore`: `release/`, `lifecounter.koplugin/config.lua`, `worker/node_modules/`.
- [ ] **Step 6: `git init`, configurar identidade local conforme as restrições e commitar.** Commit: `chore: scaffold plugin and test runner`.

### Task 2: Emulador do KOReader e ciclo de desenvolvimento

**Files:**
- Create: `tools/push_to_kindle.sh`, `docs/dev-loop.md`

**Interfaces:**
- Produces: um jeito de rodar `lifecounter.koplugin` no emulador do PC (documentado em `docs/dev-loop.md`) e `tools/push_to_kindle.sh` que copia a pasta do plugin para `/mnt/us/koreader/plugins/` do Kindle.

- [ ] **Step 1: (com o Tales) Confirmar o download do emulador:** informar arquivo, origem (release oficial `koreader/koreader` v2025.10 para Linux) e tamanho, e esperar o sim. Baixar para uma pasta nova e vazia, fora do projeto.
- [ ] **Step 2: Rodar o emulador** e abrir o gerenciador de arquivos. Anotar o comando em `docs/dev-loop.md`.
- [ ] **Step 3: Ligar o plugin.** Linkar `lifecounter.koplugin` na pasta de plugins do emulador. Em `main.lua`, registrar uma entrada de menu "Contador MTG" que mostra um `InfoMessage` "olá". Conferir que aparece e funciona.
- [ ] **Step 4: Escrever `tools/push_to_kindle.sh`** com dois modos: `--usb` (copia para `/media/$USER/Kindle/koreader/plugins/`) e `--ssh host` (usa `scp` via o `SSH.koplugin`). Nunca copiar `config.lua` do repo (ele não existe lá).
- [ ] **Step 5: (com o Tales) Testar `--usb`:** copiar, ejetar, abrir no Kindle e ver a entrada de menu. Commit: `feat: dev loop with emulator and push script`.

### Task 3: Protótipo de risco no aparelho (portão)

Código descartável. O resultado é o documento, não o código.

**Files:**
- Create: `docs/spike-findings.md` e um plugin temporário `spike.koplugin/` (não entra no release; apagar ao fim)

**Interfaces:**
- Produces: `docs/spike-findings.md` com as decisões abaixo, que as tasks 7, 8 e 13 usam.

- [ ] **Step 1: Tela mínima** com um número grande e botões − e +. Toque = ±1; segurar = ±10. Rodar no emulador.
- [ ] **Step 2: (com o Tales) Rodar no Kindle** e medir: resolução real da tela; atraso entre toque e número; fantasma depois de ~30 toques e qual modo de atualização (`ui`, `fast`, `partial`) deixa melhor; se `hold` dispara antes ou depois de soltar e se o toque de 1 também dispara ao segurar. Registrar em `docs/spike-findings.md`.
- [ ] **Step 3: Girar um buffer a 180°** e desenhar na tela. Registrar qual chamada do Blitbuffer funciona (`rotatedCopy` ou outra) e o custo visível.
- [ ] **Step 4: Verificar no aparelho:** (a) `ffi/sha2` tem `sha256`; (b) uma requisição HTTPS ao `<outro-worker>.<sua-conta>.workers.dev` funciona com a cadeia EC P-384; (c) `UIManager:restartKOReader()` (ou equivalente) existe nesta versão; (d) o relógio do Kindle valida o certificado.
- [ ] **Step 5: Portão.** Escrever em `spike-findings.md` a decisão `HOLD_MODE = "hold_release" | "hold" | "buttons"` (se o segurar não for confiável: botões "±10" separados) e `REFRESH_MODE`. **Parar e reportar ao Tales** antes de seguir. Apagar `spike.koplugin/`. Commit só do documento: `docs: spike findings`.

### Task 4: Regras do jogo (`core/game.lua`)

**Files:**
- Create: `lifecounter.koplugin/core/game.lua`
- Test: `tests/test_game.lua`

**Interfaces:**
- Produces:
  - `Game.new(player_count: integer, starting_life: integer) -> Game` (erro se contagem fora de 2..6 ou vida < 1)
  - `Game:adjust_life(i: integer, delta: integer)`
  - `Game:adjust_poison(i, delta)` (nunca abaixo de 0)
  - `Game:adjust_commander(target: integer, source: integer, delta: integer) -> integer` (devolve o delta realmente aplicado; a vida do alvo muda por `-aplicado`; erro se `source == target`; nunca abaixo de 0)
  - `Game:status(i) -> nil | "life" | "poison" | "commander"` (vida ≤ 0; veneno ≥ 10; algum comandante ≥ 21; nesta ordem de prioridade)
  - `Game:to_table() -> table` e `Game.from_table(t) -> Game | nil, err` (valida tudo)
  - Campos: `game.players[i] = {life, poison, cmd = {[source]=dano}}`, `game.player_count`, `game.starting_life`

- [ ] **Step 1: Testes que falham:** `new rejects 1 and 7 players`; `new starts everyone at 40 with zero poison`; `adjust_life subtracts and adds, allows negative`; `adjust_poison floors at 0`; `commander damage also removes life`; `commander decrement returns the life`; `commander decrement at 0 changes nothing`; `commander from self errors`; `status is commander at 21 from one source but not 11+10 from two`; `status is poison at 10`; `status priority life over poison`; `from_table rejects bad data` (contagem errada, campo faltando, número negativo de veneno).
- [ ] **Step 2: Rodar:** `luajit tests/run.lua`. Expected: FAIL (módulo não existe).
- [ ] **Step 3: Implementar** conforme as interfaces.
- [ ] **Step 4: Rodar.** Expected: todos `ok`.
- [ ] **Step 5: Commit:** `feat: game rules`.

### Task 5: Gravação do estado (`core/store.lua`)

**Files:**
- Create: `lifecounter.koplugin/core/store.lua`
- Test: `tests/test_store.lua`

**Interfaces:**
- Consumes: `Game:to_table()` e `Game.from_table()` da Task 4.
- Produces: `Store.new(path: string) -> Store`; `store:save(t: table) -> true | nil, err` (escreve em `path..".tmp"` e renomeia); `store:load() -> table | nil, err` (`nil, "missing"` se não existe; se corrompido, move para `path..".corrupt"` e devolve `nil, "corrupt"`). O arquivo é uma tabela Lua com `version = 1`.

- [ ] **Step 1: Testes que falham:** `save then load round-trips a game`; `load on missing file returns nil missing`; `load on truncated file returns nil corrupt and keeps a .corrupt copy`; `load on file from future version returns nil`; `save leaves old file intact if tmp write fails` (simular falha de escrita); `values with negative life and 4 digits round-trip`.
- [ ] **Step 2: Rodar.** Expected: FAIL.
- [ ] **Step 3: Implementar** um serializador pequeno de tabela Lua e leitura com `loadstring` em ambiente vazio (sem acesso a globais).
- [ ] **Step 4: Rodar.** Expected: `ok`.
- [ ] **Step 5: Commit:** `feat: atomic state store`.

### Task 6: Geometria e toque (`core/layout.lua`)

**Files:**
- Create: `lifecounter.koplugin/core/layout.lua`
- Test: `tests/test_layout.lua`

**Interfaces:**
- Produces:
  - `Layout.compute(n: integer, w: integer, h: integer) -> {panels = {{index, x, y, w, h, rotation}...}, center = {x,y,w,h}}` — fileira de cima com `floor(n/2)` painéis e `rotation = 180`; fileira de baixo com `ceil(n/2)` e `rotation = 0`; barra central com altura `0.06 * h`; os retângulos cobrem a tela sem sobrepor. Numeração em sentido horário vendo de cima, começando pelo canto inferior esquerdo: fileira de baixo da esquerda para a direita, depois a de cima da direita para a esquerda (da esquerda para a direita na tela).
  - `Layout.zones(pw: integer, ph: integer) -> {minus, plus, life, poison_minus, poison_value, poison_plus, commander}` (retângulos no quadro do painel em pé)
  - `Layout.hit(layout, x, y) -> nil | {index, lx, ly}` (coordenadas locais no quadro do painel em pé; para 180°, `lx = pw - 1 - (x - px)`, idem `ly`); `nil` para barra central ou fora
  - `Layout.zone_at(pw, ph, lx, ly) -> string | nil` (nome da zona)

- [ ] **Step 1: Testes que falham:** `n=2..6 panel counts per row`; `panels tile screen with no overlap and no gap` (soma das áreas = área menos barra central); `top row rotation 180 bottom 0`; `numbering is clockwise from bottom-left` (para n=4 e n=5); `hit on center bar returns nil`; `hit at the visual top-left of a 180 panel maps to local bottom-right`; `hit on exact boundary between two panels goes to exactly one`; `zone_at covers minus plus life poison commander and nil in gaps`; `zones do not overlap`.
- [ ] **Step 2: Rodar.** Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar.** Expected: `ok`.
- [ ] **Step 5: Commit:** `feat: layout and hit testing`.

### Task 7: Desenho de um painel (`ui/panel.lua`)

**Files:**
- Create: `lifecounter.koplugin/ui/panel.lua`
- Modify: `tests/` (nenhum teste automático; conferência visual no emulador)

**Interfaces:**
- Consumes: `Layout.zones`, `Game` (campos de `players[i]`), e a chamada de rotação do Blitbuffer registrada em `docs/spike-findings.md`.
- Produces: `Panel.render(player: table, status: string|nil, pw: integer, ph: integer) -> Blitbuffer` (desenha o painel em pé: vida grande, − e +, veneno com − e +, botão de comandante, marca "FORA" quando `status ~= nil`); `Panel.paint(bb, rect, rotation, player, status)` (gira a 180° quando `rotation == 180` e copia para `bb`).

- [ ] **Step 1: Implementar `Panel.render`** com o tamanho da fonte do número ajustado para caber em até 4 dígitos mais o sinal dentro de `zones.life` (reduz a fonte até caber; nunca corta).
- [ ] **Step 2: Implementar `Panel.paint`.**
- [ ] **Step 3: Conferir no emulador** com um painel de teste: vida 40, −100, 1000; veneno 0 e 9; estado "FORA"; rotação 0 e 180. Texto legível e dentro do painel em todos. Registrar o resultado no PR/commit.
- [ ] **Step 4: Commit:** `feat: panel rendering with rotation`.

### Task 8: Tela de jogo (`ui/board.lua`)

**Files:**
- Create: `lifecounter.koplugin/ui/board.lua`

**Interfaces:**
- Consumes: `Game`, `Store`, `Layout`, `Panel`, e `HOLD_MODE`/`REFRESH_MODE` de `docs/spike-findings.md`.
- Produces: `Board:new{game=Game, store=Store, on_commander=function(target_index), on_menu=function()} -> widget` (tela cheia). Comportamento: toque em − ou + faz ±1 e segurar faz ±10 (uma vez, sem também contar como toque), nos botões de vida e de veneno; toque em "comandante" chama `on_commander(i)`; toque na barra central chama `on_menu()`. Cada mudança grava no `Store` e atualiza só o retângulo do painel afetado, no modo de atualização do protótipo.

- [ ] **Step 1: Tradução de gestos.** Usar `Layout.hit` e `Layout.zone_at` para escolher a ação; centralizar num método `Board:apply(player_index, zone, big: boolean)` que chama o `Game` e grava.
- [ ] **Step 2: Atualização parcial** só do painel afetado; limpeza completa da tela a cada N mudanças (valor `FULL_REFRESH_EVERY` tirado do protótipo).
- [ ] **Step 3: Teste de lógica do `apply`** em `tests/test_board_apply.lua` com um `Game` e um `Store` falsos: `plus zone adds 1`, `big minus on poison subtracts 10 floored at 0`, `each apply saves once`, `hold never also adds 1`. (Isola `apply` em função pura que não toca no KOReader.)
- [ ] **Step 4: Rodar:** `luajit tests/run.lua`. Expected: `ok`.
- [ ] **Step 5: Conferir no emulador** com 2, 4 e 6 jogadores: toques e segurar, marca de "FORA", sem recarregar a tela inteira a cada toque. Commit: `feat: board screen and gestures`.

### Task 9: Tela de dano de comandante (`ui/commander.lua`)

**Files:**
- Create: `lifecounter.koplugin/ui/commander.lua`
- Test: `tests/test_commander_view.lua` (parte pura)

**Interfaces:**
- Consumes: `Game:adjust_commander`, `Game.players[target].cmd`.
- Produces: `Commander.rows(game, target) -> {{source, damage, lethal}...}` (puro: um item por oponente, em ordem de assento, com `lethal = damage >= 21`); `Commander:new{game, target, store, on_close} -> widget` mostrando uma linha por oponente com − e + (toque 1, segurar 10), a marca de letal e um botão "Voltar".

- [ ] **Step 1: Testes que falham:** `rows lists every opponent but not target`; `rows marks 21 as lethal and 20 as not`; `rows uses 0 for sources with no damage`.
- [ ] **Step 2: Rodar.** Expected: FAIL. **Step 3: Implementar `rows` e o widget.** **Step 4: Rodar.** Expected: `ok`.
- [ ] **Step 5: Conferir no emulador:** somar dano de comandante e ver a vida do alvo cair pelo mesmo valor na tela de jogo ao voltar. Commit: `feat: commander damage screen`.

### Task 10: Tela inicial e ciclo de vida (`ui/start.lua`, `main.lua`)

**Files:**
- Create: `lifecounter.koplugin/ui/start.lua`
- Modify: `lifecounter.koplugin/main.lua`

**Interfaces:**
- Consumes: `Store`, `Game`, `Board`, `Commander`.
- Produces: `Start:new{store, on_continue, on_new(player_count, starting_life), on_update}`; `main.lua` registra "Contador MTG" no menu e abre a tela inicial. A tela inicial mostra "Continuar partida" (só se `store:load()` devolver um jogo válido), "Nova partida" (escolhe jogadores 2..6 e vida inicial, padrão 40; confirma antes de substituir um jogo salvo), e "Atualizar".

- [ ] **Step 1: Implementar o fluxo.** "Reiniciar" na barra central da tela de jogo pede confirmação. Ao abrir, carregar o jogo salvo; se `load` falhar, mostrar só "Nova partida".
- [ ] **Step 2: Evitar o sono durante a partida** com `UIManager:preventStandby()` e liberar ao sair. Ao voltar de suspensão, recarregar do `Store` (o app nunca depende de estar acordado).
- [ ] **Step 3: Conferir no emulador:** novo jogo com 2 e 6 jogadores; fechar o KOReader no meio e reabrir mostra "Continuar" com os mesmos números; corromper o arquivo à mão e ver que abre sem "Continuar". Commit: `feat: start screen and lifecycle`.

### Task 11: Ferramenta de release e Worker

**Files:**
- Create: `tools/build_release.py`, `tools/test_build_release.py`, `worker/wrangler.toml`, `worker/src/index.js`, `worker/test/index.test.js`, `worker/package.json`

**Interfaces:**
- Produces:
  - `build_release.py --version N --out release/` copia o plugin (menos `config.lua` e `tests`) para `release/v1/` e escreve `release/v1/manifest.json` = `{"version": N, "files": [{"path": "core/game.lua", "sha256": "<hex>", "size": <int>}, ...]}` (sem `manifest.json` dentro de `files`; caminhos relativos com `/`, sem `..`).
  - Worker: `export default { fetch(request, env) }`. Sem `Authorization: Bearer <env.UPDATE_TOKEN>` correto (comparação em tempo constante) responde 401 e não revela se o arquivo existe; só aceita GET e HEAD; só serve caminhos que começam por `/v1/`; sem listagem de diretório; `manifest.json` com `Cache-Control: no-store`; os demais arquivos vêm de `env.ASSETS.fetch`.

- [ ] **Step 1: Testes Python que falham:** `manifest hashes match file contents`; `manifest excludes config.lua and tests`; `manifest paths have no dotdot or leading slash`; `version must be a positive integer`.
- [ ] **Step 2: Testes do Worker que falham** (`node --test` com `env.ASSETS` falso): `no token returns 401`; `wrong token returns 401 and same body as missing file`; `valid token serves manifest with no-store`; `POST returns 405`; `path outside /v1/ returns 404`; `directory path returns 404`.
- [ ] **Step 3: Rodar os dois.** Run: `python3 -m unittest tools/test_build_release.py` e `node --test worker/test`. Expected: FAIL.
- [ ] **Step 4: Implementar** os dois. **Step 5: Rodar.** Expected: `ok`.
- [ ] **Step 6: Commit:** `feat: release builder and update worker`. (Nada é publicado aqui.)

### Task 12: Atualizador (`core/updater.lua`, `core/fs.lua`)

**Files:**
- Create: `lifecounter.koplugin/core/updater.lua`, `lifecounter.koplugin/core/fs.lua`
- Test: `tests/test_updater.lua`

**Interfaces:**
- Consumes: formato do manifesto da Task 11; `http_get`, `sha256` e `fs` injetados.
- Produces:
  - `Updater.new{base_url, token, plugin_dir, backup_dir, staging_dir, http_get, sha256, fs} -> Updater`, onde `http_get(url, headers) -> body | nil, err` e `fs` oferece `read, write, mkdirs, rename, remove_tree, exists, list`.
  - `updater:current_version() -> integer` (lê `plugin_dir/version.txt`; 0 se não existe)
  - `updater:check() -> {state="up_to_date"|"available"|"error", version=integer?, manifest=table?, err=string?}`
  - `updater:install(manifest) -> true | nil, err` — baixa tudo para `staging_dir`, confere tamanho e `sha256` de cada arquivo, só então copia a versão atual para `backup_dir`, troca os arquivos, grava `plugin_dir/pending.marker`; qualquer falha antes da troca deixa `plugin_dir` intacta.
  - `updater:mark_boot_ok()` (apaga o marcador); `updater:rollback_if_unfinished() -> boolean` (se `pending.marker` existe ao iniciar, restaura o backup e devolve `true`).
  - `core/fs.lua`: implementação real com `lfs`, mesma interface de `fs`.

- [ ] **Step 1: Testes que falham** (com `fs` em memória e `http_get` falso): `check reports up_to_date when versions equal`; `check reports available with newer version`; `check treats lower server version as up_to_date`; `check sends Authorization Bearer header and never puts token in the url`; `check returns error on 401, timeout, bad json`; `install rejects manifest path with dotdot, absolute path or backslash`; `install aborts and leaves plugin_dir untouched when a hash differs`; `install aborts when a file is missing or truncated`; `install backs up current files and writes pending.marker`; `mark_boot_ok removes marker`; `rollback_if_unfinished restores backup when marker exists`; `rollback_if_unfinished does nothing without marker`; `install while staging_dir has old leftovers cleans them first`.
- [ ] **Step 2: Rodar.** Expected: FAIL.
- [ ] **Step 3: Implementar** `updater.lua` e `fs.lua`. A troca de arquivos usa `rename` dentro do mesmo diretório quando possível.
- [ ] **Step 4: Rodar.** Expected: `ok`.
- [ ] **Step 5: Commit:** `feat: updater with verification and rollback`.

### Task 13: Botão "Atualizar" e configuração

**Files:**
- Create: `lifecounter.koplugin/config.example.lua`
- Modify: `lifecounter.koplugin/main.lua`, `lifecounter.koplugin/ui/start.lua`

**Interfaces:**
- Consumes: `Updater`, `core/fs.lua`, `ffi/sha2` (ou a alternativa registrada no protótipo), `NetworkMgr:runWhenOnline`, a chamada de reinício registrada no protótipo.
- Produces: `config.lua` no Kindle com `return { url = "https://<nome>.<sua-conta>.workers.dev/v1/", token = "..." }` (o repositório só tem `config.example.lua`). O botão "Atualizar" aparece só na tela inicial: espera a rede, chama `check`, mostra "Já está na versão N" ou "Versão N disponível. Instalar?", instala e reinicia o KOReader. Erros mostram mensagem curta (sem rede, sem token, token recusado, hash inválido, relógio errado) e não mexem em nada. No início do plugin: `rollback_if_unfinished()`; depois que a tela inicial abre sem erro, `mark_boot_ok()`.

- [ ] **Step 1: Ligar o `Updater` real** (http via `socket.http`/`ssl.https` com timeout; token só no cabeçalho).
- [ ] **Step 2: Mensagens de erro** para cada falha acima, em português.
- [ ] **Step 3: Teste de ponta a ponta no emulador** contra um servidor local: `python3 -m http.server` falso não serve (sem token), então usar `wrangler dev` na pasta `worker/` com um token de teste. Publicar `release/` v2 localmente e confirmar: atualiza, reinicia, mostra a versão nova; token errado dá mensagem de token recusado; servidor desligado dá "sem rede"; a partida salva continua depois de atualizar.
- [ ] **Step 4: Commit:** `feat: update button and config`.

### Task 14: Publicar e aceitar no aparelho (com o Tales)

**Files:**
- Create: `docs/acceptance.md`

- [ ] **Step 1: Pedir o OK explícito do Tales para criar o Worker novo** na conta Cloudflare dele (nome sugerido: `kindle-life`, separado dos outros Workers). Sem o OK, parar aqui.
- [ ] **Step 2: Criar o Worker e definir o segredo `UPDATE_TOKEN`** (token longo e aleatório gerado na hora, mostrado só ao Tales fora do chat, por exemplo salvo em arquivo com permissão 600). Fazer deploy com `npx wrangler deploy` e publicar `v1`. Conferir com `curl` sem token (401) e com token (200 no manifesto).
- [ ] **Step 3: Escrever `config.lua`** com a URL e o token num arquivo local e copiar para `koreader/plugins/lifecounter.koplugin/` do Kindle via USB (nunca para o repositório). Instalar o plugin com `tools/push_to_kindle.sh --usb`.
- [ ] **Step 4: (com o Tales) Lista de aceitação no Kindle,** registrada em `docs/acceptance.md`: partida de 2, 4 e 6 jogadores; toque e segurar; veneno; dano de comandante tirando vida; "FORA" nos três casos; painéis da fileira de cima de cabeça para baixo e legíveis; fechar e reabrir mantém a partida; Kindle dormindo e voltando mantém a partida; "Nova partida" pede confirmação; jogar sem Wi-Fi funciona.
- [ ] **Step 5: Teste de atualização real.** Publicar `v2` com uma mudança visível, apertar "Atualizar", ver a versão nova. Depois publicar um `v3` com um `main.lua` propositalmente quebrado, atualizar, e confirmar que na abertura seguinte o plugin volta sozinho para a `v2`. Republicar uma `v4` boa.
- [ ] **Step 6: Commit:** `docs: acceptance results`.

---

## Auto-revisão

- **Cobertura da spec:** 2–6 jogadores (4, 6, 10), vida/veneno/comandante (4, 9), toque/segurar (3, 8), painéis girados (6, 7, 8), tela de comandante (9), vida inicial 40 configurável (10), botão Atualizar com hash, token, rollback (11–13), offline (8, 10: o jogo nunca chama a rede), estado persistente e atômico (5), retomar e confirmar "Nova partida" (10), sono (10), protótipo de risco com plano B para o segurar (3), verificações no aparelho (3), emulador com OK (2), deploy com OK (14). Não-objetivos não têm tarefa, de propósito.
- **Consistência de nomes:** `Game`, `Store`, `Layout`, `Panel`, `Board`, `Commander`, `Start`, `Updater`; `adjust_life`, `adjust_poison`, `adjust_commander`, `status`, `zones`, `hit`, `zone_at`, `check`, `install`, `mark_boot_ok`, `rollback_if_unfinished` aparecem iguais onde são usados.
- **Decisão que depende do protótipo:** `HOLD_MODE` e `REFRESH_MODE` (Task 3) entram nas Tasks 8 e 13; se o resultado for `buttons`, a Task 6 ganha uma zona `plus10`/`minus10` por painel antes da Task 8.
