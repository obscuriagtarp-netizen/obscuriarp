local activeBlinkVisuals = {}
local blinkSequence = 0

local function stopBlinkVisual(source)
    if not activeBlinkVisuals[source] then return end

    activeBlinkVisuals[source] = nil
    TriggerClientEvent("magic:client:blinkVisual", -1, source, false)
end

RegisterNetEvent("magic:server:blinkVisual", function(active, charge, duration)
    local source = source
    if not MagicServer.GetCitizenId(source) then return end

    if active ~= true then
        stopBlinkVisual(source)
        return
    end

    blinkSequence = blinkSequence + 1
    local token = blinkSequence
    local safeCharge = math.max(0.0, math.min(1.0, tonumber(charge) or 1.0))
    local safeDuration = math.max(500, math.min(6500, math.floor(tonumber(duration) or 1800)))

    activeBlinkVisuals[source] = token
    TriggerClientEvent(
        "magic:client:blinkVisual",
        -1,
        source,
        true,
        safeCharge,
        safeDuration
    )

    SetTimeout(safeDuration + 1200, function()
        if activeBlinkVisuals[source] == token then
            stopBlinkVisual(source)
        end
    end)
end)

AddEventHandler("playerDropped", function()
    stopBlinkVisual(source)
end)
