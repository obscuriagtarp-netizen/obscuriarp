RegisterNetEvent('ob_curandeiras:client:stopBleeding', function()
    ObCurandeiras.CastTreatment({
        abilityId = 'estancar',
        title = 'Estancar Sangramento',
        targetLabel = 'ESTANCAR',
        auraKind = 'bleeding',
        config = Config.StopBleeding,
        successMessage = 'Os tecidos do alvo começam a se regenerar.',
        failureMessage = 'Não foi possível tratar o alvo.',
    })
end)
