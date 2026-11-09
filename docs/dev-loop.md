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

- Os logs do emulador saem no terminal que o iniciou. Para recarregar o código depois de editar, feche e abra o emulador.

## Kindle

- Pelo USB (modo pendrive): `tools/push_to_kindle.sh --usb`, ejetar, e abrir o KOReader no Kindle.
  Em "Mais ferramentas" fica "Contador MTG".
- Pelo SSH (mais rápido, sem cabo): ligar o SSH no KOReader (menu de rede) e usar
  `tools/push_to_kindle.sh --ssh usuario@IP porta`.
- O script nunca mexe em `config.lua`, `version.txt` nem `pending.marker` no aparelho.
