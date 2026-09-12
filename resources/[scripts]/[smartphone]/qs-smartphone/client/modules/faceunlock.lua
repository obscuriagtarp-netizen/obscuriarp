local function isWearingMask()
    local component = Config.FaceUnlock.maskComponent
    local threshold = Config.FaceUnlock.minDrawableForMask
    local ped = cache.ped
    if not ped or ped == 0 then return false end
    local drawable = GetPedDrawableVariation(ped, component)
    return drawable >= threshold
end

RegisterNUICallback('phone:faceUnlock:evaluate', function(_, cb)
    local wearingMask = isWearingMask()
    local result = lib.callback.await('phone:faceUnlock:evaluate', false, { wearingMask = wearingMask })
    if type(result) ~= 'table' then
        cb({ ok = false, reason = 'invalid_response' })
        return
    end
    cb(result)
end)
