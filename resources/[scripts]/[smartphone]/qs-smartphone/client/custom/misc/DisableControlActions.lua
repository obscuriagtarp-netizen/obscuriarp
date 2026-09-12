function DisableControlActions()
    -- Disables mouse actions
    DisableControlAction(0, 18, true)  -- Disable mouse
    DisableControlAction(0, 69, true)  -- Disable mouse
    DisableControlAction(0, 92, true)  -- Disable mouse
    DisableControlAction(0, 106, true) -- Disable mouse
    DisableControlAction(0, 122, true) -- Disable mouse


    -- Disable vehicle weapon and radio
    DisableControlAction(0, 12, true)  -- Disable mouse
    DisableControlAction(0, 13, true)  -- Disable mouse
    DisableControlAction(0, 14, true)  -- Disable mouse
    DisableControlAction(0, 15, true)  -- Disable mouse
    DisableControlAction(0, 16, true)  -- Disable mouse
    DisableControlAction(0, 17, true)  -- Disable mouse
    DisableControlAction(0, 37, true)  -- Disable mouse
    DisableControlAction(0, 81, true)  -- Disable mouse
    DisableControlAction(0, 82, true)  -- Disable mouse
    DisableControlAction(0, 83, true)  -- Disable mouse
    DisableControlAction(0, 84, true)  -- Disable mouse
    DisableControlAction(0, 85, true)  -- Disable mouse
    DisableControlAction(0, 99, true)  -- INPUT_VEH_SELECT_NEXT_WEAPON
    DisableControlAction(0, 100, true) -- INPUT_VEH_SELECT_PREV_WEAPON
    DisableControlAction(0, 115, true) -- INPUT_VEH_SELECT_PREV_WEAPON
    DisableControlAction(0, 116, true) -- INPUT_VEH_SELECT_PREV_WEAPON
    DisableControlAction(0, 261, true) -- INPUT_VEH_SELECT_PREV_WEAPON
    DisableControlAction(0, 262, true) -- INPUT_VEH_SELECT_PREV_WEAPON


    -- Disables mouse look actions
    if not KeepInput then
        DisableControlAction(0, 12, true) -- Disable mouse look
        DisableControlAction(0, 13, true) -- Disable mouse look
        DisableControlAction(0, 1, true)  -- Disable mouse look
        DisableControlAction(0, 2, true)  -- Disable mouse look
        DisableControlAction(0, 3, true)  -- Disable mouse look
        DisableControlAction(0, 4, true)  -- Disable mouse look
        DisableControlAction(0, 5, true)  -- Disable mouse look
        DisableControlAction(0, 6, true)  -- Disable mouse look
    end

    -- Disables melee combat actions
    DisableControlAction(0, 263, true) -- Disable melee
    DisableControlAction(0, 264, true) -- Disable melee
    DisableControlAction(0, 257, true) -- Disable melee
    DisableControlAction(0, 140, true) -- Disable melee
    DisableControlAction(0, 141, true) -- Disable melee
    DisableControlAction(0, 142, true) -- Disable melee
    DisableControlAction(0, 143, true) -- Disable melee

    -- Disables escape and chat actions
    DisableControlAction(0, 177, true) -- Disable escape
    DisableControlAction(0, 200, true) -- Disable escape
    DisableControlAction(0, 202, true) -- Disable escape
    DisableControlAction(0, 322, true) -- Disable escape
    DisableControlAction(0, 245, true) -- Disable chat
    DisableControlAction(0, 199, true) -- Disable chat

    -- Disables aiming and shooting actions
    DisableControlAction(0, 25, true) -- Disable aim
    DisableControlAction(0, 24, true) -- Disable shoot

    -- Disables other specific actions
    DisableControlAction(0, 45, true)  -- Disable Reload (R)
    DisableControlAction(0, 44, true)  -- Disable Cover (Q)
    DisableControlAction(0, 0, true)   -- Disable Camera (V)
    DisableControlAction(0, 26, true)  -- Disable Camera Back (C)
    DisableControlAction(0, 20, true)  -- Disable Z
    DisableControlAction(0, 236, true) -- Disable V

    -- Disables numerical actions
    DisableControlAction(0, 157, true) -- Disable 1
    DisableControlAction(0, 158, true) -- Disable 2
    DisableControlAction(0, 160, true) -- Disable 3
    DisableControlAction(0, 164, true) -- Disable 4
    DisableControlAction(0, 165, true) -- Disable 5
    DisableControlAction(0, 159, true) -- Disable 6
    DisableControlAction(0, 161, true) -- Disable 7
    DisableControlAction(0, 162, true) -- Disable 8
    DisableControlAction(0, 163, true) -- Disable 9

    -- Other specific disablements
    DisableControlAction(0, 73, true) -- Disable X
    DisableControlAction(0, 47, true) -- Disable G
    DisableControlAction(0, 58, true) -- Disable G
    DisableControlAction(0, 74, true) -- Disable H

    -- Disables control action for second player
    DisableControlAction(1, 24, true)  -- Change weapon
    DisableControlAction(1, 69, true)  -- Fire
    DisableControlAction(1, 92, true)  -- Aim
    DisableControlAction(1, 106, true) -- Jump
    DisableControlAction(1, 122, true) -- Sprint
    DisableControlAction(1, 135, true) --  Duck / Cover
    -- ... (continues the list for the second player)
end
