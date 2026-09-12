RegisterNetEvent('ob_curandeiras:client:serenity', function()
    ObCurandeiras.CastTreatment({
        abilityId = 'serenidade',
        title = 'Serenidade',
        targetLabel = 'ACALMAR',
        auraKind = 'serenity',
        config = Config.Serenity,
        successMessage = 'Você canaliza quietude sobre o alvo.',
        failureMessage = 'Não foi possível alcançar a mente do alvo.',
    })
end)
