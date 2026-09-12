MagicHelpers = MagicHelpers or {}

local function GetLocalState()
    return LocalPlayer and LocalPlayer.state or nil
end

function MagicHelpers.IsPlayerDead()
    local ped = PlayerPedId()
    local state = GetLocalState()
    local stateDead = state and (
        state.isDead == true
        or state.dead == true
        or state.inLaststand == true
        or state.laststand == true
    )

    return ped == 0
        or stateDead == true
        or IsEntityDead(ped)
        or IsPedDeadOrDying(ped, true)
        or GetEntityHealth(ped) <= 0
end

function MagicHelpers.IsPlayerInVehicle()
    local ped = PlayerPedId()
    if ped == 0 then
        return false
    end

    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local enteringVehicle = GetVehiclePedIsTryingToEnter and GetVehiclePedIsTryingToEnter(ped) or 0

    return currentVehicle ~= 0
        or enteringVehicle ~= 0
        or IsPedInAnyVehicle(ped, true)
        or IsPedSittingInAnyVehicle(ped)
end

function MagicHelpers.IsMapOpen()
    local pauseState = GetPauseMenuState and GetPauseMenuState() or 0
    local bigMapActive = IsBigmapActive and IsBigmapActive() or false

    return IsPauseMenuActive() or pauseState ~= 0 or bigMapActive
end

function MagicHelpers.IsInventoryOpen()
    local state = GetLocalState()
    return state and state.invOpen == true or false
end

function MagicHelpers.IsCastingBlocked()
    return MagicHelpers.IsPlayerDead() or MagicHelpers.IsPlayerInVehicle()
end

function MagicHelpers.IsHudSuppressed()
    return MagicHelpers.IsCastingBlocked()
        or MagicHelpers.IsInventoryOpen()
        or MagicHelpers.IsMapOpen()
end

local function RotationToDirection(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local cosX = math.cos(radX)

    return vector3(
        -math.sin(radZ) * cosX,
        math.cos(radZ) * cosX,
        math.sin(radX)
    )
end

local function Normalize(vector)
    local magnitude = #(vector)
    if magnitude < 0.0001 then
        return vector3(0.0, 0.0, 0.0)
    end

    return vector / magnitude
end

function MagicHelpers.Notify(title, message, notifyType, duration)
    if Main and Main.Notify then
        return Main.Notify(title, message, notifyType, duration)
    end

    if lib and lib.notify then
        lib.notify({
            title = title or "Magia",
            description = message or "",
            type = notifyType or "inform",
            duration = duration or 5000
        })
    end
end

function MagicHelpers.IsCancelPressed()
    local controls = Config.Controls or {}
    return IsControlJustPressed(0, controls.Cancel or 303) or IsControlJustPressed(0, controls.Back or 177)
end

function MagicHelpers.RaycastFromCamera(maxDistance, flags)
    local ped = PlayerPedId()
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = Normalize(RotationToDirection(camRot))
    local distance = maxDistance or 20.0
    local dest = camCoord + direction * distance

    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        flags or -1,
        ped,
        0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    return {
        hit = hit == 1,
        coords = endCoords,
        normal = surfaceNormal,
        entity = entityHit,
        direction = direction
    }
end

exports('RaycastFromCamera', function(maxDistance, flags)
    return MagicHelpers.RaycastFromCamera(maxDistance, flags)
end)

function MagicHelpers.GetGroundPointFromCamera(maxDistance)
    local result = MagicHelpers.RaycastFromCamera(maxDistance or 20.0, -1)
    local coords = result and result.coords

    if coords then
        local ok, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
        if ok then
            return vector3(coords.x, coords.y, groundZ)
        end

        return coords
    end

    local ped = PlayerPedId()
    return GetEntityCoords(ped) + GetEntityForwardVector(ped) * (maxDistance or 8.0)
end

function MagicHelpers.GetEntityTargetFromCrosshair(maxDist, predicate)
    local result = MagicHelpers.RaycastFromCamera(maxDist or 12.0, -1)
    if not result or not result.entity or not DoesEntityExist(result.entity) then
        return nil
    end

    local entity = result.entity
    if predicate and not predicate(entity) then
        return nil
    end

    return entity, result
end

function MagicHelpers.GetPedTargetInFront(maxDist)
    local target = MagicHelpers.GetEntityTargetFromCrosshair(maxDist or 5.0, function(entity)
        return IsEntityAPed(entity) and IsPedAPlayer(entity)
    end)

    if target and DoesEntityExist(target) then
        local targetServerId = nil
        local ply = NetworkGetPlayerIndexFromPed(target)
        if ply and ply ~= -1 then
            targetServerId = GetPlayerServerId(ply)
        end
        return target, true, targetServerId
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local dist = maxDist or 5.0
    local bestPed, bestDot, bestSrc = nil, 0.78, nil

    local nearbyPlayers = lib.getNearbyPlayers(coords, dist, false) or {}
    for index = 1, #nearbyPlayers do
        local nearby = nearbyPlayers[index]
        local ply = tonumber(nearby.id)
        local entity = tonumber(nearby.ped) or (ply and GetPlayerPed(ply)) or 0
        if entity ~= ped and DoesEntityExist(entity) and not IsPedDeadOrDying(entity, true) then
            local dir = GetEntityCoords(entity) - coords
            local d = #(dir)
            if d <= dist and d > 0.1 then
                dir = dir / d
                local dot = forward.x * dir.x + forward.y * dir.y + forward.z * dir.z
                if dot > bestDot then
                    bestDot = dot
                    bestPed = entity
                    bestSrc = ply and GetPlayerServerId(ply) or nil
                end
            end
        end
    end

    if bestPed then
        return bestPed, true, bestSrc
    end

    return nil, false, nil
end

function MagicHelpers.GetVehicleTarget(maxDist)
    return MagicHelpers.GetEntityTargetFromCrosshair(maxDist or 8.0, function(entity)
        return IsEntityAVehicle(entity)
    end)
end

local function LoadSpellAnimDict(animCfg, context)
    RequestAnimDict(animCfg.dict)
    local timeout = GetGameTimer() + (tonumber(animCfg.loadTimeout) or 8000)

    while not HasAnimDictLoaded(animCfg.dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    if HasAnimDictLoaded(animCfg.dict) then
        return true
    end

    print(("[magicSpells][Anim] %s: o dict '%s' nao carregou (recurso: %s)."):format(
        context or "cast",
        tostring(animCfg.dict),
        tostring(GetResourceState(animCfg.resource or animCfg.dict))
    ))
    return false
end

local verifiedSpellAnimations = {}

local function GetCastPedState(ped)
    local state = GetLocalState()

    return {
        emote = state and state.isInEmote == true or false,
        limited = state and state.isLimited == true or false,
        actionMode = IsPedUsingActionMode(ped),
        attached = IsEntityAttached(ped),
        ragdoll = IsPedRagdoll(ped),
        falling = IsPedFalling(ped),
        gettingUp = IsPedGettingUp(ped),
        jumping = IsPedJumping(ped),
        climbing = IsPedClimbing(ped),
        swimming = IsPedSwimming(ped),
        scenario = IsPedUsingAnyScenario(ped)
    }
end

local function FormatCastPedState(state)
    local active = {}

    for name, enabled in pairs(state or {}) do
        if enabled then
            active[#active + 1] = name
        end
    end

    table.sort(active)
    return #active > 0 and table.concat(active, ",") or "normal"
end

local function PreparePedForCast(ped)
    local before = GetCastPedState(ped)

    if before.emote and GetResourceState("scully_emotemenu") == "started" then
        local ok, err = pcall(function()
            exports.scully_emotemenu:cancelEmote(true)
        end)

        if not ok then
            print(("[magicSpells][Anim] falha ao cancelar emote ativo: %s"):format(tostring(err)))
        end
    end

    SetPedCanPlayGestureAnims(ped, true)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanPlayAmbientBaseAnims(ped, true)
    SetPedUsingActionMode(ped, false, -1, "DEFAULT_ACTION")
    ClearPedTasksImmediately(ped)
    Wait(0)

    return before
end

local function CaptureCastBones(ped)
    local rightHand = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    local leftHand = GetPedBoneCoords(ped, 18905, 0.0, 0.0, 0.0)
    local chest = GetPedBoneCoords(ped, 24818, 0.0, 0.0, 0.0)
    return rightHand, leftHand, chest
end

local function CastBonesMoved(beforeRight, beforeLeft, beforeChest, ped)
    local rightHand, leftHand, chest = CaptureCastBones(ped)
    local movement = #(rightHand - beforeRight) + #(leftHand - beforeLeft) + #(chest - beforeChest)
    return movement >= 0.012, movement
end

local function PlayAnimationFromResource(animCfg, context)
    local resource = tostring(animCfg.resource or "")
    if resource ~= "grimorio_victoria" and resource ~= "grimorio_bola_de_fogo" then
        return false
    end

    if GetResourceState(resource) ~= "started" then
        print(("[magicSpells][Anim] %s: recurso '%s' nao esta iniciado."):format(
            context or "cast",
            resource
        ))
        return false
    end

    local mode = tostring(animCfg.anim):find("upper", 1, true) and "upper" or "full"
    local ok, started = pcall(function()
        if resource == "grimorio_victoria" then
            return exports.grimorio_victoria:PlayCast(mode, animCfg.duration)
        end

        return exports.grimorio_bola_de_fogo:PlayCast(mode, animCfg.duration)
    end)

    if not ok or started == false then
        print(("[magicSpells][Anim] %s: export de '%s' recusou o cast (%s)."):format(
            context or "cast",
            resource,
            ok and "retorno false" or tostring(started)
        ))
        return false
    end

    local key = ("%s/%s/export"):format(animCfg.dict, animCfg.anim)
    if not verifiedSpellAnimations[key] then
        verifiedSpellAnimations[key] = true
        print(("[magicSpells][Anim] '%s/%s' iniciada pelo export funcional de '%s'."):format(
            tostring(animCfg.dict),
            tostring(animCfg.anim),
            resource
        ))
    end

    return true
end

function MagicHelpers.PlayAnimation(animCfg, context, allowFallback)
    if not animCfg or not animCfg.dict or not animCfg.anim then
        print(("[magicSpells][Anim] %s: configuracao ausente ou incompleta."):format(context or "cast"))
        return false, nil
    end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return false, nil
    end

    if PlayAnimationFromResource(animCfg, context) then
        return true, animCfg
    end

    if LoadSpellAnimDict(animCfg, context) then
        local pedState = PreparePedForCast(ped)
        local playing = false
        local phase = 0.0
        local movement = 0.0
        local attempts = math.max(1, tonumber(animCfg.startAttempts) or 3)

        for attempt = 1, attempts do
            local beforeRight, beforeLeft, beforeChest = CaptureCastBones(ped)
            TaskPlayAnim(
                ped,
                animCfg.dict,
                animCfg.anim,
                animCfg.blendIn or 4.0,
                animCfg.blendOut or 2.0,
                animCfg.duration or -1,
                animCfg.flag or 48,
                animCfg.playbackRate or 1.0,
                false, false, false
            )

            Wait(attempt == 1 and 180 or 90)
            playing = IsEntityPlayingAnim(ped, animCfg.dict, animCfg.anim, 3)
            phase = playing and GetEntityAnimCurrentTime(ped, animCfg.dict, animCfg.anim) or 0.0
            local moved
            moved, movement = CastBonesMoved(beforeRight, beforeLeft, beforeChest, ped)

            if playing and phase > 0.001 and moved then
                local key = ("%s/%s"):format(animCfg.dict, animCfg.anim)
                if not verifiedSpellAnimations[key] then
                    verifiedSpellAnimations[key] = true
                    print(("[magicSpells][Anim] '%s' validada (tentativa %d, fase %.3f, movimento %.4f)."):format(
                        key,
                        attempt,
                        phase,
                        movement
                    ))
                end
                return true, animCfg
            end

            if attempt < attempts then
                ClearPedSecondaryTask(ped)
                Wait(0)
            end
        end

        print(("[magicSpells][Anim] %s: '%s/%s' recusada apos %d tentativa(s) (playing=%s, fase=%.3f, movimento=%.4f, estado=%s)."):format(
            context or "cast",
            tostring(animCfg.dict),
            tostring(animCfg.anim),
            attempts,
            tostring(playing),
            phase,
            movement,
            FormatCastPedState(pedState)
        ))
        StopAnimTask(ped, animCfg.dict, animCfg.anim, animCfg.blendOut or 2.0)
    end

    local fallback
    local allowAnotherFallback = false
    if allowFallback ~= false and Config then
        if animCfg == Config.DefaultSpellAnimationFallback then
            fallback = Config.EmergencySpellAnimationFallback
        else
            fallback = Config.DefaultSpellAnimationFallback
            allowAnotherFallback = fallback ~= nil
        end
    end

    if not fallback or fallback == animCfg then
        return false, nil
    end

    print(("[magicSpells][Anim] %s: usando animacao reserva."):format(context or "cast"))
    return MagicHelpers.PlayAnimation(fallback, (context or "cast") .. "/fallback", allowAnotherFallback)
end

function MagicHelpers.PlaySpellAnim(spellCfg, context)
    if not spellCfg then
        return false, nil
    end

    return MagicHelpers.PlayAnimation(spellCfg.animation, context or spellCfg.name or "cast", true)
end

function MagicHelpers.StartProgress(label, duration)
    TriggerEvent("Progress", label, duration)
end

function MagicHelpers.FinishSpellCooldown(spellName)
    if not Config or not Config.Spells then
        return
    end

    local cfg = Config.Spells[spellName]
    if not cfg then
        return
    end

    TriggerServerEvent("magic:server:commitCast", spellName)

    if cfg.cooldown and cfg.cooldown > 0 and StartCooldown then
        StartCooldown(spellName, cfg.cooldown)
    end
end

function MagicHelpers.CancelSpellCast(spellName)
    TriggerServerEvent("magic:server:cancelCast", spellName)
end

function MagicHelpers.ShowHints(title, lines)
    local out = {}

    if title and title ~= "" then
        out[#out + 1] = title
    end

    for _, line in ipairs(lines or {}) do
        out[#out + 1] = line
    end

    if MagicHud and MagicHud.SetHints then
        MagicHud.SetHints(out)
        return
    end

    SendNUIMessage({ action = "setHints", title = title, lines = out })
end

function MagicHelpers.HideHints()
    if MagicHud and MagicHud.SetHints then
        MagicHud.SetHints({})
        return
    end

    SendNUIMessage({ action = "setHints", lines = {} })
end

function MagicHelpers.ApplyDamageToPlayer(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return
    end

    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.magicInvulneris then
        return
    end

    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local armour = GetPedArmour(ped)

    if armour > 0 then
        SetPedArmour(ped, math.max(0, armour - amount))
    else
        SetEntityHealth(ped, math.max(0, health - amount))
    end
end
