# ob_boxes

Sistema de caixas, poções e artefatos de classe da Obscuria.

- A caixa só é consumida depois que a recompensa é validada e entregue.
- Amuletos, anéis e cintos de classe duram 30 dias e funcionam apenas equipados.
- Um artefato de outra classe não concede bônus e causa o efeito visual de corrupção.
- Anéis sobrenaturais reduzem os custos pela metade, arredondando para cima; custo 1 permanece 1.
- Cintos aumentam em 25% os efeitos numéricos e a duração das poções.
- Poções de restauração total limpam vida, fome, sede, stress, sangramentos e lesões.
- Uma poção de outra classe não é consumida e causa tontura por um minuto.

Não há declaração `dependencies` no `fxmanifest.lua`. Garanta apenas a ordem de início:

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
exports.ob_boxes:GetArtifactEffects(source)
exports.ob_boxes:ModifyEssenceCost(source, amount, context)
exports.ob_boxes:GetPotionMultiplier(source)
exports.ob_boxes:GetHealerPowerMultiplier(source, abilityId)
exports.ob_boxes:GiveBox(source, 'caixa_amuletos', 1)
```

Exports de cliente:

```lua
exports.ob_boxes:GetNecklaceEffect()
exports.ob_boxes:GetArtifactEffects()
exports.ob_boxes:GetHealerPowerMultiplier(abilityId)
exports.ob_boxes:IsWisdomActive()
```
