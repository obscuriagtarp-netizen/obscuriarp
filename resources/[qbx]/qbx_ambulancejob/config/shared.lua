return {
    checkInCost = 2000, -- Price for using the hospital check-in system
    minForCheckIn = 2, -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    locations = { -- Various interaction points
        duty = {
            vec3(-1007.17, -419.11, 38.62),
            vec3(-254.88, 6324.5, 32.58),
        },
        vehicle = {
            vec4(294.578, -574.761, 43.179, 35.79),
            vec4(-234.28, 6329.16, 32.15, 222.5),
        },
        helicopter = {
            vec4(351.58, -587.45, 74.16, 160.5),
            vec4(-475.43, 5988.353, 31.716, 31.34),
        },
        armory = {}, -- Gerenciado pelo ob_hospital
        roof = {
            vec3(338.54, -583.88, 74.17),
        },
        main = {
            vec3(298.62, -599.66, 43.29),
        },
        stash = {}, -- Gerenciado pelo ob_hospital

        ---@class Bed
        ---@field coords vector4
        ---@field model number

        ---@type table<string, {coords: vector3, checkIn?: vector3|vector3[], beds: Bed[]}>
        hospitals = {
            pillbox = {
                coords = vec3(-1000.0, -431.0, 39.37),
                beds = {
                    {coords = vec4(-1009.81, -432.98, 39.37, 208.75), model = 2117668672},
                    {coords = vec4(-993.64, -424.84, 39.37, 208.6), model = 2117668672},
                    {coords = vec4(-991.42, -429.33, 39.37, 26.8), model = 2117668672},
                    {coords = vec4(-995.18, -431.3, 39.37, 21.39), model = 2117668672},
                    {coords = vec4(-998.86, -433.37, 39.37, 30.48), model = 2117668672},
                    {coords = vec4(-1002.59, -435.06, 39.37, 30.19), model = 2117668672},
                    {coords = vec4(-1006.23, -437.03, 39.37, 26.6), model = 2117668672},
                },
            },
            paleto = {
                coords = vec3(-250, 6315, 32),
                beds = {
                    {coords = vec4(-252.43, 6312.25, 32.34, 313.48), model = 2117668672},
                    {coords = vec4(-247.04, 6317.95, 32.34, 134.64), model = 2117668672},
                    {coords = vec4(-255.98, 6315.67, 32.34, 313.91), model = 2117668672},
                },
            },
            jail = {
                coords = vec3(1761, 2600, 46),
                beds = {
                    {coords = vec4(1761.96, 2597.74, 45.66, 270.14), model = 2117668672},
                    {coords = vec4(1761.96, 2591.51, 45.66, 269.8), model = 2117668672},
                    {coords = vec4(1771.8, 2598.02, 45.66, 89.05), model = 2117668672},
                    {coords = vec4(1771.85, 2591.85, 45.66, 91.51), model = 2117668672},
                },
            },
        },
    },
}
