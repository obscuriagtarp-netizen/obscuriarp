CloudflareTurn = {}

local DEFAULT_TTL_SECONDS = 86400
local DEFAULT_REFRESH_SKEW_SECONDS = 600
local DEFAULT_RETRY_MS = 30000
local FALLBACK_REFRESH_MS = 600000 -- safety re-check if cache is empty after retries

---@type table[]
local cachedIceServers = {}
local expiresAtMs = 0
local refreshing = false
local started = false

---@return boolean
local function isEnabled()
    local cf = Config.PhoneWebRTC
    if not cf or cf.enabled ~= true then return false end
    if type(cf.turnKeyId) ~= 'string' or cf.turnKeyId == '' then return false end
    if type(cf.apiToken) ~= 'string' or cf.apiToken == '' then return false end
    return true
end

---@return number
local function resolveTtlSeconds()
    local cf = Config.PhoneWebRTC or {}
    local ttl = tonumber(cf.ttlSeconds) or DEFAULT_TTL_SECONDS
    if ttl < 60 then ttl = 60 end
    if ttl > 86400 then ttl = 86400 end
    return math.floor(ttl)
end

---@return number
local function resolveRefreshSkewSeconds()
    local cf = Config.PhoneWebRTC or {}
    local skew = tonumber(cf.refreshSkewSeconds) or DEFAULT_REFRESH_SKEW_SECONDS
    if skew < 30 then skew = 30 end
    return math.floor(skew)
end

---@return number
local function resolveRetryMs()
    local cf = Config.PhoneWebRTC or {}
    local v = tonumber(cf.retryOnFailMs) or DEFAULT_RETRY_MS
    if v < 5000 then v = 5000 end
    return math.floor(v)
end

---@param iceServers table[]
---@return table[]
local function sanitizeIceServers(iceServers)
    local sanitized = {}
    if type(iceServers) ~= 'table' then return sanitized end
    for i = 1, #iceServers do
        local entry = iceServers[i]
        if type(entry) == 'table' and entry.urls then
            local cleaned = {
                urls = entry.urls,
                username = type(entry.username) == 'string' and entry.username or nil,
                credential = type(entry.credential) == 'string' and entry.credential or nil,
            }
            sanitized[#sanitized + 1] = cleaned
        end
    end
    return sanitized
end

---@return string[]
local function maskedSummary()
    local out = {}
    for i = 1, #cachedIceServers do
        local entry = cachedIceServers[i]
        local urls = entry.urls
        if type(urls) == 'table' then
            for j = 1, #urls do
                out[#out + 1] = tostring(urls[j])
            end
        elseif type(urls) == 'string' then
            out[#out + 1] = urls
        end
    end
    return out
end

---@param turnKeyId string
---@return string
local function maskId(turnKeyId)
    local s = tostring(turnKeyId or '')
    if #s <= 8 then return s end
    return s:sub(1, 4) .. '…' .. s:sub(-4)
end

---@param onComplete? fun(success: boolean)
local function fetchCredentials(onComplete)
    if refreshing then
        if onComplete then onComplete(false) end
        return
    end
    local cf = Config.PhoneWebRTC
    if not cf or not isEnabled() then
        if onComplete then onComplete(false) end
        return
    end

    local turnKeyId = Core.trim(cf.turnKeyId)
    local apiToken = Core.trim(cf.apiToken)
    if turnKeyId == '' or apiToken == '' then
        print('^1[phone][cloudflare-turn] turnKeyId/apiToken empty after trim — check config/main.lua^0')
        if onComplete then onComplete(false) end
        return
    end

    refreshing = true
    local ttl = resolveTtlSeconds()
    local url = ('https://rtc.live.cloudflare.com/v1/turn/keys/%s/credentials/generate-ice-servers'):format(turnKeyId)
    local body = json.encode({ ttl = ttl })

    print(('^3[phone][cloudflare-turn] requesting credentials key=%s ttl=%ds^0'):format(maskId(turnKeyId), ttl))

    PerformHttpRequest(url, function(statusCode, responseText, _responseHeaders)
        refreshing = false

        if statusCode ~= 200 and statusCode ~= 201 then
            local hint = ''
            if statusCode == 404 then
                hint = ' (404 = TURN key not found; make sure you created a Realtime TURN App at https://dash.cloudflare.com/?to=/:account/calls and use its "TURN Token ID", NOT a Realtime SFU App ID)'
            elseif statusCode == 401 or statusCode == 403 then
                hint = ' (auth failed; verify the API Token belongs to the same TURN App)'
            elseif statusCode == 0 or statusCode == -1 then
                hint = ' (network/HTTP layer failure; ensure outbound HTTPS is allowed)'
            end
            print(('^1[phone][cloudflare-turn] credential fetch failed: status=%s key=%s body=%s%s^0'):format(
                tostring(statusCode), maskId(turnKeyId), tostring(responseText), hint
            ))
            if onComplete then onComplete(false) end
            return
        end

        local ok, parsed = pcall(json.decode, responseText)
        if not ok or type(parsed) ~= 'table' or type(parsed.iceServers) ~= 'table' then
            print(('^1[phone][cloudflare-turn] unexpected response payload: %s^0'):format(tostring(responseText)))
            if onComplete then onComplete(false) end
            return
        end

        cachedIceServers = sanitizeIceServers(parsed.iceServers)
        expiresAtMs = (os.time() + ttl) * 1000
        print(('^2[phone][cloudflare-turn] credentials refreshed (ttl=%ds, servers=%d)^0'):format(
            ttl, #cachedIceServers
        ))
        if onComplete then onComplete(true) end
    end, 'POST', body, {
        ['Authorization'] = 'Bearer ' .. apiToken,
        ['Content-Type'] = 'application/json',
    })
end

---@return table[]
function CloudflareTurn.getIceServers()
    if not isEnabled() then return {} end
    if #cachedIceServers == 0 then return {} end
    return cachedIceServers
end

---@return boolean
function CloudflareTurn.isEnabled()
    return isEnabled()
end

---Force a credential refresh on demand (e.g. admin command).
---@param onComplete? fun(success: boolean)
function CloudflareTurn.refresh(onComplete)
    fetchCredentials(onComplete)
end

---@return string[]
function CloudflareTurn.describe()
    return maskedSummary()
end

local function startRefreshLoop()
    if started then return end
    started = true

    CreateThread(function()
        while true do
            if not isEnabled() then
                Wait(FALLBACK_REFRESH_MS)
            else
                local nowMs = os.time() * 1000
                local skewMs = resolveRefreshSkewSeconds() * 1000

                if #cachedIceServers == 0 or expiresAtMs == 0 or nowMs >= (expiresAtMs - skewMs) then
                    local done = false
                    local succeeded = false
                    fetchCredentials(function(ok)
                        succeeded = ok == true
                        done = true
                    end)

                    local waited = 0
                    while not done and waited < 10000 do
                        Wait(200)
                        waited = waited + 200
                    end

                    if not succeeded then
                        Wait(resolveRetryMs())
                    end
                else
                    local untilRefreshMs = (expiresAtMs - skewMs) - nowMs
                    if untilRefreshMs < 1000 then untilRefreshMs = 1000 end
                    if untilRefreshMs > 3600000 then untilRefreshMs = 3600000 end
                    Wait(untilRefreshMs)
                end
            end
        end
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    startRefreshLoop()
end)

CreateThread(function()
    Wait(0)
    startRefreshLoop()
end)

RegisterCommand('phone:turn:status', function(source)
    if source ~= 0 then return end
    if not isEnabled() then
        print('^3[phone][cloudflare-turn] disabled in config (set enabled=true and provide turnKeyId/apiToken).^0')
        return
    end
    local servers = maskedSummary()
    print(('^2[phone][cloudflare-turn] cached urls=%d, expiresAt=%s^0'):format(
        #servers,
        expiresAtMs > 0 and os.date('%Y-%m-%d %H:%M:%S', math.floor(expiresAtMs / 1000)) or 'n/a'
    ))
    for i = 1, #servers do
        print(('  - %s'):format(servers[i]))
    end
end, true)

RegisterCommand('phone:turn:refresh', function(source)
    if source ~= 0 then return end
    if not isEnabled() then
        print('^3[phone][cloudflare-turn] disabled; nothing to refresh.^0')
        return
    end
    print('^3[phone][cloudflare-turn] manual refresh requested...^0')
    fetchCredentials(function(ok)
        print(('^%d[phone][cloudflare-turn] manual refresh %s^0'):format(ok and 2 or 1, ok and 'succeeded' or 'failed'))
    end)
end, true)

_G.CloudflareTurn = CloudflareTurn
