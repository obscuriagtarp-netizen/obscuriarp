# ob_boxes

Sistema de caixas com escolha, colares de classe e elixires.

- As caixas e recompensas ficam em `config.lua`.
- A caixa so e consumida depois que a recompensa foi validada e entregue.
- Os colares duram 30 dias e so funcionam equipados no slot de colar.
- O efeito do colar so funciona para a classe configurada.
- Os elixires validam a classe antes de serem consumidos.
- O Elixir da Sabedoria cura 50 e aplica velocidade `1.25` por 10 minutos.

Nao ha declaracao `dependencies` no `fxmanifest.lua`. Garanta apenas a ordem de inicio:

```cfg
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure ob_boxes
ensure ob_essencias
```

Exports de servidor:

```lua
exports.ob_boxes:GetActiveNecklace(source)
exports.ob_boxes:GetEssenceBonus(source, classId)
exports.ob_boxes:HasNecklaceEffect(source, 'maxHealthBonus')
exports.ob_boxes:GiveBox(source, 'caixa_colares', 1)
```

Exports de cliente:

```lua
exports.ob_boxes:GetNecklaceEffect()
exports.ob_boxes:IsWisdomActive()
```
