local securedFileTypes = {
    'image',
    'audio',
    'video'
}

local FIVEMESH_API = 'https://api.fivemesh.io/v1'
local FIVEMANAGE_API = 'https://api.fivemanage.com/api/v3'

local defaultFolders = {
    image = 'images',
    audio = 'audios',
    video = 'videos'
}

---@return string
local function getFivemanageToken()
    local token = fivemanage and fivemanage.token or ''
    return type(token) == 'string' and token:gsub('^%s+', ''):gsub('%s+$', '') or ''
end

---@return string
local function getFivemeshKey()
    local key = fivemesh and fivemesh.apiKey or ''
    return type(key) == 'string' and key:gsub('^%s+', ''):gsub('%s+$', '') or ''
end

---Resolves which media host should be used. FiveMesh wins when an api key is set.
---@return 'fivemesh'|'fivemanage'|nil
local function resolveProvider()
    if getFivemeshKey() ~= '' then return 'fivemesh' end
    if getFivemanageToken() ~= '' then return 'fivemanage' end
    return nil
end

---@param value string
---@return string
local function urlEncode(value)
    return (tostring(value):gsub('[^%w%-%_%.%~%/%,]', function(char)
        return ('%%%02X'):format(char:byte())
    end))
end

---Builds `phone/images` style CDN paths from the configured base path and folder.
---@param fileType string
---@return string
local function buildCdnPath(fileType)
    local base = fivemesh and fivemesh.path or ''
    if type(base) ~= 'string' then base = '' end
    base = base:gsub('^/+', ''):gsub('/+$', '')

    local folders = fivemesh and fivemesh.folders or nil
    local folder = type(folders) == 'table' and folders[fileType] or defaultFolders[fileType]
    if type(folder) ~= 'string' then folder = defaultFolders[fileType] or fileType end
    folder = folder:gsub('^/+', ''):gsub('/+$', '')

    if base == '' then return folder end
    if folder == '' then return base end
    return ('%s/%s'):format(base, folder)
end

---@param fileType string
---@return string
local function buildFivemeshQuery(fileType)
    local params = {
        ('path=%s'):format(urlEncode(buildCdnPath(fileType))),
        'maxFiles=1'
    }

    local expiresIn = tonumber(fivemesh and fivemesh.expiresIn) or 0
    if expiresIn > 0 then
        params[#params + 1] = ('expiresIn=%d'):format(math.floor(expiresIn))
    end

    local sizes = fivemesh and fivemesh.maxFileSize or nil
    local maxFileSize = type(sizes) == 'table' and tonumber(sizes[fileType]) or nil
    if maxFileSize and maxFileSize > 0 then
        params[#params + 1] = ('maxFileSize=%d'):format(math.floor(maxFileSize))
    end

    if fivemesh and fivemesh.restrictMimeTypes then
        local mimeTypes = type(fivemesh.mimeTypes) == 'table' and fivemesh.mimeTypes[fileType] or nil
        if type(mimeTypes) == 'string' and mimeTypes ~= '' then
            params[#params + 1] = ('allowedMimeTypes=%s'):format(urlEncode(mimeTypes))
        end
    end

    return table.concat(params, '&')
end

---@param fileType string
---@return { ok: boolean, presignedUrl?: string, provider?: string, error?: string }
local function requestFivemeshUploadUrl(fileType)
    local url = ('%s/presigned-url?%s'):format(FIVEMESH_API, buildFivemeshQuery(fileType))
    local promise = promise.new()

    PerformHttpRequest(url, function(status, text, _)
        local data = text and json.decode(text) or nil
        if not data then
            Error('FiveMesh presigned url request failed', status, text)
            return promise:resolve({
                ok = false,
                error = ('FiveMesh request failed (HTTP %s)'):format(tostring(status))
            })
        end

        if data.success ~= true then
            local err = type(data.error) == 'table' and data.error or {}
            Error('Failed to get FiveMesh upload url', err.code, err.message)
            return promise:resolve({
                ok = false,
                error = err.message or ('FiveMesh returned an error (%s)'):format(err.code or tostring(status))
            })
        end

        local uploadUrl = type(data.uploadUrl) == 'string' and data.uploadUrl or ''
        if uploadUrl == '' then
            return promise:resolve({
                ok = false,
                error = 'Upload URL is empty in FiveMesh response'
            })
        end

        promise:resolve({
            ok = true,
            provider = 'fivemesh',
            presignedUrl = uploadUrl
        })
    end, 'GET', nil, {
        Authorization = ('Bearer %s'):format(getFivemeshKey())
    })

    return Citizen.Await(promise)
end

---@param fileType string
---@return { ok: boolean, presignedUrl?: string, provider?: string, error?: string }
local function requestFivemanagePresignedUrl(fileType)
    local url = ('%s/file/presigned-url?fileType=%s'):format(FIVEMANAGE_API, fileType)
    local promise = promise.new()

    PerformHttpRequest(url, function(err, text, headers)
        local data = text and json.decode(text) or nil
        if not data then
            return promise:resolve({
                ok = false,
                error = 'Failed to decode presigned response'
            })
        end
        if data.status ~= 'ok' then
            Error('Failed to get presigned url', data)
            return promise:resolve({
                ok = false,
                error = data.message or 'Failed to get presigned URL from FiveManage'
            })
        end

        local presignedUrl = data.data and data.data.presignedUrl or ''
        if presignedUrl == '' then
            return promise:resolve({
                ok = false,
                error = 'Presigned URL is empty in FiveManage response'
            })
        end

        promise:resolve({
            ok = true,
            provider = 'fivemanage',
            presignedUrl = presignedUrl
        })
    end, 'GET', nil, {
        Authorization = getFivemanageToken()
    })

    return Citizen.Await(promise)
end

---Creates an upload URL on the configured media host (FiveMesh or FiveManage).
---@param fileType 'image'|'audio'|'video'
---@return { ok: boolean, presignedUrl?: string, provider?: string, error?: string }
function GetPhoneUploadUrl(fileType)
    if not table.includes(securedFileTypes, fileType) then
        Error('Invalid file type', fileType)
        return {
            ok = false,
            error = 'Invalid file type'
        }
    end

    local provider = resolveProvider()
    if not provider then
        Error('No media host configured, please set fivemesh.apiKey (https://docs.fivemesh.io) or fivemanage.token in the server/webhooks.lua file. If you are using custom server you can remove this error. its open source')
        return {
            ok = false,
            error = 'No media host configured. Set fivemesh.apiKey or fivemanage.token in server/webhooks.lua'
        }
    end

    if provider == 'fivemesh' then
        return requestFivemeshUploadUrl(fileType)
    end

    return requestFivemanagePresignedUrl(fileType)
end

---@param source number
---@param fileType string
---@return { ok: boolean, presignedUrl?: string, provider?: string, error?: string }
lib.callback.register('phone:getPresignedUrl', function(source, fileType)
    local result = GetPhoneUploadUrl(fileType)
    if not result.ok then
        Error('phone:getPresignedUrl failed for source', source, result.error)
    end
    return result
end)
