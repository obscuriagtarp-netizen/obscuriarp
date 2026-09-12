local framework = {}

local vRP
local vRPserver
local IS_VRP2 = false

PlayerData = PlayerData or {}

--- Load vRP utils.lua into this resource context so module() is available.
local function ensureVRPModule()
    if module then
        return true
    end

    local utils = LoadResourceFile('vrp', 'lib/utils.lua')
    if not utils then
        return false
    end

    local chunk, err = load(utils, '@vrp/lib/utils.lua')
    if not chunk then
        print(('^1[qs-smartphone]^7 Failed to load vRP utils: %s'):format(err or 'unknown'))
        return false
    end

    chunk()
    return module ~= nil
end

local function initVRP()
    if vRP then
        return true
    end

    if not ensureVRPModule() then
        error('[qs-smartphone] vRP resource is required. Ensure "vrp" is started before qs-smartphone.', 0)
    end

    local Proxy = module('vrp', 'lib/Proxy')
    local Tunnel = module('vrp', 'lib/Tunnel')

    vRP = Proxy.getInterface('vRP')
    vRPserver = Tunnel.getInterface('vRP', 'qs-smartphone')

    IS_VRP2 = type(vRP.users_by_source) == 'table'
        or type(vRP.EXT) == 'table'
        or (type(vRP.getUserId) ~= 'function' and type(vRP.users) == 'table')

    print(('^2[qs-smartphone]^7 vRP client adapter loaded (%s).'):format(IS_VRP2 and 'vRP 2.x' or 'vRP 1.x'))
    return true
end

local function refreshPlayerData()
    local identifier = LocalPlayer.state.identifier or LocalPlayer.state.vrp_user_id
    if identifier then
        identifier = tostring(identifier)
    end

    PlayerData = {
        identifier = identifier,
        job = {
            name = PlayerData.job and PlayerData.job.name or 'unemployed',
            grade = PlayerData.job and PlayerData.job.grade or 0,
        },
    }
end

local function setJobFromServer(jobName, grade)
    PlayerData.job = {
        name = jobName or 'unemployed',
        grade = grade or 0,
    }
end

-- vRP 1.x
AddEventHandler('vRP:playerSpawn', function()
    Wait(500)
    refreshPlayerData()
end)

-- vRP 2.x
AddEventHandler('characterLoad', function()
    Wait(500)
    refreshPlayerData()
end)

RegisterNetEvent('phone:vrp:syncJob', function(jobName, grade)
    setJobFromServer(jobName, grade)
end)

RegisterNetEvent('phone:playerConnected', function()
    refreshPlayerData()
end)

AddStateBagChangeHandler('identifier', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value then
        PlayerData.identifier = tostring(value)
    end
end)

initVRP()

CreateThread(function()
    Wait(1000)
    refreshPlayerData()
end)

function framework:getPlayerData()
    return PlayerData
end

function framework:getObject()
    return {
        vRP = vRP,
        vRPserver = vRPserver,
        isVRP2 = IS_VRP2,
    }
end

function framework:getIdentifier()
    if PlayerData.identifier then
        return PlayerData.identifier
    end
    return tostring(LocalPlayer.state.identifier or LocalPlayer.state.vrp_user_id or 'none')
end

function framework:getJobName()
    return PlayerData.job and PlayerData.job.name or 'unemployed'
end

function framework:getJobGrade()
    return PlayerData.job and PlayerData.job.grade or 0
end

function framework:getPlayers()
    local players = {}
    local active = GetActivePlayers()

    for i = 1, #active do
        local currentPlayer = active[i]
        local ped = GetPlayerPed(currentPlayer)

        if DoesEntityExist(ped) then
            players[#players + 1] = currentPlayer
        end
    end

    return players
end

return framework
