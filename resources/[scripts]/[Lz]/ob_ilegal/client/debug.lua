local commandName = 'testarminigame'
local testActive = false

local classes = {
    { id = 'humano', label = 'Humano' },
    { id = 'bruxa', label = 'Bruxa' },
    { id = 'vampiro', label = 'Vampiro' },
    { id = 'curandeira', label = 'Curandeira' },
}

local gameTypes = {
    { id = 'atm', label = 'Caixa eletrônico' },
    { id = 'fechadura', label = 'Fechadura' },
    { id = 'cofre', label = 'Cofre' },
    { id = 'saque', label = 'Extração do dinheiro' },
}

local typeAliases = {
    atm = 'atm',
    caixa = 'atm',
    fechadura = 'fechadura',
    lock = 'fechadura',
    cofre = 'cofre',
    vault = 'cofre',
    saque = 'saque',
    loot = 'saque',
    tesouraria = 'saque',
    todos = 'todos',
}

local classAliases = {
    humano = 'humano',
    human = 'humano',
    bruxa = 'bruxa',
    witch = 'bruxa',
    vampiro = 'vampiro',
    vampire = 'vampiro',
    curandeira = 'curandeira',
    healer = 'curandeira',
}

local function notify(description, kind)
    lib.notify({
        title = 'Teste de minigame',
        description = description,
        type = kind or 'inform',
    })
end

local function classLabel(classId)
    for index = 1, #classes do
        if classes[index].id == classId then return classes[index].label end
    end
    return classId
end

local function typeLabel(gameType)
    for index = 1, #gameTypes do
        if gameTypes[index].id == gameType then return gameTypes[index].label end
    end
    return gameType
end

local function playTest(gameType, classId)
    if gameType == 'atm' then
        if classId == 'humano' then
            return ObIlegalAtm and ObIlegalAtm.PlayHumanHack
                and ObIlegalAtm.PlayHumanHack(Config.Classes.humano.duration)
                or false
        end
        return ObIlegalMinigames.Play(classId, Config.Classes[classId].duration)
    end

    if gameType == 'fechadura' then
        return ObIlegalMinigames.PlayType('fechadura', {}, classId)
    end

    if gameType == 'cofre' then
        return ObIlegalMinigames.PlayType('cofre', {}, classId)
    end

    if gameType == 'saque' then
        if classId == 'humano' then
            return ObIlegalMinigames.PlayType('cofre', {}, 'humano')
        end
        return ObIlegalMinigames.Play(classId, Config.Classes[classId].duration)
    end

    return false
end

local function beginTest(gameType, classId, showResult)
    ObIlegalClient.ClearStaleBusy()
    if testActive or LocalPlayer.state.obIlegalBusy == true then
        notify('Já existe um minigame ou uma atividade ilegal em andamento.', 'error')
        return false
    end

    testActive = true
    ObIlegalClient.SetBusy(true)

    CreateThread(function()
        local ok, result = pcall(playTest, gameType, classId)
        ObIlegalClient.SetBusy(false)
        testActive = false

        if not ok then
            print(('[ob_ilegal] Falha no teste %s/%s: %s'):format(gameType, classId, result))
            notify('O minigame encontrou um erro. Consulte o F8.', 'error')
            return
        end

        if showResult ~= false then
            notify(
                ('%s - %s: %s'):format(
                    typeLabel(gameType),
                    classLabel(classId),
                    result == true and 'concluído' or 'cancelado/falhou'
                ),
                result == true and 'success' or 'error'
            )
        end
    end)
    return true
end

local function beginSequence(classId)
    ObIlegalClient.ClearStaleBusy()
    if testActive or LocalPlayer.state.obIlegalBusy == true then
        notify('Já existe um minigame ou uma atividade ilegal em andamento.', 'error')
        return
    end

    local selectedClasses = classes
    if classId then
        selectedClasses = { { id = classId, label = classLabel(classId) } }
    end

    testActive = true
    ObIlegalClient.SetBusy(true)
    CreateThread(function()
        local completed = 0
        local total = #selectedClasses * #gameTypes

        for classIndex = 1, #selectedClasses do
            for typeIndex = 1, #gameTypes do
                local selectedClass = selectedClasses[classIndex]
                local selectedType = gameTypes[typeIndex]
                notify(('%s - %s'):format(selectedType.label, selectedClass.label))

                local ok, result = pcall(playTest, selectedType.id, selectedClass.id)
                if not ok then
                    print(('[ob_ilegal] Falha no teste %s/%s: %s'):format(
                        selectedType.id,
                        selectedClass.id,
                        result
                    ))
                elseif result == true then
                    completed = completed + 1
                end
                Wait(350)
            end
        end

        ObIlegalClient.SetBusy(false)
        testActive = false
        notify(('Sequência finalizada: %d/%d concluídos.'):format(completed, total), 'success')
    end)
end

local function registerMenus()
    for typeIndex = 1, #gameTypes do
        local gameType = gameTypes[typeIndex]
        local options = {}

        for classIndex = 1, #classes do
            local selectedClass = classes[classIndex]
            options[#options + 1] = {
                title = selectedClass.label,
                description = ('Testar %s sem iniciar um roubo'):format(gameType.label:lower()),
                icon = 'flask',
                onSelect = function()
                    beginTest(gameType.id, selectedClass.id, true)
                end,
            }
        end

        lib.registerContext({
            id = ('ob_ilegal_test_%s'):format(gameType.id),
            title = gameType.label,
            menu = 'ob_ilegal_test_main',
            options = options,
        })
    end

    local mainOptions = {}
    for index = 1, #gameTypes do
        local gameType = gameTypes[index]
        mainOptions[#mainOptions + 1] = {
            title = gameType.label,
            description = 'Escolher a variação de classe',
            icon = gameType.id == 'cofre' and 'vault' or 'wand-sparkles',
            menu = ('ob_ilegal_test_%s'):format(gameType.id),
        }
    end
    mainOptions[#mainOptions + 1] = {
        title = 'Testar todos em sequência',
        description = 'Percorre os quatro desafios de todas as classes',
        icon = 'list-check',
        onSelect = function() beginSequence(nil) end,
    }

    lib.registerContext({
        id = 'ob_ilegal_test_main',
        title = 'Minigames do Obscuria',
        options = mainOptions,
    })
end

-- RegisterCommand(commandName, function(_, args)
--     local requestedType = typeAliases[tostring(args[1] or ''):lower()]
--     local requestedClass = classAliases[tostring(args[2] or ''):lower()]

--     if not requestedType then
--         lib.showContext('ob_ilegal_test_main')
--         return
--     end

--     if requestedType == 'todos' then
--         beginSequence(requestedClass)
--         return
--     end

--     requestedClass = requestedClass or classAliases[ObIlegalClient.GetClass()] or 'humano'
--     beginTest(requestedType, requestedClass, true)
-- end, false)

TriggerEvent('chat:addSuggestion', ('/%s'):format(commandName), 'Testa os minigames sem iniciar um roubo.', {
    { name = 'tipo', help = 'atm, fechadura, cofre, saque ou todos' },
    { name = 'classe', help = 'humano, bruxa, vampiro ou curandeira' },
})

registerMenus()

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ObIlegalMinigames.Cancel()
    ObIlegalClient.SetBusy(false)
    testActive = false
end)
