ObCurandeiras = ObCurandeiras or {}
ObCurandeiras.WingEffectColor = ObCurandeiras.WingEffectColor or nil

local providerRegistered = false
local cachedPlayerData = nil
local crosshairOwner = 'ob_curandeiras'
local crosshairPublished = false
local crosshairThreadRunning = false
local targetSequence = 0
local powerCrosshair = {
    active = false,
    distance = 14.0,
    label = '',
    targetLabel = 'ALVO',
}

function ObCurandeiras.SetWingEffectColor(color)
    if type(color) ~= 'table' then
        ObCurandeiras.WingEffectColor = nil
        return
    end

    ObCurandeiras.WingEffectColor = {
        math.max(0.0, math.min(1.0, tonumber(color[1]) or 0.35)),
        math.max(0.0, math.min(1.0, tonumber(color[2]) or 0.9)),
        math.max(0.0, math.min(1.0, tonumber(color[3]) or 0.55)),
    }
end

local function lower(value)
    return tostring(value or ''):lower()
end

function ObCurandeiras.Notify(title, description, kind, duration)
    if lib and lib.notify then
        lib.notify({
            title = title or 'Curandeira',
            description = description or '',
            type = kind or 'inform',
            duration = duration or 4000,
        })
        return
    end
    pcall(function()
        exports.qbx_core:Notify(description or title or 'Curandeira', kind or 'inform', duration or 4000)
    end)
end

function ObCurandeiras.GetPlayerData()
    if QBX and QBX.PlayerData and QBX.PlayerData.citizenid then
        cachedPlayerData = QBX.PlayerData
        return cachedPlayerData
    end
    local ok, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if ok and data then
        cachedPlayerData = data
    end
    return cachedPlayerData or {}
end

function ObCurandeiras.IsHealer()
    local metadata = ObCurandeiras.GetPlayerData().metadata or {}
    return lower(metadata[Config.ClassMetadataKey]) == lower(Config.ClassId)
end

function ObCurandeiras.IsPowerBlocked()
    local state = LocalPlayer and LocalPlayer.state
    local ped = PlayerPedId()
    local attachedTo = ped ~= 0 and IsEntityAttached(ped) and GetEntityAttachedTo(ped) or 0
    local attachedToVehicle = attachedTo ~= 0
        and DoesEntityExist(attachedTo)
        and IsEntityAVehicle(attachedTo)

    return attachedToVehicle or state and (
        state.obscuriaPowerBlocked == true
        or state.magicFauna == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
    )
end

function ObCurandeiras.EnsureAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

function ObCurandeiras.EnsurePtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2500
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasNamedPtfxAssetLoaded(asset)
end

function ObCurandeiras.UpdateAbility(abilityId, patch)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:UpdateAbility('ob_curandeiras', abilityId, patch)
    end
end

function ObCurandeiras.StartCooldown(abilityId, duration)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:StartCooldown('ob_curandeiras', abilityId, duration)
    end
end

function ObCurandeiras.ClearSelection()
    targetSequence = targetSequence + 1
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:SetSelected('ob_curandeiras', '')
    end
    ObCurandeiras.SetPowerCrosshair(false)
end

function ObCurandeiras.Authorize(abilityId)
    local ok, result = pcall(function()
        return lib.callback.await('ob_curandeiras:server:authorize', false, abilityId)
    end)
    if not ok or type(result) ~= 'table' or result.success ~= true then
        ObCurandeiras.Notify('Curandeira', result and result.message or 'A energia vital nao respondeu.', 'error')
        ObCurandeiras.ClearSelection()
        return false
    end
    return true
end

function ObCurandeiras.AuthorizeNpcAbility(abilityId)
    local ok, result = pcall(function()
        return lib.callback.await('ob_curandeiras:server:authorizeNpc', false, abilityId)
    end)
    if not ok or type(result) ~= 'table' or result.success ~= true then
        ObCurandeiras.Notify('Curandeira', result and result.message or 'A energia vital nao respondeu.', 'error')
        ObCurandeiras.ClearSelection()
        return false
    end
    return true
end

function ObCurandeiras.RaycastFromCamera(maxDistance, flags)
    if GetResourceState('magicSpells') ~= 'started' then return nil end
    local ok, result = pcall(function()
        return exports.magicSpells:RaycastFromCamera(maxDistance or 14.0, flags or -1)
    end)
    return ok and result or nil
end

local function hideClassCrosshair()
    if not crosshairPublished then return end

    if GetResourceState('magicSpells') == 'started' then
        pcall(function()
            exports.magicSpells:HideExternalCrosshair(crosshairOwner)
        end)
    end
    crosshairPublished = false
end

function ObCurandeiras.SetPowerCrosshair(active, options)
    options = type(options) == 'table' and options or {}
    powerCrosshair.active = active == true
    if powerCrosshair.active then
        powerCrosshair.distance = math.max(1.0, tonumber(options.distance) or powerCrosshair.distance)
        powerCrosshair.label = tostring(options.label or '')
        powerCrosshair.targetLabel = tostring(options.targetLabel or 'ALVO')

        if not crosshairThreadRunning then
            crosshairThreadRunning = true
            CreateThread(function()
                while powerCrosshair.active
                    and ObCurandeiras.IsHealer()
                    and not ObCurandeiras.IsPowerBlocked()
                    and GetResourceState('magicSpells') == 'started' do
                    local result = ObCurandeiras.RaycastFromCamera(powerCrosshair.distance, -1)
                    local entity = result and result.entity or 0
                    local hasTarget = entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity)
                        and not IsPedDeadOrDying(entity, true) and entity ~= PlayerPedId()

                    exports.magicSpells:SetExternalCrosshair(crosshairOwner, {
                        visible = true,
                        target = hasTarget,
                        kind = hasTarget and 'ped' or nil,
                        label = hasTarget and powerCrosshair.targetLabel or powerCrosshair.label,
                        priority = 20,
                        ttl = 450,
                    })
                    crosshairPublished = true
                    Wait(100)
                end

                powerCrosshair.active = false
                hideClassCrosshair()
                crosshairThreadRunning = false
            end)
        end
    else
        hideClassCrosshair()
    end
end

function ObCurandeiras.AwaitTarget(abilityId, targetLabel, maxDistance, timeoutMs)
    if ObCurandeiras.IsPowerBlocked() then return nil end
    targetSequence = targetSequence + 1
    local sequence = targetSequence
    local expiresAt = GetGameTimer() + (timeoutMs or 8000)
    ObCurandeiras.UpdateAbility(abilityId, { selected = true })
    ObCurandeiras.SetPowerCrosshair(true, {
        distance = maxDistance,
        label = 'ESQ: ALVO · DIR: VOCÊ',
        targetLabel = ('ESQ: %s · DIR: VOCÊ'):format(targetLabel),
    })

    while sequence == targetSequence and GetGameTimer() < expiresAt do
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 142, true)
        if IsControlJustReleased(0, 177) then break end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 25) then
            ObCurandeiras.ClearSelection()
            return GetPlayerServerId(PlayerId()), PlayerPedId()
        end
        if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
            local result = ObCurandeiras.RaycastFromCamera(maxDistance, -1)
            local entity = result and result.entity or 0
            if entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity)
                and not IsPedDeadOrDying(entity, true) and entity ~= PlayerPedId() then
                local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity))
                if distance <= maxDistance + 0.5 then
                    if IsPedAPlayer(entity) then
                        local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                        if playerIndex ~= -1 then
                            ObCurandeiras.ClearSelection()
                            return GetPlayerServerId(playerIndex), entity
                        end
                    else
                        ObCurandeiras.ClearSelection()
                        return 0, entity
                    end
                end
            end
            ObCurandeiras.Notify(targetLabel, 'Mantenha uma pessoa viva no centro da mira.', 'warning', 2200)
        end
        Wait(0)
    end
    ObCurandeiras.ClearSelection()
    return nil
end

local function abilities()
    return {
        {
            id = 'voo', slot = 1, input = 1, key = '1',
            label = 'Voo',
            description = 'Manifestar asas etéreas e voar livremente.',
            icon = 'nui://ob_curandeiras/web/icons/voo.png',
            clientEvent = 'ob_curandeiras:client:toggleFlight',
        },
        {
            id = 'cura_vital', slot = 2, input = 2, key = '2',
            label = 'Cura Vital',
            description = 'Restaurar gradualmente os próprios ferimentos ou os de outro ser.',
            icon = 'nui://ob_curandeiras/web/icons/cura-vital.png',
            clientEvent = 'ob_curandeiras:client:vitalHeal',
        },
        {
            id = 'serenidade', slot = 3, input = 3, key = '3',
            label = 'Serenidade',
            description = 'Dissipar estresse, medo, ansiedade e exaustão.',
            icon = 'nui://ob_curandeiras/web/icons/serenidade.png',
            clientEvent = 'ob_curandeiras:client:serenity',
        },
        {
            id = 'estancar', slot = 4, input = 4, key = '4',
            label = 'Estancar Sangramento',
            description = 'Interromper hemorragias com regeneração acelerada.',
            icon = 'nui://ob_curandeiras/web/icons/estancar-sangramento.png',
            clientEvent = 'ob_curandeiras:client:stopBleeding',
        },
    }
end

function ObCurandeiras.RefreshProvider()
    if GetResourceState('obscuriaHud') ~= 'started' then
        providerRegistered = false
        return
    end
    if not ObCurandeiras.IsHealer() then
        if providerRegistered then
            exports.obscuriaHud:ClearProvider('ob_curandeiras')
            providerRegistered = false
        end
        return
    end
    if not providerRegistered then
        exports.obscuriaHud:RegisterProvider('ob_curandeiras', {
            label = 'Curandeira',
            archetype = 'healer',
            position = Config.Hud.position,
            theme = Config.Hud.theme,
            abilities = abilities(),
            visible = true,
        })
        providerRegistered = true
    end
    exports.obscuriaHud:SetActiveProvider('ob_curandeiras')
    exports.obscuriaHud:SetProviderVisible('ob_curandeiras', true)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(500, ObCurandeiras.RefreshProvider) end)
RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then
        cachedPlayerData = nil
        SetTimeout(100, ObCurandeiras.RefreshProvider)
    end
end)
local function handleExternalClassChange(classId)
    cachedPlayerData = ObCurandeiras.GetPlayerData()
    cachedPlayerData.metadata = cachedPlayerData.metadata or {}
    cachedPlayerData.metadata[Config.ClassMetadataKey] = classId
    SetTimeout(250, ObCurandeiras.RefreshProvider)
end

RegisterNetEvent('classeSelector:classChosenSuccess', handleExternalClassChange)
RegisterNetEvent('classeSelector:classChanged', handleExternalClassChange)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'obscuriaHud' then
        SetTimeout(700, ObCurandeiras.RefreshProvider)
    end
end)
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'obscuriaHud' then
        providerRegistered = false
    elseif resourceName == GetCurrentResourceName() then
        ObCurandeiras.ClearSelection()
        if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
            exports.obscuriaHud:ClearProvider('ob_curandeiras')
        end
        providerRegistered = false
    end
end)

CreateThread(function()
    Wait(1200)
    ObCurandeiras.RefreshProvider()
end)
