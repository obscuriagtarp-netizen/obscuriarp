SpellsHud = SpellsHud or {}

local function IsKnown(knownSpells, spellName)
    return knownSpells and knownSpells[spellName] == true
end

function SpellsHud.GetOrderedSpellNames(knownSpells)
    local ordered = {}
    local added = {}

    for _, spellName in ipairs(Config.SpellOrder or {}) do
        if IsKnown(knownSpells, spellName) and Config.Spells[spellName] then
            ordered[#ordered + 1] = spellName
            added[spellName] = true
        end
    end

    for spellName in pairs(knownSpells or {}) do
        if not added[spellName] and Config.Spells[spellName] then
            ordered[#ordered + 1] = spellName
        end
    end

    table.sort(ordered, function(a, b)
        local spellA = Config.Spells[a] or {}
        local spellB = Config.Spells[b] or {}
        return (spellA.order or 9999) < (spellB.order or 9999)
    end)

    return ordered
end

function SpellsHud.BuildHudSpells(knownSpells)
    local pages = SpellsHud.GetOrderedSpellNames(knownSpells)
    local spells = {}

    for _, spellName in ipairs(pages) do
        local data = Config.Spells[spellName]
        spells[#spells + 1] = {
            name = spellName,
            label = data.label or spellName,
            shortLabel = data.shortLabel or data.label or spellName,
            description = data.description or "",
            icon = data.icon or ("icons/" .. spellName .. ".png"),
            essenceCost = math.max(0, math.floor(tonumber(data.essenceCost) or 0)),
            actionPrimary = data.actionPrimary,
            actionSecondary = data.actionSecondary
        }
    end

    return spells, pages
end
