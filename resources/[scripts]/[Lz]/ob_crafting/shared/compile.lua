Config = Config or {}
Config.Stations = {}

local function accessFor(location)
    if type(location.access) == 'table' then return location.access end
    return {
        jobs = location.jobs,
        classes = location.classes,
        ace = location.ace
    }
end

for id, location in pairs(Config.CraftLocations or {}) do
    local operation = Config.CraftOperations and Config.CraftOperations[tostring(location.operation or '')]
    if operation then
        Config.Stations[tostring(id)] = {
            enabled = location.enabled == true,
            label = location.label or operation.label,
            kind = operation.kind or 'utility',
            animation = operation.animation or operation.kind or 'utility',
            coords = location.coords,
            stages = location.stages,
            scene = {
                spawnBench = location.spawnBench == true,
                bench = location.bench
            },
            access = accessFor(location),
            recipes = operation.recipes or {}
        }
    else
        print(('[ob_crafting] Operacao "%s" nao encontrada para o local "%s".'):format(tostring(location.operation), tostring(id)))
    end
end
