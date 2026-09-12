Config = {}

-- Verifica veiculos carregados localmente sem executar trabalho a cada frame.
Config.ScanInterval = 2500
Config.CurrentVehicleInterval = 400
Config.RestoreOnStop = true
Config.Debug = false

-- multiply usa o valor original do GTA como base.
-- set substitui o campo por um valor absoluto.
-- Evite configurar o mesmo campo nas duas listas.
Config.Vehicles = {
    prairie = {
        enabled = true,
        label = 'Bollokan Prairie',

        multiply = {
            fInitialDriveForce = 1.10,
            fDriveInertia = 1.11,
            fInitialDriveMaxFlatVel = 1.12,
            fBrakeForce = 1.10,
            fTractionCurveMax = 1.10,
            fTractionCurveMin = 1.09,
            fLowSpeedTractionLossMult = 0.70,
            fTractionLossMult = 0.90,
            fSteeringLock = 1.03,
            fSuspensionForce = 1.04,
            fSuspensionReboundDamp = 1.04,
        },

        set = {
            -- Exemplo:
            -- fDriveBiasFront = 1.0,
        }
    }
}
