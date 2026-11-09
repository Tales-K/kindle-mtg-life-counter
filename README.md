# Contador MTG para Kindle

Contador de vidas de **Magic: The Gathering** (formato Commander) feito como plugin do
[KOReader](https://github.com/koreader/koreader) para **Kindle com jailbreak**.

A ideia é deixar o Kindle no meio da mesa, no lugar do celular, com cada jogador lendo o próprio
painel virado para o seu lado. Inspirado no LifeTap.

<p align="center">
  <img src="docs/img/seis-jogadores.png" width="270" alt="Partida com 6 jogadores">
  <img src="docs/img/dois-jogadores.png" width="270" alt="Partida com 2 jogadores, um fora por dano de comandante">
  <img src="docs/img/campo-dano.png" width="270" alt="Campo de dano de comandante de J4 em J1">
</p>

> Capturas do emulador do KOReader no tamanho da tela do Kindle (1072 × 1448).

## Recursos

- **2 a 6 jogadores**, com os painéis girados para cada lado da mesa.
- **Toque** soma ou subtrai 1; **segurar** soma ou subtrai 10.
- **Veneno** por jogador: a gota com o número fica sempre à vista embaixo do painel; tocar nela
  abre o campo de veneno (só toque, ±1).
- **Dano de comandante** separado por oponente: embaixo de cada painel, uma miniatura da mesa mostra
  o dano recebido de cada oponente no lugar dele. Tocar no quadradinho de um oponente abre um campo
  em tela cheia, virado para o dono do painel, só com aquele número (toque ±1, segurar ±10).
  O dano tira a mesma vida, e devolver dano devolve a vida.
- **Jogador fora** (vida 0, veneno 10 ou 21 de um mesmo comandante) vira painel preto com caveira,
  e volta ao jogo sozinho se o número for corrigido.
- **Partida salva a cada toque**: fechar o KOReader ou acabar a bateria não perde o jogo
  ("Continuar partida" no menu).
- **Atualização pelo ar** com o botão "Atualizar" do menu:
  - os arquivos vêm de um Cloudflare Worker próprio, que só responde com o token certo;
  - cada arquivo é conferido por SHA-256 contra o manifesto antes de trocar qualquer coisa;
  - a versão anterior fica guardada e volta sozinha (rollback) se a versão nova não abrir.
- Funciona sem rede: Wi-Fi só é preciso para atualizar.

## Instalação

Requisitos: Kindle com jailbreak e KOReader instalado.

1. Copie a pasta `lifecounter.koplugin` para `koreader/plugins/` no Kindle (modo USB).
   O script `tools/push_to_kindle.sh` faz isso por você:

   ```bash
   tools/push_to_kindle.sh --usb                    # padrão: /media/$USER/Kindle
   tools/push_to_kindle.sh --usb /caminho/do/Kindle
   tools/push_to_kindle.sh --ssh usuario@IP 2222   # com o SSH ligado no KOReader
   ```

   No modo USB, se o Kindle tiver a pasta `extensions/` (KUAL), o script também copia
   `kual/lifecounter` para lá. O script nunca envia nem apaga `config.lua`, `version.txt`
   e `pending.marker` do aparelho.

2. Abra o KOReader. O app fica em **Mais ferramentas → Contador MTG**.

Atalhos opcionais:

- **Biblioteca do Kindle**: com o Universal Hotfix (suporte a *scriptlets*), o plugin copia
  `shortcut/contador-mtg.sh` para `documents/` na primeira abertura. Ele aparece na biblioteca
  como um livro com capa própria, e tocar nele abre o KOReader já no contador. Se você apagar o
  atalho, ele não volta. A capa e o script são gerados por `tools/make_shortcut.py`.
- **KUAL**: a entrada `kual/lifecounter` (copiada para `extensions/lifecounter`) abre o KOReader já
  dentro do contador.
- **Gesto**: em Configurações → Toques e gestos, associe um gesto à ação **"Contador MTG"**.

Mais detalhes em [docs/dev-loop.md](docs/dev-loop.md).

## Atualização pelo ar (opcional)

O botão "Atualizar" baixa a versão nova de um Worker seu na Cloudflare. O Worker
(`worker/src/index.js`) serve os arquivos de `release/` como assets estáticos e recusa com 401
qualquer pedido sem o cabeçalho `Authorization: Bearer <token>`, comparando com o segredo
`UPDATE_TOKEN` do Worker. Só aceita `GET`/`HEAD` em caminhos `/v1/...`, e o `manifest.json`
sai com `Cache-Control: no-store`.

### 1. Gerar a release

```bash
python3 tools/build_release.py --version 2    # número inteiro, maior que o instalado
```

Gera `release/v1/` com os arquivos do plugin e um `manifest.json` (versão inteira, caminho,
SHA-256 e tamanho de cada arquivo). Ficam de fora os arquivos que o atualizador nunca troca
(`main.lua`, `_meta.lua`, `core/updater.lua`, `core/fs.lua`) e os privados ou locais
(`config.lua`, `version.txt`, `pending.marker`). A pasta `release/` não vai para o git.

### 2. Publicar o Worker

O `wrangler` não está nas dependências; use via `npx`. Ajuste `name` em `worker/wrangler.toml`
se quiser outro nome.

```bash
cd worker
npx wrangler login
openssl rand -base64 32                    # um jeito de gerar um token
npx wrangler secret put UPDATE_TOKEN       # cole o token quando pedir
npx wrangler deploy                        # publica o Worker e os assets de ../release
```

Rode `build_release.py` antes de cada `wrangler deploy`: os assets são lidos de `../release`
no momento do deploy.

### 3. Configurar o Kindle

Copie `lifecounter.koplugin/config.example.lua` para `config.lua` na pasta do plugin **no Kindle**
e preencha:

```lua
return {
    url = "https://kindle-life.SEU-SUBDOMINIO.workers.dev/v1/",
    token = "COLE-AQUI-O-TOKEN",
}
```

O `config.lua` real está no `.gitignore` e nunca deve ir para o repositório.

## Desenvolvimento

Testes:

```bash
luajit tests/run.lua                               # lógica do plugin (Lua)
python3 -m unittest discover -s tools -p 'test_*.py'   # gerador de release
cd worker && node --test                           # Worker
```

Para testar a interface sem o Kindle, use o emulador do KOReader no PC numa janela do tamanho
da tela do Kindle (1072 × 1448). O passo a passo, incluindo `LIFECOUNTER_AUTOSTART=1` para abrir
o app direto e `tools/screenshot.py` para capturar a janela, está em
[docs/dev-loop.md](docs/dev-loop.md).

Estrutura:

```
lifecounter.koplugin/   plugin do KOReader
  main.lua, app.lua       entrada do plugin, menu e ações
  core/                   regras do jogo, gravação, geometria, atualizador (testáveis no PC)
  ui/                     telas e desenho dos painéis
kual/lifecounter/       entrada opcional no KUAL
worker/                 Cloudflare Worker das atualizações (+ testes)
tools/                  build da release, envio ao Kindle, captura de tela
tests/                  testes em Lua (luajit tests/run.lua)
docs/                   ciclo de desenvolvimento, aceite e notas de projeto
```

## Licença

MIT. Veja [LICENSE](LICENSE).
