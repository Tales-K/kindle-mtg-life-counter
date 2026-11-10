-- Valores de ajuste que dependem do aparelho. Ver docs/spike-findings.md.
return {
    SMALL_STEP = 1,            -- toque
    BIG_STEP = 10,             -- segurar
    HOLD_MODE = "hold",        -- "hold" (aplica ao detectar o segurar) | "hold_release" | "buttons"
    REFRESH_MODE = "fast",     -- "ui" | "fast" | "partial" (fast escolhido pelo Tales no teste no Kindle)
    OPEN_GUARD_S = 0.4,        -- ignora toques por este tempo depois de abrir uma tela
    FULL_REFRESH_EVERY = 30,   -- limpeza completa da tela a cada N mudancas
    KEEP_AWAKE_S = 30 * 60,    -- Kindle nao dorme na partida ate 30 min sem nenhum toque
    DELTA_S = 3,               -- o "-6" em cima do numero some depois deste tempo sem mudar
}
