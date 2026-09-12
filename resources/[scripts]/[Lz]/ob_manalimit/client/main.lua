local snapshot = {
    success = false,
    class = nil,
    value = 0,
    max = Config.Max,
    tier = 'stable',
    tierLabel = 'Estavel',
}
local recovering = false

local function applySnapshot(payload)
    if type(payload) ~= 'table' then return false end
    snapshot = payload
    TriggerEvent('ob_manalimit:client:updated', snapshot)
    return true
end

local function refresh(delay)
    CreateThread(function()
        Wait(math.max(0, tonumber(delay) or 0))
        if GetResourceState(GetCurrentResourceName()) ~= 'started' then return end
        local payload = lib.callback.await('ob_manalimit:server:get', false)
        applySnapshot(payload)
    end)
end

local function notify(description, notificationType)
    lib.notify({
        title = 'Excesso sobrenatural',
        description = description,
        type = notificationType or 'inform',
    })
end

local function showStatus()
    local payload = lib.callback.await('ob_manalimit:server:get', false)
    if not applySnapshot(payload) or not payload.success then
        notify('Seu personagem nao possui uma essencia sobrenatural.', 'error')
        return
    end

    notify(('Nivel: %.1f%% | Estado: %s'):format(payload.value or 0, payload.tierLabel or 'Estavel'))
end

local function recover()
    if recovering then
        notify('Voce ja esta tentando conter sua essencia.', 'error')
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        notify('Voce precisa estar vivo e fora de um veiculo.', 'error')
        return
    end

    local result = lib.callback.await('ob_manalimit:server:beginRecovery', false)
    if type(result) ~= 'table' or not result.success then
        local messages = {
            class = 'Sua classe nao possui uma forma de contencao.',
            empty = 'Sua essencia ja esta estavel.',
            busy = 'Uma contencao ja esta em andamento.',
            cooldown = ('Seu corpo ainda precisa de %d minuto(s) antes de outra contencao.'):format(
                math.max(1, math.ceil((tonumber(result and result.cooldown) or 0) / 60))
            ),
            item = 'Voce precisa de sangue de puma para estabilizar sua essencia.',
        }
        notify(messages[result and result.reason] or 'Nao foi possivel iniciar a contencao.', 'error')
        return
    end

    recovering = true
    local progress = {
        duration = result.duration,
        label = result.label or 'Contendo a essencia...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
    }
    if result.scenario then
        progress.anim = { scenario = result.scenario }
    elseif type(result.anim) == 'table' then
        progress.anim = result.anim
    end

    local completed = lib.progressCircle(progress)
    recovering = false
    if not completed then
        TriggerServerEvent('ob_manalimit:server:cancelRecovery', result.token)
        notify('A contencao foi interrompida.', 'error')
        return
    end

    local finished = lib.callback.await('ob_manalimit:server:finishRecovery', false, result.token)
    if type(finished) ~= 'table' or not finished.success then
        notify('A contencao nao conseguiu estabilizar sua essencia.', 'error')
        return
    end

    applySnapshot(finished.snapshot)
    notify(('Sua essencia recuou %.0f pontos.'):format(finished.reduced or 0), 'success')
end

RegisterNetEvent('ob_manalimit:client:update', applySnapshot)

RegisterNetEvent('ob_manalimit:client:consequence', function(data)
    if type(data) ~= 'table' then return end

    local ped = PlayerPedId()
    local outcome = tostring(data.outcome or 'failure')
    notify(data.description or 'Sua essencia interrompeu a habilidade.', outcome == 'failure' and 'warning' or 'error')
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', outcome == 'catastrophe' and 0.7 or 0.25)

    if outcome == 'failure' then
        AnimpostfxPlay('FocusOut', 0, false)
        Wait(350)
        AnimpostfxStop('FocusOut')
        return
    end

    local coords = GetEntityCoords(ped)
    AnimpostfxPlay(data.class == 'vampiro' and 'Rampage' or 'DrugsDrivingOut', 0, false)
    AddExplosion(coords.x, coords.y, coords.z + 0.35, 24, 0.0, true, false, outcome == 'catastrophe' and 0.7 or 0.25)
    SetPedToRagdoll(ped, outcome == 'catastrophe' and 1800 or 800, 2200, 0, false, false, false)

    local totalDamage = math.max(0, math.floor(tonumber(data.damage) or 0))
    local ticks = outcome == 'catastrophe' and 4 or 1
    local damagePerTick = ticks > 0 and math.ceil(totalDamage / ticks) or 0
    for _ = 1, ticks do
        if damagePerTick > 0 and not IsEntityDead(ped) then
            ApplyDamageToPed(ped, damagePerTick, false)
        end
        if ticks > 1 then Wait(900) end
    end

    Wait(500)
    AnimpostfxStop(data.class == 'vampiro' and 'Rampage' or 'DrugsDrivingOut')
end)

exports('GetSnapshot', function()
    return snapshot
end)

local commands = Config.Commands or {}
if commands.status and commands.status ~= '' then
    RegisterCommand(commands.status, showStatus, false)
end
if commands.recover and commands.recover ~= '' then
    RegisterCommand(commands.recover, recover, false)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refresh(500)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(key)
    if key == Config.ClassMetadataKey or key == Config.MetadataKey then refresh(100) end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'qbx_core' then refresh(700) end
end)

CreateThread(function()
    Wait(1200)
    refresh(0)
end)
