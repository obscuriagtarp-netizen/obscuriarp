local oxmysql = exports.oxmysql
local cache = {
    expiresAt = 0,
    data = nil
}

local function safeTableName(value, fallback)
    value = tostring(value or "")
    return value:match("^[%w_]+$") and value or fallback
end

local function safeQuery(statement, params, label)
    local ok, rows = pcall(function()
        return oxmysql:querySync(statement, params or {})
    end)

    if not ok then
        print(("[magicPauseObscuria][Ranking] Falha ao consultar %s: %s"):format(label, tostring(rows)))
        return {}
    end

    return type(rows) == "table" and rows or {}
end

local function decode(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" then return {} end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == "table" and result or {}
end

local function characterName(row)
    local charinfo = decode(row.charinfo)
    local first = tostring(charinfo.firstname or charinfo.firstName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local last = tostring(charinfo.lastname or charinfo.lastName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local fullName = (first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", "")

    if fullName ~= "" then return fullName end
    if row.player_name and tostring(row.player_name) ~= "" then return tostring(row.player_name) end
    if row.account_name and tostring(row.account_name) ~= "" then return tostring(row.account_name) end
    return "Cidadão de Obscuria"
end

local function rankedData(rows, mapper, limit)
    local ranking = {}
    local placements = {}

    for index, row in ipairs(rows) do
        local entry = mapper(row)
        entry.position = index
        entry.passport = tostring(row.passport or row.citizenid or "")
        placements[entry.passport] = entry

        if index <= limit then
            local topEntry = {}
            for key, value in pairs(entry) do topEntry[key] = value end
            topEntry.name = characterName(row)
            ranking[#ranking + 1] = topEntry
        end
    end

    return ranking, placements
end

local function buildRankings()
    local cfg = Config.Rankings or {}
    local limit = math.min(50, math.max(3, math.floor(tonumber(cfg.limit) or 10)))
    local players = safeTableName(cfg.playersTable, "players")
    local vehicles = safeTableName(cfg.vehiclesTable, "player_vehicles")
    local donations = safeTableName(cfg.donationsTable, "magic_pause_vip_orders")
    local donationProductId = tostring(cfg.donationProductId or "rune_deposit")

    local donationRows = safeQuery(([=[
        SELECT
            orders.passport,
            MAX(orders.player_name) AS player_name,
            players.charinfo,
            COALESCE(SUM(
                CASE
                    WHEN JSON_VALID(orders.metadata) THEN CAST(
                        COALESCE(JSON_UNQUOTE(JSON_EXTRACT(orders.metadata, '$.runes')), '0')
                        AS UNSIGNED
                    )
                    ELSE 0
                END
            ), 0) AS total,
            COUNT(*) AS contributions
        FROM `%s` orders
        LEFT JOIN `%s` players ON players.citizenid = orders.passport
        WHERE orders.status = 'paid'
          AND orders.payment_method = 'pix'
          AND orders.currency = 'BRL'
          AND orders.product_id = ?
          AND orders.amount > 0
        GROUP BY orders.passport, players.charinfo
        HAVING total > 0
        ORDER BY total DESC, contributions DESC, orders.passport ASC
    ]=]):format(donations, players), { donationProductId }, "doações")

    local vehicleRows = safeQuery(([=[
        SELECT
            players.citizenid AS passport,
            players.name AS account_name,
            players.charinfo,
            COUNT(vehicles.id) AS total
        FROM `%s` vehicles
        INNER JOIN `%s` players ON players.citizenid = vehicles.citizenid
        GROUP BY players.citizenid, players.name, players.charinfo
        ORDER BY total DESC, players.citizenid ASC
    ]=]):format(vehicles, players), {}, "veículos")

    local cashExpression = "CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(players.money, '$.cash')), '0') AS DECIMAL(20,2))"
    local bankExpression = "CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(players.money, '$.bank')), '0') AS DECIMAL(20,2))"
    local moneyRows = safeQuery(([=[
        SELECT
            players.citizenid AS passport,
            players.name AS account_name,
            players.charinfo,
            %s AS cash,
            %s AS bank,
            (%s + %s) AS total
        FROM `%s` players
        ORDER BY total DESC, players.citizenid ASC
    ]=]):format(cashExpression, bankExpression, cashExpression, bankExpression, players), {}, "dinheiro")

    local donationRanking, donationPlacements = rankedData(donationRows, function(row)
        return {
            value = tonumber(row.total) or 0,
            contributions = tonumber(row.contributions) or 0
        }
    end, limit)

    local vehicleRanking, vehiclePlacements = rankedData(vehicleRows, function(row)
        return { value = tonumber(row.total) or 0 }
    end, limit)

    local moneyRanking, moneyPlacements = rankedData(moneyRows, function(row)
        return {
            value = tonumber(row.total) or 0,
            cash = tonumber(row.cash) or 0,
            bank = tonumber(row.bank) or 0
        }
    end, limit)

    return {
        limit = limit,
        generatedAt = os.time(),
        donations = donationRanking,
        vehicles = vehicleRanking,
        money = moneyRanking,
        placements = {
            donations = donationPlacements,
            vehicles = vehiclePlacements,
            money = moneyPlacements
        }
    }
end

local function payloadFor(src)
    local now = os.time()
    if not cache.data or cache.expiresAt <= now then
        cache.data = buildRankings()
        cache.expiresAt = now + math.max(15, math.floor(tonumber((Config.Rankings or {}).cacheSeconds) or 60))
    end

    local passport = tostring(Utils.getPassport(src) or "")
    local response = {
        ok = true,
        limit = cache.data.limit,
        generatedAt = cache.data.generatedAt,
        rankings = {},
        current = {}
    }

    for _, topic in ipairs({ "donations", "vehicles", "money" }) do
        response.rankings[topic] = {}
        for _, cachedEntry in ipairs(cache.data[topic] or {}) do
            local entry = {}
            for key, value in pairs(cachedEntry) do entry[key] = value end
            entry.isCurrent = entry.passport == passport
            response.rankings[topic][#response.rankings[topic] + 1] = entry
        end

        local placement = cache.data.placements
            and cache.data.placements[topic]
            and cache.data.placements[topic][passport]

        if placement then
            response.current[topic] = {}
            for key, value in pairs(placement) do response.current[topic][key] = value end
            response.current[topic].inTop = placement.position <= cache.data.limit
        end
    end

    return response
end

RegisterNetEvent("MagicPause:server:getRankings", function(token)
    local src = source
    TriggerClientEvent("MagicPause:client:serverResponse", src, token, payloadFor(src))
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        cache.expiresAt = 0
        cache.data = nil
    end
end)
