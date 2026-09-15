# ob_vip

Sistema central de VIP da Obscuria para Qbox e ox_inventory.

## Configuracao

Os planos ficam em `config.lua`, dentro de `Config.Vips`. Cada chamada de
`AddVip` cria uma concessao independente. Enquanto duas concessoes estiverem
ativas, os dois salarios serao pagos.

- `salary.amount`: valor de cada pagamento.
- `salary.everyMinutes`: intervalo normal entre pagamentos.
- `salary.everySeconds`: intervalo opcional para testes.
- `salary.account`: conta Qbox que recebe o valor.
- `initialMoney`: valor e conta entregues uma unica vez por concessao.
- `vehicleDiscount`: percentual de desconto na concessionaria.
- `fuelDiscount`: percentual aplicado pelo `ox_fuel`.
- `medicalDiscount`: percentual aplicado aos pagamentos hospitalares.
- `inventoryWeight`: peso extra automatico enquanto o VIP estiver ativo.
- `vehicles`: quantidade de escolhas e catalogo de modelos.
- `nameChanges`: quantidade de itens `troca_nome` entregues.
- `discordRoleId`: cargo sincronizado pelo bot.

O banco e criado automaticamente. `sql/install.sql` tambem pode ser importado
manualmente.

## Comandos

```text
/setvip [id ou citizenid] [vip] [dias]
/removevip [id ou citizenid] [vip ou id da concessao]
/listvips [id ou citizenid]
```

Use `0` dias para uma concessao permanente.

## Exports do servidor

```lua
exports.ob_vip:AddVip(citizenid, 'arcano', 30, {
    grantedBy = 'loja',
    reason = 'compra aprovada',
})

exports.ob_vip:RemoveVip(citizenid, 'arcano')
exports.ob_vip:ClearVips(citizenid)
exports.ob_vip:RefreshPlayer(citizenid)

local active = exports.ob_vip:IsVip(citizenid)
local hasArcano = exports.ob_vip:HasVip(citizenid, 'arcano')
local vips = exports.ob_vip:GetVips(citizenid)
local highest = exports.ob_vip:GetHighestVip(citizenid)
local benefits = exports.ob_vip:GetBenefits(citizenid)
local salary = exports.ob_vip:GetSalaryTotal(citizenid)
local salaries = exports.ob_vip:GetSalaryEntries(citizenid)
local discount = exports.ob_vip:GetVehicleDiscount(citizenid)
local final, saved, percent = exports.ob_vip:CalculateVehicleDiscount(citizenid, 100000)
local fuelFinal = exports.ob_vip:CalculateFuelDiscount(citizenid, 1000)
local medicalFinal = exports.ob_vip:CalculateMedicalDiscount(citizenid, 5000)
local extraWeight = exports.ob_vip:GetInventoryBonus(citizenid)
local roles = exports.ob_vip:GetDiscordRoleIds(citizenid)
local store = exports.ob_vip:GetStoreState(citizenid)
```

`AddVip`, `SetVip`, `RemoveVip` e `ClearVips` retornam sucesso como primeiro
valor e o resultado ou erro como segundo valor.

## Exports do cliente

```lua
local active = exports.ob_vip:IsVip()
local hasArcano = exports.ob_vip:HasVip('arcano')
local vips = exports.ob_vip:GetVips()
local highest = exports.ob_vip:GetHighestVip()
local benefits = exports.ob_vip:GetBenefits()
local salary = exports.ob_vip:GetSalaryTotal()
local salaries = exports.ob_vip:GetSalaryEntries()
local discount = exports.ob_vip:GetVehicleDiscount()
local fuelDiscount = exports.ob_vip:GetFuelDiscount()
local medicalDiscount = exports.ob_vip:GetMedicalDiscount()
local extraWeight = exports.ob_vip:GetInventoryBonus()
local roles = exports.ob_vip:GetDiscordRoleIds()
```

Mudancas sincronizadas disparam `ob_vip:client:onUpdated` no cliente e
`ob_vip:server:membershipChanged` no servidor.

As mochilas pequena, media e grande sao itens independentes do VIP. Ao usar,
o item e consumido e o peso adicional permanece ate a proxima morte.
