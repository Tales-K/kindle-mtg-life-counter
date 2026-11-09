# Aceitação no Kindle

Plugin instalado em `koreader/plugins/lifecounter.koplugin` (com `config.lua` apontando para
`https://<nome>.<sua-conta>.workers.dev/v1/`). Abrir: KOReader → menu de cima → Mais ferramentas → **Contador MTG**.

Marque cada item depois de testar no aparelho.

## Jogo
- [ ] Nova partida com 2 jogadores, 40 de vida: os dois painéis aparecem, um de cabeça para baixo.
- [ ] Nova partida com 4 e com 6 jogadores: todos os painéis legíveis; numeração J1..Jn no sentido horário a partir do canto inferior esquerdo.
- [ ] Toque na metade esquerda do painel tira 1 e na direita soma 1; segurar muda 10; vale também no painel de cabeça para baixo (as metades seguem quem está sentado ali).
- [ ] Veneno aparece no canto (gota + número) só quando não é zero.
- [ ] Vida em 0 ou menos, veneno 10 ou 21 de um mesmo comandante: painel preto com caveira, sem texto de motivo, e os controles continuam funcionando.
- [ ] A miniatura da mesa embaixo do painel mostra o dano recebido de cada oponente no lugar dele; tocar nela abre a tela de dano sem mudar nada.
- [ ] Tela de dano: metade esquerda/direita do quadrado de um oponente tira/soma 1 (segurar 10); somar dano tira a mesma vida do jogador; o quadrado "VOCÊ" não reage.
- [ ] Tela de dano aberta pelo painel de cima: a faixa do meio (Voltar e veneno) aparece virada para quem está lá.
- [ ] Veneno − e + na faixa do meio mudam 1.
- [ ] Toque duplo rápido na miniatura não altera o dano nem a vida.
- [ ] "Voltar" fecha a tela de dano e o jogo mostra os números novos.
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
