Locale = 'en'

Locales = {
    ["en"] = {
        ["test"] = "Teste"
    },
    ["fr"] = {
        ["test"] = "Tést"
    }
}

function _L(key)
    if Locales[Locale] == nil then
        return "Locale not found"
    end

    if Locales[Locale][key] == nil then
        return "Key not found"
    end

    return Locales[Locale][key]
end