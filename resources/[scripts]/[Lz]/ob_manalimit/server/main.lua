local states = {}
local recoveries = {}

math.randomseed(os.time() + GetGameTimer())

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function normalize(value)
    return tostring(value or ''):lower()
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(tonumber(source))
end

local function getClass(player)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = normalize(metadata[Config.ClassMetadataKey])
    return classId, Config.Classes[classId], metadata
end

local function setMetadata(source, key, value)
    local player = getPlayer(source)
    if player and player.Functions then
        local setter = player.Functions.SetMetaData or player.Functions.SetMetadata
        if setter then
            local ok, result = pcall(function()
                return setter(key, value)
            end)
            if ok and result ~= false then return true end
        end
    end

    local ok, result = pcall(function()
        return exports.qbx_core:SetMetadata(source, key, value)
    end)
    return ok and result ~= false
end

local function getTier(value)
    for index = 1, #(Config.Consequences.tiers or {}) do
        local tier = Config.Consequences.tiers[index]
        if value >= (tonumber(tier.minimum) or 0) then
            return tier
        end
    end

    return { id = 'stable', label = 'Estavel', minimum = 0 }
end

local function decayPressure(state, now)
    now = now or GetGameTimer()
    local previous = tonumber(state.pressureUpdatedAt) or now
    local elapsed = math.max(0, now - previous) / 1000
    local decay = elapsed * math.max(0, tonumber(Config.Growth.pressureDecayPerSecond) or 0)
    state.pressure = math.max(0, (tonumber(state.pressure) or 0) - decay)
    state.pressureUpdatedAt = now
end

local function ensureState(source)
    source = tonumber(source)
    local player = source and getPlayer(source)
    if not player then return nil, nil, nil end

    local classId, classConfig, metadata = getClass(player)
    if not classConfig then
        states[source] = nil
        return nil, classId, nil
    end

    local state = states[source]
    if not state or state.class ~= classId then
        state = {
            class = classId,
            value = clamp(tonumber(metadata[Config.MetadataKey]) or 0, 0, Config.Max),
            pressure = 0,
            pressureUpdatedAt = GetGameTimer(),
            lastRollAt = 0,
            recoveryAvailableAt = math.max(0, tonumber(metadata[Config.RecoveryCooldownMetadataKey]) or 0),
        }
        states[source] = state
    end

    return state, classId, classConfig
end

local function buildSnapshot(source)
    local state, classId, classConfig = ensureState(source)
    if not state then
        return {
            success = false,
            class = classId ~= '' and classId or nil,
            value = 0,
            max = Config.Max,
            tier = 'stable',
            tierLabel = 'Estavel',
        }
    end

    decayPressure(state)
    local tier = getTier(state.value)
    local now = os.time()
    return {
        success = true,
        class = classId,
        classLabel = classConfig.label,
        value = state.value,
        max = Config.Max,
        pressure = state.pressure,
        tier = tier.id,
        tierLabel = tier.label,
        dangerous = state.value >= 50,
        recoveryCooldown = math.max(0, (state.recoveryAvailableAt or 0) - now),
    }
end

local function pushUpdate(source)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return end

    local snapshot = buildSnapshot(source)
    local player = Player(source)
    if player and player.state then
        player.state:set('obArcaneExcess', snapshot.success and snapshot.value or 0, true)
        player.state:set('obArcaneExcessTier', snapshot.tier, true)
    end
    TriggerClientEvent('ob_manalimit:client:update', source, snapshot)
end

local function setExcess(source, value)
    local state = ensureState(source)
    if not state then return false, buildSnapshot(source) end

    value = clamp(tonumber(value) or 0, 0, Config.Max)
    state.value = math.floor(value * 100 + 0.5) / 100
    if not setMetadata(source, Config.MetadataKey, state.value) then
        return false, buildSnapshot(source)
    end

    pushUpdate(source)
    return true, buildSnapshot(source)
end

local function registerConsumption(source, spent)
    spent = math.max(0, tonumber(spent) or 0)
    if not Config.Enabled or spent <= 0 then return buildSnapshot(source) end

    local state, _, classConfig = ensureState(source)
    if not state or not classConfig then return buildSnapshot(source) end

    local now = GetGameTimer()
    decayPressure(state, now)

    local growth = Config.Growth
    local freePressure = math.max(0, tonumber(growth.freePressure) or 0)
    local beforePressure = state.pressure
    local afterPressure = math.min(
        math.max(freePressure, tonumber(growth.maximumPressure) or 180),
        beforePressure + spent
    )
    local taxable = beforePressure >= freePressure
        and spent
        or math.max(0, afterPressure - freePressure)

    state.pressure = afterPressure
    state.pressureUpdatedAt = now

    if taxable > 0 then
        local pressureMultiplier = 1.0
        if afterPressure >= (tonumber(growth.criticalPressure) or 135) then
            pressureMultiplier = tonumber(growth.criticalPressureMultiplier) or 1.55
        elseif afterPressure >= (tonumber(growth.highPressure) or 90) then
            pressureMultiplier = tonumber(growth.highPressureMultiplier) or 1.25
        end

        local gain = taxable
            * math.max(0, tonumber(growth.gainPerSpentPoint) or 0)
            * math.max(0, tonumber(classConfig.growthMultiplier) or 1)
            * pressureMultiplier

        if gain > 0 then
            setExcess(source, state.value + gain)
        else
            pushUpdate(source)
        end
    else
        pushUpdate(source)
    end

    return buildSnapshot(source)
end

local function evaluateConsumption(source, amount)
    amount = math.max(0, tonumber(amount) or 0)
    local snapshot = buildSnapshot(source)
    if not Config.Enabled or not snapshot.success then
        return { allow = true, outcome = 'ok', snapshot = snapshot }
    end

    local state = states[tonumber(source)]
    local tier = getTier(snapshot.value)
    local minimumCost = math.max(1, tonumber(Config.Consequences.minimumCostToRoll) or 1)
    local cooldown = math.max(0, tonumber(Config.Consequences.rollCooldownMs) or 0)
    local now = GetGameTimer()
    if amount < minimumCost or snapshot.value < 50 or now - (state.lastRollAt or 0) < cooldown then
        return { allow = true, outcome = 'ok', snapshot = snapshot }
    end

    state.lastRollAt = now
    local catastrophe = math.max(0, tonumber(tier.catastrophe) or 0)
    local backlash = math.max(0, tonumber(tier.backlash) or 0)
    local failure = math.max(0, tonumber(tier.failure) or 0)
    local roll = math.random() * 100
    local outcome = 'ok'

    if roll <= catastrophe then
        outcome = 'catastrophe'
    elseif roll <= catastrophe + backlash then
        outcome = 'backlash'
    elseif roll <= catastrophe + backlash + failure then
        outcome = 'failure'
    end

    return {
        allow = outcome == 'ok',
        outcome = outcome,
        class = snapshot.class,
        level = snapshot.value,
        tier = snapshot.tier,
        roll = Config.Debug and roll or nil,
        snapshot = snapshot,
    }
end

local function applyConsequence(source, decision)
    if type(decision) ~= 'table' or decision.allow ~= false then return false end

    local state, classId, classConfig = ensureState(source)
    if not state or not classConfig then return false end

    local outcome = tostring(decision.outcome or 'failure')
    local damageConfig = Config.Consequences.damage[classId] or {}
    local damage = math.max(0, math.floor(tonumber(damageConfig[outcome]) or 0))
    local description = classConfig.messages and classConfig.messages[outcome]
        or 'A sobrecarga interrompeu sua habilidade.'

    TriggerClientEvent('ob_manalimit:client:consequence', source, {
        class = classId,
        outcome = outcome,
        level = state.value,
        damage = damage,
        description = description,
    })

    if classId == 'vampiro' and outcome == 'catastrophe'
        and GetResourceState('ob_essencias') == 'started' then
        local drain = math.max(0, tonumber(Config.Consequences.vampireCatastropheExtraDrain) or 0)
        local ok, snapshot = pcall(function()
            return exports.ob_essencias:GetEssenciaSnapshot(source)
        end)
        if ok and type(snapshot) == 'table' and snapshot.success and drain > 0 then
            pcall(function()
                exports.ob_essencias:SetEssencia(source, math.max(0, (tonumber(snapshot.value) or 0) - drain))
            end)
        end
    end

    return true
end

lib.callback.register('ob_manalimit:server:get', function(source)
    pushUpdate(source)
    return buildSnapshot(source)
end)

lib.callback.register('ob_manalimit:server:beginRecovery', function(source)
    local state, classId, classConfig = ensureState(source)
    local recovery = classConfig and classConfig.recovery
    if not state or not recovery then return { success = false, reason = 'class' } end
    if state.value < 1 then return { success = false, reason = 'empty' } end
    if recoveries[source] then return { success = false, reason = 'busy' } end

    local now = os.time()
    if (state.recoveryAvailableAt or 0) > now then
        return {
            success = false,
            reason = 'cooldown',
            cooldown = state.recoveryAvailableAt - now,
        }
    end

    local item = tostring(recovery.item or '')
    local itemCount = math.max(1, math.floor(tonumber(recovery.itemCount) or 1))
    if item ~= '' then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(source, 'count', item)
        end)
        if not ok or (tonumber(count) or 0) < itemCount then
            return { success = false, reason = 'item', item = item }
        end
    end

    local duration = math.max(10000, math.floor(tonumber(recovery.durationMs) or 60000))
    local token = ('%s:%s:%s'):format(source, GetGameTimer(), math.random(100000, 999999))
    recoveries[source] = {
        token = token,
        class = classId,
        startedAt = GetGameTimer(),
        duration = duration,
        expiresAt = GetGameTimer() + duration + 30000,
    }

    return {
        success = true,
        token = token,
        duration = duration,
        label = recovery.label,
        scenario = recovery.scenario,
        anim = recovery.anim,
    }
end)

lib.callback.register('ob_manalimit:server:finishRecovery', function(source, token)
    local active = recoveries[source]
    recoveries[source] = nil
    if not active or active.token ~= token then return { success = false, reason = 'invalid' } end

    local now = GetGameTimer()
    if now + 1200 < active.startedAt + active.duration or now > active.expiresAt then
        return { success = false, reason = 'time' }
    end

    local state, classId, classConfig = ensureState(source)
    local recovery = classConfig and classConfig.recovery
    if not state or classId ~= active.class or not recovery then
        return { success = false, reason = 'class' }
    end

    local item = tostring(recovery.item or '')
    local itemCount = math.max(1, math.floor(tonumber(recovery.itemCount) or 1))
    if item ~= '' then
        local ok, removed = pcall(function()
            return exports.ox_inventory:RemoveItem(source, item, itemCount)
        end)
        if not ok or removed ~= true then return { success = false, reason = 'item' } end
    end

    local reduction = recovery.reduction or {}
    local minimum = math.max(1, math.floor(tonumber(reduction.min) or 10))
    local maximum = math.max(minimum, math.floor(tonumber(reduction.max) or minimum))
    local amount = math.random(minimum, maximum)
    state.pressure = 0
    state.pressureUpdatedAt = GetGameTimer()
    state.recoveryAvailableAt = os.time() + math.max(1, tonumber(recovery.cooldownMinutes) or 20) * 60
    if not setMetadata(source, Config.RecoveryCooldownMetadataKey, state.recoveryAvailableAt) then
        return { success = false, reason = 'metadata' }
    end
    local ok, snapshot = setExcess(source, state.value - amount)
    if not ok then return { success = false, reason = 'metadata' } end

    return { success = true, reduced = amount, snapshot = snapshot }
end)

RegisterNetEvent('ob_manalimit:server:cancelRecovery', function(token)
    local active = recoveries[source]
    if active and active.token == token then recoveries[source] = nil end
end)

AddEventHandler('ob_essencias:server:spent', function(source, spent)
    registerConsumption(source, spent)
end)

exports('GetSnapshot', buildSnapshot)
exports('SetExcess', setExcess)
exports('AddExcess', function(source, amount)
    local state = ensureState(source)
    if not state then return false, buildSnapshot(source) end
    return setExcess(source, state.value + (tonumber(amount) or 0))
end)
exports('RegisterConsumption', registerConsumption)
exports('EvaluateConsumption', evaluateConsumption)
exports('ApplyConsequence', applyConsequence)
exports('GetBlockedCostRatio', function(outcome)
    return clamp(tonumber(Config.Consequences.blockedCostRatio[tostring(outcome or '')]) or 0, 0, 1)
end)

local function notify(source, description, notificationType)
    if source == 0 then
        print(('[ob_manalimit] %s'):format(description))
        return
    end
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Excesso sobrenatural',
        description = description,
        type = notificationType or 'inform',
    })
end

local commands = Config.Commands or {}
if commands.set and commands.set ~= '' then
    lib.addCommand(commands.set, {
        help = 'Define o excesso sobrenatural de um jogador',
        params = {
            { name = 'target', type = 'playerId', help = 'ID do jogador' },
            { name = 'value', type = 'number', help = 'Valor de 0 a 100' },
        },
        restricted = commands.adminPermission or 'group.admin',
    }, function(source, args)
        local ok, snapshot = setExcess(args.target, args.value)
        notify(source, ok
            and ('Excesso do ID %d definido em %.1f%%.'):format(args.target, snapshot.value)
            or 'Nao foi possivel alterar esse jogador.', ok and 'success' or 'error')
    end)
end

if commands.add and commands.add ~= '' then
    lib.addCommand(commands.add, {
        help = 'Adiciona excesso sobrenatural a um jogador',
        params = {
            { name = 'target', type = 'playerId', help = 'ID do jogador' },
            { name = 'value', type = 'number', help = 'Quantidade' },
        },
        restricted = commands.adminPermission or 'group.admin',
    }, function(source, args)
        local state = ensureState(args.target)
        local ok, snapshot = false, nil
        if state then ok, snapshot = setExcess(args.target, state.value + args.value) end
        notify(source, ok
            and ('Excesso do ID %d agora esta em %.1f%%.'):format(args.target, snapshot.value)
            or 'Nao foi possivel alterar esse jogador.', ok and 'success' or 'error')
    end)
end

CreateThread(function()
    local passive = Config.PassiveRecovery or {}
    while true do
        Wait(math.max(10000, tonumber(passive.intervalMs) or 60000))
        if passive.enabled then
            for _, playerId in ipairs(GetPlayers()) do
                local source = tonumber(playerId)
                local state = source and ensureState(source) or nil
                if state and state.value > 0 and state.value <= (tonumber(passive.maximumLevel) or 49.99) then
                    setExcess(source, state.value - math.max(0, tonumber(passive.amountPerMinute) or 0))
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    states[source] = nil
    recoveries[source] = nil
end)
