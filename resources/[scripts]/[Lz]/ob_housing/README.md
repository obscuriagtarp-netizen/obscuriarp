# ob_housing

Sistema de apartamentos e casas instanciadas para Qbox, com catálogo NUI,
cadastro inteiramente in-game, baú individual e integração opcional com Bob74 IPL.

## Ordem de inicialização

O `fxmanifest.lua` não declara `dependencies`, para que reiniciar uma integração não
reinicie a resource em cascata. Garanta apenas esta ordem no `server.cfg`:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure bob74_ipl
ensure ob_housing
```

`ox_target` e `bob74_ipl` são opcionais em tempo de execução. Sem `ox_target`, a
resource usa os pontos com TextUI e tecla E. Sem Bob74, os interiores do GTA ainda
são acessados, mas a personalização de props do IPL não é executada.

As tabelas são criadas automaticamente. O mesmo esquema está em `sql/install.sql`.

O painel é aberto apenas pelo comando `/casas`. Administradores entram diretamente
na aba de administração; jogadores entram em seus imóveis. Ao capturar um ponto, o painel libera o personagem;
posicione-o e confirme com `E`, ou cancele com `BACKSPACE`.

## Funcionamento

- O apartamento inicial é instanciado, concedido automaticamente e acessado com `E`.
- Imóveis exclusivos aceitam um proprietário ativo; imóveis instanciados podem ser
  entregues a várias pessoas, cada uma em sua própria instância e com seu próprio baú.
- A campainha solicita autorização ao proprietário online. A visita é temporária, entra
  na instância correta e não permite usar baú nem guarda-roupa.
- Casas comuns podem ser compradas pelo catálogo. Ao informar um benefício VIP no cadastro,
  a venda comum é desativada e o imóvel fica apenas para concessão por painel ou export.
- Concessões temporárias expiram automaticamente e removem quem ainda estiver no interior.
- O painel oferece 12 modelos residenciais do Bob74. `Visualizar` abre uma instância de
  demonstração por no máximo 5 minutos; `E` na saída encerra antes desse prazo.

## Imagens

Coloque as imagens em `web/images` e informe, no painel, caminhos como:

```text
images/mansao-eclipse-01.webp
```

Também são aceitas URLs HTTPS. Cada imóvel suporta até 8 imagens.

## Exports do servidor

```lua
-- Concessão comum ou VIP. durationDays é opcional; sem ele, não expira.
local result = exports.ob_housing:GrantProperty(citizenid, 'mansao_eclipse', {
    acquisition = 'vip',
    durationDays = 30,
    metadata = { membershipId = membershipId, vip = 'eclipse' }
})

exports.ob_housing:GrantVipProperty(citizenid, 'mansao_eclipse', 'eclipse', 30, {
    membershipId = membershipId
})

exports.ob_housing:RevokeProperty(citizenid, 'mansao_eclipse', 'vip_expired')
exports.ob_housing:HasProperty(citizenid, 'mansao_eclipse')
exports.ob_housing:GetPlayerProperties(citizenid)
exports.ob_housing:GetProperty('mansao_eclipse')
exports.ob_housing:EnsureStarterApartment(citizenid)
exports.ob_housing:OpenCatalog(source)
```

O evento interno `ob_housing:server:granted` é disparado após cada concessão com
`citizenid`, `propertyKey`, `ownershipId` e `acquisition`.

## Exports do cliente

```lua
exports.ob_housing:OpenCatalog()
exports.ob_housing:OpenMyProperties()
exports.ob_housing:IsInsideProperty()
exports.ob_housing:GetCurrentProperty()
```
