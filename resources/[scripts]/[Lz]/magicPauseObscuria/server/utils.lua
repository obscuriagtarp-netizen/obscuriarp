Utils = Utils or {}

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function callExport(resource, exportName, ...)
    if not resource or resource == "" or not exportName or exportName == "" then return nil end
    if GetResourceState(resource) ~= "started" then return nil end

    local args = { ... }
    local ok, result = pcall(function()
        local provider = exports[resource]
        return provider[exportName](provider, table.unpack(args))
    end)

    return ok and result or nil
end

function Utils.getPlayer(src)
    src = tonumber(src)
    if not src then return nil end

    local player = callExport("qbx_core", "GetPlayer", src)
    if player then return player end

    if GetResourceState("qb-core") == "started" then
        local ok, core = pcall(function() return exports["qb-core"]:GetCoreObject() end)
        if ok and core and core.Functions and core.Functions.GetPlayer then
            return core.Functions.GetPlayer(src)
        end
    end

    return nil
end

function Utils.getPassport(src)
    local player = Utils.getPlayer(src)
    local data = player and player.PlayerData or {}
    return trim(data.citizenid) or trim(data.citizenId) or trim(data.license) or tostring(src)
end

function Utils.getSourceByIdentifier(identifier)
    identifier = trim(identifier)
    if not identifier then return nil end

    for _, src in ipairs(GetPlayers()) do
        if Utils.getPassport(src) == identifier or tostring(src) == identifier then
            return tonumber(src)
        end
    end

    return nil
end

function Utils.getIdentity(src)
    local player = Utils.getPlayer(src)
    local data = player and player.PlayerData or {}
    local charinfo = type(data.charinfo) == "table" and data.charinfo or {}
    return {
        firstName = trim(charinfo.firstname) or trim(charinfo.firstName),
        lastName = trim(charinfo.lastname) or trim(charinfo.lastName),
        phone = trim(charinfo.phone) or trim(charinfo.phoneNumber),
        gender = charinfo.gender,
        birthdate = trim(charinfo.birthdate),
        avatar = trim(charinfo.avatar) or trim(charinfo.image) or trim(data.image)
    }
end

function Utils.getName(src)
    local identity = Utils.getIdentity(src)
    local first, last = identity.firstName, identity.lastName
    if first and last then return first .. " " .. last end
    return first or last or "Cidadão de Obscuria"
end

function Utils.getJob(src)
    local player = Utils.getPlayer(src)
    local data = player and player.PlayerData or {}
    local job = type(data.job) == "table" and data.job or {}
    local grade = type(job.grade) == "table" and job.grade or {}
    return {
        name = trim(job.name) or "unemployed",
        label = trim(job.label) or trim(job.name) or "Unemployed",
        grade = tonumber(grade.level) or tonumber(grade.grade) or 0,
        gradeName = trim(grade.name)
    }
end

function Utils.getGang(src)
    local player = Utils.getPlayer(src)
    local data = player and player.PlayerData or {}
    local gang = type(data.gang) == "table" and data.gang or {}
    local grade = type(gang.grade) == "table" and gang.grade or {}
    return {
        name = trim(gang.name) or "none",
        label = trim(gang.label) or trim(gang.name) or "None",
        grade = tonumber(grade.level) or tonumber(grade.grade) or 0,
        gradeName = trim(grade.name)
    }
end

function Utils.getGroups(src)
    return {
        job = Utils.getJob(src),
        gang = Utils.getGang(src)
    }
end

function Utils.isStaff(src)
    src = tonumber(src) or 0
    if src <= 0 then return true end

    for _, permission in ipairs((Config.AdminPermissions or { "admin", "god" })) do
        local allowed = callExport("qbx_core", "HasPermission", src, permission)
        if allowed == true then return true end
        if IsPlayerAceAllowed(src, permission) then return true end
    end

    local job = Utils.getJob(src)
    return (Config.AdminJobs or {})[job.name] ~= nil and job.grade >= tonumber(Config.AdminJobs[job.name] or 0)
end

function Utils.getMoney(src, account)
    local player = Utils.getPlayer(src)
    account = account or "cash"

    local money = player and player.PlayerData and player.PlayerData.money
    if type(money) == "table" then
        local amount = tonumber(money[account])
        if amount ~= nil then return amount end
    end

    if player and player.Functions and player.Functions.GetMoney then
        local ok, amount = pcall(player.Functions.GetMoney, account)
        if ok and tonumber(amount) ~= nil then return tonumber(amount) end
    end

    local exported = callExport("qbx_core", "GetMoney", tonumber(src), account)
    if tonumber(exported) ~= nil then return tonumber(exported) end

    return 0
end

function Utils.addMoney(src, account, amount, reason)
    local player = Utils.getPlayer(src)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if not player or amount <= 0 then return false end
    if player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(account or "cash", amount, reason or "magicpause") ~= false
    end
    return false
end

function Utils.removeMoney(src, account, amount, reason)
    local player = Utils.getPlayer(src)
    account = account or "cash"
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if not player or amount <= 0 then return false end
    if Utils.getMoney(src, account) < amount then return false end
    if player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney(account, amount, reason or "magicpause") == true
    end
    return false
end

function Utils.getRunes(src)
    local cfg = Config.Runes or {}
    local identifier = Utils.getPassport(src)
    local exported = callExport(cfg.resource, cfg.getExport, identifier, src)
    if exported ~= nil then return math.max(0, math.floor(tonumber(exported) or 0)) end
    return math.max(0, math.floor(tonumber(Utils.getMoney(src, cfg.account or "bank")) or 0))
end

function Utils.removeRunes(src, amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount <= 0 then return true end

    local cfg = Config.Runes or {}
    local identifier = Utils.getPassport(src)
    if Utils.getRunes(src) < amount then return false end
    local exported = callExport(cfg.resource, cfg.removeExport, identifier, amount, reason, src)
    if exported ~= nil then return exported == true end
    return Utils.removeMoney(src, cfg.account or "bank", amount, reason)
end

function Utils.addRunes(src, amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount <= 0 then return true end

    local cfg = Config.Runes or {}
    local identifier = Utils.getPassport(src)
    local exported = callExport(cfg.resource, cfg.addExport, identifier, amount, reason, src)
    if exported ~= nil then return exported == true end
    return Utils.addMoney(src, cfg.account or "bank", amount, reason)
end

Utils.getCoins = Utils.getRunes
Utils.removeCoins = Utils.removeRunes
Utils.addCoins = Utils.addRunes

exports("GetRunes", function(src)
    return Utils.getRunes(tonumber(src))
end)

exports("RemoveRunes", function(src, amount, reason)
    return Utils.removeRunes(tonumber(src), amount, reason)
end)

exports("AddRunes", function(src, amount, reason)
    return Utils.addRunes(tonumber(src), amount, reason)
end)

local function readPath(root, path)
    local value = root
    for part in tostring(path or ""):gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

function Utils.locale()
    local locales = Config.Locales or {}
    return locales[tostring(Config.Locale or "pt-br")] or locales["pt-br"] or {}
end

function Utils.t(path, replacements)
    local text = readPath(Utils.locale(), path) or tostring(path or "")
    if type(text) ~= "string" then return tostring(path or "") end
    for key, value in pairs(replacements or {}) do
        text = text:gsub("{" .. tostring(key) .. "}", tostring(value))
    end
    return text
end

function Utils.localePayload()
    return { current = tostring(Config.Locale or "pt-br"), messages = Utils.locale() }
end

function Utils.giveItem(src, item, amount, metadata)
    item = trim(item)
    amount = math.floor(math.abs(tonumber(amount) or 1))
    if not item or amount <= 0 then return false end

    if GetResourceState("ox_inventory") == "started" then
        local ok, result = pcall(function()
            return exports.ox_inventory:AddItem(src, item, amount, metadata)
        end)
        if ok then return result ~= false end
    end

    local player = Utils.getPlayer(src)
    if player and player.Functions and player.Functions.AddItem then
        return player.Functions.AddItem(item, amount, false, metadata) ~= false
    end

    return false
end

function Utils.setFaction(src, faction, grade)
    local player = Utils.getPlayer(src)
    if not player or not faction then return false end

    grade = tonumber(grade) or 0
    local groupType = tostring(Config.FactionGroupType or "gang"):lower()

    if groupType == "job" and player.Functions and player.Functions.SetJob then
        return player.Functions.SetJob(faction, grade) ~= false
    end

    if player.Functions and player.Functions.SetGang then
        return player.Functions.SetGang(faction, grade) ~= false
    end

    if player.Functions and player.Functions.SetJob then
        return player.Functions.SetJob(faction, grade) ~= false
    end

    return false
end

function Utils.hasFaction(src, factionGroup)
    local groupType = tostring(Config.FactionGroupType or "gang"):lower()
    local data = groupType == "job" and Utils.getJob(src) or Utils.getGang(src)
    return data.name == factionGroup
end
