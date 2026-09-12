Locales = {}
while true do
    Citizen.Wait(0)
    if Config then
        break
    end
end

local lang = Config.Language or "en"
local localeFile = ("locales/%s.lua"):format(lang)
local success, localeTable = pcall(function()
    return LoadResourceFile(GetCurrentResourceName(), localeFile)
end)

if success then
    local localeFunc, err = load(localeTable)
    if localeFunc then
        Locales[lang] = localeFunc()
    else
        print("Locale load error: ", err)
    end
else
    print("Failed to load locale file: ", localeFile)
end

function Lang(str, ...)
    local lang = Config.Language or "en"
    local localeTable = Locales[lang]

    if localeTable and localeTable[str] then
        if select("#", ...) > 0 then
            return string.format(localeTable[str], ...)
        else
            return localeTable[str]
        end
    else
        return ('Translation %s not found'):format(str)
    end
end