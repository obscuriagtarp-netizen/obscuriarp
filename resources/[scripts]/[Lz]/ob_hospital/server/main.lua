local callCooldowns = {}
local activeStretchers = {}
local patientStretchers = {}
local queuePatientLocks = {}
local queueRepeatCooldowns = {}
local acceptingQueueTicket = false
local databaseReady = false
local treatmentLocks = {}

local function trim(value)
    local text = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return text ~= '' and text or nil
end

local function clip(value, limit)
    local text = trim(value) or ''
    return text:sub(1, limit or 500)
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
end

local function encode(value)
    local ok, result = pcall(json.encode, value or {})
    return ok and result or '{}'
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(tonumber(src))
end

local function medicalTitle(gender)
    local numeric = tonumber(gender)
    if numeric ~= nil then return numeric == 1 and 'Doutora' or 'Doutor' end
    local value = tostring(gender or ''):lower()
    return (value == 'female' or value == 'feminino' or value == 'f' or value == 'mulher' or value == 'woman') and 'Doutora' or 'Doutor'
end

local function playerIdentity(src)
    local player = getPlayer(src)
    if not player then return nil end
    local data = player.PlayerData or {}
    local charinfo = type(data.charinfo) == 'table' and data.charinfo or {}
    local first = trim(charinfo.firstname) or trim(charinfo.name)
    local last = trim(charinfo.lastname) or trim(charinfo.lastName)
    return {
        source = tonumber(src),
        citizenid = trim(data.citizenid) or trim(data.citizenId),
        name = first and last and (first .. ' ' .. last) or first or last or GetPlayerName(src) or ('Cidadão ' .. src),
        medicalTitle = medicalTitle(charinfo.gender or charinfo.sex),
        job = type(data.job) == 'table' and data.job or {}
    }
end

local function jobGrade(job)
    local grade = type(job.grade) == 'table' and job.grade or {}
    return tonumber(grade.level) or tonumber(grade.grade) or tonumber(job.grade) or 0
end

local function isDoctor(src)
    local identity = playerIdentity(src)
    if not identity then return false end
    local job = identity.job
    return (job.name == Config.Job.name or job.type == Config.Job.type) and job.onduty ~= false
end

local function isAdmin(src)
    if src == 0 then return true end
    if Config.AdminAce and IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    for _, permission in ipairs(Config.AdminPermissions or {}) do
        local ok, result = pcall(function()
            return exports.qbx_core:HasPermission(src, permission)
        end)
        if ok and result == true then return true end
        if IsPlayerAceAllowed(src, permission) then return true end
    end
    return false
end

local function canEditRecords(src)
    if isAdmin(src) then return true end
    local identity = playerIdentity(src)
    if not identity then return false end
    local job = identity.job
    local isHospitalDoctor = (job.name == Config.Job.name or job.type == Config.Job.type) and job.onduty ~= false
    return isHospitalDoctor and jobGrade(job) >= (tonumber(Config.Job.editRecordsGrade) or Config.Job.managerGrade or 4)
end

local function canManageBilling(src)
    if isAdmin(src) then return true end
    local identity = playerIdentity(src)
    if not identity then return false end
    local job = identity.job
    local isHospitalStaff = (job.name == Config.Job.name or job.type == Config.Job.type) and job.onduty ~= false
    return isHospitalStaff and jobGrade(job) >= (tonumber(Config.Job.receptionGrade) or 0)
end

local function canManageStaff(src)
    if isAdmin(src) then return true end
    local identity = playerIdentity(src)
    if not identity then return false end
    local job = identity.job
    return job.name == Config.Job.name
        and job.onduty ~= false
        and jobGrade(job) >= (tonumber(Config.Job.managerGrade) or 4)
end

local function hospitalJobGrades()
    local job = exports.qbx_core:GetJob(Config.Job.name) or {}
    local grades = {}
    for grade, entry in pairs(job.grades or {}) do
        local numericGrade = tonumber(grade)
        if numericGrade then
            grades[#grades + 1] = {
                grade = numericGrade,
                label = trim(entry.name) or ('Grau ' .. numericGrade),
                isBoss = entry.isboss == true
            }
        end
    end
    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return grades
end

local function staffName(row)
    local charinfo = decode(row.charinfo, {})
    local first = trim(charinfo.firstname or charinfo.name)
    local last = trim(charinfo.lastname or charinfo.lastName)
    if first and last then return first .. ' ' .. last end
    return first or last or trim(row.player_name) or tostring(row.citizenid)
end

local function loadHospitalStaff()
    local rows = MySQL.query.await([[
        SELECT pg.citizenid, pg.grade, p.charinfo, p.name AS player_name
        FROM player_groups pg
        LEFT JOIN players p ON p.citizenid = pg.citizenid
        WHERE pg.type = 'job' AND pg.`group` = ?
        ORDER BY pg.grade DESC, p.name ASC
    ]], { Config.Job.name }) or {}
    local grades, gradeMap = hospitalJobGrades(), {}
    for _, entry in ipairs(grades) do gradeMap[entry.grade] = entry end

    local members = {}
    for _, row in ipairs(rows) do
        local grade = math.max(0, math.floor(tonumber(row.grade) or 0))
        local gradeInfo = gradeMap[grade] or { label = 'Grau ' .. grade, isBoss = false }
        local onlinePlayer = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
        local onlineData = onlinePlayer and onlinePlayer.PlayerData or nil
        local onlineJob = onlineData and onlineData.job or {}
        local source = onlineData and tonumber(onlineData.source) or nil
        local identity = source and playerIdentity(source) or nil
        local primary = onlineJob.name == Config.Job.name
        members[#members + 1] = {
            citizenid = tostring(row.citizenid),
            source = source,
            name = identity and identity.name or staffName(row),
            grade = grade,
            role = gradeInfo.label,
            isBoss = gradeInfo.isBoss == true,
            online = onlineData ~= nil,
            primary = primary,
            onDuty = primary and onlineJob.onduty ~= false
        }
    end
    return members, grades
end

local function nearbyHireCandidates(src, members)
    local ped = GetPlayerPed(src)
    if ped <= 0 then return {} end
    local coords = GetEntityCoords(ped)
    local maxDistance = tonumber(Config.Management.hireDistance) or 5.0
    local existing = {}
    for _, member in ipairs(members or {}) do existing[member.citizenid] = true end

    local candidates = {}
    for _, playerId in ipairs(GetPlayers()) do
        local targetSource = tonumber(playerId)
        if targetSource and targetSource ~= src then
            local target = playerIdentity(targetSource)
            local targetPed = GetPlayerPed(targetSource)
            if target and target.citizenid and not existing[target.citizenid] and targetPed > 0 then
                local distance = #(coords - GetEntityCoords(targetPed))
                if distance <= maxDistance then
                    candidates[#candidates + 1] = {
                        source = targetSource,
                        citizenid = target.citizenid,
                        name = target.name,
                        distance = math.floor(distance * 10 + 0.5) / 10
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    return candidates
end

local function managementPayload(src)
    local members, grades = loadHospitalStaff()
    local identity = playerIdentity(src)
    local online, onDuty = 0, 0
    for _, member in ipairs(members) do
        if member.online then online = online + 1 end
        if member.onDuty then onDuty = onDuty + 1 end
    end
    return {
        ok = true,
        staff = members,
        grades = grades,
        candidates = nearbyHireCandidates(src, members),
        summary = { total = #members, online = online, onDuty = onDuty, offline = #members - online },
        actor = {
            citizenid = identity and identity.citizenid or '',
            grade = identity and jobGrade(identity.job) or 0,
            isAdmin = isAdmin(src)
        }
    }
end

local function staffMember(citizenid)
    return MySQL.single.await([[
        SELECT citizenid, grade FROM player_groups
        WHERE citizenid = ? AND type = 'job' AND `group` = ?
        LIMIT 1
    ]], { citizenid, Config.Job.name })
end

local function canChangeStaffMember(src, member, desiredGrade)
    if isAdmin(src) then return true end
    local actor = playerIdentity(src)
    if not actor or actor.citizenid == member.citizenid then return false, 'cannot_manage_self' end
    local actorGrade = jobGrade(actor.job)
    if (tonumber(member.grade) or 0) >= actorGrade then return false, 'manager_hierarchy' end
    if desiredGrade and desiredGrade >= actorGrade then return false, 'manager_hierarchy' end
    return true
end

local function recordManagementActivity(src, action, payload)
    local actor = playerIdentity(src)
    if not actor then return end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
            VALUES (?, ?, ?, ?)
        ]], { actor.citizenid, actor.name, action, encode(payload) })
    end)
end

local function doctorCount()
    local count = exports.qbx_core:GetDutyCountType(Config.Job.type)
    return tonumber(count) or 0
end

local function notify(src, message, kind)
    exports.qbx_core:Notify(src, message, kind or 'inform')
end

local function nearCoords(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if ped <= 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (maxDistance or 5.0)
end

local function billingPlanConfig()
    local plan = Config.Billing.plan or {}
    return {
        enabled = plan.enabled == true,
        name = clip(plan.name, 96) ~= '' and clip(plan.name, 96) or 'Plano hospitalar',
        monthlyPrice = math.max(1, math.floor(tonumber(plan.monthlyPrice) or 5000)),
        intervalDays = math.max(1, math.floor(tonumber(plan.intervalDays) or 30))
    }
end

local function activeSubscription(citizenid)
    if not databaseReady or not citizenid or citizenid == '' then return nil end
    return MySQL.single.await([[
        SELECT * FROM ob_hospital_subscriptions
        WHERE patient_identifier = ? AND status = 'active' AND next_charge_at > NOW()
        LIMIT 1
    ]], { citizenid })
end

local function subscriptionSummaryFromRow(row)
    local plan = billingPlanConfig()
    if not row then
        return { active = false, status = 'none', name = plan.name }
    end
    return {
        active = row.active == true or tonumber(row.active) == 1,
        status = row.status or 'none',
        name = plan.name,
        monthly_price = tonumber(row.monthly_price) or plan.monthlyPrice,
        starts_at = row.starts_at,
        next_charge_at = row.next_charge_at
    }
end

local function attachSubscriptionSummaries(items, identifierKey)
    items = items or {}
    identifierKey = identifierKey or 'citizenid'
    if #items == 0 then return items end

    local identifiers, placeholders, seen = {}, {}, {}
    for _, item in ipairs(items) do
        local identifier = trim(item[identifierKey])
        if identifier and not seen[identifier] then
            seen[identifier] = true
            identifiers[#identifiers + 1] = identifier
            placeholders[#placeholders + 1] = '?'
        end
    end
    if #identifiers == 0 then return items end

    local rows = MySQL.query.await(([=[
        SELECT patient_identifier, status, monthly_price, starts_at, next_charge_at,
               IF(status = 'active' AND next_charge_at > NOW(), 1, 0) AS active
        FROM ob_hospital_subscriptions
        WHERE patient_identifier IN (%s)
    ]=]):format(table.concat(placeholders, ',')), identifiers) or {}
    local byIdentifier = {}
    for _, row in ipairs(rows) do byIdentifier[row.patient_identifier] = row end
    for _, item in ipairs(items) do
        item.plan = subscriptionSummaryFromRow(byIdentifier[item[identifierKey]])
    end
    return items
end

local function subscriptionSummary(citizenid)
    if not databaseReady or not citizenid or citizenid == '' then
        return subscriptionSummaryFromRow(nil)
    end
    local row = MySQL.single.await([[
        SELECT status, monthly_price, starts_at, next_charge_at,
               IF(status = 'active' AND next_charge_at > NOW(), 1, 0) AS active
        FROM ob_hospital_subscriptions
        WHERE patient_identifier = ?
        LIMIT 1
    ]], { citizenid })
    return subscriptionSummaryFromRow(row)
end

local function broadcastSubscription(citizenid)
    local summary = subscriptionSummary(citizenid)
    local _, doctors = exports.qbx_core:GetDutyCountType(Config.Job.type)
    for _, doctorSrc in ipairs(doctors or {}) do
        TriggerClientEvent('ob_hospital:client:subscriptionUpdate', doctorSrc, citizenid, summary)
    end
end

local function depositHospital(amount, reason)
    amount = math.floor(math.abs(tonumber(amount) or 0))
    if amount < 1 then return true end
    local bank = Config.Billing.companyBank or {}
    if bank.provider == 'internal' then return true end
    if bank.provider == 'renewed' then
        local resource = trim(bank.resource) or 'Renewed-Banking'
        if GetResourceState(resource) ~= 'started' then
            print(('[ob_hospital] pagamento recebido, mas %s não está iniciado para o depósito da sociedade.'):format(resource))
            return false
        end
        local ok, err = pcall(function()
            exports[resource]:addAccountMoney(trim(bank.account) or Config.Job.name, amount, reason or 'receita-hospital')
        end)
        if not ok then print(('[ob_hospital] falha ao depositar na sociedade: %s'):format(tostring(err))) end
        return ok
    end
    return true
end

local function removeBank(identifier, amount, reason)
    local ok, removed = pcall(function()
        return exports.qbx_core:RemoveMoney(identifier, 'bank', amount, reason)
    end)
    return ok and removed == true
end

local function medicalPrice(identifier, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if GetResourceState('ob_vip') ~= 'started' then return amount, 0, 0 end

    local ok, finalAmount, discount, percent = pcall(function()
        return exports.ob_vip:CalculateMedicalDiscount(identifier, amount)
    end)
    if not ok then return amount, 0, 0 end
    return math.max(0, math.floor(tonumber(finalAmount) or amount)),
        math.max(0, math.floor(tonumber(discount) or 0)),
        math.max(0, tonumber(percent) or 0)
end

local function patientPlanConfig(identifier)
    local plan = billingPlanConfig()
    local original = plan.monthlyPrice
    plan.monthlyPrice, plan.vipDiscount, plan.vipDiscountPercent = medicalPrice(identifier, original)
    plan.originalMonthlyPrice = original
    return plan
end

local function billingPayload(src)
    local identity = playerIdentity(src)
    if not identity then return nil end
    MySQL.update.await("UPDATE ob_hospital_invoices SET status = 'expired' WHERE status = 'pending' AND expires_at <= NOW()")
    local invoices = MySQL.query.await([[
        SELECT id, public_code, description, amount, status, employee_name, expires_at, created_at
        FROM ob_hospital_invoices
        WHERE patient_identifier = ? AND status = 'pending' AND expires_at > NOW()
        ORDER BY created_at ASC
    ]], { identity.citizenid }) or {}
    local subscription = MySQL.single.await([[
        SELECT id, status, monthly_price, starts_at, next_charge_at, last_charge_at, cancelled_at, created_at
        FROM ob_hospital_subscriptions WHERE patient_identifier = ? LIMIT 1
    ]], { identity.citizenid })
    return {
        ok = true,
        mode = 'billing',
        patient = { name = identity.name, citizenid = identity.citizenid },
        invoices = invoices,
        subscription = subscription,
        plan = patientPlanConfig(identity.citizenid)
    }
end

local function nearbyPatients(src)
    if not canManageBilling(src) then return nil, 'not_authorized' end
    local staffPed = GetPlayerPed(src)
    if staffPed <= 0 then return {}, nil end
    local origin = GetEntityCoords(staffPed)
    local maxDistance = math.max(1.0, tonumber(Config.Billing.nearbyDistance) or 5.0)
    local patients = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target and target ~= src then
            local ped = GetPlayerPed(target)
            if ped > 0 then
                local distance = #(origin - GetEntityCoords(ped))
                if distance <= maxDistance then
                    local identity = playerIdentity(target)
                    if identity then
                        patients[#patients + 1] = {
                            source = target,
                            citizenid = identity.citizenid,
                            name = identity.name,
                            distance = math.floor(distance * 10 + 0.5) / 10
                        }
                    end
                end
            end
        end
    end
    table.sort(patients, function(a, b) return a.distance < b.distance end)
    return attachSubscriptionSummaries(patients), nil
end

local function nearbyPatient(src, targetSource)
    local patients, err = nearbyPatients(src)
    if not patients then return nil, err end
    targetSource = tonumber(targetSource)
    for _, patient in ipairs(patients) do
        if patient.source == targetSource then return patient, nil end
    end
    return nil, 'patient_not_nearby'
end

local function respond(src, token, payload)
    TriggerClientEvent('ob_hospital:client:response', src, token, payload or {})
end

local function requestPlayerRows(query)
    local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players ORDER BY citizenid LIMIT 750') or {}
    local needle = clip(query, 80):lower()
    local patients = {}
    for _, row in ipairs(rows) do
        local info = decode(row.charinfo, {})
        local first = trim(info.firstname) or trim(info.name) or ''
        local last = trim(info.lastname) or trim(info.lastName) or ''
        local name = trim(first .. ' ' .. last) or row.citizenid
        local haystack = (tostring(row.citizenid) .. ' ' .. name):lower()
        if needle == '' or haystack:find(needle, 1, true) then
            patients[#patients + 1] = { citizenid = row.citizenid, name = name }
            if #patients >= 60 then break end
        end
    end
    return attachSubscriptionSummaries(patients)
end

local function ensurePatient(citizenid, name)
    MySQL.update.await([[
        INSERT INTO ob_hospital_patients (citizenid, name)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { citizenid, name })
end

local function patientName(citizenid)
    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if online then
        local identity = playerIdentity(online.PlayerData.source)
        if identity then return identity.name, online.PlayerData.source end
    end
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    if not row then return nil end
    local info = decode(row.charinfo, {})
    local first = trim(info.firstname) or trim(info.name)
    local last = trim(info.lastname) or trim(info.lastName)
    return first and last and (first .. ' ' .. last) or first or last or citizenid, nil
end

local function sanitizeBodyParts(parts)
    local result, seen = {}, {}
    if type(parts) ~= 'table' then return result end
    for _, key in ipairs(parts) do
        key = tostring(key)
        if Config.Triage.bodyParts[key] and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    return result
end

local function sanitizeVitals(vitals)
    vitals = type(vitals) == 'table' and vitals or {}
    return {
        heartRate = clip(vitals.heartRate, 12),
        pressure = clip(vitals.pressure, 16),
        temperature = clip(vitals.temperature, 12),
        oxygen = clip(vitals.oxygen, 12),
        consciousness = clip(vitals.consciousness, 40)
    }
end

local function validPhotoUrl(url)
    url = clip(url, Config.Photos.maxUrlLength)
    if url == '' then return nil end
    for _, protocol in ipairs(Config.Photos.allowedProtocols or {}) do
        if url:sub(1, #protocol):lower() == protocol:lower() then return url end
    end
end

local function sanitizePhotos(photos)
    local result = {}
    if type(photos) ~= 'table' then return result end
    for _, entry in ipairs(photos) do
        if #result >= Config.Photos.maxPerRecord then break end
        local url = validPhotoUrl(type(entry) == 'table' and entry.url or entry)
        if url then
            result[#result + 1] = {
                url = url,
                caption = clip(type(entry) == 'table' and entry.caption or '', 180)
            }
        end
    end
    return result
end

local function severityAllowed(value)
    for _, entry in ipairs(Config.Triage.severities) do
        if entry.value == value then return value end
    end
    return 'stable'
end

local function loadCalls(includeClosed)
    local where = includeClosed and '' or "WHERE status NOT IN ('resolved', 'cancelled')"
    local rows = MySQL.query.await(([=[
        SELECT * FROM ob_hospital_calls %s
        ORDER BY FIELD(priority, 'critical', 'urgent', 'normal', 'low'), created_at ASC
        LIMIT 100
    ]=]):format(where)) or {}
    for _, row in ipairs(rows) do row.coords = decode(row.coords, {}) end
    return rows
end

local function loadClinicalQueue(includeClosed)
    local where = includeClosed and '' or "WHERE status NOT IN ('resolved', 'cancelled')"
    local rows = MySQL.query.await(([=[
        SELECT * FROM ob_hospital_queue %s
        ORDER BY FIELD(status, 'called', 'in_service', 'waiting'),
                 COALESCE(called_at, created_at) ASC, created_at ASC
        LIMIT 150
    ]=]):format(where)) or {}
    return attachSubscriptionSummaries(rows, 'patient_identifier')
end

local function publicQueue()
    local rows = MySQL.query.await([[
        SELECT id, ticket_code, patient_name, status, called_by_name, called_by_title, called_at, created_at
        FROM ob_hospital_queue
        WHERE status IN ('waiting', 'called')
        ORDER BY FIELD(status, 'called', 'waiting'), COALESCE(called_at, created_at) ASC, id ASC
    ]]) or {}
    local result = {}
    for _, ticket in ipairs(rows) do
        result[#result + 1] = {
            id = ticket.id,
            ticket_code = ticket.ticket_code,
            patient_name = ticket.patient_name,
            status = ticket.status,
            called_by_name = ticket.called_by_name,
            called_by_title = ticket.called_by_title,
            called_at = ticket.called_at,
            created_at = ticket.created_at
        }
    end
    return result
end

local function announceQueueTicket(ticket, phase, nonce)
    if not Config.QueueVoice.enabled then return end
    local introduction = phase == 'repeat' and 'Repetindo a chamada. ' or ''
    local title = ticket.called_by_title == 'Doutora' and 'Doutora' or 'Doutor'
    local article = title == 'Doutora' and 'a' or 'o'
    local professional = ticket.called_by_name and ('%s %s %s'):format(article, title, ticket.called_by_name) or 'a equipe médica'
    local announcementId = ('%s:%s:%s'):format(ticket.id, tostring(ticket.called_at), phase)
    if nonce then announcementId = ('%s:%s'):format(announcementId, tostring(nonce)) end
    TriggerClientEvent('ob_hospital:client:queueAnnouncement', -1, {
        id = announcementId,
        phase = phase,
        ticket = {
            id = ticket.id, ticket_code = ticket.ticket_code, patient_name = ticket.patient_name,
            status = 'called', called_by_name = ticket.called_by_name,
            called_by_title = ticket.called_by_title, called_at = ticket.called_at
        },
        message = ('%sSenha %s. %s, dirija-se ao atendimento com %s.'):format(
            introduction, ticket.ticket_code, ticket.patient_name, professional
        )
    })
end

local function panelBootstrap(src)
    local identity = playerIdentity(src)
    local calls = loadCalls(false)
    local queue = loadClinicalQueue(false)
    local metrics = MySQL.single.await([[
        SELECT
            (SELECT COUNT(*) FROM ob_hospital_records WHERE DATE(created_at) = CURDATE()) AS records_today,
            (SELECT COUNT(*) FROM ob_hospital_patients) AS patients,
            (SELECT COUNT(*) FROM ob_hospital_calls WHERE status = 'resolved' AND DATE(resolved_at) = CURDATE()) AS resolved_today
    ]]) or {}
    local recent = MySQL.query.await([[
        SELECT patient_identifier AS citizenid, MAX(patient_name) AS name, MAX(created_at) AS last_visit, COUNT(*) AS records
        FROM ob_hospital_records
        GROUP BY patient_identifier
        ORDER BY last_visit DESC LIMIT 12
    ]]) or {}
    attachSubscriptionSummaries(recent)
    return {
        ok = true,
        mode = 'panel',
        user = {
            name = identity.name,
            citizenid = identity.citizenid,
            grade = jobGrade(identity.job),
            isManager = canManageStaff(src),
            isAdmin = isAdmin(src),
            canEditRecords = canEditRecords(src),
            canManageStaff = canManageStaff(src)
        },
        doctorCount = doctorCount(),
        calls = calls,
        queue = queue,
        metrics = metrics,
        recentPatients = recent,
        severities = Config.Triage.severities,
        bodyPartLabels = Config.Triage.bodyParts,
        billing = {
            plan = billingPlanConfig(),
            maxInvoiceAmount = math.max(1, math.floor(tonumber(Config.Billing.maxInvoiceAmount) or 1000000))
        }
    }
end

local function loadPatient(citizenid)
    local name, onlineSource = patientName(citizenid)
    if not name then return nil end
    ensurePatient(citizenid, name)
    local profile = MySQL.single.await('SELECT * FROM ob_hospital_patients WHERE citizenid = ?', { citizenid }) or {}
    local records = MySQL.query.await([[
        SELECT * FROM ob_hospital_records WHERE patient_identifier = ? ORDER BY created_at DESC LIMIT 100
    ]], { citizenid }) or {}
    for _, record in ipairs(records) do
        record.body_parts = decode(record.body_parts, {})
        record.vitals = decode(record.vitals, {})
        record.photos = decode(record.photos, {})
    end
    local status
    if onlineSource then
        local ok, current = pcall(function() return exports.qbx_medical:GetPlayerStatus(onlineSource) end)
        if ok then status = current end
    end
    return {
        citizenid = citizenid,
        name = name,
        online = onlineSource ~= nil,
        source = onlineSource,
        profile = profile,
        records = records,
        medicalStatus = status,
        plan = subscriptionSummary(citizenid)
    }
end

local function broadcastDispatch(call, isNew)
    local _, doctors = exports.qbx_core:GetDutyCountType(Config.Job.type)
    for _, doctorSrc in ipairs(doctors or {}) do
        TriggerClientEvent('ob_hospital:client:dispatchUpdate', doctorSrc, call, isNew == true)
    end
end

local function expireEmergencyCalls()
    local expirationMinutes = math.max(1, math.floor(tonumber(Config.Dispatch.expirationMinutes) or 15))
    local calls = MySQL.query.await([[
        SELECT * FROM ob_hospital_calls
        WHERE status NOT IN ('resolved', 'cancelled')
          AND created_at <= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { expirationMinutes }) or {}
    for _, call in ipairs(calls) do
        local changed = MySQL.update.await([[
            UPDATE ob_hospital_calls
            SET status = 'cancelled', resolved_at = NOW()
            WHERE id = ? AND status NOT IN ('resolved', 'cancelled')
        ]], { call.id })
        if changed and changed > 0 then
            call.status = 'cancelled'
            call.coords = decode(call.coords, {})
            broadcastDispatch(call, false)
        end
    end
end

local function broadcastQueue()
    local queue = loadClinicalQueue(false)
    local _, doctors = exports.qbx_core:GetDutyCountType(Config.Job.type)
    for _, doctorSrc in ipairs(doctors or {}) do
        TriggerClientEvent('ob_hospital:client:queueUpdate', doctorSrc, queue)
    end
    TriggerClientEvent('ob_hospital:client:queueDisplayUpdate', -1, publicQueue(), Config.Queue.maxPublicEntries)
end

local function finishQueueAnnouncements()
    local tickets = MySQL.query.await([[
        SELECT * FROM ob_hospital_queue
        WHERE status = 'called' AND called_at <= DATE_SUB(NOW(), INTERVAL ? SECOND)
        ORDER BY called_at ASC, id ASC
    ]], { Config.Queue.calledDisplaySeconds }) or {}
    local changed = false
    for _, ticket in ipairs(tickets) do
        local updated = MySQL.update.await([[
            UPDATE ob_hospital_queue SET status = 'in_service', started_at = NOW()
            WHERE id = ? AND status = 'called' AND called_at <= DATE_SUB(NOW(), INTERVAL ? SECOND)
        ]], { ticket.id, Config.Queue.calledDisplaySeconds })
        if updated and updated > 0 then
            changed = true
        end
    end
    if changed then broadcastQueue() end
end

local function ensureQueueTicket(citizenid, name, patientSrc, triaged)
    if queuePatientLocks[citizenid] then return nil, 'queue_busy' end
    queuePatientLocks[citizenid] = true
    local ok, ticket, existing = pcall(function()
        local row = MySQL.single.await([[
            SELECT * FROM ob_hospital_queue
            WHERE patient_identifier = ? AND status NOT IN ('resolved', 'cancelled')
            ORDER BY id DESC LIMIT 1
        ]], { citizenid })
        if row then
            if triaged and row.status == 'awaiting_triage' then
                if patientSrc then
                    MySQL.update.await([[
                        UPDATE ob_hospital_queue SET status = 'waiting', patient_source = ?, patient_name = ?
                        WHERE id = ? AND status = 'awaiting_triage'
                    ]], { patientSrc, name, row.id })
                else
                    MySQL.update.await([[
                        UPDATE ob_hospital_queue SET status = 'waiting', patient_name = ?
                        WHERE id = ? AND status = 'awaiting_triage'
                    ]], { name, row.id })
                end
                row = MySQL.single.await('SELECT * FROM ob_hospital_queue WHERE id = ?', { row.id })
            end
            return row, true
        end
        local status = triaged and 'waiting' or 'awaiting_triage'
        local id
        if patientSrc then
            id = MySQL.insert.await([[
                INSERT INTO ob_hospital_queue (patient_identifier, patient_name, patient_source, status)
                VALUES (?, ?, ?, ?)
            ]], { citizenid, name, patientSrc, status })
        else
            id = MySQL.insert.await([[
                INSERT INTO ob_hospital_queue (patient_identifier, patient_name, status)
                VALUES (?, ?, ?)
            ]], { citizenid, name, status })
        end
        assert(id, 'queue_insert_failed')
        local code = ('%s-%03d'):format(Config.Queue.ticketPrefix or 'A', id)
        MySQL.update.await('UPDATE ob_hospital_queue SET ticket_code = ? WHERE id = ?', { code, id })
        return MySQL.single.await('SELECT * FROM ob_hospital_queue WHERE id = ?', { id }), false
    end)
    queuePatientLocks[citizenid] = nil
    if not ok then error(ticket) end
    broadcastQueue()
    return ticket, existing and 'already_in_queue' or nil
end

local function isPatientUnableToCheckIn(src)
    local player = getPlayer(src)
    if not player then return true end
    local metadata = type(player.PlayerData.metadata) == 'table' and player.PlayerData.metadata or {}
    local state = Player(src).state
    return metadata.isdead == true or metadata.inlaststand == true
        or state.isDead == true or state.dead == true or state.laststand == true
end

local function createQueueTicket(src)
    src = tonumber(src)
    if not nearCoords(src, Config.Points.triage, Config.Queue.checkInDistance) then
        return nil, 'too_far'
    end
    if isPatientUnableToCheckIn(src) then return nil, 'patient_unavailable' end

    local identity = playerIdentity(src)
    if not identity or not identity.citizenid then return nil, 'player_not_found' end
    return ensureQueueTicket(identity.citizenid, identity.name, src, false)
end

local function nextCallCode()
    return ('MED-%04d'):format(math.random(1, 9999))
end

local function createCall(src, reason, priority, coords, automatic)
    src = tonumber(src)
    local now = os.time()
    if not automatic and callCooldowns[src] and now - callCooldowns[src] < Config.CallCooldownSeconds then
        return nil, 'cooldown'
    end
    local identity = playerIdentity(src)
    if not identity then return nil, 'player_not_found' end
    local existing = MySQL.single.await([[
        SELECT id FROM ob_hospital_calls
        WHERE patient_identifier = ? AND status NOT IN ('resolved', 'cancelled')
        ORDER BY id DESC LIMIT 1
    ]], { identity.citizenid })
    if existing then return existing.id, 'already_open' end
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    coords = type(coords) == 'table' and coords or { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
    priority = Config.Dispatch.priorities[priority] and priority or 'normal'
    local code
    repeat
        code = nextCallCode()
    until not MySQL.single.await('SELECT id FROM ob_hospital_calls WHERE public_code = ?', { code })
    local id = MySQL.insert.await([[
        INSERT INTO ob_hospital_calls
            (public_code, patient_identifier, patient_name, patient_source, reason, priority, status, coords)
        VALUES (?, ?, ?, ?, ?, ?, 'waiting', ?)
    ]], { code, identity.citizenid, identity.name, src, clip(reason, 500) ~= '' and clip(reason, 500) or Config.Dispatch.defaultReason, priority, encode(coords) })
    callCooldowns[src] = now
    local call = MySQL.single.await('SELECT * FROM ob_hospital_calls WHERE id = ?', { id })
    call.coords = decode(call.coords, {})
    broadcastDispatch(call, true)
    return id
end

local function createAutomaticRecord(src, title, notes)
    local identity = playerIdentity(src)
    if not identity then return end
    ensurePatient(identity.citizenid, identity.name)
    MySQL.insert.await([[
        INSERT INTO ob_hospital_records
            (patient_identifier, patient_name, medic_identifier, medic_name, record_type, title, notes,
             diagnosis, treatment, severity, body_parts, vitals, photos)
        VALUES (?, ?, 'system', 'Atendente hospitalar', 'automatic', ?, ?, '', 'Tratamento automatizado',
                'stable', '[]', '{}', '[]')
    ]], { identity.citizenid, identity.name, title, notes })
end

local function processSubscriptionRenewals()
    local plan = billingPlanConfig()
    if not plan.enabled then return end
    local subscriptions = MySQL.query.await([[
        SELECT * FROM ob_hospital_subscriptions
        WHERE status = 'active' AND next_charge_at IS NOT NULL AND next_charge_at <= NOW()
        ORDER BY next_charge_at ASC LIMIT 100
    ]]) or {}
    for _, subscription in ipairs(subscriptions) do
        local locked = MySQL.update.await([[
            UPDATE ob_hospital_subscriptions SET status = 'processing'
            WHERE id = ? AND status = 'active' AND next_charge_at <= NOW()
        ]], { subscription.id })
        if tonumber(locked) == 1 then
            local baseAmount = math.max(1, math.floor(tonumber(subscription.monthly_price) or plan.monthlyPrice))
            local amount = medicalPrice(subscription.patient_identifier, baseAmount)
            local paid = removeBank(subscription.patient_identifier, amount, 'renovacao-plano-hospital')
            if paid then
                MySQL.update.await(([=[
                    UPDATE ob_hospital_subscriptions
                    SET status = 'active', last_charge_at = NOW(), next_charge_at = DATE_ADD(NOW(), INTERVAL %d DAY),
                        failure_count = 0
                    WHERE id = ? AND status = 'processing'
                ]=]):format(plan.intervalDays), { subscription.id })
                MySQL.insert.await([[
                    INSERT INTO ob_hospital_billing_transactions
                        (patient_identifier, subscription_id, transaction_type, amount, status, description)
                    VALUES (?, ?, 'subscription', ?, 'paid', ?)
                ]], { subscription.patient_identifier, subscription.id, amount, plan.name })
                depositHospital(amount, 'renovacao-plano-hospital')
                local _, targetSource = patientName(subscription.patient_identifier)
                if targetSource then notify(targetSource, ('%s renovado com sucesso.'):format(plan.name), 'success') end
            else
                MySQL.update.await([[
                    UPDATE ob_hospital_subscriptions
                    SET status = 'past_due', failure_count = failure_count + 1
                    WHERE id = ? AND status = 'processing'
                ]], { subscription.id })
                MySQL.insert.await([[
                    INSERT INTO ob_hospital_billing_transactions
                        (patient_identifier, subscription_id, transaction_type, amount, status, description)
                    VALUES (?, ?, 'subscription', ?, 'failed', ?)
                ]], { subscription.patient_identifier, subscription.id, amount, plan.name })
                local _, targetSource = patientName(subscription.patient_identifier)
                if targetSource then notify(targetSource, 'A renovação do plano hospitalar não foi paga. Regularize na maquininha.', 'error') end
            end
            broadcastSubscription(subscription.patient_identifier)
        end
    end
end

local actions = {}

function actions.availability()
    return { ok = true, doctors = doctorCount(), autoAttendant = doctorCount() == 0 }
end

function actions.bootstrap(src, data)
    local mode = tostring(data.mode or 'panel')
    if mode == 'display' then
        return {
            ok = true,
            mode = 'display',
            queue = publicQueue(),
            displayLimit = Config.Queue.maxPublicEntries
        }
    end
    if mode == 'shop' then
        if doctorCount() > 0 then return { ok = false, error = 'doctors_online' } end
        return { ok = true, mode = 'shop', items = Config.PublicShop, doctors = 0 }
    end
    if mode == 'billing' then
        if not nearCoords(src, Config.Points.billing, Config.Billing.terminalDistance) then
            return { ok = false, error = 'terminal_too_far' }
        end
        return billingPayload(src) or { ok = false, error = 'patient_unavailable' }
    end
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    return panelBootstrap(src)
end

function actions.management(src)
    if not canManageStaff(src) then return { ok = false, error = 'not_manager' } end
    return managementPayload(src)
end

function actions.hireStaff(src, data)
    if not canManageStaff(src) then return { ok = false, error = 'not_manager' } end
    local targetSource = tonumber(data.source)
    local target = targetSource and playerIdentity(targetSource) or nil
    local targetPed = targetSource and GetPlayerPed(targetSource) or 0
    if not target or not target.citizenid or targetPed <= 0 then return { ok = false, error = 'target_player_not_found' } end
    if targetSource == src then return { ok = false, error = 'cannot_manage_self' } end
    if not nearCoords(src, GetEntityCoords(targetPed), tonumber(Config.Management.hireDistance) or 5.0) then
        return { ok = false, error = 'target_not_nearby' }
    end
    if staffMember(target.citizenid) then return { ok = false, error = 'already_staff' } end

    local grade = math.max(0, math.floor(tonumber(Config.Management.initialGrade) or 0))
    local success = exports.qbx_core:AddPlayerToJob(target.citizenid, Config.Job.name, grade)
    if success ~= true then return { ok = false, error = 'job_update_failed' } end
    if Config.Management.setPrimaryJobOnHire == true then
        exports.qbx_core:SetPlayerPrimaryJob(target.citizenid, Config.Job.name)
    end
    recordManagementActivity(src, 'staff_hired', { citizenid = target.citizenid, grade = grade })
    notify(targetSource, 'Você foi contratado pelo Instituto Médico de Obscuria.', 'success')
    notify(src, ('%s foi contratado com sucesso.'):format(target.name), 'success')
    return managementPayload(src)
end

function actions.setStaffGrade(src, data)
    if not canManageStaff(src) then return { ok = false, error = 'not_manager' } end
    local citizenid = clip(data.citizenid, 64)
    local desiredGrade = math.floor(tonumber(data.grade) or -1)
    local member = citizenid ~= '' and staffMember(citizenid) or nil
    if not member then return { ok = false, error = 'member_not_found' } end

    local validGrade = false
    for _, grade in ipairs(hospitalJobGrades()) do
        if grade.grade == desiredGrade then validGrade = true break end
    end
    if not validGrade then return { ok = false, error = 'invalid_grade' } end
    local allowed, reason = canChangeStaffMember(src, member, desiredGrade)
    if not allowed then return { ok = false, error = reason } end

    local success = exports.qbx_core:AddPlayerToJob(citizenid, Config.Job.name, desiredGrade)
    if success ~= true then return { ok = false, error = 'job_update_failed' } end
    recordManagementActivity(src, 'staff_grade_changed', {
        citizenid = citizenid,
        previousGrade = tonumber(member.grade) or 0,
        grade = desiredGrade
    })
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target and target.PlayerData and target.PlayerData.source then
        notify(target.PlayerData.source, 'Seu cargo no Instituto Médico foi atualizado.', 'inform')
    end
    return managementPayload(src)
end

function actions.fireStaff(src, data)
    if not canManageStaff(src) then return { ok = false, error = 'not_manager' } end
    local citizenid = clip(data.citizenid, 64)
    local member = citizenid ~= '' and staffMember(citizenid) or nil
    if not member then return { ok = false, error = 'member_not_found' } end
    local allowed, reason = canChangeStaffMember(src, member)
    if not allowed then return { ok = false, error = reason } end

    local success = exports.qbx_core:RemovePlayerFromJob(citizenid, Config.Job.name)
    if success ~= true then return { ok = false, error = 'job_update_failed' } end
    recordManagementActivity(src, 'staff_fired', { citizenid = citizenid, grade = tonumber(member.grade) or 0 })
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target and target.PlayerData and target.PlayerData.source then
        notify(target.PlayerData.source, 'Você foi desligado do Instituto Médico de Obscuria.', 'inform')
    end
    return managementPayload(src)
end

function actions.joinQueue(src)
    local ticket, err = createQueueTicket(src)
    if not ticket then return { ok = false, error = err } end
    if err == 'already_in_queue' then
        return { ok = true, existing = true, ticket = ticket }
    end
    return { ok = true, existing = false, ticket = ticket }
end

function actions.searchPatients(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    return { ok = true, patients = requestPlayerRows(data.query) }
end

function actions.patient(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    local patient = loadPatient(clip(data.citizenid, 64))
    return patient and { ok = true, patient = patient } or { ok = false, error = 'patient_not_found' }
end

function actions.savePatient(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    local citizenid = clip(data.citizenid, 64)
    local name = patientName(citizenid)
    if not name then return { ok = false, error = 'patient_not_found' } end
    ensurePatient(citizenid, name)
    local photoUrl = validPhotoUrl(data.photoUrl) or ''
    MySQL.update.await([[
        UPDATE ob_hospital_patients
        SET blood_type = ?, allergies = ?, conditions = ?, notes = ?, photo_url = ?
        WHERE citizenid = ?
    ]], {
        clip(data.bloodType, 8), clip(data.allergies, 500), clip(data.conditions, 1000),
        clip(data.notes, 5000), photoUrl, citizenid
    })
    return { ok = true, patient = loadPatient(citizenid) }
end

function actions.createRecord(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    local medic = playerIdentity(src)
    local citizenid = clip(data.citizenid, 64)
    local name, patientSrc = patientName(citizenid)
    if not name then return { ok = false, error = 'patient_not_found' } end
    local requestedSource = tonumber(data.patientSource)
    if not patientSrc and requestedSource then
        local requestedPatient = playerIdentity(requestedSource)
        if requestedPatient and requestedPatient.citizenid == citizenid then
            patientSrc = requestedSource
        end
    end
    ensurePatient(citizenid, name)
    local photos = sanitizePhotos(data.photos)
    local recordType = clip(data.recordType, 24) ~= '' and clip(data.recordType, 24) or 'triage'
    local recordId = MySQL.insert.await([[
        INSERT INTO ob_hospital_records
            (patient_identifier, patient_name, medic_identifier, medic_name, record_type, title, notes,
             diagnosis, treatment, severity, body_parts, vitals, photos)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, name, medic.citizenid, medic.name, recordType,
        clip(data.title, 120) ~= '' and clip(data.title, 120) or 'Triagem clínica', clip(data.notes, 8000),
        clip(data.diagnosis, 8000), clip(data.treatment, 8000), severityAllowed(data.severity),
        encode(sanitizeBodyParts(data.bodyParts)), encode(sanitizeVitals(data.vitals)), encode(photos)
    })
    for _, photo in ipairs(photos) do
        MySQL.insert.await([[
            INSERT INTO ob_hospital_photos (record_id, patient_identifier, url, caption, created_by)
            VALUES (?, ?, ?, ?, ?)
        ]], { recordId, citizenid, photo.url, photo.caption, medic.citizenid })
    end
    MySQL.insert.await([[
        INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
        VALUES (?, ?, 'record_created', ?)
    ]], { medic.citizenid, medic.name, encode({ recordId = recordId, patient = citizenid }) })
    local ticket, queueError
    if recordType == 'triage' then
        local ok, result, err = pcall(ensureQueueTicket, citizenid, name, patientSrc, true)
        if ok and result then
            ticket = result
            if patientSrc then
                notify(patientSrc, ('Triagem registrada. Sua senha é %s. Aguarde a chamada no telão.'):format(ticket.ticket_code), 'inform')
            end
        else
            queueError = ok and err or 'queue_unavailable'
            print(('[ob_hospital] triage queue failed: %s'):format(tostring(ok and err or result)))
        end
    end
    return { ok = true, recordId = recordId, patient = loadPatient(citizenid), ticket = ticket, queueError = queueError, queue = loadClinicalQueue(false) }
end

function actions.updateRecord(src, data)
    if not canEditRecords(src) then return { ok = false, error = 'record_edit_forbidden' } end
    local recordId = tonumber(data.id)
    if not recordId then return { ok = false, error = 'record_not_found' } end
    local record = MySQL.single.await('SELECT * FROM ob_hospital_records WHERE id = ?', { recordId })
    if not record then return { ok = false, error = 'record_not_found' } end

    local photos = sanitizePhotos(data.photos)
    local title = clip(data.title, 120)
    if title == '' then title = record.title end
    MySQL.update.await([[
        UPDATE ob_hospital_records
        SET title = ?, notes = ?, diagnosis = ?, treatment = ?, severity = ?,
            body_parts = ?, vitals = ?, photos = ?
        WHERE id = ?
    ]], {
        title, clip(data.notes, 8000), clip(data.diagnosis, 8000), clip(data.treatment, 8000),
        severityAllowed(data.severity), encode(sanitizeBodyParts(data.bodyParts)),
        encode(sanitizeVitals(data.vitals)), encode(photos), recordId
    })

    MySQL.update.await('DELETE FROM ob_hospital_photos WHERE record_id = ?', { recordId })
    local editor = playerIdentity(src)
    for _, photo in ipairs(photos) do
        MySQL.insert.await([[
            INSERT INTO ob_hospital_photos (record_id, patient_identifier, url, caption, created_by)
            VALUES (?, ?, ?, ?, ?)
        ]], { recordId, record.patient_identifier, photo.url, photo.caption, editor.citizenid })
    end
    MySQL.insert.await([[
        INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
        VALUES (?, ?, 'record_updated', ?)
    ]], { editor.citizenid, editor.name, encode({ recordId = recordId, patient = record.patient_identifier }) })

    return { ok = true, patient = loadPatient(record.patient_identifier) }
end

function actions.nearbyPatients(src)
    local patients, err = nearbyPatients(src)
    if not patients then return { ok = false, error = err } end
    return { ok = true, patients = patients }
end

function actions.createInvoice(src, data)
    if not canManageBilling(src) then return { ok = false, error = 'not_authorized' } end
    local patient, err = nearbyPatient(src, data.customerSource)
    if not patient then return { ok = false, error = err } end
    local amount = math.floor(tonumber(data.amount) or 0)
    local maxAmount = math.max(1, math.floor(tonumber(Config.Billing.maxInvoiceAmount) or 1000000))
    if amount < 1 or amount > maxAmount then return { ok = false, error = 'invalid_amount' } end
    local description = clip(data.description, 500)
    if description == '' then return { ok = false, error = 'description_required' } end

    local originalAmount = amount
    local vipDiscount, vipDiscountPercent
    amount, vipDiscount, vipDiscountPercent = medicalPrice(patient.citizenid, amount)

    local employee = playerIdentity(src)
    local subscription = activeSubscription(patient.citizenid)
    local status = subscription and 'covered' or 'pending'
    local expires = math.max(1, math.floor(tonumber(Config.Billing.invoiceExpiryMinutes) or 10))
    local code
    repeat
        code = ('HOSP-%06d'):format(math.random(0, 999999))
    until not MySQL.single.await('SELECT id FROM ob_hospital_invoices WHERE public_code = ?', { code })
    local invoiceId = MySQL.insert.await([[
        INSERT INTO ob_hospital_invoices
            (public_code, patient_identifier, patient_name, patient_source, employee_identifier,
             employee_name, description, amount, status, expires_at, paid_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE),
                CASE WHEN ? = 'covered' THEN NOW() ELSE NULL END)
    ]], {
        code, patient.citizenid, patient.name, patient.source, employee.citizenid, employee.name,
        description, amount, status, expires, status
    })
    MySQL.insert.await([[
        INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
        VALUES (?, ?, 'invoice_created', ?)
    ]], { employee.citizenid, employee.name, encode({ invoiceId = invoiceId, patient = patient.citizenid, amount = amount, covered = subscription ~= nil }) })

    if subscription then
        notify(patient.source, ('A comanda %s de $ %s foi coberta pelo seu plano hospitalar.'):format(code, amount), 'success')
        return { ok = true, covered = true, invoiceId = invoiceId, code = code, amount = amount, originalAmount = originalAmount, vipDiscount = vipDiscount }
    end
    local discountText = vipDiscountPercent > 0 and (' (desconto VIP de %s%%)'):format(vipDiscountPercent) or ''
    notify(patient.source, ('Nova comanda hospitalar %s no valor de $ %s%s. Confirme o pagamento na maquininha.'):format(code, amount, discountText), 'inform')
    TriggerClientEvent('ob_hospital:client:billingChanged', patient.source)
    return { ok = true, covered = false, invoiceId = invoiceId, code = code, amount = amount, originalAmount = originalAmount, vipDiscount = vipDiscount }
end

function actions.proposeSubscription(src, data)
    if not canManageBilling(src) then return { ok = false, error = 'not_authorized' } end
    local plan = billingPlanConfig()
    if not plan.enabled then return { ok = false, error = 'plan_disabled' } end
    local patient, err = nearbyPatient(src, data.customerSource)
    if not patient then return { ok = false, error = err } end
    local existing = MySQL.single.await('SELECT id, status FROM ob_hospital_subscriptions WHERE patient_identifier = ?', { patient.citizenid })
    if existing and (existing.status == 'active' or existing.status == 'processing') then
        return { ok = false, error = 'plan_already_active' }
    end
    if existing and (existing.status == 'pending' or existing.status == 'past_due') then
        return { ok = false, error = 'subscription_already_pending' }
    end
    local employee = playerIdentity(src)
    MySQL.update.await([[
        INSERT INTO ob_hospital_subscriptions
            (patient_identifier, patient_name, patient_source, status, monthly_price,
             created_by_identifier, created_by_name)
        VALUES (?, ?, ?, 'pending', ?, ?, ?)
        ON DUPLICATE KEY UPDATE patient_name = VALUES(patient_name), patient_source = VALUES(patient_source),
            status = 'pending', monthly_price = VALUES(monthly_price),
            created_by_identifier = VALUES(created_by_identifier), created_by_name = VALUES(created_by_name),
            starts_at = NULL, next_charge_at = NULL, last_charge_at = NULL, cancelled_at = NULL,
            failure_count = 0
    ]], { patient.citizenid, patient.name, patient.source, plan.monthlyPrice, employee.citizenid, employee.name })
    MySQL.insert.await([[
        INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
        VALUES (?, ?, 'subscription_proposed', ?)
    ]], { employee.citizenid, employee.name, encode({ patient = patient.citizenid, monthlyPrice = plan.monthlyPrice }) })
    notify(patient.source, ('%s disponível por $ %s ao mês. Revise e aceite na maquininha do hospital.'):format(plan.name, plan.monthlyPrice), 'inform')
    TriggerClientEvent('ob_hospital:client:billingChanged', patient.source)
    broadcastSubscription(patient.citizenid)
    return { ok = true, plan = plan }
end

function actions.billing(src)
    if not nearCoords(src, Config.Points.billing, Config.Billing.terminalDistance) then
        return { ok = false, error = 'terminal_too_far' }
    end
    return billingPayload(src) or { ok = false, error = 'patient_unavailable' }
end

function actions.payInvoice(src, data)
    if not nearCoords(src, Config.Points.billing, Config.Billing.terminalDistance) then
        return { ok = false, error = 'terminal_too_far' }
    end
    local identity = playerIdentity(src)
    if not identity then return { ok = false, error = 'patient_unavailable' } end
    local invoiceId = tonumber(data.id)
    local invoice = invoiceId and MySQL.single.await('SELECT * FROM ob_hospital_invoices WHERE id = ?', { invoiceId })
    if not invoice or invoice.patient_identifier ~= identity.citizenid then return { ok = false, error = 'invoice_unavailable' } end
    local locked = MySQL.update.await([[
        UPDATE ob_hospital_invoices SET status = 'processing'
        WHERE id = ? AND patient_identifier = ? AND status = 'pending' AND expires_at > NOW()
    ]], { invoiceId, identity.citizenid })
    if tonumber(locked) ~= 1 then return { ok = false, error = 'invoice_unavailable' } end

    local amount = math.floor(tonumber(invoice.amount) or 0)
    if amount < 1 or not removeBank(src, amount, 'pagamento-hospital') then
        MySQL.update.await("UPDATE ob_hospital_invoices SET status = 'pending' WHERE id = ? AND status = 'processing'", { invoiceId })
        return { ok = false, error = 'insufficient_money' }
    end
    MySQL.update.await("UPDATE ob_hospital_invoices SET status = 'paid', paid_at = NOW() WHERE id = ?", { invoiceId })
    MySQL.insert.await([[
        INSERT INTO ob_hospital_billing_transactions
            (patient_identifier, invoice_id, transaction_type, amount, status, description)
        VALUES (?, ?, 'invoice', ?, 'paid', ?)
    ]], { identity.citizenid, invoiceId, amount, invoice.description })
    depositHospital(amount, 'comanda-hospitalar')
    local result = billingPayload(src)
    result.paidAmount = amount
    return result
end

function actions.acceptSubscription(src)
    if not nearCoords(src, Config.Points.billing, Config.Billing.terminalDistance) then
        return { ok = false, error = 'terminal_too_far' }
    end
    local plan = billingPlanConfig()
    if not plan.enabled then return { ok = false, error = 'plan_disabled' } end
    local identity = playerIdentity(src)
    if not identity then return { ok = false, error = 'patient_unavailable' } end
    local subscription = MySQL.single.await('SELECT * FROM ob_hospital_subscriptions WHERE patient_identifier = ?', { identity.citizenid })
    if not subscription or (subscription.status ~= 'pending' and subscription.status ~= 'past_due') then
        return { ok = false, error = 'subscription_unavailable' }
    end
    local previousStatus = subscription.status
    local locked = MySQL.update.await([[
        UPDATE ob_hospital_subscriptions SET status = 'processing'
        WHERE id = ? AND patient_identifier = ? AND status IN ('pending', 'past_due')
    ]], { subscription.id, identity.citizenid })
    if tonumber(locked) ~= 1 then return { ok = false, error = 'subscription_unavailable' } end

    local baseAmount = math.max(1, math.floor(tonumber(subscription.monthly_price) or plan.monthlyPrice))
    local amount = medicalPrice(identity.citizenid, baseAmount)
    if not removeBank(src, amount, 'mensalidade-plano-hospital') then
        MySQL.update.await([[
            UPDATE ob_hospital_subscriptions SET status = ?, failure_count = failure_count + 1
            WHERE id = ? AND status = 'processing'
        ]], { previousStatus, subscription.id })
        return { ok = false, error = 'insufficient_money' }
    end
    local intervalDays = plan.intervalDays
    MySQL.update.await(([=[
        UPDATE ob_hospital_subscriptions
        SET status = 'active', starts_at = COALESCE(starts_at, NOW()), last_charge_at = NOW(),
            next_charge_at = DATE_ADD(NOW(), INTERVAL %d DAY), cancelled_at = NULL, failure_count = 0
        WHERE id = ? AND status = 'processing'
    ]=]):format(intervalDays), { subscription.id })
    MySQL.insert.await([[
        INSERT INTO ob_hospital_billing_transactions
            (patient_identifier, subscription_id, transaction_type, amount, status, description)
        VALUES (?, ?, 'subscription', ?, 'paid', ?)
    ]], { identity.citizenid, subscription.id, amount, plan.name })
    depositHospital(amount, 'mensalidade-plano-hospital')
    local result = billingPayload(src)
    result.paidAmount = amount
    result.subscriptionActivated = true
    broadcastSubscription(identity.citizenid)
    return result
end

function actions.cancelSubscription(src)
    if not nearCoords(src, Config.Points.billing, Config.Billing.terminalDistance) then
        return { ok = false, error = 'terminal_too_far' }
    end
    local identity = playerIdentity(src)
    if not identity then return { ok = false, error = 'patient_unavailable' } end
    local changed = MySQL.update.await([[
        UPDATE ob_hospital_subscriptions
        SET status = 'cancelled', cancelled_at = NOW(), patient_source = ?
        WHERE patient_identifier = ? AND status IN ('pending', 'active', 'past_due')
    ]], { src, identity.citizenid })
    if tonumber(changed) ~= 1 then return { ok = false, error = 'subscription_unavailable' } end
    MySQL.insert.await([[
        INSERT INTO ob_hospital_activity (actor_identifier, actor_name, action, payload)
        VALUES (?, ?, 'subscription_cancelled', ?)
    ]], { identity.citizenid, identity.name, encode({ patient = identity.citizenid }) })
    local result = billingPayload(src)
    result.subscriptionCancelled = true
    broadcastSubscription(identity.citizenid)
    return result
end

function actions.updateCall(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    local identity = playerIdentity(src)
    local call = MySQL.single.await('SELECT * FROM ob_hospital_calls WHERE id = ?', { tonumber(data.id) })
    if not call then return { ok = false, error = 'call_not_found' } end
    local action = tostring(data.status or '')
    local allowed = { waiting = true, assigned = true, on_scene = true, transporting = true, resolved = true, cancelled = true }
    if not allowed[action] then return { ok = false, error = 'invalid_status' } end
    local assignedId, assignedName = call.assigned_identifier, call.assigned_name
    if action == 'assigned' then
        assignedId, assignedName = identity.citizenid, identity.name
    elseif assignedId and assignedId ~= identity.citizenid and not isAdmin(src) and jobGrade(identity.job) < Config.Job.managerGrade then
        return { ok = false, error = 'call_owned' }
    end
    MySQL.update.await([[
        UPDATE ob_hospital_calls
        SET status = ?, assigned_identifier = ?, assigned_name = ?,
            resolved_at = CASE WHEN ? IN ('resolved', 'cancelled') THEN NOW() ELSE NULL END
        WHERE id = ?
    ]], { action, assignedId, assignedName, action, call.id })
    call = MySQL.single.await('SELECT * FROM ob_hospital_calls WHERE id = ?', { call.id })
    call.coords = decode(call.coords, {})
    broadcastDispatch(call, false)
    return { ok = true, calls = loadCalls(false) }
end

local function updateQueueTicket(src, data)
    if not isDoctor(src) and not isAdmin(src) then return { ok = false, error = 'not_authorized' } end
    local identity = playerIdentity(src)
    local ticket = MySQL.single.await('SELECT * FROM ob_hospital_queue WHERE id = ?', { tonumber(data.id) })
    if not ticket then return { ok = false, error = 'queue_not_found' } end

    local nextStatus = tostring(data.status or '')
    if nextStatus == 'repeat' then
        if ticket.status ~= 'called' then return { ok = false, error = 'invalid_transition' } end
        if ticket.called_by_identifier and ticket.called_by_identifier ~= identity.citizenid
            and not isAdmin(src) and jobGrade(identity.job) < Config.Job.managerGrade then
            return { ok = false, error = 'queue_owned' }
        end
        local now = os.time()
        local cooldown = math.max(1, tonumber(Config.Queue.repeatCooldownSeconds) or 5)
        if queueRepeatCooldowns[ticket.id] and now - queueRepeatCooldowns[ticket.id] < cooldown then
            return { ok = false, error = 'repeat_cooldown' }
        end
        queueRepeatCooldowns[ticket.id] = now
        announceQueueTicket(ticket, 'repeat', now)
        return { ok = true, queue = loadClinicalQueue(false) }
    end
    local transitions = {
        awaiting_triage = { cancelled = true },
        waiting = { called = true, cancelled = true },
        called = { cancelled = true },
        in_service = { resolved = true, cancelled = true }
    }
    if not transitions[ticket.status] or not transitions[ticket.status][nextStatus] then
        return { ok = false, error = 'invalid_transition' }
    end

    local calledById, calledByName = ticket.called_by_identifier, ticket.called_by_name
    local calledByTitle = ticket.called_by_title
    if nextStatus == 'called' then
        local count = MySQL.scalar.await("SELECT COUNT(*) FROM ob_hospital_queue WHERE status = 'called'") or 0
        if count >= Config.Queue.maxPublicEntries then return { ok = false, error = 'display_full' } end
        calledById, calledByName = identity.citizenid, identity.name
        calledByTitle = identity.medicalTitle
    elseif calledById and calledById ~= identity.citizenid and not isAdmin(src) and jobGrade(identity.job) < Config.Job.managerGrade then
        return { ok = false, error = 'queue_owned' }
    end
    local changed = MySQL.update.await([[
        UPDATE ob_hospital_queue
        SET status = ?, called_by_identifier = ?, called_by_name = ?, called_by_title = ?,
            called_at = CASE WHEN ? = 'called' THEN NOW() ELSE called_at END,
            started_at = CASE WHEN ? = 'in_service' THEN NOW() ELSE started_at END,
            resolved_at = CASE WHEN ? IN ('resolved', 'cancelled') THEN NOW() ELSE NULL END
        WHERE id = ? AND status = ?
    ]], { nextStatus, calledById, calledByName, calledByTitle, nextStatus, nextStatus, nextStatus, ticket.id, ticket.status })
    if not changed or changed == 0 then return { ok = false, error = 'queue_changed' } end

    if nextStatus == 'called' then
        ticket = MySQL.single.await('SELECT * FROM ob_hospital_queue WHERE id = ?', { ticket.id })
        announceQueueTicket(ticket, 'start')
        local _, targetSrc = patientName(ticket.patient_identifier)
        if targetSrc then
            notify(targetSrc, ('Sua senha %s foi chamada. Dirija-se ao atendimento.'):format(ticket.ticket_code), 'success')
        end
    end
    broadcastQueue()
    return { ok = true, queue = loadClinicalQueue(false) }
end

function actions.updateQueue(src, data)
    if acceptingQueueTicket then return { ok = false, error = 'queue_busy' } end
    acceptingQueueTicket = true
    local ok, result = pcall(updateQueueTicket, src, data)
    acceptingQueueTicket = false
    if not ok then error(result) end
    return result
end

function actions.createCall(src, data)
    local id, err = createCall(src, data.reason, data.priority, data.coords, false)
    if err then return { ok = false, error = err } end
    return { ok = true, id = id }
end

function actions.purchase(src, data)
    if doctorCount() > 0 then return { ok = false, error = 'doctors_online' } end
    if not nearCoords(src, Config.AutoAttendant.coords.xyz, 5.0) then return { ok = false, error = 'too_far' } end
    local item
    for _, entry in ipairs(Config.PublicShop) do if entry.name == data.name then item = entry break end end
    if not item then return { ok = false, error = 'item_not_found' } end
    local amount = math.max(1, math.min(10, math.floor(tonumber(data.amount) or 1)))
    local originalTotal = item.price * amount
    local total, _, vipDiscountPercent = medicalPrice(src, originalTotal)
    if not exports.ox_inventory:CanCarryItem(src, item.name, amount) then return { ok = false, error = 'inventory_full' } end
    local player = getPlayer(src)
    if not player or player.Functions.RemoveMoney('bank', total, 'ob_hospital_public_shop') ~= true then
        return { ok = false, error = 'not_enough_money' }
    end
    if not exports.ox_inventory:AddItem(src, item.name, amount) then
        player.Functions.AddMoney('bank', total, 'ob_hospital_shop_refund')
        return { ok = false, error = 'inventory_error' }
    end
    return { ok = true, amount = amount, total = total, originalTotal = originalTotal, vipDiscountPercent = vipDiscountPercent }
end

function actions.selfTreatment(src)
    if doctorCount() > 0 then return { ok = false, error = 'doctors_online' } end
    if not nearCoords(src, Config.AutoAttendant.coords.xyz, 5.0) then return { ok = false, error = 'too_far' } end
    local ok, result = pcall(function()
        return exports.qbx_ambulancejob:CheckIn(src, src, Config.HospitalKey)
    end)
    if not ok or result == false then return { ok = false, error = 'no_bed' } end
    createAutomaticRecord(src, 'Atendimento automático', 'Paciente encaminhado ao leito pelo atendente hospitalar.')
    return { ok = true }
end

RegisterNetEvent('ob_hospital:server:request', function(token, action, data)
    local src = source
    if not databaseReady then respond(src, token, { ok = false, error = 'starting' }) return end
    local handler = actions[tostring(action or '')]
    if not handler then respond(src, token, { ok = false, error = 'unknown_action' }) return end
    local ok, payload = pcall(handler, src, type(data) == 'table' and data or {})
    if not ok then
        print(('[ob_hospital] request %s failed: %s'):format(tostring(action), tostring(payload)))
        respond(src, token, { ok = false, error = 'server_error' })
        return
    end
    respond(src, token, payload)
end)

RegisterNetEvent('ob_hospital:server:createCall', function(reason, priority)
    local src = source
    local _, err = createCall(src, reason, priority, nil, false)
    if err == 'cooldown' then notify(src, 'Aguarde antes de enviar outro chamado.', 'error')
    elseif err == 'already_open' then notify(src, 'Você já possui um chamado em atendimento.', 'inform')
    else notify(src, 'Chamado médico enviado.', 'success') end
end)

RegisterNetEvent('qbx_medical:server:onPlayerLaststand', function()
    createCall(source, 'Paciente inconsciente aguardando atendimento.', 'urgent', nil, true)
end)

RegisterNetEvent('qbx_medical:server:onPlayerDied', function()
    createCall(source, 'Paciente em estado crítico.', 'critical', nil, true)
end)

exports('CreateCall', function(src, reason, priority, coords)
    return createCall(src, reason, priority, coords, true)
end)

local function useExistingMedicalItem(src, itemName, callbackName)
    if exports.ox_inventory:Search(src, 'count', itemName) < 1 then return end
    local remove = lib.callback.await(callbackName, src)
    if remove then exports.ox_inventory:RemoveItem(src, itemName, 1) end
end

local function treatmentOption(optionId)
    for _, option in ipairs(Config.Treatment.options or {}) do
        if option.id == optionId then return option end
    end
end

local function openTreatmentMenu(src)
    if not isDoctor(src) then
        notify(src, 'Apenas profissionais em serviço podem aplicar medicamentos em outras pessoas.', 'error')
        return
    end
    local counts = {}
    for _, option in ipairs(Config.Treatment.options or {}) do
        if counts[option.item] == nil then
            counts[option.item] = exports.ox_inventory:Search(src, 'count', option.item) or 0
        end
    end
    TriggerClientEvent('ob_hospital:client:openTreatmentMenu', src, counts)
end

RegisterNetEvent('ob_hospital:server:openTreatmentMenu', function()
    openTreatmentMenu(source)
end)

RegisterNetEvent('ob_hospital:server:applyTreatment', function(targetSource, optionId)
    local src = source
    local now = GetGameTimer()
    if treatmentLocks[src] and treatmentLocks[src] > now then return end
    treatmentLocks[src] = now + 1500

    if not isDoctor(src) then return end
    local option = treatmentOption(tostring(optionId or ''))
    targetSource = tonumber(targetSource)
    if not option or not targetSource or targetSource == src then return end

    local target = getPlayer(targetSource)
    local targetPed = GetPlayerPed(targetSource)
    if not target or targetPed <= 0 then notify(src, 'Paciente indisponível.', 'error') return end
    if not nearCoords(src, GetEntityCoords(targetPed), tonumber(Config.Treatment.maxDistance) or 3.0) then
        notify(src, 'O paciente se afastou.', 'error')
        return
    end

    local metadata = target.PlayerData.metadata or {}
    local unconscious = metadata.isdead == true or metadata.inlaststand == true
    if option.revive == true and not unconscious then
        notify(src, 'Este paciente não está inconsciente.', 'error')
        return
    end
    if option.revive ~= true and unconscious then
        notify(src, 'Reanime o paciente antes de aplicar este tratamento.', 'error')
        return
    end
    if exports.ox_inventory:Search(src, 'count', option.item) < 1 then
        notify(src, ('Você não possui %s.'):format(option.label), 'error')
        return
    end
    if not exports.ox_inventory:RemoveItem(src, option.item, 1) then
        notify(src, 'Não foi possível consumir o medicamento.', 'error')
        return
    end

    if option.revive == true then
        exports.qbx_medical:Revive(targetSource)
    elseif option.heal == 'full' then
        TriggerClientEvent('qbx_medical:client:heal', targetSource, 'full')
    elseif option.heal == 'partial' then
        exports.qbx_medical:HealPartially(targetSource)
    end

    local stressRelief = math.max(0, math.floor(tonumber(option.stress) or 0))
    if stressRelief > 0 then
        local currentStress = tonumber(metadata.stress) or 0
        target.Functions.SetMetaData('stress', math.max(0, currentStress - stressRelief))
    end
    TriggerClientEvent('ob_hospital:client:receiveTreatment', targetSource, {
        health = math.max(0, math.floor(tonumber(option.health) or 0)),
        revived = option.revive == true,
        label = option.label
    })
    local targetIdentity = playerIdentity(targetSource)
    notify(src, ('%s aplicado em %s.'):format(option.label, targetIdentity and targetIdentity.name or 'paciente'), 'success')
    notify(targetSource, ('Você recebeu: %s.'):format(option.label), 'success')
end)

exports.qbx_core:CreateUseableItem('gauze', function(src)
    useExistingMedicalItem(src, 'gauze', 'hospital:client:UseBandage')
end)

exports.qbx_core:CreateUseableItem('medical_kit', function(src)
    openTreatmentMenu(src)
end)

exports.qbx_core:CreateUseableItem('firstaid', function(src)
    if isDoctor(src) then
        openTreatmentMenu(src)
    else
        lib.callback.await('hospital:client:UseFirstAid', src)
    end
end)

exports.qbx_core:CreateUseableItem('painkillers', function(src)
    if exports.ox_inventory:Search(src, 'count', 'painkillers') < 1 then return end
    local remove = lib.callback.await('hospital:client:UsePainkillers', src)
    if not remove or not exports.ox_inventory:RemoveItem(src, 'painkillers', 1) then return end
    local player = getPlayer(src)
    if not player then return end
    local metadata = player.PlayerData.metadata or {}
    local relief = 25
    player.Functions.SetMetaData('stress', math.max(0, (tonumber(metadata.stress) or 0) - relief))
    notify(src, 'O analgésico reduziu sua dor e seu estresse.', 'success')
end)

exports.qbx_core:CreateUseableItem(Config.Stretcher.item, function(src)
    if not isDoctor(src) then notify(src, 'Apenas profissionais de saúde podem operar a maca.', 'error') return end
    TriggerClientEvent('ob_hospital:client:deployStretcher', src)
end)

RegisterNetEvent('ob_hospital:server:registerStretcher', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId or not isDoctor(src) or exports.ox_inventory:Search(src, 'count', Config.Stretcher.item) < 1 then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local timeout = GetGameTimer() + 2000
    while entity == 0 and GetGameTimer() < timeout do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity == 0 or not nearCoords(src, GetEntityCoords(entity), 6.0) then return end
    if not exports.ox_inventory:RemoveItem(src, Config.Stretcher.item, 1) then return end
    activeStretchers[netId] = { owner = src, patient = nil }
    Entity(entity).state:set('obHospitalStretcher', true, true)
end)

RegisterNetEvent('ob_hospital:server:storeStretcher', function(netId)
    local src = source
    netId = tonumber(netId)
    local state = activeStretchers[netId]
    if not state or state.patient or not isDoctor(src) then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not nearCoords(src, GetEntityCoords(entity), 5.0) then return end
    if not exports.ox_inventory:CanCarryItem(src, Config.Stretcher.item, 1) then
        notify(src, 'Sem espaço para guardar a maca.', 'error')
        return
    end
    exports.ox_inventory:AddItem(src, Config.Stretcher.item, 1)
    activeStretchers[netId] = nil
    TriggerClientEvent('ob_hospital:client:deleteStretcher', -1, netId)
end)

RegisterNetEvent('ob_hospital:server:setStretcherPatient', function(netId, targetSrc)
    local src = source
    netId, targetSrc = tonumber(netId), tonumber(targetSrc)
    local state = activeStretchers[netId]
    if not state or not targetSrc or state.patient or patientStretchers[targetSrc] or not isDoctor(src) then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not nearCoords(src, GetEntityCoords(entity), 5.0) or not nearCoords(targetSrc, GetEntityCoords(entity), Config.Stretcher.maxPatientDistance + 1.0) then return end
    state.patient = targetSrc
    patientStretchers[targetSrc] = netId
    TriggerClientEvent('ob_hospital:client:setOnStretcher', targetSrc, netId, true)
end)

RegisterNetEvent('ob_hospital:server:removeStretcherPatient', function(netId)
    local src = source
    netId = tonumber(netId)
    local state = activeStretchers[netId]
    if not state or not state.patient then return end
    if src ~= state.patient and not isDoctor(src) then return end
    local patient = state.patient
    state.patient = nil
    patientStretchers[patient] = nil
    TriggerClientEvent('ob_hospital:client:setOnStretcher', patient, netId, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for netId, state in pairs(activeStretchers) do
        if state.patient then
            TriggerClientEvent('ob_hospital:client:setOnStretcher', state.patient, netId, false)
        end

        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end

    activeStretchers = {}
    patientStretchers = {}
end)

AddEventHandler('playerDropped', function()
    local src = source
    treatmentLocks[src] = nil
    local netId = patientStretchers[src]
    if netId and activeStretchers[netId] then activeStretchers[netId].patient = nil end
    patientStretchers[src] = nil
    if not databaseReady then return end
    local changed = MySQL.update.await([[
        UPDATE ob_hospital_queue
        SET status = 'cancelled', resolved_at = NOW()
        WHERE patient_source = ? AND status NOT IN ('resolved', 'cancelled')
    ]], { src })
    if changed and changed > 0 then broadcastQueue() end
end)

local schema = {
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_patients` (`citizenid` varchar(64) NOT NULL,`name` varchar(96) NOT NULL,`blood_type` varchar(8) NOT NULL DEFAULT '',`allergies` varchar(500) NOT NULL DEFAULT '',`conditions` varchar(1000) NOT NULL DEFAULT '',`notes` text NULL,`photo_url` varchar(600) NOT NULL DEFAULT '',`created_at` timestamp NOT NULL DEFAULT current_timestamp(),`updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),PRIMARY KEY (`citizenid`),KEY `idx_ob_hospital_patient_name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_records` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`patient_identifier` varchar(64) NOT NULL,`patient_name` varchar(96) NOT NULL,`medic_identifier` varchar(64) NOT NULL,`medic_name` varchar(96) NOT NULL,`record_type` varchar(24) NOT NULL DEFAULT 'consultation',`title` varchar(120) NOT NULL,`notes` text NULL,`diagnosis` text NULL,`treatment` text NULL,`severity` varchar(24) NOT NULL DEFAULT 'stable',`body_parts` longtext NOT NULL,`vitals` longtext NOT NULL,`photos` longtext NOT NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),PRIMARY KEY (`id`),KEY `idx_ob_hospital_records_patient` (`patient_identifier`,`created_at`),KEY `idx_ob_hospital_records_medic` (`medic_identifier`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_photos` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`record_id` bigint unsigned NOT NULL,`patient_identifier` varchar(64) NOT NULL,`url` varchar(600) NOT NULL,`caption` varchar(180) NOT NULL DEFAULT '',`created_by` varchar(64) NOT NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),PRIMARY KEY (`id`),KEY `idx_ob_hospital_photos_patient` (`patient_identifier`,`created_at`),CONSTRAINT `fk_ob_hospital_photo_record` FOREIGN KEY (`record_id`) REFERENCES `ob_hospital_records` (`id`) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_calls` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`public_code` varchar(16) NOT NULL,`patient_identifier` varchar(64) NULL,`patient_name` varchar(96) NOT NULL,`patient_source` int NULL,`reason` varchar(500) NOT NULL,`priority` varchar(24) NOT NULL DEFAULT 'normal',`status` varchar(24) NOT NULL DEFAULT 'waiting',`coords` longtext NOT NULL,`assigned_identifier` varchar(64) NULL,`assigned_name` varchar(96) NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),`updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),`resolved_at` datetime NULL,PRIMARY KEY (`id`),UNIQUE KEY `uq_ob_hospital_call_code` (`public_code`),KEY `idx_ob_hospital_calls_board` (`status`,`priority`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_queue` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`ticket_code` varchar(24) NULL,`patient_identifier` varchar(64) NOT NULL,`patient_name` varchar(96) NOT NULL,`patient_source` int NULL,`status` varchar(24) NOT NULL DEFAULT 'waiting',`called_by_identifier` varchar(64) NULL,`called_by_name` varchar(96) NULL,`called_by_title` varchar(16) NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),`called_at` datetime NULL,`started_at` datetime NULL,`resolved_at` datetime NULL,PRIMARY KEY (`id`),UNIQUE KEY `uq_ob_hospital_queue_code` (`ticket_code`),KEY `idx_ob_hospital_queue_status` (`status`,`called_at`,`created_at`),KEY `idx_ob_hospital_queue_patient` (`patient_identifier`,`status`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_activity` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`actor_identifier` varchar(64) NOT NULL,`actor_name` varchar(96) NOT NULL,`action` varchar(48) NOT NULL,`payload` longtext NOT NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),PRIMARY KEY (`id`),KEY `idx_ob_hospital_activity_date` (`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_invoices` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`public_code` varchar(24) NOT NULL,`patient_identifier` varchar(64) NOT NULL,`patient_name` varchar(96) NOT NULL,`patient_source` int NULL,`employee_identifier` varchar(64) NOT NULL,`employee_name` varchar(96) NOT NULL,`description` varchar(500) NOT NULL,`amount` int unsigned NOT NULL,`status` varchar(24) NOT NULL DEFAULT 'pending',`expires_at` datetime NULL,`paid_at` datetime NULL,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),PRIMARY KEY (`id`),UNIQUE KEY `uq_ob_hospital_invoice_code` (`public_code`),KEY `idx_ob_hospital_invoice_patient` (`patient_identifier`,`status`,`created_at`),KEY `idx_ob_hospital_invoice_status` (`status`,`expires_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_subscriptions` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`patient_identifier` varchar(64) NOT NULL,`patient_name` varchar(96) NOT NULL,`patient_source` int NULL,`status` varchar(24) NOT NULL DEFAULT 'pending',`monthly_price` int unsigned NOT NULL,`created_by_identifier` varchar(64) NOT NULL,`created_by_name` varchar(96) NOT NULL,`starts_at` datetime NULL,`next_charge_at` datetime NULL,`last_charge_at` datetime NULL,`cancelled_at` datetime NULL,`failure_count` int unsigned NOT NULL DEFAULT 0,`created_at` timestamp NOT NULL DEFAULT current_timestamp(),`updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),PRIMARY KEY (`id`),UNIQUE KEY `uq_ob_hospital_subscription_patient` (`patient_identifier`),KEY `idx_ob_hospital_subscription_due` (`status`,`next_charge_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `ob_hospital_billing_transactions` (`id` bigint unsigned NOT NULL AUTO_INCREMENT,`patient_identifier` varchar(64) NOT NULL,`invoice_id` bigint unsigned NULL,`subscription_id` bigint unsigned NULL,`transaction_type` varchar(24) NOT NULL,`amount` int unsigned NOT NULL,`status` varchar(24) NOT NULL,`description` varchar(500) NOT NULL DEFAULT '',`created_at` timestamp NOT NULL DEFAULT current_timestamp(),PRIMARY KEY (`id`),KEY `idx_ob_hospital_transaction_patient` (`patient_identifier`,`created_at`),KEY `idx_ob_hospital_transaction_invoice` (`invoice_id`),KEY `idx_ob_hospital_transaction_subscription` (`subscription_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
}

MySQL.ready(function()
    for _, statement in ipairs(schema) do MySQL.query.await(statement) end
    local hasCallerTitle = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ob_hospital_queue' AND COLUMN_NAME = 'called_by_title'
    ]])
    if tonumber(hasCallerTitle) == 0 then
        MySQL.query.await('ALTER TABLE ob_hospital_queue ADD COLUMN called_by_title varchar(16) NULL AFTER called_by_name')
    end
    MySQL.update.await("UPDATE ob_hospital_invoices SET status = 'pending' WHERE status = 'processing' AND expires_at > NOW()")
    MySQL.update.await("UPDATE ob_hospital_invoices SET status = 'expired' WHERE status IN ('pending', 'processing') AND expires_at <= NOW()")
    MySQL.update.await("UPDATE ob_hospital_subscriptions SET status = 'active', next_charge_at = DATE_ADD(NOW(), INTERVAL 1 DAY) WHERE status = 'processing'")
    MySQL.update.await(([[
        UPDATE ob_hospital_queue
        SET status = 'cancelled', resolved_at = NOW()
        WHERE status NOT IN ('resolved', 'cancelled')
          AND created_at < DATE_SUB(NOW(), INTERVAL %d MINUTE)
    ]]):format(math.max(1, math.floor(Config.Queue.staleMinutes))))
    MySQL.update.await(('DELETE FROM ob_hospital_calls WHERE created_at < DATE_SUB(NOW(), INTERVAL %d DAY)'):format(math.max(1, math.floor(Config.CallRetentionDays))))
    MySQL.update.await(('DELETE FROM ob_hospital_queue WHERE status IN (\'resolved\', \'cancelled\') AND created_at < DATE_SUB(NOW(), INTERVAL %d DAY)'):format(math.max(1, math.floor(Config.CallRetentionDays))))
    expireEmergencyCalls()
    exports.ox_inventory:RegisterStash(Config.Stash.name, Config.Stash.label, Config.Stash.slots, Config.Stash.weight, Config.Stash.owner, Config.Stash.groups, Config.Points.stash)
    exports.ox_inventory:RegisterShop(Config.Armory.name, {
        name = Config.Armory.label,
        inventory = Config.Armory.inventory,
        locations = { Config.Points.armory },
        groups = Config.Armory.groups
    })
    databaseReady = true
    CreateThread(function()
        while true do
            local ok, err = pcall(finishQueueAnnouncements)
            if not ok then print(('[ob_hospital] queue timer failed: %s'):format(tostring(err))) end
            Wait(1000)
        end
    end)
    CreateThread(function()
        while true do
            Wait(5000)
            local ok, err = pcall(expireEmergencyCalls)
            if not ok then print(('[ob_hospital] emergency expiration failed: %s'):format(tostring(err))) end
        end
    end)
    CreateThread(function()
        while true do
            local ok, err = pcall(processSubscriptionRenewals)
            if not ok then print(('[ob_hospital] subscription renewal failed: %s'):format(tostring(err))) end
            Wait(math.max(1, math.floor(tonumber(Config.Billing.renewalCheckMinutes) or 10)) * 60000)
        end
    end)
end)

exports('HasActivePlan', function(citizenid)
    return activeSubscription(clip(citizenid, 64)) ~= nil
end)
