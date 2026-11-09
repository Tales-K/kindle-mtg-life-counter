# Contador de vidas de Magic (Commander) para Kindle — design

Data: 2026-11-09. Estado: aprovado pelo Tales em 2026-11-09.

## Intenção e por quê

O Tales joga commander e não quer deixar o celular na mesa só para contar vida.
A ideia é usar o Kindle dele como placar compartilhado no meio da mesa: sem
notificação, sem bateria acabando, tela de e-ink legível. O modelo é o app
LifeTap (cópia funcional, não visual exato), reduzido ao essencial.

## Objetivos

1. Jogo de **2 a 6 jogadores**, formato commander, num único Kindle no meio da mesa.
2. Por jogador: **vida**, **dano de comandante recebido de cada oponente** e **marcadores de veneno**.
3. Controle da vida: botões − e +. **Toque = 1; segurar = 10** (uma vez por segurada, ver "Decisões minhas").
4. A tela é dividida em um **painel por jogador, virado para quem está sentado ali**.
5. **Dano de comandante numa tela à parte**: o jogador escolhe de qual oponente veio o dano.
6. **Vida inicial 40** (padrão commander), configurável.
7. **Botão "Atualizar"** no plugin: baixa a versão nova de um servidor próprio, confere e instala.
8. Funciona **offline** durante o jogo; Wi-Fi só é usado para atualizar.

## Não-objetivos (decididos pelo Tales)

- Contadores extras: Treasure, Experience, Commander tax, Monarch, Initiative, Energy, Dia/Noite, City's Blessing.
- Dados e moeda.
- Perfis de jogo e histórico de partidas.
- Mais de 6 jogadores.

## Anti-objetivos (o que seria falha mesmo funcionando)

- A tela ficar tão atrasada que o jogador perde a conta de quantos toques deu.
- O app exigir Wi-Fi ou servidor para jogar.
- Uma atualização quebrar o app sem como voltar.
- O Kindle dormir ou o app fechar no meio da partida e perder os números.

## Restrições

- Aparelho: Kindle básico de 11ª geração (o KOReader o chama de `KindleBasic4`), firmware 5.18.2, com jailbreak AdBreak. Tela de 6", em torno de 1072×1448 (a confirmar no aparelho).
- Plataforma: **plugin do KOReader v2025.10, em Lua**. Já instalado; sem toolchain nova.
- E-ink: atualização lenta; evitar redesenhar a tela inteira a cada toque.
- Não atualizar o firmware do Kindle (há o `renameotabin` instalado para isso).
- Servidor: um **Cloudflare Worker novo e separado** servindo arquivos estáticos em `<nome>.<sua-conta>.workers.dev`. Nada do servidor de casa fica exposto. Não tocar nos outros Workers da conta.
- Segurança da atualização: só HTTPS, endereço fixo, **token no cabeçalho `Authorization`** (nunca na URL), hash de cada arquivo, e rollback para a versão anterior.
- Publicar (criar o Worker e fazer deploy) exige o OK explícito do Tales; o login do `wrangler` tem permissão ampla na conta.

## O que o Tales decidiu

- Comportamento da vida: toque = 1, segurar = 10.
- Até 6 jogadores; os contadores extras ficam de fora.
- Um Kindle no meio da mesa, painéis virados para cada jogador, dano de comandante em tela separada escolhendo o oponente, vida inicial 40 configurável (ele confirmou esses palpites).
- Tecnologia: plugin KOReader/Lua (a explicação foi dada e ele não objetou).
- Atualização por botão no plugin, puxando de um Worker do Cloudflare com token.

## Decisões minhas (marcadas como minhas; o Tales pode rejeitar)

- **Segurar = um passo de 10**, não repetição contínua, para o e-ink não ficar para trás. O número final pode aparecer só ao soltar.
- Desenvolver e conferir **no emulador do KOReader no PC** e só depois levar ao Kindle. Baixar o emulador precisa de OK separado.
- **Assinatura do manifesto é desejável, não obrigatória.** O servidor tem `ssh-keygen -Y sign`, mas o Kindle precisaria verificar em Lua; decidir após testar no protótipo. Sem assinatura, vale HTTPS + token + hash.
- Marcar um jogador como "fora" (vida ≤ 0, veneno ≥ 10, ou 21 de dano de um mesmo comandante) só com um aviso visual, sem travar os controles.
- Guardar o estado da partida em disco a cada mudança, para sobreviver a sono, travamento ou reinício.
- Tentar evitar o Kindle dormir durante a partida (o KOReader tem o plugin `keepalive`), mas **assumir que ele pode dormir** (o plugin pode não bloquear totalmente no firmware 5.18.2). O app sempre retoma do estado salvo.
- **Primeiro marco é um protótipo de risco no aparelho**: testar toque, segurar para 10 e o atraso do e-ink antes de construir o resto. Se o "segurar" não for confiável, o plano B é um botão separado "±10" ao lado de ±1.
- **Rotação só em 0° e 180°** (confirmado: jogadores só nos dois lados compridos), com cópia de buffer girada.
- **Atualização:** só a partir da tela inicial, nunca no meio de uma partida. Hash errado cancela e nada é trocado. A versão anterior fica numa pasta de backup; se o app não completar a primeira abertura depois da atualização (o plugin grava um marcador de "abriu bem"), na próxima abertura ele volta sozinho para a versão anterior. Como último recurso, a versão anterior pode ser restaurada copiando arquivos pelo USB.
- **Token de atualização:** fica num arquivo de configuração no próprio Kindle, copiado por mim via USB; nunca no repositório nem digitado na tela. O token só permite baixar o plugin, não publicar nada, então perder o Kindle tem risco baixo.
- **Retomar partida:** ao abrir, o app mostra "Continuar partida" e "Nova partida". "Nova partida" e "Reiniciar" pedem confirmação, para um toque errado não apagar o jogo.

## Respostas do Tales (2026-11-09)

1. Assentos: **só nos dois lados compridos da mesa** (uma fileira virada para cima, outra para baixo). Sem painéis a 90° ou 270°.
2. **O dano de comandante também tira vida** do jogador, com o mesmo valor.
3. **Pode baixar o emulador do KOReader no PC.** No momento do download, confirmar com ele o arquivo, a origem e o tamanho.
4. As decisões marcadas como minhas acima foram aceitas ("o resto ok").

## Verificado

- O pacote de certificados do KOReader (`data/ca-bundle.crt`, 146 certs) valida o certificado do `workers.dev` (cadeia Let's Encrypt YE1 → Root YE → ISRG X2 → X1), em TLS 1.2 e 1.3. Foi testado no PC com OpenSSL, **não no aparelho**. A cadeia tem EC P-384; confirmar no aparelho que o KOReader consegue a conexão.

## Deixado para quem for construir

- Geometria dos painéis para 2, 3, 4, 5 e 6 jogadores e a rotação de cada painel (o KOReader não gira widgets facilmente; provável desenhar o número num buffer e girar).
- Estratégia de atualização parcial da tela e quando limpar a imagem fantasma.
- Formato do manifesto e da pasta de arquivos; como o botão reinicia o KOReader depois de instalar.
- Como o desenvolvimento conversa com o Kindle (SSH pelo `SSH.koplugin`, ou emulador).
- Tela de início: escolher o número de jogadores e a vida inicial; botão de reiniciar a partida.
