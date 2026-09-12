local activeEffects = {}

local palettes = {
    humano = { 0.12, 0.72, 1.0 },
    bruxa = { 0.62, 0.12, 1.0 },
    vampiro = { 0.88, 0.02, 0.03 },
    curandeira = { 0.20, 0.94, 0.38 },
}

local function stopHandle(handle)
    if handle and handle ~= 0 and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, false)
    end
end

local function stopEffect(key)
    local effect = activeEffects[key]
    if not effect then return end
    effect.active = false
    stopHandle(effect.handle)
    stopHandle(effect.playerHandle)
    activeEffects[key] = nil
end

local function playerPedFromSource(sourceId)
    local player = GetPlayerFromServerId(tonumber(sourceId) or -1)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    return ped ~= 0 and DoesEntityExist(ped) and ped or nil
end

local function setLoopedFxColour(handle, color, alpha)
    if not handle or handle == 0 then return end
    SetParticleFxLoopedColour(handle, color[1], color[2], color[3], false)
    SetParticleFxLoopedAlpha(handle, alpha or 0.8)
end

local function startLoopedAt(asset, fx, coords, scale, color, alpha)
    if not ObIlegalClient.EnsurePtfx(asset, 900) then return nil end
    UseParticleFxAssetNextCall(asset)
    local handle = StartParticleFxLoopedAtCoord(
        fx,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        scale,
        false, false, false, false
    )
    if not handle or handle == 0 then return nil end
    setLoopedFxColour(handle, color, alpha)
    return handle
end

local function timedLoopedFx(asset, fx, coords, scale, color, alpha, lifetime)
    CreateThread(function()
        local handle = startLoopedAt(asset, fx, coords, scale, color, alpha)
        if not handle then return end
        Wait(lifetime or 1200)
        stopHandle(handle)
    end)
end

local function trailNodes(asset, fx, startCoords, endCoords, scale, color)
    CreateThread(function()
        if not ObIlegalClient.EnsurePtfx(asset, 900) then return end
        local direction = endCoords - startCoords
        local distance = #direction
        if distance < 0.2 then return end
        direction = direction / distance
        local count = math.min(18, math.max(5, math.floor(distance / 0.34)))

        for index = 1, count do
            local progress = index / count
            local point = startCoords + (direction * (distance * progress))
            UseParticleFxAssetNextCall(asset)
            local handle = StartParticleFxLoopedAtCoord(
                fx,
                point.x, point.y, point.z + (math.sin(progress * math.pi) * 0.10),
                0.0, 0.0, 0.0,
                scale,
                false, false, false, false
            )
            setLoopedFxColour(handle, color, 0.88)
            if handle and handle ~= 0 then
                local lifetime = math.floor(330 + (progress * 690))
                CreateThread(function()
                    Wait(lifetime)
                    stopHandle(handle)
                end)
            end
            Wait(24)
        end
    end)
end

local function timedBoneFx(asset, fx, ped, bone, scale, color, lifetime)
    if not ped or not DoesEntityExist(ped) then return end
    CreateThread(function()
        if not ObIlegalClient.EnsurePtfx(asset, 700) then return end
        UseParticleFxAssetNextCall(asset)
        local handle = StartParticleFxLoopedOnEntityBone(
            fx,
            ped,
            0.10, 0.0, 0.0,
            0.0, 0.0, 0.0,
            GetPedBoneIndex(ped, bone),
            scale,
            false, false, false
        )
        setLoopedFxColour(handle, color, 0.90)
        Wait(lifetime or 1200)
        stopHandle(handle)
    end)
end

local function nonLoopedBurst(asset, fx, coords, scale, color)
    if not ObIlegalClient.EnsurePtfx(asset, 700) then return end
    UseParticleFxAssetNextCall(asset)
    SetParticleFxNonLoopedColour(color[1], color[2], color[3])
    SetParticleFxNonLoopedAlpha(0.9)
    StartParticleFxNonLoopedAtCoord(
        fx,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        scale,
        false, false, false
    )
end

local function cameraImpact(coords, strength)
    local here = GetEntityCoords(PlayerPedId())
    if #(here - vector3(coords.x, coords.y, coords.z)) > 26.0 then return end
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', strength or 0.16)
end

local function witchImpact(coords, caster)
    local target = vector3(coords.x, coords.y, coords.z + 0.72)
    local start = caster and GetPedBoneCoords(caster, 57005, 0.12, 0.0, 0.0)
        or vector3(coords.x, coords.y - 2.0, coords.z + 1.1)
    local color = palettes.bruxa
    local asset, fx = 'core', 'fire_petroltank_heli'
    if ObIlegalClient.EnsurePtfx('ob_fogo_vermelho', 500) then
        asset, fx = 'ob_fogo_vermelho', 'ob_fogo_vermelho'
    end

    if caster then timedBoneFx(asset, fx, caster, 57005, 0.42, color, 1250) end
    trailNodes('core', 'fire_petroltank_heli', start, target, 0.68, { 1.0, 0.05, 0.02 })
    CreateThread(function()
        Wait(560)
        timedLoopedFx('core', 'ent_ray_meth_fires', target, 0.88, { 1.0, 0.08, 0.03 }, 0.82, 1400)
        cameraImpact(coords, 0.19)
    end)
end

local function vampireImpact(coords, caster)
    local target = vector3(coords.x, coords.y, coords.z + 0.72)
    local origin = caster and GetPedBoneCoords(caster, 24818, 0.0, 0.0, 0.0)
        or vector3(coords.x, coords.y - 1.0, coords.z + 1.0)
    local color = palettes.vampiro

    for index = 1, 3 do
        local offset = ((index - 2) * 0.22)
        local circuitPoint = vector3(target.x + offset, target.y, target.z + (index * 0.10))
        local delay = (index - 1) * 90
        CreateThread(function()
            Wait(delay)
            trailNodes('scr_powerplay', 'scr_powerplay_beast_vapor', origin, circuitPoint, 0.30, color)
        end)
    end
    CreateThread(function()
        Wait(620)
        timedLoopedFx('scr_powerplay', 'scr_powerplay_beast_vapor', target, 0.82, color, 0.78, 1500)
        nonLoopedBurst('core', 'ent_sht_electrical_box', target, 0.48, color)
    end)
    cameraImpact(coords, 0.15)
end

local function healerImpact(coords, caster)
    local target = vector3(coords.x, coords.y, coords.z + 0.68)
    local destination = caster and GetPedBoneCoords(caster, 24818, 0.0, 0.0, 0.0)
        or vector3(coords.x, coords.y - 1.3, coords.z + 0.55)
    local color = palettes.curandeira
    for index = 1, 5 do
        local angle = ((index - 1) / 5.0) * (math.pi * 2.0)
        local origin = vector3(
            coords.x + (math.cos(angle) * 1.45),
            coords.y + (math.sin(angle) * 1.45),
            coords.z + 0.05
        )
        local delay = (index - 1) * 80
        CreateThread(function()
            Wait(delay)
            trailNodes('scr_powerplay', 'scr_powerplay_beast_vapor', origin, target, 0.24, color)
        end)
    end
    CreateThread(function()
        Wait(760)
        timedLoopedFx('scr_powerplay', 'scr_powerplay_beast_vapor', target, 0.68, color, 0.76, 1550)
        for index = 1, 3 do
            local offset = ((index - 2) * 0.16)
            local pullOrigin = vector3(target.x + offset, target.y, target.z + (index * 0.06))
            CreateThread(function()
                Wait((index - 1) * 85)
                trailNodes('scr_powerplay', 'scr_powerplay_beast_vapor', pullOrigin, destination, 0.22, color)
            end)
        end
        cameraImpact(coords, 0.11)
    end)
end

local function humanImpact(coords)
    local target = vector3(coords.x, coords.y, coords.z + 0.72)
    for index = 1, 4 do
        local delay = (index - 1) * 130
        CreateThread(function()
            Wait(delay)
            nonLoopedBurst('core', 'ent_sht_electrical_box', target, 0.55, palettes.humano)
        end)
    end
    cameraImpact(coords, 0.12)
end

RegisterNetEvent('ob_ilegal:client:routeImpact', function(data)
    local coords = ObIlegalShared.NormalizeCoords(data and data.coords)
    if not coords then return end
    local here = GetEntityCoords(PlayerPedId())
    if #(here - vector3(coords.x, coords.y, coords.z)) > 120.0 then return end

    local classId = tostring(data.classId or '')
    local caster = playerPedFromSource(data.sourceId)
    if classId == 'bruxa' then
        witchImpact(coords, caster)
    elseif classId == 'vampiro' then
        vampireImpact(coords, caster)
    elseif classId == 'curandeira' then
        healerImpact(coords, caster)
    else
        humanImpact(coords)
    end
end)

RegisterNetEvent('ob_ilegal:client:startAtmFx', function(key, classId, coords, sourceId, duration)
    coords = ObIlegalShared.NormalizeCoords(coords)
    if not key or not coords then return end

    local here = GetEntityCoords(PlayerPedId())
    if #(here - vector3(coords.x, coords.y, coords.z)) > 120.0 then return end

    stopEffect(key)
    local color = palettes[classId] or palettes.humano
    local effect = { active = true }
    activeEffects[key] = effect

    if classId ~= 'humano' and ObIlegalClient.EnsurePtfx('scr_powerplay') then
        UseParticleFxAssetNextCall('scr_powerplay')
        effect.handle = StartParticleFxLoopedAtCoord(
            'scr_powerplay_beast_vapor',
            coords.x, coords.y, coords.z + 0.55,
            0.0, 0.0, 0.0,
            classId == 'vampiro' and 0.62 or 0.52,
            false, false, false, false
        )
        if effect.handle and effect.handle ~= 0 then
            SetParticleFxLoopedColour(effect.handle, color[1], color[2], color[3], false)
            SetParticleFxLoopedAlpha(effect.handle, 0.70)
        end
    end

    if classId == 'vampiro' and ObIlegalClient.EnsurePtfx('scr_powerplay') then
        local sourcePed = playerPedFromSource(sourceId)
        if sourcePed then
            UseParticleFxAssetNextCall('scr_powerplay')
            effect.playerHandle = StartParticleFxLoopedOnEntityBone(
                'sp_powerplay_beast_appear_trails',
                sourcePed,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                24818,
                0.75,
                false, false, false
            )
            if effect.playerHandle and effect.playerHandle ~= 0 then
                SetParticleFxLoopedColour(effect.playerHandle, color[1], color[2], color[3], false)
                SetParticleFxLoopedAlpha(effect.playerHandle, 0.45)
            end
        end
    end

    CreateThread(function()
        local expiresAt = GetGameTimer() + math.max(3000, tonumber(duration) or 30000)
        local nextSpark = 0
        while effect.active and GetGameTimer() < expiresAt do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))
            if distance < 38.0 then
                DrawLightWithRange(
                    coords.x, coords.y, coords.z + 0.8,
                    math.floor(color[1] * 255),
                    math.floor(color[2] * 255),
                    math.floor(color[3] * 255),
                    2.4,
                    classId == 'humano' and 1.5 or 1.0
                )
            end

            if classId == 'humano' and distance < 55.0 and GetGameTimer() >= nextSpark then
                nextSpark = GetGameTimer() + 450
                if ObIlegalClient.EnsurePtfx('core', 500) then
                    UseParticleFxAssetNextCall('core')
                    SetParticleFxNonLoopedColour(color[1], color[2], color[3])
                    StartParticleFxNonLoopedAtCoord(
                        'ent_sht_electrical_box',
                        coords.x, coords.y, coords.z + 0.75,
                        0.0, 0.0, 0.0,
                        0.35, false, false, false
                    )
                end
            end
            Wait(distance < 38.0 and 0 or 250)
        end
        stopEffect(key)
    end)
end)

RegisterNetEvent('ob_ilegal:client:stopAtmFx', function(key)
    stopEffect(key)
end)

RegisterNetEvent('ob_ilegal:client:policeAlert', function(data)
    local coords = ObIlegalShared.NormalizeCoords(data and data.coords)
    if not coords then return end

    ObIlegalClient.Notify('Uma violação de caixa eletrônico foi detectada.', 'warning')

    local radius = AddBlipForRadius(coords.x, coords.y, coords.z, tonumber(data.radius) or 90.0)
    SetBlipColour(radius, 1)
    SetBlipAlpha(radius, 85)

    local point = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(point, 161)
    SetBlipColour(point, 1)
    SetBlipScale(point, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Violação de ATM')
    EndTextCommandSetBlipName(point)

    CreateThread(function()
        Wait(math.max(5000, tonumber(data.duration) or 60000))
        if DoesBlipExist(radius) then RemoveBlip(radius) end
        if DoesBlipExist(point) then RemoveBlip(point) end
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for key in pairs(activeEffects) do stopEffect(key) end
end)
