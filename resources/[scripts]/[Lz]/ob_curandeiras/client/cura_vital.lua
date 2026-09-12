RegisterNetEvent('ob_curandeiras:client:vitalHeal', function()
    ObCurandeiras.CastTreatment({
        abilityId = 'cura_vital',
        title = 'Cura Vital',
        targetLabel = 'CURAR',
        auraKind = 'heal',
        config = Config.VitalHeal,
        requireInjured = true,
        successMessage = 'A energia vital começa a restaurar o alvo.',
        failureMessage = 'A cura não encontrou o alvo.',
    })
end)
