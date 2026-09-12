local pendingRaspCallbacks = {}

local function makeToken()
    return tostring(GetGameTimer()) .. tostring(math.random(111111, 999999))
end

RegisterNUICallback("playRaspadinha", function(data, cb)
    local token = makeToken()
    pendingRaspCallbacks[token] = cb

    local cardIndex = data and data.card or 1
    TriggerServerEvent("magicPause:raspadinha:play", token, cardIndex)
end)

RegisterNUICallback("getRaspadinhaStatus", function(data, cb)
    local token = makeToken()
    pendingRaspCallbacks[token] = cb

    TriggerServerEvent("magicPause:raspadinha:getStatus", token)
end)

RegisterNetEvent("magicPause:raspadinha:playResult", function(token, result)
    local cb = pendingRaspCallbacks[token]
    if not cb then return end

    pendingRaspCallbacks[token] = nil
    cb(result or { ok = false, message = "Erro inesperado." })
end)

RegisterNetEvent("magicPause:raspadinha:statusResult", function(token, result)
    local cb = pendingRaspCallbacks[token]
    if not cb then return end

    pendingRaspCallbacks[token] = nil
    cb(result or { playedToday = false })
end)

