local activeLocation = nil
local activeLocationLabel = nil
local activeSession = nil
local activeVehicle = nil
local baselineState = nil
local baselineValues = {}
local currentTotal = 0
local menuOpen = false
local hoverVisible = false
local availableLocations = {}
local locationBlips = {}
local previewCam = nil
local vehicleReady = false
local activeVehicleOwned = true
local pendingResume = nil
local lastCustomColors = {
    primary = nil,
    secondary = nil
}
local lastPaintColors = {
    primary = 0,
    secondary = 0
}
local forcedToggleValues = {}

local colorPresets = {
    { label = 'Preto', value = 0 },
    { label = 'Cinza', value = 13 },
    { label = 'Prata', value = 4 },
    { label = 'Branco', value = 111 },
    { label = 'Vermelho', value = 27 },
    { label = 'Vinho', value = 143 },
    { label = 'Azul', value = 64 },
    { label = 'Azul escuro', value = 62 },
    { label = 'Roxo', value = 145 },
    { label = 'Verde', value = 55 },
    { label = 'Amarelo', value = 89 },
    { label = 'Laranja', value = 38 }
}

local paintFinishes = {
    { label = 'Metalico', value = 'metallic' },
    { label = 'Fosco', value = 'matte' },
    { label = 'Cromado', value = 'chrome' }
}

local xenonColors = {
    { label = 'Original', value = 255 },
    { label = 'Branco', value = 0 },
    { label = 'Azul', value = 1 },
    { label = 'Azul eletrico', value = 2 },
    { label = 'Verde', value = 4 },
    { label = 'Amarelo', value = 5 },
    { label = 'Dourado', value = 6 },
    { label = 'Laranja', value = 7 },
    { label = 'Vermelho', value = 8 },
    { label = 'Rosa', value = 9 },
    { label = 'Roxo', value = 11 }
}

local neonColors = {
    { label = 'Branco', value = '255,255,255', rgb = { 255, 255, 255 } },
    { label = 'Roxo', value = '142,92,255', rgb = { 142, 92, 255 } },
    { label = 'Azul', value = '80,120,255', rgb = { 80, 120, 255 } },
    { label = 'Vermelho', value = '255,65,95', rgb = { 255, 65, 95 } },
    { label = 'Verde', value = '50,220,130', rgb = { 50, 220, 130 } },
    { label = 'Amarelo', value = '255,210,70', rgb = { 255, 210, 70 } }
}

local wheelTypes = {
    { label = 'Sport', value = 0 },
    { label = 'Muscle', value = 1 },
    { label = 'Lowrider', value = 2 },
    { label = 'SUV', value = 3 },
    { label = 'Offroad', value = 4 },
    { label = 'Tuner', value = 5 },
    { label = 'Moto', value = 6 },
    { label = 'High End', value = 7 }
}

local wheelBones = {
    { index = 0, bone = 'wheel_lf' },
    { index = 1, bone = 'wheel_rf' },
    { index = 2, bone = 'wheel_lm1' },
    { index = 3, bone = 'wheel_rm1' },
    { index = 4, bone = 'wheel_lr' },
    { index = 5, bone = 'wheel_rr' },
    { index = 45, bone = 'wheel_lm2' },
    { index = 47, bone = 'wheel_rm2' }
}

local modCategories = {
    {
        id = 'performance',
        label = 'Performance',
        icon = 'gauge',
        options = {
            { id = 'engine', label = 'Motor', type = 'mod', modType = 11 },
            { id = 'brakes', label = 'Freios', type = 'mod', modType = 12 },
            { id = 'transmission', label = 'Transmissão', type = 'mod', modType = 13 },
            { id = 'suspension', label = 'Suspensão', type = 'mod', modType = 15 },
            { id = 'armor', label = 'Blindagem', type = 'mod', modType = 16 },
            { id = 'turbo', label = 'Turbo', type = 'toggle', modType = 18 }
        }
    },
    {
        id = 'body',
        label = 'Lataria',
        icon = 'car',
        options = {
            { id = 'spoiler', label = 'Aerofólio', type = 'mod', modType = 0 },
            { id = 'front_bumper', label = 'Parachoque dianteiro', type = 'mod', modType = 1 },
            { id = 'rear_bumper', label = 'Parachoque traseiro', type = 'mod', modType = 2 },
            { id = 'skirts', label = 'Saias laterais', type = 'mod', modType = 3 },
            { id = 'exhaust', label = 'Escapamento', type = 'mod', modType = 4 },
            { id = 'frame', label = 'Chassi', type = 'mod', modType = 5 },
            { id = 'grille', label = 'Grade', type = 'mod', modType = 6 },
            { id = 'hood', label = 'Capô', type = 'mod', modType = 7 },
            { id = 'fender', label = 'Paralama esquerdo', type = 'mod', modType = 8 },
            { id = 'right_fender', label = 'Paralama direito', type = 'mod', modType = 9 },
            { id = 'roof', label = 'Teto', type = 'mod', modType = 10 }
        }
    },
    {
        id = 'wheels',
        label = 'Rodas',
        icon = 'circle-dot',
        options = {
            { id = 'wheel_type', label = 'Tipo de roda', type = 'wheelType' },
            { id = 'front_wheels', label = 'Rodas dianteiras', type = 'mod', modType = 23 },
            { id = 'back_wheels', label = 'Rodas traseiras', type = 'mod', modType = 24 },
            { id = 'custom_tires', label = 'Pneu customizado', type = 'tireVariation', modType = 23 },
            { id = 'bulletproof_tires', label = 'Pneu à prova de bala', type = 'tireBurst' },
            { id = 'tire_smoke', label = 'Fumaça do pneu', type = 'toggle', modType = 20 },
            { id = 'tire_smoke_color', label = 'Cor da fumaça', type = 'smokeColor' }
        }
    },
    {
        id = 'colors',
        label = 'Cores',
        icon = 'palette',
        options = {
            { id = 'paint_color', label = 'Cor', type = 'paintColor' },
            { id = 'pearlescent', label = 'Perolado', type = 'color', target = 'pearlescent' },
            { id = 'wheel_color', label = 'Cor da roda', type = 'color', target = 'wheel' }
        }
    },
    {
        id = 'lights',
        label = 'Luzes',
        icon = 'lightbulb',
        options = {
            { id = 'xenon', label = 'Xenon', type = 'toggle', modType = 22 },
            { id = 'xenon_color', label = 'Cor do xenon', type = 'xenonColor' },
            { id = 'neon_left', label = 'Neon esquerdo', type = 'neonToggle', neonIndex = 0 },
            { id = 'neon_right', label = 'Neon direito', type = 'neonToggle', neonIndex = 1 },
            { id = 'neon_front', label = 'Neon dianteiro', type = 'neonToggle', neonIndex = 2 },
            { id = 'neon_back', label = 'Neon traseiro', type = 'neonToggle', neonIndex = 3 },
            { id = 'neon_color', label = 'Cor do neon', type = 'neonColor' }
        }
    },
    {
        id = 'extras',
        label = 'Extras',
        icon = 'settings',
        options = {
            { id = 'plate', label = 'Modelo da placa', type = 'range', native = 'plateIndex', min = 0, max = 5 },
            { id = 'window_tint', label = 'Insulfilm', type = 'range', native = 'windowTint', min = 0, max = 6 },
            { id = 'livery', label = 'Livery', type = 'livery' },
            { id = 'extra_1', label = 'Extra 1', type = 'extra', extraId = 1 },
            { id = 'extra_2', label = 'Extra 2', type = 'extra', extraId = 2 },
            { id = 'extra_3', label = 'Extra 3', type = 'extra', extraId = 3 },
            { id = 'extra_4', label = 'Extra 4', type = 'extra', extraId = 4 },
            { id = 'extra_5', label = 'Extra 5', type = 'extra', extraId = 5 },
            { id = 'extra_6', label = 'Extra 6', type = 'extra', extraId = 6 },
            { id = 'extra_7', label = 'Extra 7', type = 'extra', extraId = 7 },
            { id = 'extra_8', label = 'Extra 8', type = 'extra', extraId = 8 }
        }
    }
}

local function notify(notifyType, message, duration)
    exports.qbx_core:Notify(tostring(message or ''), notifyType or 'inform', duration or 4500)
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    local formatted = tostring(value):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    return '$ ' .. formatted
end

local function rgbToValue(r, g, b)
    r = math.max(0, math.min(255, math.floor(tonumber(r) or 0)))
    g = math.max(0, math.min(255, math.floor(tonumber(g) or 0)))
    b = math.max(0, math.min(255, math.floor(tonumber(b) or 0)))
    return ('%s,%s,%s'):format(r, g, b)
end

local gtaColorRgb = {
    [0] = { 11, 11, 13 },
    [1] = { 31, 35, 40 },
    [4] = { 185, 189, 198 },
    [12] = { 5, 5, 6 },
    [13] = { 68, 71, 77 },
    [14] = { 136, 140, 145 },
    [27] = { 196, 23, 37 },
    [38] = { 199, 91, 23 },
    [39] = { 160, 24, 33 },
    [55] = { 37, 77, 34 },
    [62] = { 8, 29, 68 },
    [64] = { 29, 79, 163 },
    [82] = { 47, 99, 143 },
    [83] = { 28, 53, 95 },
    [89] = { 215, 165, 28 },
    [111] = { 241, 241, 238 },
    [120] = { 216, 216, 224 },
    [131] = { 216, 216, 210 },
    [143] = { 91, 13, 24 },
    [145] = { 78, 36, 120 },
    [149] = { 57, 32, 79 }
}

local function rgbFromIndex(color)
    local rgb = gtaColorRgb[tonumber(color) or 0] or { 255, 255, 255 }
    return rgbToValue(rgb[1], rgb[2], rgb[3])
end

local function isSpecialPaintColor(color)
    color = tonumber(color) or 0
    return color == 120 or color >= 161
end

local function rememberCustomColor(target, r, g, b)
    if target ~= 'primary' and target ~= 'secondary' then return end
    lastCustomColors[target] = {
        r = tonumber(r) or 255,
        g = tonumber(g) or 255,
        b = tonumber(b) or 255
    }
end

local function reapplyRememberedCustomColors(vehicle)
    if not DoesEntityExist(vehicle) then return end

    if lastCustomColors.primary and SetVehicleCustomPrimaryColour then
        SetVehicleCustomPrimaryColour(vehicle, lastCustomColors.primary.r, lastCustomColors.primary.g, lastCustomColors.primary.b)
    end

    if lastCustomColors.secondary and SetVehicleCustomSecondaryColour then
        SetVehicleCustomSecondaryColour(vehicle, lastCustomColors.secondary.r, lastCustomColors.secondary.g, lastCustomColors.secondary.b)
    end
end

local function toggleKey(modType)
    return tostring(tonumber(modType) or modType or '')
end

local function applyToggleMod(vehicle, modType, enabled)
    modType = tonumber(modType)
    if not modType then return end

    enabled = enabled == true or enabled == 'true'
    SetVehicleModKit(vehicle, 0)
    ToggleVehicleMod(vehicle, modType, enabled)

    if modType == 18 then
        SetVehicleModKit(vehicle, 0)
        ToggleVehicleMod(vehicle, 18, enabled)
    end

    forcedToggleValues[toggleKey(modType)] = enabled
end

local function paintTypeFromFinish(finish)
    if finish == 'matte' then return 3 end
    if finish == 'chrome' then return 5 end
    return 1
end

local function paintBaseColorFromFinish(finish)
    if finish == 'matte' then return 12 end
    if finish == 'chrome' then return 120 end
    return 0
end

local function finishFromPaintType(paintType, color)
    paintType = tonumber(paintType) or 1
    color = tonumber(color) or 0
    if paintType == 5 or color == 120 then return 'chrome' end
    if paintType == 3 then return 'matte' end
    return 'metallic'
end

local function getPaintFinish(vehicle, target)
    local paintType, color = 1, 0
    if target == 'secondary' and GetVehicleModColor_2 then
        paintType, color = GetVehicleModColor_2(vehicle)
    elseif GetVehicleModColor_1 then
        paintType, color = GetVehicleModColor_1(vehicle)
    end
    return finishFromPaintType(paintType, color)
end

local function getPaintState(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local primaryRgb = rgbFromIndex(primary)
    local secondaryRgb = rgbFromIndex(secondary)

    if GetIsVehiclePrimaryColourCustom and GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        primaryRgb = rgbToValue(r or 255, g or 255, b or 255)
    end

    if GetIsVehicleSecondaryColourCustom and GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        secondaryRgb = rgbToValue(r or 255, g or 255, b or 255)
    end

    return {
        primary = tonumber(primary) or 0,
        secondary = tonumber(secondary) or 0,
        primaryRgb = primaryRgb,
        secondaryRgb = secondaryRgb,
        primaryFinish = getPaintFinish(vehicle, 'primary'),
        secondaryFinish = getPaintFinish(vehicle, 'secondary')
    }
end

local function getPaintSignature(vehicle)
    local paint = getPaintState(vehicle)
    return ('%s:%s:%s:%s'):format(paint.primaryRgb, paint.secondaryRgb, paint.primaryFinish, paint.secondaryFinish)
end

local function parseRgbValue(value)
    if type(value) == 'table' then
        return tonumber(value[1]) or 255, tonumber(value[2]) or 255, tonumber(value[3]) or 255
    end

    local r, g, b = tostring(value or ''):match('^(%d+),(%d+),(%d+)$')
    return tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255
end

local function loadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function playAnim(animConfig)
    if type(animConfig) ~= 'table' or not animConfig.dict or not animConfig.anim then return end
    if loadAnim(animConfig.dict) then
        TaskPlayAnim(PlayerPedId(), animConfig.dict, animConfig.anim, 8.0, -8.0, -1, animConfig.flag or 1, 0.0, false, false, false)
    end
end

local function stopAnim()
    ClearPedTasks(PlayerPedId())
end

local function progress(duration, label)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })
end

local function getClosestVehicle(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest = 0
    local closestDistance = distance or 5.0

    for _, vehicle in pairs(GetGamePool('CVehicle')) do
        local vehicleDistance = #(coords - GetEntityCoords(vehicle))
        if vehicleDistance < closestDistance then
            closest = vehicle
            closestDistance = vehicleDistance
        end
    end

    return closest, closestDistance
end

local function getWheelPosition(vehicle, wheel)
    local boneIndex = GetEntityBoneIndexByName(vehicle, wheel.bone)
    if boneIndex ~= -1 then
        return GetWorldPositionOfEntityBone(vehicle, boneIndex)
    end
    return GetEntityCoords(vehicle)
end

local function getClosestBurstTire(vehicle)
    local pedCoords = GetEntityCoords(PlayerPedId())
    local bestWheel = nil
    local bestDistance = MechanicConfig.Tire.distance or 2.1

    for _, wheel in pairs(wheelBones) do
        if IsVehicleTyreBurst(vehicle, wheel.index, false) or IsVehicleTyreBurst(vehicle, wheel.index, true) then
            local distance = #(pedCoords - getWheelPosition(vehicle, wheel))
            if distance < bestDistance then
                bestWheel = wheel
                bestDistance = distance
            end
        end
    end

    return bestWheel, bestDistance
end

local function hasAnyBurstTire(vehicle)
    for _, wheel in pairs(wheelBones) do
        if IsVehicleTyreBurst(vehicle, wheel.index, false) or IsVehicleTyreBurst(vehicle, wheel.index, true) then
            return true
        end
    end
    return false
end

local function getPlate(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', '')
end

local function getVehicleName(vehicle)
    local model = GetEntityModel(vehicle)
    local display = GetDisplayNameFromVehicleModel(model)
    display = tostring(display or ''):lower()

    if display ~= '' and display ~= 'null' and display ~= 'carnotfound' then
        return display
    end

    return tostring(model)
end

local function captureVehicleState(vehicle)
    SetVehicleModKit(vehicle, 0)

    local primary, secondary = GetVehicleColours(vehicle)
    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)
    local primaryPaintType, primaryPaintColor, primaryPaintPearlescent = 1, primary, pearlescent
    local secondaryPaintType, secondaryPaintColor = 1, secondary
    local neonR, neonG, neonB = GetVehicleNeonLightsColour(vehicle)
    local smokeR, smokeG, smokeB = GetVehicleTyreSmokeColor(vehicle)

    if GetVehicleModColor_1 then
        primaryPaintType, primaryPaintColor, primaryPaintPearlescent = GetVehicleModColor_1(vehicle)
    end

    if GetVehicleModColor_2 then
        secondaryPaintType, secondaryPaintColor = GetVehicleModColor_2(vehicle)
    end

    local state = {
        mods = {},
        variations = {},
        toggles = {},
        extras = {},
        primaryColor = primary,
        secondaryColor = secondary,
        customPrimaryColor = nil,
        customSecondaryColor = nil,
        pearlescentColor = pearlescent,
        wheelColor = wheelColor,
        paint = {
            primaryType = primaryPaintType or 1,
            primaryColor = primaryPaintColor or primary,
            primaryPearlescent = primaryPaintPearlescent or pearlescent,
            secondaryType = secondaryPaintType or 1,
            secondaryColor = secondaryPaintColor or secondary
        },
        wheelType = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        livery = GetVehicleLivery(vehicle),
        tyresCanBurst = GetVehicleTyresCanBurst(vehicle),
        neon = {
            enabled = {},
            color = { neonR or 255, neonG or 255, neonB or 255 }
        },
        tireSmoke = { smokeR or 255, smokeG or 255, smokeB or 255 }
    }

    if GetIsVehiclePrimaryColourCustom and GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        state.customPrimaryColor = { r or 255, g or 255, b or 255 }
    end

    if GetIsVehicleSecondaryColourCustom and GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        state.customSecondaryColor = { r or 255, g or 255, b or 255 }
    end

    for modType = 0, 49 do
        state.mods[tostring(modType)] = GetVehicleMod(vehicle, modType)
        state.variations[tostring(modType)] = GetVehicleModVariation(vehicle, modType) == true
    end

    for _, modType in ipairs({ 18, 20, 22 }) do
        local forced = forcedToggleValues[toggleKey(modType)]
        if forced ~= nil then
            state.toggles[tostring(modType)] = forced == true
        else
            state.toggles[tostring(modType)] = IsToggleModOn(vehicle, modType) == true
        end
    end

    for i = 0, 3 do
        state.neon.enabled[tostring(i)] = IsVehicleNeonLightEnabled(vehicle, i) == true
    end

    for i = 1, 14 do
        if DoesExtraExist(vehicle, i) then
            state.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) == true
        end
    end

    if GetVehicleXenonLightsColor then
        state.xenonColor = GetVehicleXenonLightsColor(vehicle)
    end

    return state
end

local function applyVehicleState(vehicle, state)
    if type(state) ~= 'table' or not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)

    if state.wheelType ~= nil then SetVehicleWheelType(vehicle, tonumber(state.wheelType) or 0) end
    if state.primaryColor and state.secondaryColor then SetVehicleColours(vehicle, state.primaryColor, state.secondaryColor) end
    if state.paint and SetVehicleModColor_1 then
        SetVehicleModColor_1(vehicle, tonumber(state.paint.primaryType) or 1, tonumber(state.primaryColor) or tonumber(state.paint.primaryColor) or 0, tonumber(state.pearlescentColor) or tonumber(state.paint.primaryPearlescent) or 0)
    end
    if state.paint and SetVehicleModColor_2 then
        SetVehicleModColor_2(vehicle, tonumber(state.paint.secondaryType) or 1, tonumber(state.secondaryColor) or tonumber(state.paint.secondaryColor) or 0)
    end
    if ClearVehicleCustomPrimaryColour then ClearVehicleCustomPrimaryColour(vehicle) end
    if ClearVehicleCustomSecondaryColour then ClearVehicleCustomSecondaryColour(vehicle) end
    if state.customPrimaryColor and SetVehicleCustomPrimaryColour then
        SetVehicleCustomPrimaryColour(vehicle, state.customPrimaryColor[1] or 255, state.customPrimaryColor[2] or 255, state.customPrimaryColor[3] or 255)
    end
    if state.customSecondaryColor and SetVehicleCustomSecondaryColour then
        SetVehicleCustomSecondaryColour(vehicle, state.customSecondaryColor[1] or 255, state.customSecondaryColor[2] or 255, state.customSecondaryColor[3] or 255)
    end
    if state.pearlescentColor and state.wheelColor then SetVehicleExtraColours(vehicle, state.pearlescentColor, state.wheelColor) end
    if state.windowTint ~= nil then SetVehicleWindowTint(vehicle, tonumber(state.windowTint) or 0) end
    if state.plateIndex ~= nil then SetVehicleNumberPlateTextIndex(vehicle, tonumber(state.plateIndex) or 0) end
    if state.livery ~= nil and tonumber(state.livery) and tonumber(state.livery) >= 0 then SetVehicleLivery(vehicle, tonumber(state.livery)) end
    if state.tyresCanBurst ~= nil then SetVehicleTyresCanBurst(vehicle, state.tyresCanBurst == true) end

    for modType, value in pairs(state.mods or {}) do
        local index = tonumber(modType)
        if index then
            SetVehicleMod(vehicle, index, tonumber(value) or -1, (state.variations or {})[tostring(index)] == true)
        end
    end

    for modType, enabled in pairs(state.toggles or {}) do
        local index = tonumber(modType)
        if index then applyToggleMod(vehicle, index, enabled == true) end
    end

    for extraId, enabled in pairs(state.extras or {}) do
        local index = tonumber(extraId)
        if index and DoesExtraExist(vehicle, index) then
            SetVehicleExtra(vehicle, index, enabled and 0 or 1)
        end
    end

    for i = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, i, state.neon and state.neon.enabled and state.neon.enabled[tostring(i)] == true)
    end

    if state.neon and state.neon.color then
        SetVehicleNeonLightsColour(vehicle, state.neon.color[1] or 255, state.neon.color[2] or 255, state.neon.color[3] or 255)
    end

    if state.tireSmoke then
        SetVehicleTyreSmokeColor(vehicle, state.tireSmoke[1] or 255, state.tireSmoke[2] or 255, state.tireSmoke[3] or 255)
    end

    if state.xenonColor ~= nil and SetVehicleXenonLightsColor then
        SetVehicleXenonLightsColor(vehicle, tonumber(state.xenonColor) or 255)
    end
end

local function getCurrentValue(vehicle, option)
    if option.type == 'mod' then
        return GetVehicleMod(vehicle, option.modType)
    elseif option.type == 'toggle' then
        local forced = forcedToggleValues[toggleKey(option.modType)]
        if forced ~= nil then return forced == true end
        return IsToggleModOn(vehicle, option.modType) == true
    elseif option.type == 'wheelType' then
        return GetVehicleWheelType(vehicle)
    elseif option.type == 'color' then
        local primary, secondary = GetVehicleColours(vehicle)
        local pearlescent, wheel = GetVehicleExtraColours(vehicle)
        if option.target == 'primary' then return primary end
        if option.target == 'secondary' then return secondary end
        if option.target == 'pearlescent' then return pearlescent end
        if option.target == 'wheel' then return wheel end
    elseif option.type == 'rgbColor' then
        if option.target == 'primary' then
            local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
            return rgbToValue(r or 255, g or 255, b or 255)
        end
        if option.target == 'secondary' then
            local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
            return rgbToValue(r or 255, g or 255, b or 255)
        end
    elseif option.type == 'paintColor' then
        return getPaintSignature(vehicle)
    elseif option.type == 'paintFinish' then
        local paintType, color = 1, 0
        if (option.target == 'primary' or option.target == 'both') and GetVehicleModColor_1 then
            paintType, color = GetVehicleModColor_1(vehicle)
        elseif option.target == 'secondary' and GetVehicleModColor_2 then
            paintType, color = GetVehicleModColor_2(vehicle)
        end

        color = tonumber(color) or 0
        paintType = tonumber(paintType) or 1

        if paintType == 5 or color == 120 then return 'chrome' end
        if paintType == 3 then return 'matte' end
        return 'metallic'
    elseif option.type == 'range' then
        if option.native == 'windowTint' then return GetVehicleWindowTint(vehicle) end
        if option.native == 'plateIndex' then return GetVehicleNumberPlateTextIndex(vehicle) end
    elseif option.type == 'tireVariation' then
        return GetVehicleModVariation(vehicle, option.modType) == true
    elseif option.type == 'tireBurst' then
        return GetVehicleTyresCanBurst(vehicle) == false
    elseif option.type == 'neonToggle' then
        return IsVehicleNeonLightEnabled(vehicle, option.neonIndex) == true
    elseif option.type == 'neonColor' then
        local r, g, b = GetVehicleNeonLightsColour(vehicle)
        return ('%s,%s,%s'):format(r or 255, g or 255, b or 255)
    elseif option.type == 'smokeColor' then
        local r, g, b = GetVehicleTyreSmokeColor(vehicle)
        return ('%s,%s,%s'):format(r or 255, g or 255, b or 255)
    elseif option.type == 'xenonColor' and GetVehicleXenonLightsColor then
        return GetVehicleXenonLightsColor(vehicle)
    elseif option.type == 'livery' then
        return GetVehicleLivery(vehicle)
    elseif option.type == 'extra' then
        return IsVehicleExtraTurnedOn(vehicle, option.extraId) == true
    end
    return nil
end

local function optionPrice(categoryId, optionId, value)
    local prices = MechanicConfig.Shop.prices or {}
    local price = tonumber(prices[categoryId]) or tonumber(MechanicConfig.Shop.defaultPrice) or 0
    local levelPricing = MechanicConfig.Shop.levelPricing or {}

    if type(levelPricing.options) == 'table' and levelPricing.options[optionId] == true then
        local level = math.floor(tonumber(value) or -1)
        if level >= 0 then
            price = price * (1.0 + level * math.max(0, tonumber(levelPricing.step) or 0.5))
        end
    end

    return math.floor(price)
end

local function captureOptionValues(vehicle)
    local values = {}
    for _, category in pairs(modCategories) do
        for _, option in pairs(category.options) do
            values[option.id] = getCurrentValue(vehicle, option)
        end
    end
    return values
end

local function refreshTotal()
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        currentTotal = 0
        return
    end

    local total = 0
    for _, category in pairs(modCategories) do
        for _, option in pairs(category.options) do
            local original = baselineValues[option.id]
            local current = getCurrentValue(activeVehicle, option)
            if tostring(original) ~= tostring(current) then
                total = total + optionPrice(category.id, option.id, current)
            end
        end
    end

    currentTotal = total
end

local function captureChangedOptions()
    local changes = {}

    if not activeVehicle or not DoesEntityExist(activeVehicle) then return changes end

    for _, category in pairs(modCategories) do
        for _, option in pairs(category.options) do
            local original = baselineValues[option.id]
            local current = getCurrentValue(activeVehicle, option)
            if tostring(original) ~= tostring(current) then
                changes[#changes + 1] = {
                    categoryId = category.id,
                    optionId = option.id,
                    value = current
                }
            end
        end
    end

    return changes
end

local function buildOptionValues(vehicle, option)
    if option.type == 'toggle' or option.type == 'tireVariation' or option.type == 'tireBurst' or option.type == 'neonToggle' or option.type == 'extra' then
        return {
            { label = 'Desligado', value = false },
            { label = 'Ligado', value = true }
        }, getCurrentValue(vehicle, option)
    end

    if option.type == 'wheelType' then
        return wheelTypes, getCurrentValue(vehicle, option)
    end

    if option.type == 'color' then
        return colorPresets, getCurrentValue(vehicle, option)
    end

    if option.type == 'rgbColor' then
        local current = getCurrentValue(vehicle, option)
        return {
            { label = 'RGB', value = current }
        }, current
    end

    if option.type == 'paintColor' then
        return {
            { label = 'Cor', value = 'paint' }
        }, getCurrentValue(vehicle, option)
    end

    if option.type == 'paintFinish' then
        return paintFinishes, getCurrentValue(vehicle, option)
    end

    if option.type == 'neonColor' then
        return neonColors, getCurrentValue(vehicle, option)
    end

    if option.type == 'smokeColor' then
        return neonColors, getCurrentValue(vehicle, option)
    end

    if option.type == 'xenonColor' then
        return xenonColors, getCurrentValue(vehicle, option)
    end

    if option.type == 'range' then
        local values = {}
        for i = option.min or 0, option.max or 0 do
            values[#values + 1] = { label = ('Modelo %s'):format(i), value = i }
        end
        return values, getCurrentValue(vehicle, option)
    end

    if option.type == 'livery' then
        local count = GetVehicleLiveryCount(vehicle)
        if count <= 0 then return {}, nil end
        local values = { { label = 'Original', value = -1 } }
        for i = 0, count - 1 do
            values[#values + 1] = { label = ('Livery %s'):format(i + 1), value = i }
        end
        return values, getCurrentValue(vehicle, option)
    end

    if option.type == 'mod' then
        local count = GetNumVehicleMods(vehicle, option.modType)
        if count <= 0 then return {}, nil end

        local values = { { label = 'Original', value = -1 } }
        for i = 0, count - 1 do
            values[#values + 1] = { label = ('Nivel %s'):format(i + 1), value = i }
        end
        return values, getCurrentValue(vehicle, option)
    end

    return {}, nil
end

local function isVehicleDamagedForShop(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return IsVehicleDamaged(vehicle)
        or GetVehicleEngineHealth(vehicle) < 950.0
        or GetVehicleBodyHealth(vehicle) < 950.0
        or hasAnyBurstTire(vehicle)
end

local function buildShopPayload(vehicle, locationLabel, activeCategoryId)
    SetVehicleModKit(vehicle, 0)
    refreshTotal()

    local categories = {}
    for _, category in pairs(modCategories) do
        local options = {}

        for _, option in pairs(category.options) do
            if option.type ~= 'extra' or DoesExtraExist(vehicle, option.extraId) then
                local values, current = buildOptionValues(vehicle, option)
                if #values > 0 then
                    for _, entry in ipairs(values) do
                        entry.price = optionPrice(category.id, option.id, entry.value)
                        entry.priceLabel = money(entry.price)
                    end
                    local item = {}
                    for key, value in pairs(option) do item[key] = value end
                    item.values = values
                    item.current = current
                    item.changed = tostring(baselineValues[option.id]) ~= tostring(current)
                    if option.type == 'rgbColor' then
                        item.finishes = paintFinishes
                        item.finish = getCurrentValue(vehicle, { type = 'paintFinish', target = 'both' })
                    elseif option.type == 'paintColor' then
                        item.finishes = paintFinishes
                        item.paint = getPaintState(vehicle)
                    end
                    options[#options + 1] = item
                end
            end
        end

        if #options > 0 then
            categories[#categories + 1] = {
                id = category.id,
                label = category.label,
                icon = category.icon,
                price = optionPrice(category.id),
                priceLabel = money(optionPrice(category.id)),
                options = options
            }
        end
    end

    return {
        title = locationLabel or 'Automotiva Akuma',
        subtitle = activeVehicleOwned and 'Personalização, performance e acabamento do veículo.'
            or 'Veículo de NPC: somente o reparo está disponível.',
        ui = MechanicConfig.UI or {},
        categories = categories,
        activeCategoryId = activeCategoryId,
        total = currentTotal,
        totalLabel = money(currentTotal),
        usePayment = MechanicConfig.Shop.usePayment == true,
        damaged = isVehicleDamagedForShop(vehicle),
        locked = not vehicleReady or not activeVehicleOwned,
        npcVehicle = not activeVehicleOwned,
        repairPrice = MechanicConfig.Shop.repairPrice or 0,
        repairPriceLabel = money(MechanicConfig.Shop.repairPrice or 0)
    }
end

local function setCamera(view)
    if not activeVehicle or not DoesEntityExist(activeVehicle) then return end
    if previewCam and DoesCamExist(previewCam) then DestroyCam(previewCam, false) end

    local offsets = {
        front = vec3(0.0, -5.2, 1.7),
        rear = vec3(0.0, 5.2, 1.7),
        left = vec3(-4.8, 0.0, 1.5),
        right = vec3(4.8, 0.0, 1.5),
        wheels = vec3(-3.0, -2.8, 0.7),
        top = vec3(0.0, -4.0, 4.0)
    }

    local offset = offsets[view] or offsets.front
    local coords = GetOffsetFromEntityInWorldCoords(activeVehicle, offset.x, offset.y, offset.z)
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, coords.x, coords.y, coords.z)
    PointCamAtEntity(previewCam, activeVehicle, 0.0, 0.0, 0.3, true)
    SetCamFov(previewCam, view == 'top' and 52.0 or 45.0)
    RenderScriptCams(true, true, 320, true, true)
end

local function destroyCamera()
    if previewCam and DoesCamExist(previewCam) then
        DestroyCam(previewCam, false)
    end
    previewCam = nil
    RenderScriptCams(false, true, 260, true, true)
end

local function sendRefresh(activeCategoryId)
    if menuOpen and activeVehicle and DoesEntityExist(activeVehicle) then
        SendNUIMessage({
            action = 'refresh',
            payload = buildShopPayload(activeVehicle, activeLocationLabel, activeCategoryId)
        })
    end
end

local function closeMenu(restore)
    if not menuOpen then return end

    if restore and activeVehicle and DoesEntityExist(activeVehicle) and baselineState then
        applyVehicleState(activeVehicle, baselineState)
        notify('info', MechanicConfig.Messages.restored, 2500)
    end

    if activeVehicle and DoesEntityExist(activeVehicle) then
        FreezeEntityPosition(activeVehicle, false)
    end

    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    destroyCamera()
    SendNUIMessage({ action = 'close' })

    if activeSession then TriggerServerEvent('VanguardMechanic:server:closeSession', activeSession) end
    activeLocation = nil
    activeLocationLabel = nil
    activeSession = nil
    activeVehicle = nil
    baselineState = nil
    baselineValues = {}
    currentTotal = 0
    vehicleReady = false
    activeVehicleOwned = true
    lastCustomColors.primary = nil
    lastCustomColors.secondary = nil
    lastPaintColors.primary = 0
    lastPaintColors.secondary = 0
    forcedToggleValues = {}
end

local function clearLocationBlips()
    for _, blip in pairs(locationBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    locationBlips = {}
end

local function createLocationBlips()
    clearLocationBlips()
    for _, location in pairs(availableLocations or {}) do
        if location.blip and location.blip.enabled then
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, location.blip.sprite or 446)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, location.blip.scale or 0.7)
            SetBlipColour(blip, location.blip.color or 27)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(location.blip.name or location.label or 'Mecanica')
            EndTextCommandSetBlipName(blip)
            locationBlips[#locationBlips + 1] = blip
        end
    end
end

local function applyOption(vehicle, option, value)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)

    if option.type == 'toggle' then
        applyToggleMod(vehicle, option.modType, value)
    elseif option.type == 'wheelType' then
        SetVehicleWheelType(vehicle, tonumber(value) or 0)
    elseif option.type == 'mod' then
        SetVehicleMod(vehicle, tonumber(option.modType), tonumber(value) or -1, GetVehicleModVariation(vehicle, tonumber(option.modType)) == true)
    elseif option.type == 'color' then
        local primary, secondary = GetVehicleColours(vehicle)
        local pearlescent, wheel = GetVehicleExtraColours(vehicle)
        value = tonumber(value) or 0

        if option.target == 'primary' then
            lastPaintColors.primary = value
            SetVehicleColours(vehicle, value, secondary)
        elseif option.target == 'secondary' then
            lastPaintColors.secondary = value
            SetVehicleColours(vehicle, primary, value)
        elseif option.target == 'pearlescent' then
            SetVehicleExtraColours(vehicle, value, wheel)
        elseif option.target == 'wheel' then
            SetVehicleExtraColours(vehicle, pearlescent, value)
        end
    elseif option.type == 'paintColor' then
        local payload = type(value) == 'table' and value or {}
        local target = tostring(payload.target or 'primary')
        local finish = tostring(payload.finish or 'metallic')
        local r, g, b = parseRgbValue(payload.rgb or payload.color or '255,255,255')
        local primary, secondary = GetVehicleColours(vehicle)
        local pearlescent, wheel = GetVehicleExtraColours(vehicle)
        local paintType = paintTypeFromFinish(finish)
        local baseColor = paintBaseColorFromFinish(finish)

        if finish == 'chrome' then
            if target == 'secondary' then
                if not isSpecialPaintColor(secondary) then lastPaintColors.secondary = secondary end
                if ClearVehicleCustomSecondaryColour then ClearVehicleCustomSecondaryColour(vehicle) end
                secondary = baseColor
                SetVehicleColours(vehicle, primary, secondary)
                if SetVehicleModColor_2 then SetVehicleModColor_2(vehicle, paintType, baseColor) end
            else
                if not isSpecialPaintColor(primary) then lastPaintColors.primary = primary end
                if ClearVehicleCustomPrimaryColour then ClearVehicleCustomPrimaryColour(vehicle) end
                primary = baseColor
                SetVehicleColours(vehicle, primary, secondary)
                if SetVehicleModColor_1 then SetVehicleModColor_1(vehicle, paintType, baseColor, pearlescent) end
            end
        elseif target == 'secondary' then
            if not isSpecialPaintColor(secondary) then lastPaintColors.secondary = secondary end
            if ClearVehicleCustomSecondaryColour then ClearVehicleCustomSecondaryColour(vehicle) end
            secondary = baseColor
            SetVehicleColours(vehicle, primary, secondary)
            if SetVehicleModColor_2 then SetVehicleModColor_2(vehicle, paintType, secondary) end
            if SetVehicleCustomSecondaryColour then SetVehicleCustomSecondaryColour(vehicle, r, g, b) end
            rememberCustomColor('secondary', r, g, b)
        else
            if not isSpecialPaintColor(primary) then lastPaintColors.primary = primary end
            if ClearVehicleCustomPrimaryColour then ClearVehicleCustomPrimaryColour(vehicle) end
            primary = baseColor
            SetVehicleColours(vehicle, primary, secondary)
            if SetVehicleModColor_1 then SetVehicleModColor_1(vehicle, paintType, primary, pearlescent) end
            if SetVehicleCustomPrimaryColour then SetVehicleCustomPrimaryColour(vehicle, r, g, b) end
            rememberCustomColor('primary', r, g, b)
        end

        SetVehicleExtraColours(vehicle, pearlescent, wheel)
    elseif option.type == 'rgbColor' then
        local r, g, b = parseRgbValue(value)
        if option.target == 'primary' and SetVehicleCustomPrimaryColour then
            SetVehicleCustomPrimaryColour(vehicle, r, g, b)
            rememberCustomColor('primary', r, g, b)
        elseif option.target == 'secondary' and SetVehicleCustomSecondaryColour then
            SetVehicleCustomSecondaryColour(vehicle, r, g, b)
            rememberCustomColor('secondary', r, g, b)
        end
    elseif option.type == 'paintFinish' then
        local finish = tostring(value or 'metallic')
        local primary, secondary = GetVehicleColours(vehicle)
        local pearlescent, wheel = GetVehicleExtraColours(vehicle)
        local paintType = paintTypeFromFinish(finish)
        local baseColor = paintBaseColorFromFinish(finish)

        if not isSpecialPaintColor(primary) then lastPaintColors.primary = primary end
        if not isSpecialPaintColor(secondary) then lastPaintColors.secondary = secondary end
        if ClearVehicleCustomPrimaryColour then ClearVehicleCustomPrimaryColour(vehicle) end
        if ClearVehicleCustomSecondaryColour then ClearVehicleCustomSecondaryColour(vehicle) end

        primary = baseColor
        secondary = baseColor

        SetVehicleColours(vehicle, primary, secondary)
        if SetVehicleModColor_1 then SetVehicleModColor_1(vehicle, paintType, primary, pearlescent) end
        if SetVehicleModColor_2 then SetVehicleModColor_2(vehicle, paintType, secondary) end
        SetVehicleExtraColours(vehicle, pearlescent, wheel)

        if finish ~= 'chrome' then
            reapplyRememberedCustomColors(vehicle)
        end
    elseif option.type == 'range' then
        value = tonumber(value) or 0
        if option.native == 'windowTint' then
            SetVehicleWindowTint(vehicle, value)
        elseif option.native == 'plateIndex' then
            SetVehicleNumberPlateTextIndex(vehicle, value)
        end
    elseif option.type == 'tireVariation' then
        local current = GetVehicleMod(vehicle, option.modType)
        SetVehicleMod(vehicle, option.modType, current, value == true or value == 'true')
    elseif option.type == 'tireBurst' then
        SetVehicleTyresCanBurst(vehicle, not (value == true or value == 'true'))
    elseif option.type == 'neonToggle' then
        SetVehicleNeonLightEnabled(vehicle, option.neonIndex, value == true or value == 'true')
    elseif option.type == 'neonColor' or option.type == 'smokeColor' then
        local rgb = nil
        for _, item in pairs(neonColors) do
            if tostring(item.value) == tostring(value) then rgb = item.rgb end
        end
        if rgb then
            if option.type == 'neonColor' then
                SetVehicleNeonLightsColour(vehicle, rgb[1], rgb[2], rgb[3])
            else
                ToggleVehicleMod(vehicle, 20, true)
                SetVehicleTyreSmokeColor(vehicle, rgb[1], rgb[2], rgb[3])
            end
        end
    elseif option.type == 'xenonColor' and SetVehicleXenonLightsColor then
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, tonumber(value) or 255)
    elseif option.type == 'livery' then
        SetVehicleLivery(vehicle, tonumber(value) or -1)
    elseif option.type == 'extra' then
        SetVehicleExtra(vehicle, option.extraId, (value == true or value == 'true') and 0 or 1)
    end
end

local function findOption(categoryId, optionId)
    if optionId == 'paint_finish' then
        return { id = 'paint_finish', label = 'Tipo de pintura', type = 'paintFinish', target = 'both' }
    end

    for _, category in pairs(modCategories) do
        if category.id == categoryId then
            for _, option in pairs(category.options) do
                if option.id == optionId then return option end
            end
        end
    end
    return nil
end

local function repairVehicle(vehicle, fixTires)
    if not DoesEntityExist(vehicle) then return end
    if MechanicConfig.Repair.fixEngine then SetVehicleEngineHealth(vehicle, 1000.0) end
    if MechanicConfig.Repair.fixBody then SetVehicleBodyHealth(vehicle, 1000.0) end
    if MechanicConfig.Repair.fixTank then SetVehiclePetrolTankHealth(vehicle, 1000.0) end
    if MechanicConfig.Repair.fixDeformation then SetVehicleDeformationFixed(vehicle) end
    if fixTires then SetVehicleFixed(vehicle) end
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleUndriveable(vehicle, false)
end

RegisterNetEvent('VanguardMechanic:client:openShop', function(locationId, locationLabel, sessionToken, vehicleOwned)
    if menuOpen then
        TriggerServerEvent('VanguardMechanic:server:closeSession', sessionToken)
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('warning', MechanicConfig.Messages.needVehicle)
        TriggerServerEvent('VanguardMechanic:server:closeSession', sessionToken)
        return
    end

    if MechanicConfig.Shop.requireDriver == true and GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('warning', MechanicConfig.Messages.driverOnly)
        TriggerServerEvent('VanguardMechanic:server:closeSession', sessionToken)
        return
    end

    SetVehicleModKit(vehicle, 0)
    activeLocation = locationId
    activeLocationLabel = locationLabel
    activeSession = sessionToken
    activeVehicle = vehicle
    activeVehicleOwned = vehicleOwned == true
    forcedToggleValues = {}
    baselineState = captureVehicleState(vehicle)
    baselineValues = captureOptionValues(vehicle)
    currentTotal = 0
    vehicleReady = not isVehicleDamagedForShop(vehicle)
    do
        local primary, secondary = GetVehicleColours(vehicle)
        local pr, pg, pb = GetVehicleCustomPrimaryColour(vehicle)
        local sr, sg, sb = GetVehicleCustomSecondaryColour(vehicle)
        lastPaintColors.primary = isSpecialPaintColor(primary) and 0 or primary
        lastPaintColors.secondary = isSpecialPaintColor(secondary) and 0 or secondary
        if GetIsVehiclePrimaryColourCustom and GetIsVehiclePrimaryColourCustom(vehicle) then
            rememberCustomColor('primary', pr or 255, pg or 255, pb or 255)
        else
            lastCustomColors.primary = nil
        end
        if GetIsVehicleSecondaryColourCustom and GetIsVehicleSecondaryColourCustom(vehicle) then
            rememberCustomColor('secondary', sr or 255, sg or 255, sb or 255)
        else
            lastCustomColors.secondary = nil
        end
    end
    menuOpen = true

    FreezeEntityPosition(vehicle, true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SetCursorLocation(0.24, 0.5)
    setCamera('front')
    SendNUIMessage({
        action = 'open',
        payload = buildShopPayload(vehicle, locationLabel)
    })

    if activeVehicleOwned then
        TriggerServerEvent('VanguardMechanic:server:requestPending', getPlate(vehicle))
    end
end)

RegisterNetEvent('VanguardMechanic:client:setLocations', function(locations)
    availableLocations = type(locations) == 'table' and locations or {}
    createLocationBlips()
end)

RegisterNetEvent('VanguardMechanic:client:checkoutResult', function(ok)
    SendNUIMessage({ action = 'busy', payload = { busy = false } })
    if not menuOpen or not activeVehicle or not DoesEntityExist(activeVehicle) then return end

    if ok then
        baselineState = captureVehicleState(activeVehicle)
        baselineValues = captureOptionValues(activeVehicle)
        closeMenu(false)
    else
        sendRefresh()
    end
end)

RegisterNetEvent('VanguardMechanic:client:askSavePending', function(message)
    if not menuOpen then return end
    SendNUIMessage({
        action = 'prompt',
        payload = {
            type = 'savePending',
            icon = '?',
            eyebrow = 'Mecanica',
            title = 'Salvar modificacao',
            message = message or MechanicConfig.Messages.savePendingQuestion,
            confirm = 'Salvar',
            cancel = 'Cancelar'
        }
    })
end)

RegisterNetEvent('VanguardMechanic:client:askResumePending', function(data)
    if not menuOpen or not activeVehicle or not DoesEntityExist(activeVehicle) then return end
    data = type(data) == 'table' and data or {}
    if type(data.mods) ~= 'table' then return end

    pendingResume = {
        plate = data.plate or getPlate(activeVehicle),
        mods = data.mods
    }

    SendNUIMessage({
        action = 'prompt',
        payload = {
            type = 'resumePending',
            icon = '!',
            eyebrow = 'Mecanica',
            title = 'Retomar modificacao',
            message = data.message or MechanicConfig.Messages.resumePendingQuestion,
            confirm = 'Retomar',
            cancel = 'Agora nao'
        }
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('restore', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) and baselineState then
        applyVehicleState(activeVehicle, baselineState)
        sendRefresh(data and data.categoryId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('camera', function(data, cb)
    setCamera(type(data) == 'table' and data.view or 'front')
    cb({ ok = true })
end)

RegisterNUICallback('repair', function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        SendNUIMessage({ action = 'busy', payload = { busy = true, label = 'Reparando' } })
        TriggerServerEvent('VanguardMechanic:server:shopRepair', {
            locationId = activeLocation,
            sessionToken = activeSession,
            vehicleNetId = NetworkGetNetworkIdFromEntity(activeVehicle),
            plate = getPlate(activeVehicle)
        })
    end
    cb({ ok = true })
end)

RegisterNetEvent('VanguardMechanic:client:repairResult', function(ok)
    SendNUIMessage({ action = 'busy', payload = { busy = false } })
    if not ok or not menuOpen or not activeVehicle or not DoesEntityExist(activeVehicle) then return end
    repairVehicle(activeVehicle, true)
    vehicleReady = true
    baselineState = captureVehicleState(activeVehicle)
    baselineValues = captureOptionValues(activeVehicle)
    currentTotal = 0
    TriggerServerEvent('qbx_core:server:vehiclePropsChanged', NetworkGetNetworkIdFromEntity(activeVehicle), {
        bodyHealth = true,
        engineHealth = true,
        tankHealth = true,
        dirtLevel = true,
        tyres = 'deleted'
    })
    notify('success', MechanicConfig.Messages.repairDone)
    sendRefresh()
end)

RegisterNUICallback('apply', function(data, cb)
    data = type(data) == 'table' and data or {}
    if not activeVehicleOwned then
        notify('warning', MechanicConfig.Messages.npcVehicle)
        cb({ ok = false })
        return
    end

    if not vehicleReady then
        notify('warning', 'Repare o veiculo antes de modificar.')
        cb({ ok = false })
        return
    end

    local option = findOption(data.categoryId, data.optionId)
    if option and activeVehicle and DoesEntityExist(activeVehicle) then
        applyOption(activeVehicle, option, data.value)
        if data.silent == true or option.type == 'toggle' then
            refreshTotal()
            SendNUIMessage({
                action = 'total',
                payload = { totalLabel = money(currentTotal) }
            })
        else
            sendRefresh(data.categoryId)
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('checkout', function(_, cb)
    if not activeVehicle or not DoesEntityExist(activeVehicle) then
        cb({ ok = false })
        return
    end

    if not activeVehicleOwned then
        notify('warning', MechanicConfig.Messages.npcVehicle)
        cb({ ok = false })
        return
    end

    if not vehicleReady then
        notify('warning', 'Repare o veiculo antes de modificar.')
        cb({ ok = false })
        return
    end

    refreshTotal()
    SendNUIMessage({ action = 'busy', payload = { busy = true, label = 'Processando' } })
    TriggerServerEvent('VanguardMechanic:server:checkout', {
        locationId = activeLocation,
        sessionToken = activeSession,
        total = currentTotal,
        vehicleName = getVehicleName(activeVehicle),
        vehicleModel = GetEntityModel(activeVehicle),
        vehicleNetId = NetworkGetNetworkIdFromEntity(activeVehicle),
        plate = getPlate(activeVehicle),
        changes = captureChangedOptions(),
        mods = captureVehicleState(activeVehicle),
        properties = lib.getVehicleProperties(activeVehicle)
    })

    cb({ ok = true })
end)

RegisterNUICallback('promptAction', function(data, cb)
    data = type(data) == 'table' and data or {}
    local promptType = tostring(data.type or '')
    local accepted = data.accepted == true

    if promptType == 'savePending' then
        if accepted then
            TriggerServerEvent('VanguardMechanic:server:savePending')
            closeMenu(true)
        else
            TriggerServerEvent('VanguardMechanic:server:discardPendingCheckout')
        end
    elseif promptType == 'resumePending' then
        if accepted and pendingResume and activeVehicle and DoesEntityExist(activeVehicle) then
            applyVehicleState(activeVehicle, pendingResume.mods)
            notify('success', MechanicConfig.Messages.pendingLoaded)
            refreshTotal()
            sendRefresh()
        end
        pendingResume = nil
    end

    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if menuOpen then
        SetNuiFocus(false, false)
        if activeVehicle and DoesEntityExist(activeVehicle) then
            if baselineState then applyVehicleState(activeVehicle, baselineState) end
            FreezeEntityPosition(activeVehicle, false)
        end
    end
    destroyCamera()
    if hoverVisible then lib.hideTextUI() end
    clearLocationBlips()
end)

RegisterNetEvent('VanguardMechanic:client:useRepairKit', function(token)
    token = tostring(token or '')
    local vehicle = getClosestVehicle(MechanicConfig.Repair.distance or 4.0)

    if vehicle == 0 then
        notify('warning', MechanicConfig.Messages.noVehicleNearby)
        TriggerServerEvent('VanguardMechanic:server:itemResult', token, false)
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 800)
    Wait(500)
    playAnim(MechanicConfig.Repair.animation)
    FreezeEntityPosition(ped, true)
    local completed = progress(MechanicConfig.Repair.duration or 8500, 'Reparando veículo')
    FreezeEntityPosition(ped, false)
    stopAnim()
    if not completed then
        notify('warning', MechanicConfig.Messages.repairCancelled)
        TriggerServerEvent('VanguardMechanic:server:itemResult', token, false)
        return
    end
    repairVehicle(vehicle, false)

    notify('success', MechanicConfig.Messages.repairDone)
    TriggerServerEvent('VanguardMechanic:server:itemResult', token, true)
end)

RegisterNetEvent('VanguardMechanic:client:useTire', function(token)
    token = tostring(token or '')
    local vehicle = getClosestVehicle(4.0)

    if vehicle == 0 then
        notify('warning', MechanicConfig.Messages.noVehicleNearby)
        TriggerServerEvent('VanguardMechanic:server:itemResult', token, false)
        return
    end

    local wheel = getClosestBurstTire(vehicle)
    if not wheel then
        if hasAnyBurstTire(vehicle) then
            notify('warning', MechanicConfig.Messages.noBurstTire)
        else
            notify('warning', MechanicConfig.Messages.normalTire)
        end
        TriggerServerEvent('VanguardMechanic:server:itemResult', token, false)
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 800)
    Wait(500)
    playAnim(MechanicConfig.Tire.animation)
    FreezeEntityPosition(ped, true)
    local completed = progress(MechanicConfig.Tire.duration or 5500, 'Trocando pneu')
    FreezeEntityPosition(ped, false)
    stopAnim()
    if not completed then
        notify('warning', MechanicConfig.Messages.repairCancelled)
        TriggerServerEvent('VanguardMechanic:server:itemResult', token, false)
        return
    end

    SetVehicleTyreFixed(vehicle, wheel.index)
    notify('success', MechanicConfig.Messages.tireDone)
    TriggerServerEvent('VanguardMechanic:server:itemResult', token, true)
end)

local function refreshMechanicAccess()
    if menuOpen then closeMenu(true) end
    if hoverVisible then
        hoverVisible = false
        lib.hideTextUI()
    end
    TriggerServerEvent('VanguardMechanic:server:requestLocations')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshMechanicAccess)
RegisterNetEvent('QBCore:Client:OnJobUpdate', refreshMechanicAccess)
RegisterNetEvent('QBCore:Client:SetDuty', refreshMechanicAccess)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if menuOpen then closeMenu(true) end
    availableLocations = {}
    if hoverVisible then lib.hideTextUI() end
    hoverVisible = false
    clearLocationBlips()
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('VanguardMechanic:server:requestLocations')

    while true do
        Wait(60000)
        TriggerServerEvent('VanguardMechanic:server:requestLocations')
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearest = nil

        for _, location in pairs(availableLocations or {}) do
            local distance = #(coords - location.coords)
            local drawDistance = math.max((location.radius or 3.0) + 12.0, 15.0)

            if distance <= drawDistance then
                sleep = 0

                if location.marker and location.marker.enabled then
                    local color = location.marker.color or {}
                    local scale = location.marker.scale or vec3(0.75, 0.75, 0.75)
                    DrawMarker(
                        location.marker.type or 36,
                        location.coords.x, location.coords.y, location.coords.z + 0.15,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        scale.x, scale.y, scale.z,
                        color.r or 142, color.g or 92, color.b or 255, color.a or 120,
                        location.marker.bob == true,
                        true,
                        2,
                        location.marker.rotate == true,
                        nil, nil, false
                    )
                end

                if distance <= (location.radius or 3.0) then
                    nearest = location
                end
            end
        end

        if nearest and not menuOpen then
            if not hoverVisible then
                hoverVisible = true
                lib.showTextUI(('[E] %s'):format(nearest.label or 'Automotiva Akuma'), {
                    position = 'right-center',
                    icon = 'screwdriver-wrench'
                })
            end

            if IsControlJustPressed(0, MechanicConfig.Keys.open or 38) then
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if vehicle == 0 or not DoesEntityExist(vehicle) then
                    notify('warning', MechanicConfig.Messages.needVehicle)
                elseif MechanicConfig.Shop.requireDriver == true and GetPedInVehicleSeat(vehicle, -1) ~= ped then
                    notify('warning', MechanicConfig.Messages.driverOnly)
                else
                    TriggerServerEvent('VanguardMechanic:server:requestOpen', {
                        locationId = nearest.id,
                        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
                        plate = getPlate(vehicle)
                    })
                end
            end
        elseif hoverVisible then
            hoverVisible = false
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)
