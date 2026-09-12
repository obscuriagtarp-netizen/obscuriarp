local IsPedFalling = IsPedFalling
local IsPedJumping = IsPedJumping
local IsAimCamActive = IsAimCamActive
local SetPedMaxMoveBlendRatio = SetPedMaxMoveBlendRatio
local IsPedUsingActionMode = IsPedUsingActionMode
local SetPedUsingActionMode = SetPedUsingActionMode
local SetPedCanPlayAmbientAnims = SetPedCanPlayAmbientAnims
local DisableFirstPersonCamThisFrame = DisableFirstPersonCamThisFrame

PlayerState.stance = 0

-- Impede conflito entre agachar e os controles nativos.
local function disableStanceControls()
    DisableControlAction(0, 36, true)
    DisableControlAction(0, 26, true)
    lib.disableControls:Add({ 36, 26 })

    CreateThread(function()
        while IsDisabledControlPressed(0, 36)
            or IsDisabledControlPressed(0, 26)
        do
            Wait(0)
            lib.disableControls()
        end

        lib.disableControls:Remove({ 36, 26 })
    end)
end

local function resetStance()
    PlayerState.stance = 0
end

local function crouchLoop()
    lib.requestAnimSet('move_ped_crouched')

    SetPedStealthMovement(cache.ped, false, 0)
    SetPedMovementClipset(cache.ped, 'move_ped_crouched', 1.0)
    SetPedWeaponMovementClipset(cache.ped, 'move_ped_crouched')
    SetPedStrafeClipset(cache.ped, 'move_ped_crouched_strafing')
    SetPedCanPlayAmbientAnims(cache.ped, false)
    SetPedCanPlayAmbientBaseAnims(cache.ped, false)

    CreateThread(function()
        while PlayerState.stance == 2 do
            Wait(0)

            if cache.vehicle
                or IsPedFalling(cache.ped)
                or IsPedJumping(cache.ped)
            then
                resetStance()
                break
            end

            if IsAimCamActive() then
                SetPedMaxMoveBlendRatio(cache.ped, 0.2)
            end

            if IsPedUsingActionMode(cache.ped) then
                SetPedUsingActionMode(
                    cache.ped,
                    false,
                    -1,
                    'DEFAULT_ACTION'
                )
            end

            SetPedCanPlayAmbientIdles(cache.ped, true, false)
        end

        local walkstyle = PlayerState.walkstyle

        if walkstyle then
            lib.requestAnimSet(walkstyle, 1000)
            SetPedMovementClipset(cache.ped, walkstyle, 1.0)
            RemoveAnimSet(walkstyle)
        else
            ResetPedMovementClipset(cache.ped, 1.0)
        end

        ResetPedWeaponMovementClipset(cache.ped)
        ResetPedStrafeClipset(cache.ped)
        SetPedMaxMoveBlendRatio(cache.ped, 1.0)
        SetPedCanPlayAmbientAnims(cache.ped, true)
        SetPedCanPlayAmbientBaseAnims(cache.ped, true)

        RemoveAnimSet('move_ped_crouched')
    end)
end

AddStateBagChangeHandler('stance', nil, function(_, _, value)
    if value == 2 then
        crouchLoop()
        return
    end

    -- Qualquer outro estado retorna diretamente ao normal.
    SetPedStealthMovement(cache.ped, false, 0)
end)

lib.addKeybind({
    name = 'stanceKey',
    description = locale('crouch'),
    defaultKey = Config.stanceKey,

    onPressed = function()
        if PlayerState.isLimited or cache.vehicle then
            return
        end

        disableStanceControls()

        -- Um toque agacha; o próximo levanta.
        PlayerState.stance = PlayerState.stance == 2 and 0 or 2
    end
})