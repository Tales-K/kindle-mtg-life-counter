# Aceitação no Kindle

Plugin instalado em `koreader/plugins/lifecounter.koplugin` (com `config.lua` apontando para
`https://<nome>.<sua-conta>.workers.dev/v1/`). Abrir: KOReader → menu de cima → Mais ferramentas → **Contador MTG**.

Marque cada item depois de testar no aparelho.

## Jogo
- [ ] Nova partida com 2 jogadores, 40 de vida: os dois painéis aparecem, um de cabeça para baixo.
- [ ] Nova partida com 4 e com 6 jogadores: todos os painéis legíveis; numeração J1..Jn no sentido horário a partir do canto inferior esquerdo.
- [ ] Toque na metade esquerda do painel tira 1 e na direita soma 1; segurar muda 10; vale também no painel de cabeça para baixo (as metades seguem quem está sentado ali).
- [ ] A gota de veneno com o número aparece embaixo, à esquerda da miniatura, sempre (mesmo com 0); não há mais veneno no canto.
- [ ] Vida em 0 ou menos, veneno 10 ou 21 de um mesmo comandante: painel preto com caveira, sem texto de motivo, e os controles continuam funcionando.
- [ ] A miniatura da mesa embaixo do painel mostra o dano recebido de cada oponente no lugar dele.
- [ ] Tocar no quadradinho de um oponente abre o campo único em tela cheia, só com aquele número (ex.: J1 toca no canto superior esquerdo com 4 jogadores → "J1 · dano de comandante de J4"), sem mudar nada no jogo. Com 6 jogadores, tocar perto da borda de um quadradinho ainda pega o quadradinho certo.
- [ ] Tocar no quadradinho "você" não faz nada.
- [ ] Campo de dano: metade esquerda tira 1 e direita soma 1; segurar muda 10; somar dano tira a mesma vida e tirar dano devolve a vida. Mostra "de 21".
- [ ] Campo aberto por um jogador de cima: a tela inteira aparece virada para ele (OK no alto da tela).
- [ ] Tocar na gota abre o campo de veneno ("J1 · veneno", "fora com 10"): toque muda 1; segurar não muda nada.
- [ ] Reviver: com 21 de um comandante o jogador fica fora; tirar 1 no campo tira a caveira e devolve 1 de vida; voltar a 0 devolve a vida toda. Veneno 10 → 9 também tira a caveira.
- [ ] Toque duplo rápido na miniatura ou na gota não altera o número do campo.
- [ ] "OK · voltar ao jogo" fecha o campo e o jogo mostra os números novos.
- [ ] "MENU" na barra central abre o menu.

## Continuidade
- [ ] Fechar o KOReader e abrir de novo: "Continuar partida" mostra os mesmos números.
- [ ] Deixar o Kindle dormir e acordar no meio da partida: números mantidos.
- [ ] Menu (barra central): "Nova partida" e "Reiniciar partida" pedem confirmação.
- [ ] Sem Wi-Fi o jogo funciona normalmente.

## Atualização
- [ ] "Atualizar" com Wi-Fi: mostra a versão disponível (ou "Ja esta na versao N") sem erro.
- [ ] Depois de instalar: reinicia o KOReader, a tela inicial mostra a versão nova e a partida salva continua.
- [ ] Versão quebrada de propósito: o plugin volta sozinho para a anterior.

Resultados e observações:
