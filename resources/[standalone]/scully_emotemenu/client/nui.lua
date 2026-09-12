local nuiOpen = false
local favorites = KVP.getTable('obscuria_favorites')
local cachedCategories

local categoryMeta = {
    general_emotes = {
        label = 'Animações',
        description = 'Animações, poses e movimentos do cotidiano.',
        icon = 'sparkles'
    },
    prop_emotes = {
        label = 'Objetos',
        description = 'Animações que utilizam objetos e adereços.',
        icon = 'package'
    },
    consumable_emotes = {
        label = 'Consumo',
        description = 'Comidas, bebidas e pequenos objetos.',
        icon = 'coffee'
    },
    dance_emotes = {
        label = 'Danças',
        description = 'Passos, ritmos e coreografias.',
        icon = 'music'
    },
    synchronized_emotes = {
        label = 'Em dupla',
        description = 'Animações sincronizadas com outra pessoa.',
        icon = 'users'
    },
    synchronized_dance_emotes = {
        label = 'Dança em dupla',
        description = 'Coreografias sincronizadas com outra pessoa.',
        icon = 'users'
    },
    animal_emotes = {
        label = 'Animais',
        description = 'Movimentos exclusivos para formas animais.',
        icon = 'paw'
    }
}

local function isCategoryEnabled(categoryType)
    if categoryType == 'consumable_emotes' then
        return Config.enableConsumableEmotes
    elseif categoryType == 'synchronized_emotes' or categoryType == 'synchronized_dance_emotes' then
        return Config.enableSynchronizedEmotes
    elseif categoryType == 'animal_emotes' then
        return Config.enableAnimalEmotes
    end

    return true
end

local function isEmoteAvailable(emote)
    if emote.Hide then return false end
    if emote.NSFW and Config.enableNSFWEmotes == 'false' then return false end
    if emote.Gang and not Config.enableGangEmotes then return false end
    if emote.SocialMovement and not Config.enableSocialMovementEmotes then return false end
    if emote.Dictionary and not DoesAnimDictExist(emote.Dictionary) then return false end

    if emote.Options and emote.Options.Props then
        for i = 1, #emote.Options.Props do
            if not IsModelValid(joaat(emote.Options.Props[i].Name)) then
                return false
            end
        end
    end

    return true
end

local function makeItem(id, kind, label, command, categoryType, isGroup)
    return {
        id = id,
        kind = kind,
        label = label,
        command = command,
        category = categoryType,
        group = isGroup == true
    }
end

local function buildCategories()
    if cachedCategories then return cachedCategories end

    local categories = {}

    for i = 1, #Emotes do
        local category = Emotes[i]

        if isCategoryEnabled(category.type) then
            local meta = categoryMeta[category.type] or {
                label = category.name,
                description = 'Animações disponíveis nesta coleção.',
                icon = 'sparkles'
            }
            local items = {}

            for k = 1, #category.options do
                local emote = category.options[k]

                if isEmoteAvailable(emote) then
                    items[#items + 1] = makeItem(
                        ('emote:%s:%s'):format(category.type, emote.Command),
                        'emote',
                        emote.Label,
                        emote.Command,
                        category.type,
                        emote.CanGroupEmote or emote.Synchronized
                    )
                end
            end

            if #items > 0 then
                categories[#categories + 1] = {
                    id = category.type,
                    label = meta.label,
                    description = meta.description,
                    icon = meta.icon,
                    items = items
                }
            end
        end
    end

    local walks = {}
    for i = 1, #Walks do
        local walk = Walks[i]
        walks[#walks + 1] = makeItem('walk:' .. walk.Command, 'walk', walk.Label, walk.Command, 'walks')
    end

    categories[#categories + 1] = {
        id = 'walks',
        label = 'Caminhadas',
        description = 'Escolha a postura e o ritmo dos seus passos.',
        icon = 'footprints',
        items = walks
    }

    local scenarios = {}
    for i = 1, #Scenarios do
        local scenario = Scenarios[i]
        scenarios[#scenarios + 1] = makeItem('scenario:' .. scenario.Command, 'scenario', scenario.Label, scenario.Command, 'scenarios')
    end

    categories[#categories + 1] = {
        id = 'scenarios',
        label = 'Cenários',
        description = 'Ações completas integradas ao ambiente.',
        icon = 'clapperboard',
        items = scenarios
    }

    local expressions = {}
    for i = 1, #Expressions do
        local expression = Expressions[i]
        expressions[#expressions + 1] = makeItem('expression:' .. expression.Command, 'expression', expression.Label, expression.Command, 'expressions')
    end

    categories[#categories + 1] = {
        id = 'expressions',
        label = 'Expressões',
        description = 'Humor e expressões faciais persistentes.',
        icon = 'smile',
        items = expressions
    }

    cachedCategories = categories
    return cachedCategories
end

local function sendMenu(action)
    SendNUIMessage({
        action = action or 'open',
        categories = buildCategories(),
        favorites = favorites
    })
end

function CloseMenu()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
exports('closeMenu', CloseMenu)

function ToggleMenu()
    if PlayerState.isLimited then return end

    if nuiOpen then
        CloseMenu()
        return
    end

    nuiOpen = true
    SetNuiFocus(true, true)
    sendMenu('open')
end
exports('toggleMenu', ToggleMenu)

function RegisterMenu()
    if nuiOpen then
        sendMenu('update')
    end
end

local function findEmote(categoryType, command)
    for i = 1, #Emotes do
        local category = Emotes[i]

        if category.type == categoryType then
            for k = 1, #category.options do
                if category.options[k].Command == command then
                    return category.options[k]
                end
            end
        end
    end
end

local function findScenario(command)
    for i = 1, #Scenarios do
        if Scenarios[i].Command == command then
            return Scenarios[i]
        end
    end
end

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    if PlayerState.isLimited then
        cb({ ok = false })
        return
    end

    CloseMenu()

    if data.kind == 'walk' then
        SetWalkByCommand(data.command)
    elseif data.kind == 'expression' then
        SetExpressionByCommand(data.command)
    elseif data.kind == 'scenario' then
        local scenario = findScenario(data.command)
        if scenario then PlayEmote(scenario) end
    elseif data.kind == 'emote' then
        local emote = findEmote(data.category, data.command)
        if emote then PlayEmote(emote) end
    end

    cb({ ok = true })
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    if type(data.id) ~= 'string' or data.id == '' then
        cb({ ok = false, favorites = favorites })
        return
    end

    if favorites[data.id] then
        favorites[data.id] = nil
    else
        favorites[data.id] = true
    end

    KVP.update('obscuria_favorites', favorites)
    cb({ ok = true, favorites = favorites })
end)

RegisterNUICallback('cancel', function(_, cb)
    CancelEmote()
    ResetWalk()
    ResetExpression()
    CloseMenu()
    cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
    if nuiOpen then
        sendMenu('open')
    else
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
    cb({ ok = true })
end)

RegisterNetEvent('scully_emotemenu:toggleMenu', ToggleMenu)
RegisterNetEvent('scully_emotemenu:closeMenu', CloseMenu)

for i = 1, #Config.menuCommands do
    Utils.addCommand(Config.menuCommands[i], {
        help = locale('open_emote_menu')
    }, ToggleMenu)
end

if Config.menuKeybind ~= '' and #Config.menuCommands > 0 then
    RegisterKeyMapping(Config.menuCommands[1], locale('open_emote_menu'), 'keyboard', Config.menuKeybind)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    SetNuiFocus(false, false)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)
