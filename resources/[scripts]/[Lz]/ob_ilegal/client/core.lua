ObIlegalClient = ObIlegalClient or {}

local cachedPlayerData
local busySnapshot

local reasonMessages = {
    busy = 'Este caixa eletrônico já está sendo violado.',
    cooldown = 'O mecanismo deste caixa ainda está bloqueado.',
    dead = 'Você não pode fazer isso neste estado.',
    vehicle = 'Saia do veículo para interagir com o caixa.',
    invalid_atm = 'Este caixa eletrônico não pode ser violado.',
    invalid_class = 'Sua classe não possui uma rota para este roubo.',
    invalid_robbery = 'Este roubo não está configurado ou está desativado.',
    invalid_stage = 'Esta etapa ainda não possui coordenadas válidas.',
    stage = 'Conclua os mecanismos anteriores primeiro.',
    distance = 'Aproxime-se do mecanismo para continuar.',
    police = 'Não há efetivo policial suficiente na cidade.',
    item = 'Você precisa de um dispositivo de hacking.',
    essence = 'Sua essência não é suficiente.',
    inventory = 'Não há espaço para receber a premiação.',
    too_fast = 'A violação foi interrompida pelo sistema de segurança.',
    action_failed = 'A tentativa falhou. O caixa pode ser violado novamente.',
    session = 'A sessão deste roubo não é mais válida.',
}

function ObIlegalClient.GetPlayerData()
    if QBX and QBX.PlayerData and QBX.PlayerData.citizenid then
        cachedPlayerData = QBX.PlayerData
        return cachedPlayerData
    end

    local ok, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if ok and data then cachedPlayerData = data end
    return cachedPlayerData or {}
end

function ObIlegalClient.GetClass()
    local data = ObIlegalClient.GetPlayerData()
    local metadata = data.metadata or {}
    return tostring(metadata[Config.ClassMetadataKey] or ''):lower()
end

function ObIlegalClient.Notify(description, kind)
    lib.notify({
        title = 'Obscuria Ilegal',
        description = description,
        type = kind or 'inform',
        duration = 4500,
    })
end

function ObIlegalClient.NotifyReason(reason, fallback)
    ObIlegalClient.Notify(reasonMessages[reason] or fallback or 'Não foi possível concluir a ação.', 'error')
end

function ObIlegalClient.IsUnavailable()
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsPedDeadOrDying(ped, true) then return true, 'dead' end
    if IsPedInAnyVehicle(ped, false) then return true, 'vehicle' end
    local state = LocalPlayer.state
    if state.obIlegalBusy == true
        or state.obscuriaPowerBlocked == true
        or state.magicFauna == true
        or state.obHypnotized == true
        or lib.progressActive() then
        return true, 'busy'
    end

    local classId = ObIlegalClient.GetClass()
    local route = Config.Classes[classId]
    if not route or route.enabled ~= true then return true, 'invalid_class' end
    return false, nil
end

function ObIlegalClient.SetBusy(enabled)
    enabled = enabled == true
    if enabled then
        if busySnapshot then return end
        busySnapshot = {
            invBusy = LocalPlayer.state.invBusy == true,
            powerBlocked = LocalPlayer.state.obscuriaPowerBlocked == true,
        }
        LocalPlayer.state:set('obIlegalBusy', true, true)
        LocalPlayer.state:set('invBusy', true, true)
        LocalPlayer.state:set('obscuriaPowerBlocked', true, true)
        return
    end

    local snapshot = busySnapshot
    busySnapshot = nil
    LocalPlayer.state:set('obIlegalBusy', false, true)
    if snapshot and not snapshot.invBusy then
        LocalPlayer.state:set('invBusy', false, true)
    end
    if snapshot and not snapshot.powerBlocked then
        LocalPlayer.state:set('obscuriaPowerBlocked', false, true)
    end
end

function ObIlegalClient.HasBusySession()
    return busySnapshot ~= nil
end

function ObIlegalClient.ClearStaleBusy()
    if busySnapshot or LocalPlayer.state.obIlegalBusy ~= true then return false end

    LocalPlayer.state:set('obIlegalBusy', false, true)
    LocalPlayer.state:set('invBusy', false, true)
    LocalPlayer.state:set('obscuriaPowerBlocked', false, true)
    return true
end

function ObIlegalClient.EnsureAnim(dict, timeout)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local expiresAt = GetGameTimer() + (timeout or 2500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < expiresAt do Wait(10) end
    return HasAnimDictLoaded(dict)
end

function ObIlegalClient.EnsurePtfx(asset, timeout)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local expiresAt = GetGameTimer() + (timeout or 2500)
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < expiresAt do Wait(10) end
    return HasNamedPtfxAssetLoaded(asset)
end

function ObIlegalClient.EnsureModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local expiresAt = GetGameTimer() + (timeout or 2500)
    while not HasModelLoaded(hash) and GetGameTimer() < expiresAt do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    cachedPlayerData = nil
    ObIlegalClient.ClearStaleBusy()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    cachedPlayerData = data
end)

CreateThread(function()

    Wait(250)
    ObIlegalClient.ClearStaleBusy()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ObIlegalClient.SetBusy(false)
    ClearPedTasks(PlayerPedId())
end)
