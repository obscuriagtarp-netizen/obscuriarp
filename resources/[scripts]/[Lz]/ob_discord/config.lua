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
    Admin = {
        Enabled = true,
        AllowRevive = true,
        MedicalResource = 'qbx_medical',
        MulticharResource = 'ob_multichar',
        Destinations = {
            inicial = {
                label = 'Local inicial',
                coords = vec4(-540.58, -212.02, 37.65, 208.88),
            },
            hotel = {
                label = 'Hotel Ravenwood',
                coords = vec4(-940.85, -385.03, 39.0, 24.39),
            },
            hospital = {
                label = 'Hospital',
                coords = vec4(-1007.17, -419.11, 38.62, 27.33),
            },
        },
    },
    BlockedStates = {
        'obscuriaPowerBlocked', 'magicFauna', 'obHypnotized',
        'obInVehicleAttachment', 'obHealerFlight', 'inTrunk', 'intrunk',
    },
}
