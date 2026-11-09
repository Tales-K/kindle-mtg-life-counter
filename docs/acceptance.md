# Aceitação no Kindle

Plugin instalado em `koreader/plugins/lifecounter.koplugin` (com `config.lua` apontando para
`https://<nome>.<sua-conta>.workers.dev/v1/`). Abrir: KOReader → menu de cima → Mais ferramentas → **Contador MTG**.

Marque cada item depois de testar no aparelho.

## Jogo
- [ ] Nova partida com 2 jogadores, 40 de vida: os dois painéis aparecem, um de cabeça para baixo.
- [ ] Nova partida com 4 e com 6 jogadores: todos os painéis legíveis; numeração J1..Jn no sentido horário a partir do canto inferior esquerdo.
- [ ] Toque em + e − muda 1; segurar muda 10; os dois funcionam também no painel de cabeça para baixo.
- [ ] Veneno: + e − mudam o número; em 10 o painel mostra "FORA: veneno".
- [ ] Vida em 0 ou menos mostra "FORA: vida" e os controles continuam funcionando.
- [ ] "Comandante" abre a tela de dano; somar dano tira a mesma vida do jogador; 21 de um mesmo oponente mostra "LETAL" e o painel "FORA: comandante".
- [ ] Na tela de comandante aberta pelo painel de cima, ela aparece de cabeça para baixo e legível para quem está lá.
- [ ] Toque duplo rápido em "Comandante" não altera o dano nem a vida.
- [ ] "Voltar" fecha a tela de comandante e o jogo mostra os números novos.

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
