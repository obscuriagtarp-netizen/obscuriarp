Config = {
    Destination = vec4(-940.85, -385.03, 39.0, 24.39),
    Profile = {
        Enabled = true,
        ClassMetadataKey = 'classe',
        RunesResource = 'magicPauseObscuria',
        RunesExport = 'GetRunes',
    },
    RoleSync = {
        Enabled = true,
        VipResource = 'ob_vip',
        ClassResource = 'classeSelector',
        ClassMetadataKey = 'classe',
    },
    Automatic = {
        Enabled = true,
        BelowWorldZ = -80.0,
        CooldownSeconds = 900,
        ExcludedZones = {
            -- { coords = vec3(0.0, 0.0, -100.0), radius = 80.0 },
        },
    },
    Staff = { Enabled = true, CustomDestination = true },
    BlockedStates = {
        'obscuriaPowerBlocked', 'magicFauna', 'obHypnotized',
        'obInVehicleAttachment', 'obHealerFlight', 'inTrunk', 'intrunk',
    },
}
