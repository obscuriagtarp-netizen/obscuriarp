local sentidoActive = false
local sentidoTransitioning = false
local sentidoSequence = 0
local glowVisible = false
local residues = {}
local residueFxReady = false

local stopSentido

local function setArcaneGlow(visible)
    visible = visible == true
    if glowVisible == visible then return end

    glowVisible = visible
    SendNUIMessage({
        action = 'setArcaneSenseGlow',
        visible = visible,
    })
end

local function residueColor(kind)
    return Config.SentidoArcano.colors[kind]
        or Config.SentidoArcano.colors.magic
        or { 58, 126, 255 }
end

local function stopResidueFx(entry)
    if entry then
        entry.nextFxAt = nil
        entry.fxPulse = nil
    end
end

local function clearResidues()
    for _, entry in pairs(residues) do
        stopResidueFx(entry)
    end
    residues = {}
end

local function ensureResidueFx()
    if residueFxReady then return true end

    local fx = Config.SentidoArcano.residueFx or {}
    residueFxReady = ObBruxas.EnsurePtfx(fx.asset or 'scr_powerplay')
    return residueFxReady
end

local function emitResidueFx(entry, now, distance)
    local fx = Config.SentidoArcano.residueFx or {}
    if not entry.coords or not ensureResidueFx() then return end
    if now < (entry.nextFxAt or 0) then return end

    local nearDistance = math.max(1.0, tonumber(fx.nearDistance) or 24.0)
    local middleDistance = math.max(nearDistance, tonumber(fx.middleDistance) or 48.0)
    local interval
    if distance <= nearDistance then
        interval = math.max(150, tonumber(fx.nearInterval) or 180)
    elseif distance <= middleDistance then
        interval = math.max(250, tonumber(fx.middleInterval) or 350)
    else
        interval = math.max(400, tonumber(fx.farInterval) or 650)
    end

    entry.nextFxAt = now + interval
    entry.fxPulse = (entry.fxPulse or 0) + 1

    local color = residueColor(entry.kind)
    local strength = math.max(0.85, math.min(1.28, tonumber(entry.strength) or 1.0))
    local identityOffset = ((tonumber(tostring(entry.id):match('(%d+)$')) or 0) % 5) * 0.025
    local phase = entry.fxPulse * 2.399 + identityOffset
    local spread = math.max(0.0, tonumber(fx.spread) or 0.12)
    local radius = spread * (0.55 + ((entry.fxPulse % 3) * 0.18))

    UseParticleFxAssetNextCall(fx.asset or 'scr_powerplay')
    SetParticleFxNonLoopedColour(
        (tonumber(color[1]) or 58) / 255.0,
        (tonumber(color[2]) or 126) / 255.0,
        (tonumber(color[3]) or 255) / 255.0
    )
    SetParticleFxNonLoopedAlpha(tonumber(fx.alpha) or 0.68)
    StartParticleFxNonLoopedAtCoord(
        fx.effect or 'sp_powerplay_beast_appear_trails',
        entry.coords.x + math.cos(phase) * radius,
        entry.coords.y + math.sin(phase) * radius,
        entry.coords.z + (tonumber(fx.height) or 0.1),
        0.0, 0.0, math.deg(phase) % 360.0,
        (tonumber(fx.scale) or 1.65) * strength,
        false, false, false
    )
end

local function syncResidueFx()
    local now = GetGameTimer()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local renderDistance = math.max(1.0, tonumber(Config.SentidoArcano.renderDistance) or 80.0)

    for id, entry in pairs(residues) do
        if not entry.coords or (entry.expiresAt and entry.expiresAt <= now) then
            stopResidueFx(entry)
            residues[id] = nil
        else
            local coords = vector3(entry.coords.x + 0.0, entry.coords.y + 0.0, entry.coords.z + 0.0)
            local distance = #(playerCoords - coords)
            if distance <= renderDistance then
                emitResidueFx(entry, now, distance)
            else
                stopResidueFx(entry)
            end
        end
    end
end

RegisterNetEvent('ob_bruxas:client:arcaneSnapshot', function(snapshot)
    if not sentidoActive then return end

    local now = GetGameTimer()
    local received = {}

    for _, entry in ipairs(type(snapshot) == 'table' and snapshot or {}) do
        local id = tostring(entry.id or '')
        if id ~= '' and entry.coords then
            local current = residues[id]
            if current then
                local dx = (current.coords.x or 0.0) - (entry.coords.x or 0.0)
                local dy = (current.coords.y or 0.0) - (entry.coords.y or 0.0)
                local dz = (current.coords.z or 0.0) - (entry.coords.z or 0.0)
                if (dx * dx) + (dy * dy) + (dz * dz) > 0.04 then
                    stopResidueFx(current)
                end
                entry.nextFxAt = current.nextFxAt
                entry.fxPulse = current.fxPulse
            end

            entry.expiresAt = now
                + math.max(1000, tonumber(entry.ttl) or Config.SentidoArcano.defaultResidueDuration)
            residues[id] = entry
            received[id] = true
        end
    end

    for id, entry in pairs(residues) do
        if not received[id] then
            stopResidueFx(entry)
            residues[id] = nil
        end
    end
end)

local function startRenderLoop(sequence)
    CreateThread(function()
        local nextRefresh = 0
        local refreshInterval = math.max(1000, tonumber(Config.SentidoArcano.snapshotRefresh) or 3500)
        local residueFx = Config.SentidoArcano.residueFx or {}
        local fxInterval = math.max(100, tonumber(residueFx.updateInterval) or 100)

        while sentidoActive and sentidoSequence == sequence do
            local now = GetGameTimer()
            syncResidueFx()

            if now >= nextRefresh then
                nextRefresh = now + refreshInterval
                TriggerServerEvent('ob_bruxas:server:requestArcaneSnapshot')
            end

            Wait(fxInterval)
        end
    end)
end

local function startSustainLoop(sequence)
    CreateThread(function()
        local interval = math.max(1000, tonumber(Config.SentidoArcano.sustainInterval) or 3000)
        local nextChargeAt = GetGameTimer() + interval

        while sentidoActive and sentidoSequence == sequence do
            if not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
                stopSentido(true, false)
                return
            end

            local now = GetGameTimer()
            if now >= nextChargeAt then
                nextChargeAt = now + interval
                local ok, result = pcall(function()
                    return lib.callback.await('ob_bruxas:server:sustainArcaneSense', false)
                end)

                if not ok or type(result) ~= 'table' or result.success ~= true then
                    ObBruxas.FailAbility('sentido_arcano')
                    stopSentido(false, true)
                    return
                end

                if result.depleted == true then
                    stopSentido(false, true)
                    return
                end
            end

            Wait(150)
        end
    end)
end

stopSentido = function(silent, serverAlreadyStopped)
    if not sentidoActive and not sentidoTransitioning then
        setArcaneGlow(false)
        return
    end

    sentidoSequence = sentidoSequence + 1
    sentidoActive = false
    sentidoTransitioning = false
    clearResidues()
    setArcaneGlow(false)
    ObBruxas.ClearSelection()

    if not serverAlreadyStopped then
        TriggerServerEvent('ob_bruxas:server:arcaneSenseEnded')
    end

    if not silent then
        ObBruxas.StartCooldown('sentido_arcano', Config.SentidoArcano.cooldown)
    end
end

RegisterNetEvent('ob_bruxas:client:sentidoArcano', function()
    if sentidoActive then
        stopSentido(false, false)
        return
    end

    if sentidoTransitioning or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
        ObBruxas.ClearSelection()
        return
    end

    sentidoTransitioning = true
    local ok, result = pcall(function()
        return lib.callback.await('ob_bruxas:server:beginArcaneSense', false)
    end)

    if not ok or type(result) ~= 'table' or result.success ~= true then
        sentidoTransitioning = false
        ObBruxas.ClearSelection()
        ObBruxas.FailAbility('sentido_arcano')
        return
    end

    sentidoSequence = sentidoSequence + 1
    local sequence = sentidoSequence
    sentidoActive = true
    sentidoTransitioning = false
    clearResidues()
    setArcaneGlow(true)
    ObBruxas.UpdateAbility('sentido_arcano', { selected = true })
    TriggerServerEvent('ob_bruxas:server:requestArcaneSnapshot')
    ObBruxas.Notify('Sentido Arcano', 'Os resquicios de mana se revelam ao seu redor.', 'success')

    startRenderLoop(sequence)
    startSustainLoop(sequence)
end)

exports('IsSentidoArcanoActive', function()
    return sentidoActive
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    clearResidues()
    setArcaneGlow(false)
    if sentidoActive then TriggerServerEvent('ob_bruxas:server:arcaneSenseEnded') end
end)
