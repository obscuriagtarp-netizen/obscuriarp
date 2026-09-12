ObBruxas = ObBruxas or {}

local providerRegistered = false
local cachedPlayerData = nil
local crosshairOwner = 'ob_bruxas'
local crosshairPublished = false
local crosshairThreadRunning = false
local powerCrosshair = {
    active = false,
    distance = 20.0,
    label = '',
    targetLabel = 'ALVO',
}
local grimoireHudRaised = nil

local function lower(value)
    return tostring(value or ''):lower()
end

function ObBruxas.Notify(title, description, kind, duration)
    if lib and lib.notify then
        lib.notify({
            title = title or 'Bruxa',
            description = description or '',
            type = kind or 'inform',
            duration = duration or 4000,
        })
        return
    end

    pcall(function()
        exports.qbx_core:Notify(description or title or 'Bruxa', kind or 'inform', duration or 4000)
    end)
end

function ObBruxas.GetPlayerData()
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

function ObBruxas.IsWitch()
    local data = ObBruxas.GetPlayerData()
    local metadata = data.metadata or {}
    return lower(metadata[Config.ClassMetadataKey]) == lower(Config.ClassId)
end

function ObBruxas.IsPowerBlocked()
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

function ObBruxas.EnsureModel(model)
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

function ObBruxas.EnsureAnim(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

function ObBruxas.EnsurePtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2200
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

function ObBruxas.UpdateAbility(abilityId, patch)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:UpdateAbility('ob_bruxas', abilityId, patch)
    end
end

function ObBruxas.FailAbility(abilityId)
    if not providerRegistered or GetResourceState('obscuriaHud') ~= 'started' then return end

    pcall(function()
        exports.obscuriaHud:PulseAbility('ob_bruxas', abilityId, 'error')
    end)
end

function ObBruxas.StartCooldown(abilityId, duration)
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:StartCooldown('ob_bruxas', abilityId, duration)
    end
end

function ObBruxas.ClearSelection()
    if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
        exports.obscuriaHud:SetSelected('ob_bruxas', '')
    end
end

function ObBruxas.RaycastFromCamera(maxDistance, flags)
    if GetResourceState('magicSpells') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return exports.magicSpells:RaycastFromCamera(maxDistance or 20.0, flags or -1)
    end)
    return ok and result or nil
end

function ObBruxas.SetCrosshairCharge(active, duration, label)
    if GetResourceState('magicSpells') == 'started' then
        pcall(function()
            exports.magicSpells:SetCrosshairCharge(active == true, duration or 0, label)
        end)
    end
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

function ObBruxas.SetPowerCrosshair(active, options)
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
                    and ObBruxas.IsWitch()
                    and not ObBruxas.IsPowerBlocked()
                    and GetResourceState('magicSpells') == 'started' do
                    local result = ObBruxas.RaycastFromCamera(powerCrosshair.distance, -1)
                    local entity = result and result.entity or 0
                    local hasPlayer = entity ~= 0
                        and DoesEntityExist(entity)
                        and IsEntityAPed(entity)
                        and IsPedAPlayer(entity)
                        and entity ~= PlayerPedId()

                    exports.magicSpells:SetExternalCrosshair(crosshairOwner, {
                        visible = true,
                        target = hasPlayer,
                        kind = hasPlayer and 'ped' or nil,
                        label = hasPlayer and powerCrosshair.targetLabel or powerCrosshair.label,
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
        return
    end

    hideClassCrosshair()
end

local function readGrimoireVisibility()
    if GetResourceState('magicSpells') ~= 'started' then return false end

    local visible = false
    local ok = pcall(function()
        visible = exports.magicSpells:IsGrimoireHudVisible() == true
    end)
    return ok and visible or false
end

local function applyGrimoireHudPosition(shouldRaise, force)
    shouldRaise = shouldRaise == true
    if not force and grimoireHudRaised == shouldRaise then return end

    grimoireHudRaised = shouldRaise
    if not providerRegistered or GetResourceState('obscuriaHud') ~= 'started' then return end

    local position = shouldRaise and Config.Hud.positions.grimoire or Config.Hud.positions.normal
    exports.obscuriaHud:SetProviderPosition('ob_bruxas', position)
end

local function abilities()
    return {
        {
            id = 'familiar',
            slot = 1,
            input = 1,
            key = '1',
            label = 'Familiar',
            description = 'Assumir ou abandonar a forma de gato preto.',
            icon = 'nui://ob_bruxas/web/icons/familiar.png',
            clientEvent = 'ob_bruxas:client:toggleFamiliar',
        },
        {
            id = 'sentido_arcano',
            slot = 4,
            input = 2,
            key = '2',
            label = 'Sentido Arcano',
            description = 'Revelar residuos, encantamentos e presencas sobrenaturais.',
            icon = 'nui://ob_bruxas/web/icons/sentido-arcano.png',
            clientEvent = 'ob_bruxas:client:sentidoArcano',
        },
        {
            id = 'elo_arcano',
            slot = 3,
            input = 3,
            key = '3',
            label = 'Elo Arcano',
            description = 'Canalizar mana para si ou para um aliado sob a mira.',
            icon = 'nui://ob_bruxas/web/icons/elo-arcano.png',
            clientEvent = 'ob_bruxas:client:eloArcano',
        },
        {
            id = 'nevoa_bruxas',
            slot = 2,
            input = 4,
            key = '4',
            label = 'Nevoa das Bruxas',
            description = 'Invocar uma nevoa densa para ocultar fugas e feiticos.',
            icon = 'nui://ob_bruxas/web/icons/nevoa-das-bruxas.png',
            clientEvent = 'ob_bruxas:client:nevoaBruxas',
        },
    }
end

function ObBruxas.RefreshProvider()
    if GetResourceState('obscuriaHud') ~= 'started' then
        providerRegistered = false
        return
    end

    if not ObBruxas.IsWitch() then
        if providerRegistered then
            exports.obscuriaHud:ClearProvider('ob_bruxas')
            providerRegistered = false
        end
        grimoireHudRaised = nil
        return
    end

    if providerRegistered then
        exports.obscuriaHud:SetActiveProvider('ob_bruxas')
        exports.obscuriaHud:SetProviderVisible('ob_bruxas', true)
        applyGrimoireHudPosition(readGrimoireVisibility(), true)
        return
    end

    local shouldRaise = readGrimoireVisibility()

    exports.obscuriaHud:RegisterProvider('ob_bruxas', {
        label = 'Bruxa',
        archetype = 'witch',
        position = shouldRaise and Config.Hud.positions.grimoire or Config.Hud.positions.normal,
        theme = Config.Hud.theme,
        abilities = abilities(),
        visible = true,
    })
    exports.obscuriaHud:SetActiveProvider('ob_bruxas')
    exports.obscuriaHud:SetProviderVisible('ob_bruxas', true)
    providerRegistered = true
    grimoireHudRaised = shouldRaise
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(500, ObBruxas.RefreshProvider)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then
        cachedPlayerData = nil
        SetTimeout(100, ObBruxas.RefreshProvider)
    end
end)

local function handleExternalClassChange(classId)
    cachedPlayerData = ObBruxas.GetPlayerData()
    cachedPlayerData.metadata = cachedPlayerData.metadata or {}
    cachedPlayerData.metadata[Config.ClassMetadataKey] = classId
    SetTimeout(250, ObBruxas.RefreshProvider)
end

RegisterNetEvent('classeSelector:classChosenSuccess', handleExternalClassChange)
RegisterNetEvent('classeSelector:classChanged', handleExternalClassChange)

AddEventHandler('magic:client:grimoireVisibilityChanged', function(visible)
    if not ObBruxas.IsWitch() then return end
    applyGrimoireHudPosition(visible)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'obscuriaHud' or resourceName == 'magicSpells' then
        SetTimeout(700, ObBruxas.RefreshProvider)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'obscuriaHud' then
        providerRegistered = false
    elseif resourceName == GetCurrentResourceName() then
        hideClassCrosshair()
        ObBruxas.SetCrosshairCharge(false)

        if providerRegistered and GetResourceState('obscuriaHud') == 'started' then
            exports.obscuriaHud:ClearProvider('ob_bruxas')
        end
        providerRegistered = false
    end
end)

CreateThread(function()
    Wait(1200)
    ObBruxas.RefreshProvider()
end)
