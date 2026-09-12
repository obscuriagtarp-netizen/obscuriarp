if not Config.UseTarget then
    return
end

---@class Target
---@field export string
---@field zones table<string, string[]>
_G['target'] = {
    export = GetResourceState('ox_target'):find('started') and 'qtarget' or 'qb-target',
    zones = {},
    ---@type table<string, string[]>
    modelTargets = {},
}

---@param key string
function target:destroyZones(key)
    if not self.zones[key] then return end
    for k, v in pairs(self.zones[key]) do
        exports[self.export]:RemoveZone(v)
    end
    self.zones[key] = {}
    Debug('destroyed target zones')
end

---@param key string
---@param id string | number
---@param coords vector3
---@param options {icon: string, label: string, action: function, canInteract?: function}[]
---@param distance? number
function target:addBoxZone(key, id, coords, options, distance)
    if not coords then return Error('target:addBoxZone :: coords is nil, probably bad configuration. Please check /hospital_creator', 'key', key, 'id', id) end
    if type(Config.TargetWidth) ~= 'number' or type(Config.TargetHeight) ~= 'number' then
        return Error('target:addBoxZone :: invalid target size configuration', 'TargetWidth', Config.TargetWidth, 'TargetHeight', Config.TargetHeight)
    end
    local _id = key .. id
    if self.zones[key] and self.zones[key][id] then
        exports[self.export]:RemoveZone(self.zones[key][id])
    end
    exports[self.export]:AddBoxZone(_id, coords, Config.TargetWidth, Config.TargetHeight, {
        name = _id,
        heading = 90.0,
        debugPoly = Config.ZoneDebug,
        minZ = coords.z - 5,
        maxZ = coords.z + 1,
    }, {
        options = options,
        distance = distance or 2.5
    })
    if not self.zones[key] then self.zones[key] = {} end
    self.zones[key][id] = _id
end

---@param key string
function target:destroyTargetModels(key)
    if not self.modelTargets[key] then return end
    for _, model in pairs(self.modelTargets[key]) do
        exports[self.export]:RemoveTargetModel(model)
    end
    self.modelTargets[key] = {}
    Debug('destroyed target models', key)
end

--- Register qb-target / qtarget model options (one model per key; re-call replaces previous).
---@param key string
---@param model string|number
---@param options {icon: string, label: string, action: function, canInteract?: function}[]
---@param distance? number
function target:addTargetModel(key, model, options, distance)
    local modelName = model
    if type(model) == 'number' then
        -- Resolve hash to name when possible for RemoveTargetModel compatibility
        modelName = model
    end
    self:destroyTargetModels(key)
    exports[self.export]:AddTargetModel(modelName, {
        options = options,
        distance = distance or 5.0,
    })
    if not self.modelTargets[key] then self.modelTargets[key] = {} end
    self.modelTargets[key][#self.modelTargets[key] + 1] = modelName
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Debug('destroying target zones', target.zones)
        for k, v in pairs(target.zones) do
            if type(v) == 'table' then
                for _, zone in pairs(v) do
                    exports[target.export]:RemoveZone(zone)
                end
            else
                exports[target.export]:RemoveZone(v)
            end
        end
        target.zones = {}
        for key, _ in pairs(target.modelTargets or {}) do
            target:destroyTargetModels(key)
        end
        target.modelTargets = {}
    end
end)
