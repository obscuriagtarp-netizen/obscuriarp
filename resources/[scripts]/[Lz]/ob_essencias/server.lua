local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getDefinition(player)
    local metadata = player and player.PlayerData and player.PlayerData.metadata or {}
    local classId = tostring(metadata[Config.ClassMetadataKey] or ''):lower()
    return Config.Classes[classId], classId, metadata
end

local function setMetadata(source, key, value)
    local player = getPlayer(source)
    if player and player.Functions then
        local setter = player.Functions.SetMetaData or player.Functions.SetMetadata
        if setter then
            local ok, result = pcall(function()
                return setter(key, value)
            end)
            if ok and result ~= false then
                return true
            end
        end
    end

    local ok, result = pcall(function()
        return exports.qbx_core:SetMetadata(source, key, value)
    end)
    return ok and result ~= false
end

local function buildPayload(source, initialize)
    local player = getPlayer(source)
    if not player then
        return { success = false, value = 0, max = 0 }
    end

    local definition, classId, metadata = getDefinition(player)
    if not definition then
        return {
            success = false,
            class = classId ~= '' and classId or nil,
            value = 0,
            max = 0,
        }
    end

    local maxValue = tonumber(metadata[definition.maxKey]) or tonumber(definition.max) or 100
    local value = tonumber(metadata[definition.key])
    if value == nil then
        value = math.min(maxValue, tonumber(definition.initial) or maxValue)
    end

    maxValue = math.max(1, math.floor(maxValue + 0.5))
    value = math.max(0, math.min(maxValue, math.floor(value + 0.5)))

    if initialize then
        if tonumber(metadata[definition.maxKey]) ~= maxValue then
            setMetadata(source, definition.maxKey, maxValue)
        end
        if tonumber(metadata[definition.key]) ~= value then
            setMetadata(source, definition.key, value)
        end
    end

    return {
        success = true,
        class = classId,
        key = definition.key,
        maxKey = definition.maxKey,
        label = definition.label,
        value = value,
        max = maxValue,
    }
end

local function pushUpdate(source, payload)
    if GetPlayerName(source) then
        local statePlayer = Player(source)
        if statePlayer and statePlayer.state then
            statePlayer.state:set('essencia', payload.value, true)
            statePlayer.state:set('essenciaMax', payload.max, true)
            statePlayer.state:set('essenciaKey', payload.key, true)
        end
        TriggerClientEvent('ob_essencias:client:update', source, payload)
    end
end

local function changeEssence(source, amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount then
        return { success = false, value = 0, max = 0 }
    end

    local payload = buildPayload(source, true)
    if not payload.success then
        return payload
    end

    local target = payload.value + amount
    if amount < 0 and target < 0 then
        payload.success = false
        payload.reason = 'insufficient'
        return payload
    end

    local value = math.max(0, math.min(payload.max, math.floor(target + 0.5)))
    if value == payload.value then
        return payload
    end

    if not setMetadata(source, payload.key, value) then
        payload.success = false
        payload.reason = 'metadata'
        return payload
    end

    local previousValue = payload.value
    payload.value = value
    pushUpdate(source, payload)

    if amount < 0 then
        local spent = math.max(0, previousValue - value)
        if spent > 0 then
            TriggerEvent('ob_essencias:server:spent', source, spent, {
                class = payload.class,
                key = payload.key,
                label = payload.label,
                value = payload.value,
                max = payload.max,
            })
        end
    end
    return payload
end

local function setEssence(source, value)
    value = tonumber(value)
    if not value or value ~= value then
        return { success = false, value = 0, max = 0 }
    end

    local payload = buildPayload(source, true)
    if not payload.success then
        return payload
    end

    value = math.max(0, math.min(payload.max, math.floor(value + 0.5)))
    if not setMetadata(source, payload.key, value) then
        payload.success = false
        payload.reason = 'metadata'
        return payload
    end

    payload.value = value
    pushUpdate(source, payload)
    return payload
end

local function evaluateManaLimit(source, amount, context)
    if GetResourceState('ob_manalimit') ~= 'started' then
        return { allow = true, outcome = 'ok' }
    end

    local ok, decision = pcall(function()
        return exports.ob_manalimit:EvaluateConsumption(source, amount, context)
    end)
    if not ok or type(decision) ~= 'table' then
        print(('[ob_essencias] ob_manalimit nao respondeu; consumo liberado para o ID %s.'):format(source))
        return { allow = true, outcome = 'ok' }
    end

    return decision
end

local function applyManaLimitConsequence(source, decision)
    if GetResourceState('ob_manalimit') ~= 'started' then return end
    pcall(function()
        exports.ob_manalimit:ApplyConsequence(source, decision)
    end)
end

local function blockConsumption(source, amount, current, decision)
    local ratio = 0
    local ok, result = pcall(function()
        return exports.ob_manalimit:GetBlockedCostRatio(decision.outcome)
    end)
    if ok then ratio = math.max(0, math.min(1, tonumber(result) or 0)) end

    local penalty = math.min(amount, math.max(0, math.floor(amount * ratio + 0.5)))
    local payload = penalty > 0 and changeEssence(source, -penalty) or current
    payload.success = false
    payload.reason = 'overload'
    payload.overload = decision
    applyManaLimitConsequence(source, decision)
    return payload
end

local function preflightEssence(source, amount, context)
    amount = math.abs(tonumber(amount) or 0)
    local current = buildPayload(source, true)
    if not current.success or amount <= 0 then return current end
    if current.value < amount then
        current.success = false
        current.reason = 'insufficient'
        return current
    end

    local decision = evaluateManaLimit(source, amount, context)
    if decision.allow == false then
        return blockConsumption(source, amount, current, decision)
    end

    current.success = true
    current.preflight = true
    return current
end

local function consumeEssence(source, amount, context)
    amount = math.abs(tonumber(amount) or 0)
    if amount <= 0 then
        local payload = buildPayload(source, true)
        payload.success = payload.success == true
        return payload
    end

    local current = buildPayload(source, true)
    if not current.success then return current end
    if current.value < amount then
        current.success = false
        current.reason = 'insufficient'
        return current
    end

    local decision = type(context) == 'table' and context.skipEvaluation == true
        and { allow = true, outcome = 'ok' }
        or evaluateManaLimit(source, amount, context)
    if decision.allow == false then
        return blockConsumption(source, amount, current, decision)
    end

    return changeEssence(source, -amount)
end

lib.callback.register('ob_essencias:server:get', function(source)
    local payload = buildPayload(source, true)
    if payload.success then
        pushUpdate(source, payload)
    end
    return payload
end)

lib.callback.register('ob_essencias:server:change', function(source, amount)
    amount = tonumber(amount)
    local clientConfig = Config.Client or {}
    local maxCost = math.max(1, tonumber(clientConfig.maxCostPerRequest) or 100)

    if not amount or amount == 0 or math.abs(amount) > maxCost then
        return { success = false, reason = 'invalid_amount', value = 0, max = 0 }
    end

    if amount > 0 and clientConfig.allowRestore ~= true then
        return { success = false, reason = 'server_only', value = 0, max = 0 }
    end

    if amount < 0 then
        return consumeEssence(source, math.abs(amount), { origin = 'client' })
    end

    return changeEssence(source, amount)
end)

lib.callback.register('ob_essencias:server:set', function(source, value)
    if not Config.Client or Config.Client.allowSet ~= true then
        return { success = false, reason = 'server_only', value = 0, max = 0 }
    end
    return setEssence(source, value)
end)

exports('GetEssencia', function(source)
    local payload = buildPayload(source, true)
    return payload.value, payload.max, payload.key
end)

exports('GetEssenciaMetaKey', function(source)
    return buildPayload(source, true).key
end)

exports('GetEssenciaSnapshot', function(source)
    return buildPayload(source, true)
end)

exports('ConsumeEssencia', function(source, amount, context)
    return consumeEssence(source, amount, context)
end)

exports('PreflightEssencia', function(source, amount, context)
    return preflightEssence(source, amount, context)
end)

exports('AddEssencia', function(source, amount)
    return changeEssence(source, math.abs(tonumber(amount) or 0)).success
end)

exports('RemoveEssencia', function(source, amount)
    return changeEssence(source, -math.abs(tonumber(amount) or 0)).success
end)

exports('SetEssencia', function(source, value)
    return setEssence(source, value).success
end)

local function notifyCommand(source, title, description, notificationType)
    if source == 0 then
        print(('[ob_essencias] %s: %s'):format(title, description))
        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = description,
        type = notificationType or 'inform',
    })
end

local commandConfig = Config.Commands or {}
if commandConfig.AddEssence and commandConfig.AddEssence ~= '' then
    lib.addCommand(commandConfig.AddEssence, {
        help = 'Adiciona essencia a um jogador',
        params = {
            { name = 'target', type = 'playerId', help = 'ID do jogador' },
            { name = 'amount', type = 'number', help = 'Quantidade de essencia' },
        },
        restricted = commandConfig.AdminPermission or 'group.admin',
    }, function(source, args)
        local amount = math.floor(tonumber(args.amount) or 0)
        if amount <= 0 then
            notifyCommand(source, 'Essencia', 'Informe uma quantidade maior que zero.', 'error')
            return
        end

        local payload = changeEssence(args.target, amount)
        if not payload.success then
            notifyCommand(source, 'Essencia', 'Nao foi possivel alterar a essencia desse jogador.', 'error')
            return
        end

        local targetName = GetPlayerName(args.target) or ('ID %s'):format(args.target)
        local status = ('%s esta com %d/%d de %s.'):format(
            targetName,
            payload.value,
            payload.max,
            payload.label or 'essencia'
        )

        notifyCommand(source, 'Essencia adicionada', status, 'success')
        if source ~= args.target then
            notifyCommand(
                args.target,
                'Essencia restaurada',
                ('Sua %s esta em %d/%d.'):format(payload.label or 'essencia', payload.value, payload.max),
                'success'
            )
        end
    end)
end

if commandConfig.SetEssence and commandConfig.SetEssence ~= '' then
    lib.addCommand(commandConfig.SetEssence, {
        help = 'Define a essencia de um jogador',
        params = {
            { name = 'target', type = 'playerId', help = 'ID do jogador' },
            { name = 'value', type = 'number', help = 'Novo valor da essencia' },
        },
        restricted = commandConfig.AdminPermission or 'group.admin',
    }, function(source, args)
        local payload = setEssence(args.target, args.value)
        if not payload.success then
            notifyCommand(source, 'Essencia', 'Nao foi possivel definir a essencia desse jogador.', 'error')
            return
        end

        local targetName = GetPlayerName(args.target) or ('ID %s'):format(args.target)
        notifyCommand(
            source,
            'Essencia definida',
            ('%s esta com %d/%d de %s.'):format(
                targetName,
                payload.value,
                payload.max,
                payload.label or 'essencia'
            ),
            'success'
        )
    end)
end

if Config.Regen.enabled then
    CreateThread(function()
        while true do
            Wait(math.max(1000, tonumber(Config.Regen.interval) or 10000))
            for _, playerId in ipairs(GetPlayers()) do
                local source = tonumber(playerId)
                local player = source and getPlayer(source)
                local definition = player and getDefinition(player) or nil
                local amount = definition and tonumber(definition.regen) or 0
                if source and amount > 0 then
                    changeEssence(source, amount)
                end
            end
        end
    end)
end

if Config.Debug then
    RegisterCommand(Config.DebugCommand or 'setessencia', function(source, args)
        if source <= 0 then
            return
        end
        setEssence(source, tonumber(args[1]) or 100)
    end, false)
end
