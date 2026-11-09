#!/usr/bin/env bash
# Copia lifecounter.koplugin para o Kindle.
#   tools/push_to_kindle.sh --usb [PONTO_DE_MONTAGEM]   (padrao: /media/$USER/Kindle)
#   tools/push_to_kindle.sh --ssh USUARIO@HOST [PORTA]  (precisa do SSH.koplugin ligado no KOReader)
# Nunca envia nem apaga config.lua, version.txt nem pending.marker do aparelho.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lifecounter.koplugin/"
RSYNC_OPTS=(-rltv --delete --exclude 'config.lua' --exclude 'version.txt' --exclude 'pending.marker' --exclude '.*')

case "${1:-}" in
  --usb)
    MNT="${2:-/media/$USER/Kindle}"
    DEST="$MNT/koreader/plugins/lifecounter.koplugin/"
    [ -d "$MNT/koreader/plugins" ] || { echo "Kindle nao encontrado em $MNT (modo USB ligado?)" >&2; exit 1; }
    rsync "${RSYNC_OPTS[@]}" "$SRC" "$DEST"
    KUAL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/kual/lifecounter/"
    if [ -d "$MNT/extensions" ]; then
        rsync -rltv --delete "$KUAL_SRC" "$MNT/extensions/lifecounter/"
    fi
    sync
    echo "Copiado para $DEST. Ejete o Kindle antes de desligar o USB."
    ;;
  --ssh)
    TARGET="${2:?uso: --ssh usuario@host [porta]}"
    PORT="${3:-2222}"
    rsync "${RSYNC_OPTS[@]}" -e "ssh -p $PORT" "$SRC" "$TARGET:/mnt/us/koreader/plugins/lifecounter.koplugin/"
    ;;
  *)
    sed -n '2,5p' "$0" >&2
    exit 2
    ;;
esac
