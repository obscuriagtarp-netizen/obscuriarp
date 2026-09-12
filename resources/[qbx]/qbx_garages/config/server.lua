---Represents a function that calculates a fee based on vehicle data.
---
---The function receives a vehicle identifier and a model name,
---retrieves or derives the necessary vehicle information,
---and returns a numeric fee based on custom logic.
---
---@alias FeeCalculator fun(vehicleId: number, modelName: string): number

return {
    autoRespawn = true,   -- True == auto respawn cars that are outside into your garage on script restart, false == does not put them into your garage and players have to go to the impound
    warpInVehicle = true, -- Places the player in the driver's seat when retrieving a vehicle.
    universalGarages = false, -- Mantem carros, barcos e aeronaves em garagens do mesmo tipo.
    retrieveFromAnyGarageOfSameType = true,
    previewBucketBase = 42000,
    doorsLocked = true, -- If true, the doors will be locked upon taking the vehicle out.
    distanceCheck = 5.0, -- The distance that needs to bee clear to let the vehicle spawn, this prevents vehicles stacking on top of each other
    spawnGhost = {
        enabled = true,
        durationMs = 7000,
    },
    calculateImpoundFee = require 'server.default-calculate-impound-fee',
    logging = {
        webhook = {
            error = nil,
            default = nil,
            anticheat = nil,
        },
    },

    ---@class GarageBlip
    ---@field name? string -- Name of the blip. Defaults to garage label.
    ---@field sprite? number -- Sprite for the blip. Defaults to 357
    ---@field color? number -- Color for the blip. Defaults to 3.

    ---The place where the player can access the garage and spawn a car
    ---@class AccessPoint
    ---@field coords vector4 where the garage menu can be accessed from
    ---@field blip? GarageBlip
    ---@field spawn? vector4 where the vehicle will spawn. Defaults to coords
    ---@field dropPoint? vector3 where a vehicle can be stored, Defaults to spawn or coords
    ---@field drawRadius? number draw distance for the garage marker (default: 60)
    ---@field dropDrawRadius? number draw distance for the drop-off marker (default: 60)
    ---@field useRadius? number interaction distance for the garage marker (default: 1)
    ---@field dropUseRadius? number interaction distance for the drop-off marker (default: 1.5)
    ---@field preview? vector4 | table showroom vehicle position or complete vehicle/player/camera setup

    ---@class GarageConfig
    ---@field label string -- Label for the garage
    ---@field type? GarageType -- Optional special type of garage. Currently only used to mark DEPOT garages.
    ---@field vehicleType VehicleType -- Vehicle type
    ---@field groups? string | string[] | table<string, number> job/gangs that can access the garage
    ---@field classes? string | string[] | table<string, boolean> Obscuria class access, using metadata.classe
    ---@field uiClass? string Default presentation category: car, motorcycle, truck, armored, police or vip.
    ---@field vehicleUiClasses? table<string, string> Optional model category overrides for mixed garages.
    ---@field allowedModels? string[] Only these model names can be retrieved from this garage.
    ---@field allowedVehicleClasses? number[] Filter by GTA vehicle class when the vehicle definition exposes it.
    ---@field fixedVehicles? table[] Service vehicles spawned from config instead of the owned fleet.
    ---@field claimFixedVehicle? boolean Reserved for future faction ownership flow.
    ---@field blipOnlyForGroups? boolean Hide the blip unless the player has the garage group.
    ---@field shared? boolean defaults to false. Shared garages give all players with access to the garage access to all vehicles in it. If shared is off, the garage will only give access to player's vehicles which they own.
    ---@field states? VehicleState | VehicleState[] if set, only vehicles in the given states will be retrievable from the garage. Defaults to GARAGED.
    ---@field skipGarageCheck? boolean if true, returns vehicles for retrieval regardless of if that vehicle's garage matches this garage's name
    ---@field canAccess? fun(source: number): boolean checks access as an additional guard clause. Other filter fields still need to pass in addition to this function.
    ---@field accessPoints AccessPoint[]

    ---@type table<string, GarageConfig>

    garages = {
        -- Public Garages
        motelgarage = {
            label = 'Motel Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    blip = {
                        name = 'Garagem Pública',
                        sprite = 357,
                        color = 3,
                    },
                    coords = vec4(-952.06, -385.73, 38.96, 216.52),
                    spawn = vec4(-966.41, -392.65, 37.83, 206.14),
                    preview = vec4(-942.95, -400.51, 38.96, 23.71),
                }
            },
        },
        legionsquareGarage = {
            label = 'Legion Square',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    blip = {
                        name = 'Garagem Pública',
                        sprite = 357,
                        color = 3,
                    },
                    coords = vec4(55.77, -876.3, 30.66, 73.49),
                    spawn = vec4(57.37, -864.87, 30.58, 156.13),
                    preview = vec4(39.02, -871.99, 30.43, 249.22),
                }
            },
        },
        pillboxgarage = {
            label = 'Pillbox',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    blip = {
                        name = 'Garagem Pública',
                        sprite = 357,
                        color = 3,
                    },
                    coords = vec4(213.98, -808.56, 31.01, 334.36),
                    spawn = vec4(223.4, -801.88, 31.65, 68.68),
                    preview = vec4(230.56, -793.5, 30.61, 338.68),
                }
            },
        },
        paletogarage = {
            label = 'Paleto Bay',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    blip = {
                        name = 'Garagem Pública',
                        sprite = 357,
                        color = 3,
                    },
                    coords = vec4(68.13, 6410.67, 30.23 + 1, 211.3),
                    spawn = vec4(63.06, 6402.94, 30.23 + 1, 36.74),
                    preview = vec4(68.06, 6394.23, 30.23 + 1, 218.64),
                }
            },
        },
        parkinggarage = {
            label = 'Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    blip = {
                        name = 'Garagem Pública',
                        sprite = 357,
                        color = 3,
                    },
                    coords = vec4(-746.9, 5547.24, 32.61 + 1, 151.99),
                    spawn = vec4(-755.99, 5547.28, 32.49 + 1, 0.54),
                    preview = vec4(-760.86, 5537.97, 32.48 + 1, 149.2),
                }
            },
        },
        -- intairport = {
        --     label = 'Airport Hangar',
        --     vehicleType = VehicleType.AIR,
        --     accessPoints = {
        --         {
        --             blip = {
        --                 name = 'Hangar',
        --                 sprite = 360,
        --                 color = 3,
        --             },
        --             coords = vec4(-1025.34, -3017.0, 13.95, 331.99),
        --             spawn = vec4(-979.2, -2995.51, 13.95, 52.19),
        --             useRadius = 2.0,
        --             dropUseRadius = 4.0,
        --             drawRadius = 100,
        --             dropDrawRadius = 250,
        --         }
        --     },
        -- },
      
        -- lsymc = {
        --     label = 'LSYMC Boathouse',
        --     vehicleType = VehicleType.SEA,
        --     accessPoints = {
        --         {
        --             blip = {
        --                 name = 'Boathouse',
        --                 sprite = 356,
        --                 color = 3,
        --             },
        --             coords = vec4(-794.64, -1510.89, 1.6, 201.55),
        --             spawn = vec4(-793.58, -1501.4, 0.12, 111.5),
        --             dropUseRadius = 3.0,
        --             dropDrawRadius = 100,
        --         }
        --     },
        -- },

        -- Job Garages
        -- police = {
        --     label = 'Police',
        --     vehicleType = VehicleType.CAR,
        --     groups = 'police',
        --     uiClass = 'police',
        --     blipOnlyForGroups = true,
        --     fixedVehicles = {
        --         { model = 'police', label = 'Viatura de serviço', plate = 'POLICIA' },
        --     },
        --     accessPoints = {
        --         {
        --             blip = {
        --                 name = 'Garagem policial',
        --                 sprite = 357,
        --                 color = 38,
        --             },
        --             coords = vec4(454.6, -1017.4, 28.4, 0),
        --             spawn = vec4(438.4, -1018.3, 27.7, 90.0),
        --             spawns = {
        --                 vec4(438.4, -1018.3, 27.7, 90.0),
        --                 vec4(438.4, -1022.2, 27.7, 90.0),
        --             },
        --         }
        --     },
        -- },

        -- Gang Garages
        -- ballas = {
        --     label = 'Ballas',
        --     vehicleType = VehicleType.CAR,
        --     groups = 'ballas',
        --     accessPoints = {
        --         {
        --             coords = vec4(98.50, -1954.49, 20.84, 0),
        --             spawn = vec4(98.50, -1954.49, 20.75, 335.73),
        --         }
        --     },
        -- },

        -- Impound Lots
        -- impoundlot = {
        --     label = 'Impound Lot',
        --     type = GarageType.DEPOT,
        --     states = { VehicleState.OUT, VehicleState.IMPOUNDED },
        --     skipGarageCheck = true,
        --     vehicleType = VehicleType.CAR,
        --     accessPoints = {
        --         {
        --             blip = {
        --                 name = 'Impound Lot',
        --                 sprite = 68,
        --                 color = 3,
        --             },
        --             coords = vec4(400.45, -1630.87, 29.29, 228.88),
        --             spawn = vec4(407.2, -1645.58, 29.31, 228.28),
        --         }
        --     },
        -- },
    },
}
