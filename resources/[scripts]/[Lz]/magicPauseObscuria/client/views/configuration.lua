

RegisterNUICallback("openGtaSettings", function(_, cb)
    EnableAllControlActions(0)
    SetNuiFocus(false, false)
    StopScreenEffect("MenuMGIn")

    ActivateFrontendMenu(-1031775802, 0, 0)
    cb('ok')
end)