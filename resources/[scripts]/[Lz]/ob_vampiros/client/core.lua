ObVampiros = ObVampiros or {}

local providerRegistered = false
local cachedPlayerData = nil
local crosshairOwner = 'ob_vampiros'
local crosshairPublished = false
local crosshairThreadRunning = false
local powerCrosshair = {
    active = false,
    distance = 15.0,
    label = '',
    targetLabel = 'ALVO',
}
local targetSequence = 0

local function lower(value)
    return tostring(value or ''):lower()
end

function ObVampiros.GetPlayerData()
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

function ObVampiros.IsVampire()
    local metadata = ObVampiros.GetPlayerData().metadata or {}
    return lower(metadata[Config.ClassMetadataKey]) == lower(Config.ClassId)
end

function ObVampiros.IsSolarWeakened()
    local state = LocalPlayer and LocalPlayer.state
    return Config.SolarWeakness and Config.SolarWeakness.enabled ~= false
        and state and state.obSunWeakened == true or false
end

function ObVampiros.IsPowerBlocked()
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
        or state.obVampireHarvesting == true
    )
end

function ObVampiros.EnsureModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(hash) and hash or nil
end

function ObVampiros.EnsureAnim(dict, timeoutMs)
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + math.max(500, tonumber(timeoutMs) or 3000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

function ObVampiros.EnsurePtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2500
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasNamedPtfxAssetLoaded(asset)
end

function ObVampiros.UpdateAbility(abilityId, patch)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:UpdateAbility('ob_vampiros', abilityId, patch)
    end
end

function ObVampiros.StartCooldown(abilityId, duration)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:StartCooldown('ob_vampiros', abilityId, duration)
    end
end

function ObVampiros.FailAbility(abilityId, message)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        pcall(function()
            exports.obscuriaHud:PulseAbility('ob_vampiros', abilityId, 'error')
        end)
    end

    if message and message ~= '' then
        lib.notify({
            title = 'Poder vampirico',
            description = message,
            type = 'error',
        })
    end
end

function ObVampiros.ClearSelection()
    targetSequence = targetSequence + 1
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:SetSelected('ob_vampiros', '')
    end
    ObVampiros.SetPowerCrosshair(false)
end

function ObVampiros.Authorize(abilityId)
    local ok, result = pcall(function()
        return lib.callback.await('ob_vampiros:server:authorize', false, abilityId)
    end)
    if not ok or type(result) ~= 'table' or result.success ~= true then
        ObVampiros.ClearSelection()
        ObVampiros.FailAbility(abilityId)
        return false
    end
    return true
end

function ObVampiros.IsFarmPuma(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) or not IsEntityAPed(entity)
        or IsPedAPlayer(entity) then
        return false
    end

    local validModel = false
    for _, configuredModel in ipairs((Config.PumaFarm or {}).models or {}) do
        local model = type(configuredModel) == 'number' and configuredModel or joaat(configuredModel)
        if GetEntityModel(entity) == model then
            validModel = true
            break
        end
    end

    return validModel and Entity(entity).state.obVampireFarmPuma == true
end

function ObVampiros.RaycastFromCamera(maxDistance, flags)
    if GetResourceState('magicSpells') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return exports.magicSpells:RaycastFromCamera(maxDistance or 15.0, flags or -1)
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

function ObVampiros.SetPowerCrosshair(active, options)
    options = type(options) == 'table' and options or {}
    powerCrosshair.active = active == true
    if powerCrosshair.active then
        powerCrosshair.distance = math.max(1.0, tonumber(options.distance) or powerCrosshair.distance)
        powerCrosshair.label = tostring(options.label or '')
        powerCrosshair.targetLabel = tostring(options.targetLabel or 'ALVO')
        powerCrosshair.allowFarmPuma = options.allowFarmPuma == true

        if not crosshairThreadRunning then
            crosshairThreadRunning = true
            CreateThread(function()
                while powerCrosshair.active
                    and ObVampiros.IsVampire()
                    and not ObVampiros.IsPowerBlocked()
                    and GetResourceState('magicSpells') == 'started' do
                    local result = ObVampiros.RaycastFromCamera(powerCrosshair.distance, -1)
                    local entity = result and result.entity or 0
                    local isPlayerTarget = entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity)
                        and IsPedAPlayer(entity) and entity ~= PlayerPedId()
                    local isPumaTarget = powerCrosshair.allowFarmPuma == true
                        and ObVampiros.IsFarmPuma(entity)
                    local hasTarget = (isPlayerTarget or isPumaTarget)
                        and not IsPedDeadOrDying(entity, true)

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

function ObVampiros.AwaitTarget(abilityId, label, maxDistance, timeoutMs)
    if ObVampiros.IsPowerBlocked() then
        ObVampiros.FailAbility(abilityId)
        return nil
    end

    targetSequence = targetSequence + 1
    local sequence = targetSequence
    local expiresAt = GetGameTimer() + (timeoutMs or 8000)
    ObVampiros.UpdateAbility(abilityId, { selected = true })
    ObVampiros.SetPowerCrosshair(true, {
        distance = maxDistance,
        label = 'MIRE EM UM ALVO',
        targetLabel = label,
        allowFarmPuma = abilityId == 'abraco_noite',
    })

    while sequence == targetSequence and GetGameTimer() < expiresAt do
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        if IsDisabledControlJustReleased(0, 25) or IsControlJustReleased(0, 177) then
            break
        end

        if IsDisabledControlJustReleased(0, 24) then
            local result = ObVampiros.RaycastFromCamera(maxDistance, -1)
            local entity = result and result.entity or 0
            if entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity)
                and not IsPedDeadOrDying(entity, true) and entity ~= PlayerPedId() then
                local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity))
                if distance <= maxDistance + 0.5 then
                    if IsPedAPlayer(entity) then
                        local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                        if playerIndex ~= -1 then
                            ObVampiros.ClearSelection()
                            return GetPlayerServerId(playerIndex), entity
                        end
                    elseif abilityId == 'abraco_noite' and ObVampiros.IsFarmPuma(entity) then
                        ObVampiros.ClearSelection()
                        return 0, entity
                    end
                end
            end
            ObVampiros.FailAbility(abilityId)
        end
        Wait(0)
    end

    ObVampiros.ClearSelection()
    return nil
end

local function abilities()
    return {
        {
            id = 'passo_sombrio', slot = 1, input = 1, key = '1',
            label = 'Passo Sombrio',
            description = 'Velocidade sobrenatural envolta em sombras.',
            icon = 'nui://ob_vampiros/web/icons/passo-sombrio.png',
            clientEvent = 'ob_vampiros:client:passoSombrio',
        },
        {
            id = 'forma_morcego', slot = 2, input = 2, key = '2',
            label = 'Forma de Morcego',
            description = 'Assumir uma forma alada pequena e discreta.',
            icon = 'nui://ob_vampiros/web/icons/forma-morcego.png',
            clientEvent = 'ob_vampiros:client:toggleBatForm',
        },
        {
            id = 'hipnose', slot = 3, input = 3, key = '3',
            label = 'Hipnose',
            description = 'Projetar uma onda mental que paralisa o primeiro alvo atingido.',
            icon = 'nui://ob_vampiros/web/icons/hipnose.png',
            clientEvent = 'ob_vampiros:client:hipnose',
        },
        {
            id = 'abraco_noite', slot = 4, input = 4, key = '4',
            label = 'Abraco da Noite',
            description = 'Drenar a vida de um alvo proximo.',
            icon = 'nui://ob_vampiros/web/icons/abraco-da-noite.png',
            clientEvent = 'ob_vampiros:client:abracoNoite',
        },
    }
end

function ObVampiros.RefreshProvider()
    if GetResourceState('obscuriaHud') ~= 'started' then
        providerRegistered = false
        return
    end

    if not ObVampiros.IsVampire() then
        if providerRegistered then
            exports.obscuriaHud:ClearProvider('ob_vampiros')
            providerRegistered = false
        end
        return
    end

    if not providerRegistered then
        exports.obscuriaHud:RegisterProvider('ob_vampiros', {
            label = 'Vampiro',
            archetype = 'vampire',
            position = Config.Hud.position,
            theme = Config.Hud.theme,
            abilities = abilities(),
            visible = true,
        })
        providerRegistered = true
    end

    exports.obscuriaHud:SetActiveProvider('ob_vampiros')
    exports.obscuriaHud:SetProviderVisible('ob_vampiros', true)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(500, ObVampiros.RefreshProvider)
end)
RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then
        cachedPlayerData = nil
        SetTimeout(100, ObVampiros.RefreshProvider)
    end
end)
local function handleExternalClassChange(classId)
    cachedPlayerData = ObVampiros.GetPlayerData()
    cachedPlayerData.metadata = cachedPlayerData.metadata or {}
    cachedPlayerData.metadata[Config.ClassMetadataKey] = classId
    SetTimeout(250, ObVampiros.RefreshProvider)
end

RegisterNetEvent('classeSelector:classChosenSuccess', handleExternalClassChange)
RegisterNetEvent('classeSelector:classChanged', handleExternalClassChange)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'obscuriaHud' then
        SetTimeout(700, ObVampiros.RefreshProvider)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'obscuriaHud' then
        providerRegistered = false
    elseif resourceName == GetCurrentResourceName() then
        ObVampiros.ClearSelection()
        if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
            exports.obscuriaHud:ClearProvider('ob_vampiros')
        end
        providerRegistered = false
    end
end)

CreateThread(function()
    Wait(1200)
    ObVampiros.RefreshProvider()
end)
