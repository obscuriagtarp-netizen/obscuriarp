-- Your discord webhook urls

Config.ShowWebhookIP = false

_G.webhook = {
    -- Global fallback — used when an app-specific URL is empty
    global = '',

    pictagram = '',   -- posts, comments, likes, follows, stories, live
    tweedle = '',     -- tweets, replies, likes, reposts, follows, profile
    beatzy = '',      -- videos, comments, likes, follows, profile, account delete
    yellowpages = '', -- listing create / delete
    weazel = '',      -- article create / update / delete
}

_G.fivemanage = {
    -- If you want to use camera, voice recorder, and video recorder, you need to set a fivemanage token here.
    -- If you have custom server. You can edit the qs-smartphone/web/build/custom-upload.js file to use your own upload function.
    token = ''
}

-- FiveMesh CDN (https://docs.fivemesh.io) — alternative media host for camera / voice / video uploads.
-- If `apiKey` is filled in, the phone uses FiveMesh instead of FiveManage. Leave it empty to keep FiveManage.
_G.fivemesh = {
    -- Service key created in the FiveMesh dashboard (Account -> API keys). Needs the `cdn:write` permission.
    -- Never expose this key to the client, it is only used server side.
    apiKey = '',

    -- Base CDN folder for every phone upload. Must be inside the key's allowed path prefix.
    path = 'phone',

    -- Sub folders per file type, created under `path` (e.g. phone/images/photo-1730000000.webp)
    folders = {
        image = 'images',
        audio = 'audios',
        video = 'videos'
    },

    -- Lifetime of the generated upload URL in seconds (the API clamps it to the workspace maximum).
    expiresIn = 300,

    -- Max upload size per file type, in bytes. Set to 0 to let FiveMesh use the workspace default.
    maxFileSize = {
        image = 12 * 1024 * 1024,  -- 12 MB
        audio = 25 * 1024 * 1024,  -- 25 MB
        video = 100 * 1024 * 1024  -- 100 MB
    },

    -- Send an `allowedMimeTypes` allow-list with the upload URL. Recorders may report exotic mime
    -- types (audio/webm;codecs=opus etc.), so this is disabled by default to avoid rejected uploads.
    restrictMimeTypes = false,
    mimeTypes = {
        image = 'image/webp,image/png,image/jpeg',
        audio = 'audio/webm,audio/ogg,audio/mpeg,audio/mp4,audio/wav',
        video = 'video/webm,video/mp4'
    }
}
