Main = Main or {}

local wandEntity = nil
local wandEntities = {}
local spellMode = false
local grimoireAccessCached = false
local grimoireAccessReady = false

print("[magicSpells][Anim] exports de cast sem correcao de rotacao por script (v3.2.2).")

local function lower(value)
    return tostring(value or ''):lower()
end

local function ReadPlayerData()
    local playerData = QBX and QBX.PlayerData or nil
    if playerData and playerData.citizenid then
        return playerData
    end

    local ok, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)

    return ok and data or nil
end

function Main.RefreshGrimoireAccess()
    local access = Config.GrimoireAccess or {}
    local playerData = ReadPlayerData()
    local metadata = playerData and playerData.metadata or {}
    local classId = lower(metadata[access.metadataKey or 'classe'])
    local allowedClasses = access.allowedClasses or { bruxa = true }
    grimoireAccessCached = allowedClasses[classId] == true
    grimoireAccessReady = playerData ~= nil
    return grimoireAccessCached
end

function Main.HasGrimoireAccess()
    if not grimoireAccessReady then
        return Main.RefreshGrimoireAccess()
    end

    return grimoireAccessCached
end

local function NotifyType(kind)
    local value = tostring(kind or "inform"):lower()

    if value == "sucesso" or value == "success" or value == "verde" then
        return "success"
    end

    if value == "negado" or value == "error" or value == "erro" or value == "vermelho" then
        return "error"
    end

    if value == "importante" or value == "warning" or value == "amarelo" then
        return "warning"
    end

    return "inform"
end

function Main.Notify(title, message, notifyType, duration)
    if type(notifyType) == "number" and duration == nil then
        duration = notifyType
        notifyType = nil
    end

    local mappedType = NotifyType(notifyType or title)

    if lib and lib.notify then
        lib.notify({
            title = title or "Magia",
            description = message or "",
            type = mappedType,
            duration = duration or 5000
        })
        return
    end

    local ok = pcall(function()
        exports.qbx_core:Notify(message or title or "Magia", mappedType, duration or 5000)
    end)

    if not ok then
        TriggerEvent("QBCore:Notify", message or title or "Magia", mappedType, duration or 5000)
    end
end

function Main.HasLocalWand()
    return wandEntity and DoesEntityExist(wandEntity)
end

function Main.SetLocalWandVisible(visible)
    if wandEntity and DoesEntityExist(wandEntity) then
        SetEntityVisible(wandEntity, visible and true or false, false)
    end
end

function Main.SetWandVisibleFor(serverId, visible)
    local entity = wandEntities[tonumber(serverId)]
    if entity and DoesEntityExist(entity) then
        SetEntityVisible(entity, visible == true, false)
    end
end

function Main.IsSpellMode()
    return spellMode == true
end

exports('IsSpellMode', function()
    return Main.IsSpellMode()
end)

function Main.IsMagicLocked()
    local state = LocalPlayer and LocalPlayer.state
    local ped = PlayerPedId()
    local attachedTo = ped ~= 0 and IsEntityAttached(ped) and GetEntityAttachedTo(ped) or 0
    local attachedToVehicle = attachedTo ~= 0
        and DoesEntityExist(attachedTo)
        and IsEntityAVehicle(attachedTo)
    local formLocked = state and (
        state.magicFauna == true
        or state.obscuriaPowerBlocked == true
        or state.obHypnotized == true
        or state.obInVehicleAttachment == true
        or state.magicGlaciesFrozen == true
    )
    local runtimeLocked = MagicHelpers and MagicHelpers.IsCastingBlocked and MagicHelpers.IsCastingBlocked()

    return attachedToVehicle or formLocked == true or runtimeLocked == true
end

local function Notify(title, message, notifyType, duration)
    Main.Notify(title, message, notifyType, duration)
end

local function RefreshGrimoire()
    if MagicGrimoire and MagicGrimoire.Refresh then
        MagicGrimoire.Refresh()
    end
end

local function HideGrimoireTip()
    if MagicHud and MagicHud.SetCancelTipVisible then
        MagicHud.SetCancelTipVisible(false)
    end
end

function Main.ForceCloseGrimoire(silent)
    local ped = PlayerPedId()

    TriggerServerEvent("magic:server:setWandState", false)
    ClearPedTasks(ped)

    spellMode = false
    if MagicGrimoire and MagicGrimoire.ResetCurrentSpell then
        MagicGrimoire.ResetCurrentSpell()
    end

    HideGrimoireTip()
    RefreshGrimoire()

    if not silent then
        Notify("Grimorio", "O grimorio se fecha.", "inform", 2500)
    end
end

RegisterNetEvent("magic:client:forceCloseGrimoire", function(silent)
    Main.ForceCloseGrimoire(silent ~= false)
end)

exports("ForceCloseGrimoire", function(silent)
    Main.ForceCloseGrimoire(silent ~= false)
end)

RegisterNetEvent("magic:client:notify", function(title, message, notifyType, duration)
    Notify(title, message, notifyType, duration)
end)

RegisterNetEvent("magic:client:useWandItem", function()
    TriggerServerEvent("magic:server:useWandItem")
end)

if Config.TestCommand and Config.TestCommand.Enabled ~= false then
    RegisterCommand("testemagiaanim", function(_, args)
        local requested = tostring(args[1] or "victoria"):lower()
        local tests = {
            victoria = {
                resource = "grimorio_victoria",
                dict = "grimorio_victoria",
                anim = "cast_upper",
                flag = 48,
                duration = 5200,
                loadTimeout = 8000
            },
            ignis = {
                resource = "grimorio_bola_de_fogo",
                dict = "grimorio_bola_de_fogo",
                anim = "fireball_upper",
                flag = 48,
                duration = 4600,
                loadTimeout = 8000
            },
            reserva = Config.DefaultSpellAnimationFallback,
            nativa = Config.EmergencySpellAnimationFallback
        }
        local test = tests[requested]

        if not test then
            Notify("Teste de animacao", "Use: /testemagiaanim victoria, ignis, reserva ou nativa.", "inform", 5000)
            return
        end

        ClearPedSecondaryTask(PlayerPedId())
        local ok, active = MagicHelpers.PlayAnimation(test, "teste:" .. requested, false)
        if ok then
            local phase = GetEntityAnimCurrentTime(PlayerPedId(), active.dict, active.anim)
            print(("[magicSpells][Anim] teste '%s' iniciou; fase %.3f."):format(requested, phase))
            Notify("Teste de animacao", ("%s iniciou. Resultado detalhado no F8."):format(requested), "success", 4000)
        else
            Notify("Teste de animacao", ("%s foi recusada. Confira o F8."):format(requested), "error", 6000)
        end
    end, false)
end

local function PlayAnim(dict, anim, duration, flag)
    local ped = PlayerPedId()
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end

    TaskPlayAnim(ped, dict, anim, 8.0, 8.0, duration or -1, flag or 48, 0.0, false, false, false)
end

local function CreateWandForPed(ped, modelName)
    modelName = modelName or Config.WandProp or "victoriawand"
    local modelHash = GetHashKey(modelName)
    local attach = Config.WandAttach or {}
    local pos = attach.pos or vec3(0.27, 0.16, -0.02)
    local rot = attach.rot or vec3(140.0, 90.0, 0.0)
    local bone = attach.bone or 57005

    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        print(("[magicSpells] Modelo da varinha nao encontrado/valido no stream: %s"):format(modelName))
        return nil
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(modelHash) then
        print(("[magicSpells] Falha ao carregar modelo da varinha: %s"):format(modelName))
        return nil
    end

    local pCoords = GetEntityCoords(ped)
    local obj = CreateObjectNoOffset(modelHash, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(obj) then
        print("[magicSpells] Falha ao criar entidade da varinha.")
        return nil
    end

    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(
        obj,
        ped,
        GetPedBoneIndex(ped, bone),
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    return obj
end

local function DeleteWandEntityFor(serverId)
    local ent = wandEntities[serverId]
    if ent and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end

    wandEntities[serverId] = nil

    if serverId == GetPlayerServerId(PlayerId()) then
        wandEntity = nil
        RefreshGrimoire()
    end
end

RegisterNetEvent("magic:client:updateWandState", function(src, state, modelName)
    local serverId = src
    local myServerId = GetPlayerServerId(PlayerId())

    if not state then
        DeleteWandEntityFor(serverId)
        return
    end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then
        return
    end

    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then
        return
    end

    DeleteWandEntityFor(serverId)

    local obj = CreateWandForPed(ped, modelName)
    if not obj then
        if serverId == myServerId then
            Notify("Varinha", ("Modelo %s nao carregou. Confira se o .ydr/.ytd esta no stream."):format(modelName or "victoriawand"), "error", 7000)
        end
        return
    end

    wandEntities[serverId] = obj

    if serverId == myServerId then
        wandEntity = obj
        RefreshGrimoire()
    end
end)

RegisterNetEvent("magic:client:useWand", function()
    local ped = PlayerPedId()

    if Main.IsMagicLocked() then
        local familiar = LocalPlayer and LocalPlayer.state and LocalPlayer.state.obFamiliar == true
        if familiar then
            Notify("Familiar", "Voce nao consegue usar a varinha nessa forma.", "error", 3500)
        end
        return
    end

    if Main.HasLocalWand() then
        PlayAnim("clothingshirt", "try_shirt_positive_d", 1200, 48)
        Wait(500)

        Main.ForceCloseGrimoire(true)
        if Main.HasGrimoireAccess() then
            Notify("Grimorio", "Voce guardou a varinha e o grimorio se fecha.", "inform", 3000)
        end
        return
    end

    PlayAnim("clothingshirt", "try_shirt_positive_d", 1200, 48)
    Wait(400)

    local canOpenGrimoire = Main.HasGrimoireAccess()
    spellMode = canOpenGrimoire
    if canOpenGrimoire and MagicGrimoire and MagicGrimoire.ResetCurrentSpell then
        MagicGrimoire.ResetCurrentSpell()
    end

    TriggerServerEvent("magic:server:setWandState", true, Config.WandProp)

    HideGrimoireTip()
    if canOpenGrimoire then
        TriggerServerEvent("magic:server:syncSpells")
        Notify("Grimorio", "A varinha canaliza energia. O grimorio desperta.", "success", 3000)
    end
    RefreshGrimoire()
end)

local function refreshMagicAccess()
    local canOpenGrimoire = Main.RefreshGrimoireAccess()
    spellMode = canOpenGrimoire and Main.HasLocalWand()

    if spellMode then
        TriggerServerEvent("magic:server:syncSpells")
    end
    RefreshGrimoire()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(250, refreshMagicAccess)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    grimoireAccessCached = false
    grimoireAccessReady = false
    spellMode = false
    RefreshGrimoire()
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    local access = Config.GrimoireAccess or {}
    if key == (access.metadataKey or 'classe') then
        SetTimeout(150, refreshMagicAccess)
    end
end)

RegisterNetEvent('classeSelector:classChosenSuccess', function()
    SetTimeout(150, refreshMagicAccess)
end)

RegisterNetEvent('classeSelector:classChanged', function()
    SetTimeout(150, refreshMagicAccess)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for serverId in pairs(wandEntities) do
        DeleteWandEntityFor(serverId)
    end
end)
