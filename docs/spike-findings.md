# Protótipo de risco (Task 3) — resultados

Plugin descartável `spike.koplugin/` (ignorado pelo git; apagar ao fim da Task 3).
Entradas no menu do KOReader, em "Mais ferramentas": **Spike: contador** e **Spike: diagnóstico**.

## Já verificado no emulador (PC)

- Girar um buffer a 180°: `buffer:rotatedCopy(180)` funciona; texto girado fica legível e na posição certa.
- Texto grande e caixas: `TextWidget:paintTo(bb, x, y)` em um buffer próprio, depois `bb:blitFrom(...)`.
- Gestos simulados chegam ao widget: `tap` e `hold` (e `hold_release`) disparam `onTap`, `onHold`, `onHoldRelease` com `ges.pos`.
- Módulos que existem no código do KOReader v2025.10: `ffi/sha2` (`sha256`), `json` (rapidjson), `UIManager:restartKOReader`, `NetworkMgr:runWhenOnline`.
- No emulador, `EMULATE_READER_H=1448` não cabe na tela: a janela sai com 1043 px de altura. Para conferir layout usar uma janela menor com a mesma proporção (por exemplo 720×972).

## Medido no Kindle (diagnóstico, 2026-11-09)

- Tela **1074×1448, 300 dpi**; modelo `kindlebasic4` (Kindle básico 11ª geração).
- `sha256(abc)` correto; `json` ok; `UIManager.restartKOReader` existe; hora do aparelho correta.
- **HTTPS ao `workers.dev` funciona no aparelho** (handshake com a cadeia EC P-384 aceito; status 404 porque a rota `/` de outro Worker já existente não existe). Isso resolve o item "confirmar no aparelho" do design.

## Medido no Kindle (contador)

- **Segurar para 10 e tocar para 1: funcionaram em todas as tentativas** (relato do Tales). `HOLD_MODE = "hold"` fica como está.
- Modo de atualização `fast` foi o melhor ("ficou excelente").

## (antigo) A medir no Kindle (contador)

1. **Resolução real** da tela e modelo (linha "tela ... modelo" do diagnóstico).
2. **Atraso toque → número** e **fantasma** depois de ~30 toques, em cada modo de atualização (botão "modo": ui / fast / partial).
3. **Ordem dos eventos ao segurar:** o log na tela mostra `hold`, `hold_release` e se um `tap` também dispara. Anotar se o "segurar" é confiável (0 a 10 tentativas certas).
4. **Diagnóstico:** `sha256(abc) ok`, `json ok`, `restartKOReader: function`, hora certa, e a linha do HTTPS (`HTTPS ok, status N` ou o erro).

## Decisões (preencher depois das medidas)

- `HOLD_MODE` = **`hold`** (aplica ao detectar o segurar; confiável em todas as tentativas do Tales).
- `REFRESH_MODE` = **`fast`** (decidido pelo Tales: "ficou excelente" no teste no Kindle). `FULL_REFRESH_EVERY` = 30 por enquanto.
