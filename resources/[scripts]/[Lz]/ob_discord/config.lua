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
        ReconcileSeconds = 300,
    },
    Automatic = {
        Enabled = true,
        -- Apenas diagnostico no registro. Nao impede o resgate com captura.
        BelowWorldZ = -80.0,
        CooldownSeconds = 900,
        -- MLOs subterraneos legitimos: centro e raio (3D).
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
        AppearanceResource = 'illenium-appearance',
        Destinations = {
            inicial = {
                label = 'Local inicial',
                coords = vec4(-939.83, -379.45, 37.96, 115.26),
            },
            hospital = {
                label = 'Hospital',
                coords = vec4(-1027.62, -413.17, 38.62, 37.68),
            },
            praca = {
                label = 'Praça',
                coords = vec4(161.66, -1001.13, 28.35, 161.93),
            },
        },
    },
    BlockedStates = {
        'obscuriaPowerBlocked', 'magicFauna', 'obHypnotized',
        'obInVehicleAttachment', 'obHealerFlight', 'inTrunk', 'intrunk',
    },
}
