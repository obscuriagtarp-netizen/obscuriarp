Config = {}

Config.Framework = "qbox"

Config.ClassSelector = {
    StartCoords  = vector3(-1746.5,4880.69,9.99),
    StartHeading = 235.28,
    MarkerCoords = vector3(-1703.65, 4850.39, 10.08),
    MarkerRadius = 2.6,
    ViewDistance = 65.0,
    TeleportDelay = 2000,

    Audio = {
        Intro = {
            File = "../audio/sem-rosto-falas-iniciais.ogg",
            Volume = 0.7,
            Timeout = 190000
        }
    },

    DestinationCoords  = vector3(-936.98, -379.33, 37.96),
    DestinationHeading = 113.09,

    Marker = {
        Prompt = "~r~E~s~  SELAR O DESTINO",
        LockedPrompt = "~p~ESCUTE O CHAMADO...",
        PromptHeight = 1.55,
        FxHeight = 0.12,
        FxInterval = 260,
        FxScale = 0.65,
        FxAlpha = 0.92,
        FxColor = { 1.0, 0.04, 0.02 },
        FxAsset = "ob_fogo_vermelho",
        FxName = "ob_fogo_vermelho",
        FallbackAsset = "scr_powerplay",
        FallbackName = "sp_powerplay_beast_appear_trails",
        LightColor = { 255, 30, 18 },
        LightRange = 5.5,
        LightIntensity = 1.2,
    },

    Trail = {
        Enabled = true,
        RenderDistance = 48.0,
        FxInterval = 720,
        FxHeight = 0.18,
        FxScale = 0.2,
        FxAlpha = 0.7,
        FxColor = { 1.0, 0.04, 0.02 },
        FxAsset = "ob_fogo_vermelho",
        FxName = "ob_fogo_vermelho",
        FallbackAsset = "scr_powerplay",
        FallbackName = "sp_powerplay_beast_appear_trails",
        Points = {
            vector3(-1747.2, 4877.96, 8.95),
            vector3(-1745.52, 4876.73, 8.95),
            vector3(-1743.82, 4875.58, 8.95),
            vector3(-1742.09, 4874.37, 8.95),
            vector3(-1740.39, 4873.24, 8.95),
            vector3(-1738.73, 4872.07, 8.95),
            vector3(-1737.03, 4870.92, 8.96),
            vector3(-1735.38, 4869.83, 8.96),
            vector3(-1733.64, 4868.59, 8.96),
            vector3(-1731.95, 4867.42, 8.96),
            vector3(-1730.18, 4866.17, 8.96),
            vector3(-1728.77, 4864.86, 8.95),
            vector3(-1728.52, 4862.42, 8.93),
            vector3(-1727.18, 4859.87, 8.93),
            vector3(-1723.57, 4857.75, 8.93),
            vector3(-1719.88, 4858.12, 8.93),
            vector3(-1716.9, 4856.63, 8.94),
            vector3(-1715.35, 4855.62, 8.94),
            vector3(-1713.37, 4854.24, 8.94),
            vector3(-1711.62, 4853.06, 8.93),
            vector3(-1710.01, 4851.96, 8.93),
            vector3(-1708.41, 4850.88, 8.92),
            vector3(-1706.59, 4849.56, 8.92),
            vector3(-1728.81, 4863.75, 8.93),
            vector3(-1727.91, 4861.17, 8.93),
            vector3(-1726.15, 4858.75, 8.93),
            vector3(-1721.55, 4857.69, 8.93),
            vector3(-1718.53, 4857.68, 8.94),
            vector3(-1724.84, 4857.88, 8.93),
            vector3(-1744.32, 4882.09, 8.94),
            vector3(-1742.59, 4880.88, 8.92),
            vector3(-1740.8, 4879.71, 8.92),
            vector3(-1739.14, 4878.61, 8.92),
            vector3(-1737.44, 4877.48, 8.92),
            vector3(-1735.76, 4876.27, 8.92),
            vector3(-1734.02, 4875.06, 8.92),
            vector3(-1732.42, 4873.93, 8.92),
            vector3(-1730.74, 4872.8, 8.92),
            vector3(-1728.99, 4871.55, 8.92),
            vector3(-1727.35, 4870.28, 8.92),
            vector3(-1725.73, 4869.14, 8.93),
            vector3(-1724.66, 4869.29, 8.93),
            vector3(-1723.3, 4869.66, 8.93),
            vector3(-1721.62, 4869.55, 8.93),
            vector3(-1720.24, 4869.34, 8.93),
            vector3(-1718.86, 4868.6, 8.93),
            vector3(-1717.76, 4867.66, 8.93),
            vector3(-1717.19, 4866.72, 8.93),
            vector3(-1716.51, 4864.81, 8.93),
            vector3(-1716.38, 4862.96, 8.93),
            vector3(-1715.42, 4862.0, 8.92),
            vector3(-1713.84, 4860.81, 8.92),
            vector3(-1712.28, 4859.69, 8.92),
            vector3(-1710.55, 4858.44, 8.92),
            vector3(-1708.85, 4857.24, 8.92),
            vector3(-1707.17, 4856.02, 8.92),
            vector3(-1705.48, 4854.9, 8.92),
            vector3(-1703.85, 4853.68, 8.92),
        },
    },

    EnableTestCommand = true
}

Config.Database = {
    AutoCreate = true,
    TableName = "classe_selector"
}

Config.Qbox = {
    MetadataKey = "classe",
    SaveMetadata = true,
    PreventChangingClass = true
}

Config.Commands = {
    ChangeClass = "darclasse",
    CurrentClass = "minhaclasse",
    AdminPermission = "group.admin"
}

Config.Classes = {
    {
        id = "bruxa",
        label = "Bruxa",
        description = "Mestre dos feitiços e da manipulação das forças ocultas.",
        image = "img/class-bruxa.png",
        card = "img/class-card-bruxa.png",
        panel = "img/class-panel-bruxa.png",
        audio = "../audio/classes/bruxa.ogg",
        audioVolume = 0.7,
        affinity = "Magia",
        weakness = "Fogo"
    },
    {
        id = "vampiro",
        label = "Vampiro",
        description = "Criatura imortal que caminha entre a luz e a escuridão.",
        image = "img/class-vampiro.png",
        card = "img/class-card-vampiro.png",
        panel = "img/class-panel-vampiro.png",
        audio = "../audio/classes/vampiro.ogg",
        audioVolume = 0.7,
        affinity = "Sangue",
        weakness = "Luz"
    },
    {
        id = "curandeira",
        label = "Curandeira",
        description = "Guardiã da vida, especialista em cura e regeneração.",
        image = "img/class-curandeira.png",
        card = "img/class-card-curandeira.png",
        panel = "img/class-panel-curandeira.png",
        audio = "../audio/classes/curandeira.ogg",
        audioVolume = 0.7,
        affinity = "Cura",
        weakness = "Veneno"
    },
    {
        id = "humano",
        label = "Humano",
        description = "Mortal treinado para sobreviver ao sobrenatural com preparo, coragem e instinto.",
        image = "img/class-humano.png",
        card = "img/class-card-humano.png",
        panel = "img/class-panel-humano.png",
        audio = "../audio/classes/humano.ogg",
        audioVolume = 0.7,
        affinity = "Versatilidade",
        weakness = "Fragilidade"
    }
}
