# Ciclo de desenvolvimento

## Emulador do KOReader no PC

- Versão: v2025.10 (tarball oficial), em `<koreader-emu>/app/` (fora do projeto).
  O hash do arquivo baixado foi `b83fb359c4844fb9788216cf5e7d551048d465b445275f78762ada13a9cb3fd6`
  (a release não publica checksum).
- O plugin é ligado por link simbólico:
  `<koreader-emu>/app/lib/koreader/plugins/lifecounter.koplugin -> lifecounter.koplugin/`
- Rodar (a janela abre no tamanho do Kindle com as duas variáveis `EMULATE_READER_*`):

```bash
cd <koreader-emu>/app && LIFECOUNTER_AUTOSTART=1 EMULATE_READER_W=1072 EMULATE_READER_H=1448 DISPLAY=:1 ./bin/koreader
```

- `LIFECOUNTER_AUTOSTART=1` abre o app sozinho ao iniciar (gancho só de desenvolvimento em `main.lua`).
- O emulador guarda configurações em `~/.config/koreader` (fora do projeto).
- Captura só da janela do emulador, sem pegar o resto da tela:

```bash
DISPLAY=:1 xwininfo -root -tree | grep -i koreader     # achar o id da janela
python3 tools/screenshot.py saida.png :1 <ID_DA_JANELA>
```

- Se a tela do PC tiver menos de 1448 px de altura, a janela fica cortada. Nesse caso, rode dentro de
  um Xephyr do tamanho do Kindle e capture a raiz dele:

```bash
Xephyr :5 -screen 1072x1448 -no-host-grab &
cd <koreader-emu>/app && KOREADER_WINDOW_POS_X=0 KOREADER_WINDOW_POS_Y=0 DISPLAY=:5 \
  LIFECOUNTER_AUTOSTART=1 EMULATE_READER_W=1072 EMULATE_READER_H=1448 ./bin/koreader
xwd -root -display :5 -silent > tela.xwd   # ou tools/screenshot.py trocando -id por -root
```

- Ganchos de demonstração (só desenvolvimento, em `app.lua`):
  - `LIFECOUNTER_DEMO=<n>` abre direto uma partida de n jogadores com dano de comandante de 2 oponentes
    em J1, veneno, J2 fora por 21 de comandante e J6 fora por vida.
  - `LIFECOUNTER_DEMO_COMMANDER=<dono>:<oponente>[:<toques>]` (junto com o anterior) toca, como um
    jogador, no quadradinho do oponente na miniatura do painel do dono e depois simula toques no campo
    único: `+`/`-` tocar, `H`/`h` segurar em +/−, `o` OK (padrão `++H`). Com `v` no lugar do oponente
    (`1:v`) abre o campo de veneno. O campo gira sozinho se o dono está na fileira de cima.
    Ex.: `4` + `2:1:-o` revive J2 (21 → 20 de J1) e volta ao jogo.
  - `LIFECOUNTER_SIM_TAPS="x:y:segundos,..."` simula toques na tela.
- Os logs do emulador saem no terminal que o iniciou. Para recarregar o código depois de editar, feche e abra o emulador.

## Kindle

- Pelo USB (modo pendrive): `tools/push_to_kindle.sh --usb`, ejetar, e abrir o KOReader no Kindle.
  Em "Mais ferramentas" fica "Contador MTG".
- Pelo SSH (mais rápido, sem cabo): ligar o SSH no KOReader (menu de rede) e usar
  `tools/push_to_kindle.sh --ssh usuario@IP porta`.
- O script nunca mexe em `config.lua`, `version.txt` nem `pending.marker` no aparelho.
