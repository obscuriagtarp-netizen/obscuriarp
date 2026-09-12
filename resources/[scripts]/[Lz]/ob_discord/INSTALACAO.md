# Obscuria | ob_discord

Autor: discord: lzdv_. Requer OneSync, qbx_core e screenshot-basic (com yarn/webpack).
Consulta de veiculos usa oxmysql; runas usam o export GetRunes de magicPauseObscuria.
Nenhum arquivo do screenshot-basic foi alterado ou incluido. Usa o export server-side oficial
`requestClientScreenshot` (https://github.com/citizenfx/screenshot-basic).

## Ativacao

1. O bot e este resource compartilham uma chave privada. Os arquivos `.env.city` do bot e
   `bridge.secret.cfg` deste resource sao gerados uma unica vez por `node scripts/setup-city.js`
   na pasta do bot. Preserve os dois ao transferir para a VPS. Nao publique esses arquivos.
2. Copie `ob_discord` para sua pasta de resources. Exemplo da VPS informada, depois do qbx_core:

```cfg
exec resources/[scripts]/[Lz]/ob_discord/bridge.secret.cfg
ensure yarn
ensure webpack
ensure screenshot-basic
ensure ob_discord
```

3. Reinicie o bot. `index.js` le `.env` e depois `.env.city`, sem sobrescrever variaveis existentes.
   O bot registra `/cidade` (staff, sem revive) e `/jogador` (consulta privada).
4. Por padrao ambos rodam na MESMA VPS: `http://127.0.0.1:30120/ob_discord`.
   Ajuste a porta em `.env.city` se preciso. Em hosts diferentes, use HTTPS via proxy,
   ajuste `CITY_BRIDGE_URL` e a lista `ob_discord_addresses` para o IP que chega ao FXServer.
   Restrinja o acesso no firewall/proxy. Nao exponha a chave ou permita origem `*`.
5. O `GROQ_API_KEY` ja configurado no bot tambem atende a leitura visual. O modelo visual
   e separado do modelo de conversa: `CITY_VISION_MODEL=qwen/qwen3.6-27b`.
   Verifique acesso/cotas em https://console.groq.com/docs/vision. A leitura visual e apenas
   auxiliar: indisponibilidade ou resultado negativo NAO impedem o resgate com captura.
6. O bot usa `CITY_STAFF_ROLE_IDS` (IDs separados por virgula) para avisar a equipe.
   Sem essa variavel, usa `SUPPORT_ROLE_IDS`; se vazio, `ADMIN_ROLE_IDS`.
   Ao primeiro resgate cria/reutiliza o canal PRIVADO `registros-resgates`.
   Requer Gerenciar Canais, Anexar Arquivos, Ler Historico, Enviar Mensagens e permissao
   para mencionar os cargos. Ou configure `CITY_AUDIT_CHANNEL_ID` com um canal privado
   acessivel somente aos cargos da equipe e ao bot. Nunca use o chat publico para evidencias.
   Falha ao arquivar antes da acao impede o transporte. Sem cargos validos tambem bloqueia.

## Whitelist e sincronizacao de cargos

Este resource tambem faz a ponte cidade -> Discord. Quando o personagem termina de carregar,
ou quando seu VIP/classe muda, `server/roles.lua` envia somente `discordId`, `citizenid`,
classe e nomes dos VIPs ativos ao bot. O bot converte os nomes pelos mapas do `.env` e
gerencia exclusivamente esses cargos.

O vinculo `citizenid` -> Discord observado pelo servidor e guardado somente em
`data/discord-links.json`. Isso permite retirar cargo VIP quando uma concessao expira com o
jogador offline. Se o Discord vinculado ao mesmo personagem mudar, os cargos gerenciados
sao removidos do vinculo anterior antes da nova sincronizacao. Preserve o arquivo na VPS e
nao o publique.

Convars server-side em `bridge.secret.cfg`:

```cfg
set ob_discord_bot_url "http://127.0.0.1:30121"
set ob_discord_whitelist_enabled "false"
set ob_discord_whitelist_fail_open "false"
set ob_discord_role_sync_enabled "true"
```

Use HTTP apenas em loopback. Se o bot estiver no Railway/outro host, use a URL HTTPS pública.
No bot, `CITY_SYNC_SECRET` vazio reutiliza `CITY_BRIDGE_SECRET`. Nunca use `setr` para a chave.

Mantenha a whitelist em `false` durante a instalação. Configure no bot o ID do cargo
`Liberado`, o canal/categoria da prova e os mapas de cargos. Reinicie o bot, confira o log
`Sincronização ouvindo` e teste `GET /health`. Depois altere somente
`ob_discord_whitelist_enabled` para `true` e reinicie este resource.

Ao conectar, o FiveM exige o identificador `discord:` e consulta em tempo real se o membro
possui `WHITELIST_ROLE_ID` (ou um cargo explicitamente listado em
`WHITELIST_BYPASS_ROLE_IDS`). Sem resposta, a conexão é recusada por padrão. A verificação
não concede cargo, não aceita dados do cliente e não confia em `citizenid` enviado pelo jogador.

## Uso

- Jogador, no proprio ticket de suporte ainda sem staff: `@Obscuria estou no limbo`.
  O bot pede `@Obscuria ID 42`. Nao pergunta sobre morte e NUNCA revive.
  Respostas antigas `ID 42, sim/nao` continuam aceitas, mas somente transportam.
  O ID da sessao precisa ter `discord:ID_DO_AUTOR` nos identificadores FiveM.
  Sem Discord vinculado, o jogador deve aguardar a staff; um ID digitado nao prova identidade.
- Administrador ou staff responsavel que seja tambem o autor do ticket pode usar
  `estou no limbo` no proprio ticket, mesmo assumido ou de outra categoria. Continua sendo
  resgate automatico do proprio personagem, com vinculo Discord, evidencia e cooldown;
  nao transforma a resposta de ID em um comando administrativo para outro jogador.
- Staff responsavel pelo ticket ou admin: `@Obscuria consultar ID 42`.
- Staff: `@Obscuria teleportar ID 42 para vec4(-940.85, -385.03, 39.0, 24.39)`.
- Tambem existe `/cidade acao:teleportar id:42 coordenadas:...`. Coordenadas sao opcionais.
  A staff pode auxiliar outro ID explicitamente, sem vinculo com o dono do ticket.
  Consulta/captura isolada nao move, cura nem revive.
- Jogador no chat autorizado ou ticket acessivel: `@Obscuria meus dados`, `meus veiculos`,
  `meu saldo`, `minhas runas`, `minha classe`, ou `/jogador`. Consulta o personagem ONLINE
  pelo Discord vinculado; nao exige ID. Por mencao envia DM; slash responde so ao solicitante.
  DM fechada: orienta usar `/jogador`, nunca publica os dados no canal.
  Admin ou responsavel do ticket: `/jogador id:42` pode consultar outro jogador em privado.
  Suporte fora do ticket que assumiu consulta somente o proprio personagem.
  Nao retorna license, IP, telefone, nascimento, inventario ou personagens offline.
  Dinheiro/banco: PlayerData.money; classe: metadata.classe; runas: GetRunes do MagicPause.
  Na configuracao atual do MagicPause, runas usam a conta crypto. Mantem a mesma fonte do menu.
  Lista veiculos da tabela player_vehicles por citizenid, ate 500, em TXT privado.
  Fonte indisponivel e exibida como indisponivel, nunca como saldo zero inventado.

Somente estas acoes sao aceitas. O modelo nao executa console, eventos, itens, dinheiro ou bans.
Nao ha botoes publicos de administracao. Os controles anteriores dos tickets continuam iguais.

## Evidencia e Limites

Antes da mutacao, uma captura JPEG do jogo e anexada no ticket com o estado do personagem.
Horario, hash e dados tecnicos ficam no arquivo JSON interno da auditoria, nao no HTML.
Nao captura a area de trabalho. O bot informa a coleta ao
jogador; a resposta inicia a consulta. A imagem e enviada ao provedor visual configurado.
Inclua esse uso na politica do servidor e limite quem tem acesso aos tickets/transcripts.
Capturas sao dados do cliente e podem ser adulteradas; nem elas nem o estado replicado
constituem anticheat. A imagem nao prova a causa da morte, nem identifica o dono do ID.

O resgate automatico exige o mesmo Discord/personagem/sessao, captura, arquivo da staff
e ausencia de bloqueios. A altura BelowWorldZ e ExcludedZones ficam somente no diagnostico;
nao bloqueiam transporte. O jogador pode solicitar mesmo sem limbo confirmado.
NUNCA revive ou cura, inclusive a pedido de admin e inclusive se o personagem estiver morto.
O estado de vida nao e alterado pelo bot. O uso indevido deve ser avaliado pela staff;
nenhuma punicao e aplicada automaticamente.

Destino padrao: `vec4(-940.85, -385.03, 39.0, 24.39)`, em config.lua. Cooldown automatico:
15 minutos. Buckets diferentes de zero, veiculos, algemas, prisao, hipnose, voo e outros
estados protegidos bloqueiam ate comandos da staff por esta ponte; a staff deve entrar
na cidade para esses casos. Destinos personalizados exigem conhecimento do mapa; a ponte
nao consegue garantir que uma coordenada manual tenha chao ou esteja fora de uma parede.

Captura falhou, upload no Discord falhou ou sessao mudou: nao autoriza a acao.
Evidencia vence em 90 segundos. Assumir/fechar durante a consulta cancela o fluxo automatico.
Durante os poucos segundos da mutacao, assumir/fechar aguarda o resultado.
O servidor confirma a chegada antes de informar sucesso.

## Seguranca e Operacao

- `set ob_discord_secret`, NUNCA `setr`. config.lua e server-only; o client so carrega colisao.
- HMAC SHA-256, janela de 60 segundos, guild fixo, origem restrita, lista fechada de acoes.
- `data/requests.json` registra IDs, autor, ticket, destino e resultados. Entradas com mais
  de 24 horas sao removidas na proxima requisicao nova;
  preserve durante restarts. Nao guarda imagens. Corrompido/inacessivel: ponte bloqueia.
- Requisicao interrompida nao e repetida automaticamente. Resultado incerto pede checagem
  da staff, pois o teleporte pode ter ocorrido parcialmente.
- Execute somente UMA instancia do bot para a mesma configuracao de tickets.
- Cada resgate tem transcript HTML com a captura incorporada (nao depende de link CDN)
  e resultado legivel, sem o bloco tecnico "Registro do resgate". O bot guarda uma copia em
  `src/data/city-audit/` e envia ao canal privado. Um JSON separado, somente no disco da VPS,
  preserva estado anterior, horario, autor, destino, hash e resultado tecnico; nunca e anexado
  no Discord. Preserve essa pasta na VPS e nos backups.
  O canal usa uma unica mensagem: a staff e marcada na publicacao inicial; ao concluir,
  a mesma mensagem recebe o resultado e um unico HTML atualizado, substituindo o anexo anterior.
  A mensagem e o HTML informam indicios de limbo com os resultados da captura e do servidor.
  Resultado inconclusivo/indisponivel nao significa ausencia de limbo e nao bloqueia o resgate.
  O ticket fica aberto. O transcript normal de encerramento continua funcionando.
  Registros de resgate nao sao apagados automaticamente; defina uma retencao interna.
  Falha de envio APOS teleporte nao causa repeticao; confira o registro inicial e o arquivo local.

## Regras, Lore e Escopo

O texto integral fornecido esta em `src/data/obscuria-rules-lore.md`, na pasta do bot.
E lido nas consultas ao assistente. Atualize esse arquivo para alterar regras/lore; mensagens
de jogadores nao podem mudar as instrucoes. Regras prevalecem sobre a narrativa da lore.
O assistente deve ficar no escopo Obscuria, aceitar conversa leve/contas simples, recusar
tarefas grandes e assuntos externos, nao inventar punicoes e encaminhar denuncias a staff.
Dados de /jogador nao sao enviados ao modelo. As instrucoes reduzem erros, mas respostas
geradas ainda devem ser supervisionadas; decisoes de moderacao continuam humanas.

## Validacao Dentro da Cidade

Teste em ambiente de homologacao: vivo no mapa; morto fora do limbo; limbo vivo; limbo morto;
ID de outra pessoa; desconectar durante captura; screenshot-basic desligado; erro de upload;
staff assumir durante analise; repetir pedido; veiculo/prisao/bucket; destino principal e customizado.
Nao ha teste local capaz de substituir essa validacao no FXServer e no cliente FiveM.
