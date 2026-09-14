local garageMarker = {
    label = 'Garagem',
    previewCommand = 'testgarageicon',
    drawDistance = 10.0,
    height = -0.08,
    size = 0.92,
}

return {
    enableClient = true, -- disable to create your own client interface
    engineOn = true, -- If true, the engine will be on upon taking the vehicle out.
    disableAutoHelmet = true, -- Prevents GTA from automatically equipping a helmet on motorcycles.
    spawnTimeoutMs = 15000, -- Releases the local request if the server cannot deliver the vehicle.
    universalGarages = false, -- CAR garages accept every ground vehicle type.
    debugPoly = false,
    spawnGhost = {
        alpha = 185, -- 0 = invisivel, 255 = totalmente visivel
        collisionRadius = 35.0,
    },
    garageMarker = garageMarker,
    showroom = {
        scenario = 'WORLD_HUMAN_LEANING',
        profiles = {
            car = {
                playerOffset = vec3(1.25, 0.2, 0.05),
                playerHeadingOffset = -90.0,
                alignPedToVehicle = true,
                playerSide = 'right',
                playerSideGap = 0.14,
                playerForwardOffset = 0.25,
                cameraOffset = vec3(4.2, 7.4, 0.72),
                lookAtOffset = vec3(0.05, 0.12, 0.46),
                fov = 40.0,
            },
            air = {
                playerOffset = vec3(-4.4, -2.0, 0.05),
                playerHeadingOffset = -90.0,
                cameraOffset = vec3(0.0, 15.0, 5.0),
                lookAtOffset = vec3(0.0, 0.0, 1.45),
                fov = 48.0,
            },
            sea = {
                playerOffset = vec3(-3.0, -2.0, 1.0),
                playerHeadingOffset = -90.0,
                cameraOffset = vec3(0.0, 11.0, 4.0),
                lookAtOffset = vec3(0.0, 0.0, 1.0),
                fov = 46.0,
            },
        },
    },

    --- called every frame when player is near the garage and there is a separate drop off marker
    ---@param coords vector3
    ---@param radius? number
    drawDropOffMarker = function(coords, radius)
        if not cache.vehicle then return end

        local size = (radius or 1.5) * 2
        local baseSize = 3.0
        local baseOffset = 2.9
        local zOffset = baseOffset
        local hasWater, waterZ = GetWaterHeight(coords.x, coords.y, coords.z)
        local hasNoWaves, waterZNoWaves = GetWaterHeightNoWaves(coords.x, coords.y, coords.z)
        if hasNoWaves and (not hasWater or waterZNoWaves > waterZ) then
            hasWater = true
            waterZ = waterZNoWaves
        end
        local waterSurfaceOffset = 1.0 -- to make sure marker is above water surface
        local drawZ = hasWater and (waterZ - baseSize + waterSurfaceOffset) or (coords.z - zOffset)
        DrawMarker(0, coords.x, coords.y, drawZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, baseSize, 242, 0, 48, 255, false, false, 0, false, nil, nil, false)
    end,

    --- called every frame when player is near the garage to draw the garage marker
    ---@param coords vector3
    ---@param radius? number
    drawGarageMarker = function(coords, radius)
        local playerCoords = GetEntityCoords(cache.ped or PlayerPedId())
        local distance = #(playerCoords - coords)
        if distance > garageMarker.drawDistance then return end

        exports.ob_markers:Draw('garagem', coords, {
            distance = distance,
            drawDistance = garageMarker.drawDistance,
            height = garageMarker.height,
            size = math.max(0.76, math.min((radius or 1.0) * garageMarker.size, 1.05)),
        })
    end,
}
