return {
    discordWebhook = nil, -- Replace nil with your webhook if you chose to use discord logging over ox_lib logging
    minOnDutyLogTimeMinutes = 30,
    formatDateTime = '%m-%d-%Y %H:%M',

    -- While the config boss menu creation still works, it is recommended to use the runtime export instead.
    -- Single menu: { coords = ..., size = ..., rotation = ..., type = ... }
    -- Multiple menus: { { coords = ..., size = ..., rotation = ..., type = ... }, { ... }  }
    ---@alias GroupName string
    ---@type table<GroupName, ZoneInfo|ZoneInfo[]>
    menus = {
        lostmc = {
            {
                coords = vec3(983.69, -90.92, 74.85),
                size = vec3(1.5, 1.5, 1.5),
                rotation = 39.68,
                type = 'gang',
            },
            {
                coords = vec3(976.2, -100.57, 74.87),
                size = vec3(1.5, 1.5, 1.5),
                rotation = 42.76,
                type = 'gang',
            },
        },

        ambulance = {
            coords = vec3(-1003.19, -418.63, 39.02),
            size = vec3(1.5, 1.5, 1.5),
            rotation = 207.32,
            type = 'job',
        },

        mechanic = {
            coords = vec3(-349.91, -172.49, 38.06),
            size = vec3(1.5, 1.5, 1.5),
            rotation = 207.32,
            type = 'job',
        },

    },
}
