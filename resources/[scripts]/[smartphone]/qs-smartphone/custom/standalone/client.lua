local framework = {}

function framework:getPlayerData()
    -- your custom function here
    return {

    }
end

function framework:getObject()
    -- your custom function here
    return {}
end

function framework:getIdentifier()
    -- your custom function here
    return LocalPlayer.state.identifier or 'none'
end

function framework:getJobName()
    -- your custom function here
    return 'unemployed'
end

function framework:getJobGrade()
    -- your custom function here
    return 0
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
