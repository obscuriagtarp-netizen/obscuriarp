local runtime = {
    vampire = false,
    protected = false,
    protection = nil,
    ped = 0,
    daytime = false,
    weakened = false,
    exposed = false,
    burning = false,
    exposureStartedAt = 0,
    shadeStartedAt = 0,
    lastIgniteAt = 0,
    lastDamageAt = 0,
    lastReason = 'inicializando',
    lastStrength = 0.0,
    lastClearSamples = 0,
    lastWeather = 'DESCONHECIDO',
}

local weatherByHash = {}
local protectionItemNames = {}

for weatherName, strength in pairs(Config.WeatherStrength or {}) do
    weatherByHash[GetHashKey(weatherName)] = {
        name = weatherName,
        strength = tonumber(strength) or 0.0,
    }
end

for index = 1, #(Config.Protection.items or {}) do
    local item = Config.Protection.items[index]
    local itemName = type(item) == 'table' and item.name or item
    if itemName and itemName ~= '' then
        protectionItemNames[itemName] = true
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function setLocalState(key, value)
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state[key] ~= value then
        LocalPlayer.state:set(key, value, true)
    end
end

local function notify(description, notificationType)
    if not Config.Burning.notify then return end

    lib.notify({
        title = 'Sensibilidade solar',
        description = description,
        type = notificationType or 'inform',
        duration = 4000,
    })
end

local function stopResourceFire(reason)
    if runtime.burning and runtime.ped ~= 0 and DoesEntityExist(runtime.ped) then
        StopEntityFire(runtime.ped)
    end

    local wasBurning = runtime.burning
    runtime.exposed = false
    runtime.burning = false
    runtime.exposureStartedAt = 0
    runtime.shadeStartedAt = 0
    runtime.lastIgniteAt = 0
    runtime.lastDamageAt = 0
    runtime.lastReason = reason or runtime.lastReason

    setLocalState('obSunExposed', false)
    setLocalState('obSunBurning', false)

    if wasBurning and reason == 'protected' then
        notify(Config.Burning.protectionMessage, 'success')
    end
end

local function refreshStatus()
    local ok, status = pcall(function()
        return lib.callback.await('ob_sol_vampiros:server:getStatus', false)
    end)

    if not ok or type(status) ~= 'table' then
        runtime.vampire = false
        runtime.protected = false
        runtime.protection = nil
        stopResourceFire('status_unavailable')
        return
    end

    runtime.vampire = status.vampire == true
    runtime.protected = status.protected == true
    runtime.protection = status.protection

    if not runtime.vampire then
        stopResourceFire('not_vampire')
    elseif runtime.protected then
        stopResourceFire('protected')
    end
end

local function getClockHour()
    return GetClockHours() + (GetClockMinutes() / 60.0) + (GetClockSeconds() / 3600.0)
end

local function isDaytime()
    local hour = getClockHour()
    local sunrise = tonumber(Config.Daylight.sunrise) or 5.5
    local sunset = tonumber(Config.Daylight.sunset) or 20.0
    return sunset > sunrise and hour >= sunrise and hour <= sunset
end

local function getSunDirectionAndStrength()
    local hour = getClockHour()
    local sunrise = tonumber(Config.Daylight.sunrise) or 5.5
    local sunset = tonumber(Config.Daylight.sunset) or 20.0

    if hour < sunrise or hour > sunset or sunset <= sunrise then
        return nil, 0.0
    end

    local progress = clamp((hour - sunrise) / (sunset - sunrise), 0.0, 1.0)
    local arc = progress * math.pi
    local altitude = math.sin(arc)
    local eastWest = math.cos(arc)
    local southBias = tonumber(Config.Daylight.southBias) or -0.30
    local azimuthOffset = math.rad(tonumber(Config.Daylight.azimuthOffsetDegrees) or 0.0)
    local offsetCos = math.cos(azimuthOffset)
    local offsetSin = math.sin(azimuthOffset)
    local x = (eastWest * offsetCos) - (southBias * offsetSin)
    local y = (eastWest * offsetSin) + (southBias * offsetCos)
    local length = math.sqrt((x * x) + (y * y) + (altitude * altitude))

    if length <= 0.0 then
        return nil, 0.0
    end

    return vector3(x / length, y / length, altitude / length), altitude
end

local function normalizedVector(x, y, z)
    local length = math.sqrt((x * x) + (y * y) + (z * z))
    if length <= 0.0001 then return nil end
    return vector3(x / length, y / length, z / length)
end

local function offsetSunDirection(direction, azimuthDegrees, elevationDegrees)
    local horizontal = math.sqrt((direction.x * direction.x) + (direction.y * direction.y))
    local right
    if horizontal > 0.0001 then
        right = vector3(-direction.y / horizontal, direction.x / horizontal, 0.0)
    else
        right = vector3(1.0, 0.0, 0.0)
    end

    local elevation = normalizedVector(
        -(direction.z * right.y),
        direction.z * right.x,
        (direction.x * right.y) - (direction.y * right.x)
    ) or vector3(0.0, 0.0, 1.0)
    local azimuthAmount = math.tan(math.rad(tonumber(azimuthDegrees) or 0.0))
    local elevationAmount = math.tan(math.rad(tonumber(elevationDegrees) or 0.0))

    return normalizedVector(
        direction.x + (right.x * azimuthAmount) + (elevation.x * elevationAmount),
        direction.y + (right.y * azimuthAmount) + (elevation.y * elevationAmount),
        direction.z + (right.z * azimuthAmount) + (elevation.z * elevationAmount)
    ) or direction
end

local function getSunDirections(primary)
    local directions = { primary }
    for index = 1, #(Config.Exposure.directionOffsets or {}) do
        local offset = Config.Exposure.directionOffsets[index]
        directions[#directions + 1] = offsetSunDirection(
            primary,
            type(offset) == 'table' and offset.azimuth or 0.0,
            type(offset) == 'table' and offset.elevation or 0.0
        )
    end
    return directions
end

local function getWeatherStrength()
    local previousHash, nextHash, transition = GetWeatherTypeTransition()
    local previous = weatherByHash[previousHash] or { name = 'DESCONHECIDO', strength = 1.0 }
    local nextWeather = weatherByHash[nextHash] or previous
    local blend = clamp(tonumber(transition) or 0.0, 0.0, 1.0)
    local strength = previous.strength + ((nextWeather.strength - previous.strength) * blend)
    local name = blend >= 0.5 and nextWeather.name or previous.name

    return strength, name
end

local function startSunRay(ped, origin, sunDirection)
    local distance = tonumber(Config.Exposure.rayDistance) or 220.0
    local start = origin + (sunDirection * 0.08)
    local destination = start + (sunDirection * distance)
    return StartShapeTestLosProbe(
        start.x,
        start.y,
        start.z,
        destination.x,
        destination.y,
        destination.z,
        tonumber(Config.Exposure.rayFlags) or 339,
        ped,
        tonumber(Config.Exposure.rayOptions) or 4
    )
end

local function readSunRays(tests, boneCount)
    local clearByBone = {}
    for boneIndex = 1, boneCount do
        clearByBone[boneIndex] = 0
    end

    local unresolved = #tests
    local attempts = math.max(1, math.floor(tonumber(Config.Exposure.resultPollFrames) or 20))
    for _ = 1, attempts do
        for index = 1, #tests do
            local test = tests[index]
            if not test.resolved then
                local state, hit = GetShapeTestResult(test.handle)
                if state ~= 1 then
                    test.resolved = true
                    unresolved = unresolved - 1
                    if state ~= 0 and hit ~= true and hit ~= 1 then
                        clearByBone[test.boneIndex] = clearByBone[test.boneIndex] + 1
                    end
                end
            end
        end

        if unresolved <= 0 then break end
        Wait(0)
    end

    return clearByBone
end


local function evaluateExposure(ped)
    if not Config.Enabled then return false, 'disabled', 0.0, 0 end
    if not runtime.vampire then return false, 'not_vampire', 0.0, 0 end
    if runtime.protected then return false, 'protected', 0.0, 0 end
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false, 'dead', 0.0, 0 end
    if Config.Exposure.ignoreWater and IsEntityInWater(ped) then return false, 'water', 0.0, 0 end

    if Config.Exposure.ignoreInteriors and GetInteriorFromEntity(ped) ~= 0 then
        return false, 'interior', 0.0, 0
    end

    local sunDirection, daylightStrength = getSunDirectionAndStrength()
    if not sunDirection then return false, 'night', 0.0, 0 end

    if Config.Exposure.useShelterNative and IsPedSheltered then
        local ok, sheltered = pcall(IsPedSheltered, ped)
        if ok and sheltered then
            return false, 'sheltered', daylightStrength, 0
        end
    end

    local weatherStrength, weatherName = getWeatherStrength()
    local totalStrength = daylightStrength * weatherStrength
    runtime.lastWeather = weatherName

    if totalStrength < (tonumber(Config.Daylight.minimumStrength) or 0.20) then
        return false, 'weak_sun', totalStrength, 0
    end

    local clearSamples = 0
    local sampleBones = Config.Exposure.sampleBones or {}
    local directions = getSunDirections(sunDirection)
    local tests = {}

    for boneIndex = 1, #sampleBones do
        local origin = GetPedBoneCoords(ped, sampleBones[boneIndex], 0.0, 0.0, 0.0)
        for directionIndex = 1, #directions do
            tests[#tests + 1] = {
                handle = startSunRay(ped, origin, directions[directionIndex]),
                boneIndex = boneIndex,
            }
        end
    end

    local clearByBone = readSunRays(tests, #sampleBones)
    local directionAgreement = clamp(
        tonumber(Config.Exposure.minimumDirectionAgreement) or 0.60,
        0.0,
        1.0
    )
    local requiredDirections = math.max(1, math.ceil(#directions * directionAgreement))

    for boneIndex = 1, #sampleBones do
        if clearByBone[boneIndex] >= requiredDirections then
            clearSamples = clearSamples + 1
            if clearSamples >= math.max(1, tonumber(Config.Exposure.minimumClearSamples) or 1) then
                return true, 'direct_sun_consensus', totalStrength, clearSamples
            end
        end
    end

    return false, 'shade', totalStrength, clearSamples
end

local function updateDayWeakness()
    local weakness = Config.DayWeakness or {}
    local daytime = isDaytime()
    local protected = runtime.protected and (
        weakness.protectionBlocks == true
        or runtime.protection and runtime.protection.blocksWeakness == true
    )
    local weakened = Config.Enabled and weakness.enabled ~= false and runtime.vampire
        and not protected and ((weakness.applyInShade == true and daytime) or runtime.exposed)

    runtime.daytime = daytime
    runtime.weakened = weakened == true
    setLocalState('obSunDaytime', runtime.daytime)
    setLocalState('obSunWeakened', runtime.weakened)
end

local function startOrMaintainFire(ped, now)
    if not runtime.burning then
        if Config.Burning.useEntityFire then
            StartEntityFire(ped)
        end

        runtime.burning = true
        runtime.lastIgniteAt = now
        runtime.lastDamageAt = now
        setLocalState('obSunBurning', true)
        notify(Config.Burning.startMessage, 'error')
        return
    end

    local reigniteInterval = math.max(250, tonumber(Config.Burning.reigniteIntervalMs) or 900)
    if Config.Burning.useEntityFire and now - runtime.lastIgniteAt >= reigniteInterval then
        if not IsEntityOnFire(ped) then
            StartEntityFire(ped)
        end
        runtime.lastIgniteAt = now
    end

    local damage = math.max(0, math.floor(tonumber(Config.Burning.additionalDamage) or 0))
    local damageInterval = math.max(250, tonumber(Config.Burning.damageIntervalMs) or 1000)
    if damage > 0 and now - runtime.lastDamageAt >= damageInterval then
        ApplyDamageToPed(ped, damage, false)
        runtime.lastDamageAt = now
    end
end

local function handleExposure(ped, exposed, reason, strength, clearSamples)
    local now = GetGameTimer()
    runtime.lastReason = reason
    runtime.lastStrength = strength or 0.0
    runtime.lastClearSamples = clearSamples or 0

    if exposed then
        runtime.shadeStartedAt = 0

        if not runtime.exposed then
            runtime.exposed = true
            runtime.exposureStartedAt = now
            setLocalState('obSunExposed', true)
        end

        local baseDelay = math.max(0, tonumber(Config.Exposure.exposureDelayMs) or 1600)
        local delay = baseDelay / clamp(strength or 1.0, 0.05, 1.0)
        if now - runtime.exposureStartedAt >= delay then
            startOrMaintainFire(ped, now)
        end
        return
    end

    if not runtime.exposed and not runtime.burning then return end

    if runtime.shadeStartedAt == 0 then
        runtime.shadeStartedAt = now
    end

    local grace = math.max(0, tonumber(Config.Exposure.shadeGraceMs) or 550)
    if now - runtime.shadeStartedAt >= grace then
        stopResourceFire(reason)
    end
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    while true do
        refreshStatus()
        Wait(math.max(1000, tonumber(Config.Protection.refreshIntervalMs) or 4000))
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if runtime.ped ~= ped then
            if runtime.burning and runtime.ped ~= 0 and DoesEntityExist(runtime.ped) then
                StopEntityFire(runtime.ped)
            end
            runtime.ped = ped
            runtime.exposed = false
            runtime.burning = false
            runtime.exposureStartedAt = 0
            runtime.shadeStartedAt = 0
            setLocalState('obSunExposed', false)
            setLocalState('obSunBurning', false)
        end

        local exposed, reason, strength, clearSamples = evaluateExposure(ped)
        handleExposure(ped, exposed, reason, strength, clearSamples)
        updateDayWeakness()
        Wait(math.max(100, tonumber(Config.Exposure.checkIntervalMs) or 400))
    end
end)

local statusRefreshQueued = false

local function requestStatusRefresh()
    if statusRefreshQueued then return end
    statusRefreshQueued = true

    SetTimeout(150, function()
        CreateThread(function()
            refreshStatus()
            statusRefreshQueued = false
        end)
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', requestStatusRefresh)
RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey then requestStatusRefresh() end
end)
RegisterNetEvent('classeSelector:classChanged', requestStatusRefresh)
RegisterNetEvent('classeSelector:classChosenSuccess', requestStatusRefresh)

AddEventHandler('ox_inventory:itemCount', function(itemName)
    if protectionItemNames[itemName] then
        requestStatusRefresh()
    end
end)

AddEventHandler('ox_inventory:equipmentChanged', function()
    requestStatusRefresh()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if runtime.burning and runtime.ped ~= 0 and DoesEntityExist(runtime.ped) then
        StopEntityFire(runtime.ped)
    end
    setLocalState('obSunDaytime', false)
    setLocalState('obSunWeakened', false)
end)

exports('IsSunExposed', function()
    return runtime.exposed, runtime.lastReason, runtime.lastStrength
end)

exports('IsBurningFromSun', function()
    return runtime.burning
end)

exports('IsDaytimeWeakened', function()
    return runtime.weakened, runtime.daytime
end)

exports('RefreshSunProtection', requestStatusRefresh)

if Config.Debug then
    RegisterCommand(Config.DebugCommand or 'solvampiro', function()
        local protection = runtime.protection and runtime.protection.label or 'nenhum'
        lib.notify({
            title = 'Diagnostico solar',
            description = ('Classe: %s | Protecao: %s | Dia: %s | Fraco: %s | Motivo: %s | Sol: %.2f | Raios livres: %d | Clima: %s'):format(
                runtime.vampire and 'vampiro' or 'outra',
                protection,
                runtime.daytime and 'sim' or 'nao',
                runtime.weakened and 'sim' or 'nao',
                runtime.lastReason,
                runtime.lastStrength,
                runtime.lastClearSamples,
                runtime.lastWeather
            ),
            type = 'inform',
            duration = 8000,
        })
    end, false)
end
