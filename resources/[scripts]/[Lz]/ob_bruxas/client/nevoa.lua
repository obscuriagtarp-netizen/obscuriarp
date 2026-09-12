local fogCasting = false
local fogSequence = 0
local activeFogGroups = {}

local function stopFx(handle)
    if handle and handle ~= 0 and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, false)
    end
end

local function stopFogGroup(sequence)
    local handle = activeFogGroups[sequence]
    if not handle then return end

    stopFx(handle)
    activeFogGroups[sequence] = nil
end

local function startFog(center, height, radius, referenceRadius, layer)
    if type(layer) ~= 'table'
        or not layer.asset
        or not layer.effect
        or not ObBruxas.EnsurePtfx(layer.asset) then
        return nil
    end

    local color = layer.color or { 0.20, 0.27, 0.48 }
    local alpha = tonumber(layer.alpha) or 0.7
    local baseScale = tonumber(layer.scale) or 1.0
    local radiusScale = radius / math.max(1.0, referenceRadius)

    UseParticleFxAssetNextCall(layer.asset)
    local handle = StartParticleFxLoopedAtCoord(
        layer.effect,
        center.x,
        center.y,
        center.z + height,
        0.0,
        0.0,
        0.0,
        baseScale * radiusScale,
        false, false, false, false
    )

    if not handle or handle == 0 then
        return nil
    end

    SetParticleFxLoopedColour(handle, color[1], color[2], color[3], false)
    SetParticleFxLoopedAlpha(handle, alpha)
    return handle
end

local function playWitchFog(coords, duration, radius)
    if type(coords) ~= 'table' then return end

    local config = Config.NevoaBruxas or {}
    local effect = config.fx or {}
    local center = vector3(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0
    )
    local fogDuration = math.max(1000, tonumber(duration) or config.duration or 20000)
    local fogRadius = math.max(2.0, tonumber(radius) or config.radius or 8.5)
    local height = tonumber(effect.height) or 0.16
    local referenceRadius = math.max(1.0, tonumber(effect.referenceRadius) or fogRadius)

    fogSequence = fogSequence + 1
    local sequence = fogSequence
    local handle = startFog(
        center,
        height,
        fogRadius,
        referenceRadius,
        effect.smoke
    )
    if not handle then
        print('[ob_bruxas] Nenhuma particula da Nevoa das Bruxas foi criada.')
        return
    end

    activeFogGroups[sequence] = handle

    CreateThread(function()
        Wait(fogDuration)
        stopFogGroup(sequence)
    end)
end

RegisterNetEvent('ob_bruxas:client:showWitchFog', function(coords, duration, radius)
    playWitchFog(coords, duration, radius)
end)

RegisterNetEvent('ob_bruxas:client:nevoaBruxas', function()
    if fogCasting or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
        ObBruxas.FailAbility('nevoa_bruxas')
        return
    end

    fogCasting = true
    ObBruxas.UpdateAbility('nevoa_bruxas', { selected = true })

    CreateThread(function()
        local config = Config.NevoaBruxas or {}
        local castTime = math.max(0, tonumber(config.castTime) or 1100)
        local ped = PlayerPedId()
        local animation = config.animation or {}

        if animation.dict and animation.name and ObBruxas.EnsureAnim(animation.dict) then
            TaskPlayAnim(
                ped,
                animation.dict,
                animation.name,
                4.0, -4.0,
                castTime,
                animation.flag or 33,
                0.0,
                false, false, false
            )
        end

        if castTime > 0 then Wait(castTime) end
        ClearPedSecondaryTask(ped)

        if IsEntityDead(ped) or not ObBruxas.IsWitch() or ObBruxas.IsPowerBlocked() then
            fogCasting = false
            ObBruxas.UpdateAbility('nevoa_bruxas', { selected = false })
            ObBruxas.FailAbility('nevoa_bruxas')
            return
        end

        local ok, result = pcall(function()
            return lib.callback.await('ob_bruxas:server:castWitchFog', false)
        end)

        if ok and type(result) == 'table' and result.success == true then
            playWitchFog(
                result.coords,
                tonumber(result.duration) or config.duration,
                tonumber(result.radius) or config.radius
            )
            ObBruxas.StartCooldown(
                'nevoa_bruxas',
                tonumber(result.cooldown) or config.cooldown or 40000
            )
            ObBruxas.Notify(
                'Nevoa das Bruxas',
                'A nevoa encobre seus passos e a conjuracao ao redor.',
                'success',
                3200
            )
        else
            ObBruxas.FailAbility('nevoa_bruxas')
        end

        fogCasting = false
        ObBruxas.UpdateAbility('nevoa_bruxas', { selected = false })
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for sequence in pairs(activeFogGroups) do
        stopFogGroup(sequence)
    end
end)
