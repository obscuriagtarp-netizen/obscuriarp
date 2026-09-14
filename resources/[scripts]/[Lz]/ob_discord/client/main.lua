local preparing = false

-- Nao decide destino nem revive: apenas carrega a colisao do destino autorizado.
RegisterNetEvent('ob_discord:prepare', function(destination)
    if type(destination) ~= 'table' or preparing then return end
    if type(destination.x) ~= 'number' or type(destination.y) ~= 'number' or type(destination.z) ~= 'number' then return end
    preparing = true
    CreateThread(function()
        local expires = GetGameTimer() + 6000
        while GetGameTimer() < expires do
            RequestCollisionAtCoord(destination.x, destination.y, destination.z)
            Wait(100)
        end
        preparing = false
    end)
end)
