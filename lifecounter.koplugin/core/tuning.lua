-- Valores de ajuste que dependem do aparelho. Ver docs/spike-findings.md.
return {
    SMALL_STEP = 1,            -- toque
    BIG_STEP = 10,             -- segurar
    HOLD_MODE = "hold",        -- "hold" (aplica ao detectar o segurar) | "hold_release" | "buttons"
    REFRESH_MODE = "fast",     -- "ui" | "fast" | "partial" (fast escolhido pelo Tales no teste no Kindle)
    OPEN_GUARD_S = 0.4,        -- ignora toques por este tempo depois de abrir uma tela
    FULL_REFRESH_EVERY = 30,   -- limpeza completa da tela a cada N mudancas
}
