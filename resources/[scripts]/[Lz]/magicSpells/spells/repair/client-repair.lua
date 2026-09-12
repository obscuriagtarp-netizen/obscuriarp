local Magic = MagicHelpers

local repairing        = false
local machinaTargetNet = nil
local currentCastId    = 0

local function Notify(tipo, mensagem, cor, tempo)
    Magic.Notify(tipo, mensagem, cor, tempo)
end

local function EnsurePtfx(asset)
    if not asset or asset == "" then
        return false
    end

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

local function FaceEntity(ped, entity)
    if not ped or not entity or not DoesEntityExist(entity) then
        return
    end

    local from = GetEntityCoords(ped)
    local to = GetEntityCoords(entity)
    SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
end

local function GetVehicle(maxDist)
    if Magic.GetVehicleTarget then
        local targeted = Magic.GetVehicleTarget(maxDist or 7.0)
        if targeted and DoesEntityExist(targeted) then
            return targeted
        end
    end

    local ped      = PlayerPedId()
    local coords   = GetEntityCoords(ped)
    local forward  = GetEntityForwardVector(ped)
    local dist     = maxDist or 7.0
    local endCoords= coords + (forward * dist)

    local rayHandle1 = StartShapeTestRay(
        coords.x, coords.y, coords.z + 0.5,
        endCoords.x, endCoords.y, endCoords.z + 0.5,
        10, ped, 0
    )
    local _, hit1, _, _, entityHit1 = GetShapeTestResult(rayHandle1)
    if hit1 == 1 and IsEntityAVehicle(entityHit1) then
        return entityHit1
    end

    local rayHandle2 = StartShapeTestRay(
        coords.x, coords.y, coords.z - 0.5,
        endCoords.x, endCoords.y, endCoords.z - 0.5,
        10, ped, 0
    )
    local _, hit2, _, _, entityHit2 = GetShapeTestResult(rayHandle2)
    if hit2 == 1 and IsEntityAVehicle(entityHit2) then
        return entityHit2
    end

    local vehicles   = GetGamePool("CVehicle")
    local pForward   = GetEntityForwardVector(ped)
    local closestVeh = nil
    local closestDot = 0.92

    for _, veh in ipairs(vehicles) do
        local vCoords = GetEntityCoords(veh)
        local dir     = vCoords - coords
        local distVeh = #(dir)

        if distVeh < (maxDist or 7.5) then
            dir = dir / distVeh
            local dot = pForward.x * dir.x + pForward.y * dir.y + pForward.z * dir.z
            if dot > closestDot then
                closestDot = dot
                closestVeh = veh
            end
        end
    end

    return closestVeh
end

local function PlayPartFx(veh, bone)
    local spellCfg = Config.Spells["machina_reparatio"] or {}
    local fxCfg = spellCfg.repairFx or {}
    local asset = fxCfg.asset or "scr_ie_tw"
    local fxName = fxCfg.fx or "scr_impexp_tw_take_zone"

    local boneIndex = GetEntityBoneIndexByName(veh, bone)
    if boneIndex ~= -1 then
        local bx, by, bz = table.unpack(GetWorldPositionOfEntityBone(veh, boneIndex))
        UseParticleFxAssetNextCall(asset)
        StartParticleFxNonLoopedAtCoord(
            fxName,
            bx, by, bz + 0.3,
            0.0, 0.0, 0.0,
            fxCfg.scale or 0.8,
            false, false, false
        )
    end
end

local function PlayFullRepairEffects(veh)
    local spellCfg = Config.Spells["machina_reparatio"] or {}
    local repairFx = spellCfg.repairFx or {}
    local asset = repairFx.asset or "scr_ie_tw"

    if not EnsurePtfx(asset) then
        return
    end

    local tyres = { "wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr" }
    for _, bone in ipairs(tyres) do
        PlayPartFx(veh, bone)
        Wait(150)
    end

    local windows = { "windscreen", "window_lf", "window_rf" }
    for _, bone in ipairs(windows) do
        PlayPartFx(veh, bone)
        Wait(120)
    end

    PlayPartFx(veh, "engine")
    for _ = 1, 5 do
        SetVehicleEngineHealth(veh, math.min(1000.0, GetVehicleEngineHealth(veh) + 200))
        Wait(100)
    end

    PlayPartFx(veh, "bodyshell")
    SetVehicleDeformationFixed(veh)
    Wait(200)

    local doors = { "door_dside_f", "door_pside_f", "door_dside_r", "door_pside_r", "bonnet", "boot" }
    for i, bone in ipairs(doors) do
        PlayPartFx(veh, bone)
        SetVehicleDoorOpen(veh, i - 1, false, false)
        Wait(150)
        SetVehicleDoorShut(veh, i - 1, false)
        Wait(100)
    end

    PlayPartFx(veh, "petroltank")
    SetVehiclePetrolTankHealth(veh, 1000.0)
    Wait(100)

    UseParticleFxAssetNextCall(asset)
    local fx = StartParticleFxLoopedOnEntity(
        repairFx.fx or "scr_impexp_tw_take_zone",
        veh,
        0.0, 0.0, 0.8,
        0.0, 0.0, 0.0,
        repairFx.burstScale or 1.5,
        false, false, false
    )

    CreateThread(function()
        local endAt = GetGameTimer() + 2600
        while GetGameTimer() < endAt and DoesEntityExist(veh) do
            local coords = GetEntityCoords(veh)
            DrawMarker(
                1,
                coords.x, coords.y, coords.z - 0.45,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                3.4, 3.4, 0.025,
                92, 238, 225, 92,
                false, false, 2, false, nil, nil, false
            )
            Wait(0)
        end
    end)

    SetTimeout(3000, function()
        if DoesParticleFxLoopedExist(fx) then
            StopParticleFxLooped(fx, false)
        end
    end)
end

local function StartChannelRepairFx(veh, duration)
    local spellCfg = Config.Spells["machina_reparatio"] or {}
    local fxCfg = spellCfg.channelFx or {}
    local asset = fxCfg.asset or "scr_sum2_hal"
    local fxName = fxCfg.fx or "scr_sum2_hal_rider_death_orange"
    local interval = fxCfg.interval or 420

    if not EnsurePtfx(asset) then
        return
    end

    CreateThread(function()
        local endAt = GetGameTimer() + (duration or 6000)
        local nextPulse = 0

        while repairing and DoesEntityExist(veh) and GetGameTimer() < endAt do
            local now = GetGameTimer()
            local coords = GetEntityCoords(veh)

            if now >= nextPulse then
                nextPulse = now + interval

                UseParticleFxAssetNextCall(asset)
                if fxCfg.color then
                    SetParticleFxNonLoopedColour(fxCfg.color.x or 0.45, fxCfg.color.y or 0.95, fxCfg.color.z or 1.0)
                    SetParticleFxNonLoopedAlpha(fxCfg.color.w or 0.85)
                end
                StartParticleFxNonLoopedAtCoord(
                    fxName,
                    coords.x, coords.y, coords.z + 0.72,
                    0.0, 0.0, 0.0,
                    fxCfg.scale or 0.48,
                    false, false, false
                )
            end

            DrawMarker(
                1,
                coords.x, coords.y, coords.z - 0.48,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                3.0, 3.0, 0.02,
                90, 238, 225, 70,
                false, false, 2, false, nil, nil, false
            )

            Wait(0)
        end
    end)
end

RegisterNetEvent("magic:client:machinaRepairFx")
AddEventHandler("magic:client:machinaRepairFx", function(vehNetId)
    if not vehNetId then return end

    local veh = NetToVeh(vehNetId)
    if veh and DoesEntityExist(veh) then
        PlayFullRepairEffects(veh)
    end
end)

CreateThread(function()
    while true do
        local interval = 1000
        if machinaTargetNet then
            interval = 0
            local veh = NetToVeh(machinaTargetNet)
            if veh and DoesEntityExist(veh) then
                local x, y, z = table.unpack(GetEntityCoords(veh))
                local spellCfg = Config.Spells["machina_reparatio"] or {}
                local markFx = spellCfg.markFx or {}
                local radius = markFx.radius or 2.45
                local color = markFx.color or {}

                DrawMarker(
                    1,
                    x, y, z - 0.46,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    radius, radius, 0.024,
                    color.r or 86, color.g or 235, color.b or 218, color.a or 118,
                    false, false, 2,
                    false, nil, nil, false
                )

                DrawMarker(
                    36,
                    x, y, z + 1.15,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.42, 0.42, 0.42,
                    245, 220, 135, 150,
                    false, true, 2,
                    false, nil, nil, false
                )
            else
                machinaTargetNet = nil
                Magic.HideHints()
            end
        end
        Wait(interval)
    end
end)

RegisterCommand("machina_cancel_target", function()
    local ped = PlayerPedId()

    if repairing then
        repairing    = false
        currentCastId = currentCastId + 1

        ClearPedTasks(ped)
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Buttons", false, true)
        end

        machinaTargetNet = nil
        Notify("Importante", "Você interrompeu o feitiço de reparação.", 5000)
        Magic.HideHints()
        return
    end

    if machinaTargetNet then
        machinaTargetNet = nil
        Notify("Importante", "Você desfaz o alvo da Machina Reparatio.", 5000)
        Magic.HideHints()
    else
        Notify("Importante", "Nenhum alvo mágico para cancelar.", 3000)
    end
end, false)

RegisterKeyMapping(
    "machina_cancel_target",
    "Cancelar alvo/feitiço da Machina Reparatio",
    "keyboard",
    "U"
)

RegisterNetEvent("magic:spells:machina_reparatio")
AddEventHandler("magic:spells:machina_reparatio", function()
    if repairing then return end

    local spellCfg   = Config.Spells["machina_reparatio"] or {}
    local distance   = spellCfg.distance   or 7.0
    local repairTime = spellCfg.repairTime or 7000
    local ped        = PlayerPedId()

    if not machinaTargetNet then
        local veh = GetVehicle(distance)

        if not veh or not DoesEntityExist(veh) then
            Notify("Negado", "Nenhum veículo válido na frente para marcar.", 5000)
            return
        end

        machinaTargetNet = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdCanMigrate(machinaTargetNet, true)

        Notify("Sucesso", "Você aponta a varinha para o veículo. Use Machina Reparatio novamente para reparar ou U para cancelar.", 6000)

        Magic.ShowHints("Machina Reparatio", {
            "Veículo marcado para reparação.",
            "Use Machina Reparatio novamente para iniciar o reparo.",
            "U - Cancelar alvo marcado"
        })

        return
    end

    local targetVeh = NetToVeh(machinaTargetNet)
    if not targetVeh or not DoesEntityExist(targetVeh) then
        Notify("Negado", "O veículo alvo não está mais por perto.", 5000)
        machinaTargetNet = nil
        Magic.HideHints()
        return
    end

    local pCoords   = GetEntityCoords(ped)
    local vCoords   = GetEntityCoords(targetVeh)
    local distCheck = #(pCoords - vCoords)

    if distCheck > (distance + 3.0) then
        Notify("Negado", "Você se afastou demais do veículo alvo.", 5000)
        machinaTargetNet = nil
        Magic.HideHints()
        return
    end

    repairing     = true
    currentCastId = currentCastId + 1
    local thisCastId = currentCastId

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Buttons", true, true)
    end

    FaceEntity(ped, targetVeh)
    Magic.PlaySpellAnim(spellCfg)
    StartChannelRepairFx(targetVeh, repairTime)

    TriggerEvent("Progress", "Reparando veículo", repairTime)

    Magic.ShowHints("Machina Reparatio", {
        "Canalizando magia para reparar o veículo.",
        "U - Cancelar conjuração de Machina Reparatio"
    })

    SetTimeout(repairTime, function()
        if not repairing or thisCastId ~= currentCastId then
            return
        end

        repairing = false
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Buttons", false, true)
        end
        ClearPedTasks(ped)

        if not targetVeh or not DoesEntityExist(targetVeh) then
            Notify("Negado", "O veículo alvo não está mais por perto.", 5000)
            machinaTargetNet = nil
            Magic.HideHints()
            return
        end

        local vehNetId = NetworkGetNetworkIdFromEntity(targetVeh)

        if vehNetId and vehNetId ~= 0 then
            TriggerServerEvent("magic:server:machinaRepairFx", vehNetId)
        else
            PlayFullRepairEffects(targetVeh)
        end

        SetVehicleFixed(targetVeh)
        SetVehicleDirtLevel(targetVeh, 0.0)
        SetVehicleEngineHealth(targetVeh, 1000.0)
        SetVehicleBodyHealth(targetVeh, 1000.0)
        SetVehiclePetrolTankHealth(targetVeh, 1000.0)

        Notify("Sucesso", "Machina Reparatio restaurou o veículo à sua condição original!", 5000)
        Magic.ApplyDamageToPlayer(10)

        Magic.FinishSpellCooldown("machina_reparatio")

        machinaTargetNet = nil
        Magic.HideHints()
    end)
end)
