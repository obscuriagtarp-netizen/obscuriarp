local lessonOpen = false
local activeLesson = nil

RegisterNetEvent('ob_aprendizado:client:useLearningItem', function(data, slot)
    local itemName = type(slot) == 'table' and slot.name
        or (type(data) == 'table' and data.name or data)

    if itemName then
        TriggerServerEvent('ob_aprendizado:server:useLearningItem', itemName)
    end
end)

local function closeLesson()
    lessonOpen = false
    activeLesson = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

CreateThread(function()
    Wait(100)
    closeLesson()
end)

RegisterNetEvent('ob_aprendizado:client:startLesson', function(payload)
    if type(payload) ~= 'table' or not payload.token or not payload.spell then return end

    lessonOpen = true
    activeLesson = payload
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', lesson = payload })
end)

RegisterNetEvent('ob_aprendizado:client:lessonResult', function(payload)
    if not lessonOpen or type(payload) ~= 'table' then return end

    SendNUIMessage({ action = 'result', success = payload.success == true, reason = payload.reason })
end)

RegisterNetEvent('ob_aprendizado:client:learningError', function(reason)
    local messages = {
        spell = 'Este livro nao possui um aprendizado valido.',
        player = 'A Qbox ainda nao carregou os dados do personagem.',
        class = 'Este livro so pode ser estudado por uma bruxa.',
        known = 'Este feitico ja foi aprendido.',
        item = 'O livro de aprendizado nao foi encontrado.',
        busy = 'Finalize o aprendizado atual antes de abrir outro livro.',
    }

    lib.notify({
        title = 'Aprendizado runico',
        description = messages[reason] or 'Nao foi possivel iniciar o aprendizado.',
        type = 'error',
    })
end)

RegisterNUICallback('completeLesson', function(data, cb)
    if not lessonOpen or not activeLesson then
        cb({ ok = false })
        return
    end

    TriggerServerEvent(
        'ob_aprendizado:server:completeLesson',
        activeLesson.token,
        activeLesson.spell,
        tonumber(data and data.elapsed) or 0
    )
    cb({ ok = true })
end)

RegisterNUICallback('cancelLesson', function(_, cb)
    if activeLesson then
        TriggerServerEvent('ob_aprendizado:server:cancelLesson', activeLesson.token)
    end

    closeLesson()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)

exports('IsLessonOpen', function()
    return lessonOpen
end)
