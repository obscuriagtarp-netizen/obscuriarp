--──────────────────────────────────────────────────────────────────────────────
--  Quasar Store · Configuration Guidelines
--──────────────────────────────────────────────────────────────────────────────
--  This configuration file defines all adjustable parameters for qs-smartphone.
--  Comments are standardized to indicate which parts are safe to edit.
--
--  • [EDIT] – Safe to modify. Adjust as needed for your server.
--  • [INFO] – Explains purpose or behavior of a variable/block.
--  • [ADV]  – Advanced settings. Edit only if you understand the logic.
--  • [CORE] – Core functionality. Avoid changes unless you are a developer.
--  • [AUTO] – Automatically handled. Never modify manually.
--
--  Always make a backup before editing configuration files.
--  Documentation: https://docs.quasar-store.com/
--──────────────────────────────────────────────────────────────────────────────

--──────────────────────────────────────────────────────────────────────────────
-- Language Selection                                                          [EDIT]
-- [INFO] Select your main language. UI JSON lives in web/locales/*.json (NUI + Lua). For Vite dev (`ui_page` localhost), set Config.LocalePath below.
--        You can create your own locale if it doesn’t exist yet.
--──────────────────────────────────────────────────────────────────────────────
Config                      = {}

Config.Locale               = 'pt'                       -- [EDIT] Language code. Available: ar, bg, da, de, el, en, es, fa, fr, hi, hu, it, ja, ko, nl, pt, ro, ru, tr, zh-CN
Config.Path                 = 'nui://qs-smartphone/web/' -- [ADV]  Base NUI path (keep if you didn't move /web).
Config.ImagePath            = Config.Path .. 'images/'   -- [ADV]  Asset path for images.
Config.LocalePath           = Config.Path .. 'locales/'
Config.PhoneUiLocales       = {
    'ar', 'ba', 'bg', 'bn', 'br', 'ca', 'zh', 'cs', 'da', 'de', 'dk', 'el', 'en', 'es', 'fa',
    'fi', 'fr', 'he', 'hi', 'hu', 'id', 'it', 'ja', 'ko', 'ms', 'nl', 'no', 'pl', 'pt', 'ro',
    'ru', 'sl', 'sv', 'th', 'tr', 'uk', 'et', 'hr', 'lt', 'lv', 'sk', 'sw', 'ur', 'vi', 'sr'
}

--──────────────────────────────────────────────────────────────────────────────
-- Framework Detection                                                         [AUTO]
-- [INFO] Automatically detects your framework (ESX, QBCore, or vRP).
-- [INFO] If renamed, edit the framework name here or create adapters inside:
--        client/custom/framework/* and server/custom/framework/*
--──────────────────────────────────────────────────────────────────────────────

-- WARNING: VRP IS EXPERIMENTAL AND MAY NOT WORK CORRECTLY.
-- WARNING: VRP IS EXPERIMENTAL AND MAY NOT WORK CORRECTLY.
-- WARNING: VRP IS EXPERIMENTAL AND MAY NOT WORK CORRECTLY.
local frameworks            = {
    ['es_extended'] = 'esx',
    ['qb-core'] = 'qb',
    ['qbx_core'] = 'qb',
    ['vrp'] = 'vrp',
}

Config.Framework            = DependencyCheck(frameworks) or 'standalone' -- [AUTO]
Config.QBX                  = GetResourceState('qbx_core') == 'started'

--──────────────────────────────────────────────────────────────────────────────
-- Inventory Detection                                                         [AUTO]
-- [INFO] Detects which inventory system is running.
-- [INFO] To integrate another, create an adapter inside server/custom/inventory/adapters/.
--──────────────────────────────────────────────────────────────────────────────
local inventories           = { -- [CORE]
    ['qs-inventory']      = 'qs-inventory',
    ['qb-inventory']      = 'qb-inventory',
    ['l2s-inventory']     = 'qb-inventory',
    ['origen_inventory']  = 'origen_inventory',
    ['ps-inventory']      = 'ps-inventory',
    ['ox_inventory']      = 'ox_inventory',
    ['core_inventory']    = 'core_inventory',
    ['codem-inventory']   = 'codem-inventory',
    ['tgiann-inventory']  = 'tgiann-inventory',
    ['ak47_inventory']    = 'ak47_inventory',
    ['ak47_qb_inventory'] = 'ak47_qb_inventory'
}
Config.Inventory            = DependencyCheck(inventories) or 'standalone' -- [AUTO]

--──────────────────────────────────────────────────────────────────────────────
-- Default Stash Data                                                          [EDIT]
-- [INFO] Defines the base stash capacity for created shops.
--──────────────────────────────────────────────────────────────────────────────
Config.DefaultStashData     = {
    maxweight = 1000000, -- [EDIT] Maximum weight capacity.
    slots = 30,          -- [EDIT] Total number of item slots.
}

local keys                  = { -- [CORE]
    ['mono_carkeys']   = 'mono_carkeys',
    ['qb-vehiclekeys'] = 'qb-vehiclekeys',
    ['qs-vehiclekeys'] = 'qs-vehiclekeys',
    ['vehicle_keys']   = 'vehicle_keys',
    ['wasabi_carlock'] = 'wasabi_carlock',
    ['mk_vehiclekeys'] = 'mk_vehiclekeys',
    ['okokGarage']     = 'okokGarage'
}
Config.Vehiclekeys          = DependencyCheck(keys) or 'none' -- [AUTO]

--- web/images/wallpapers/b1.webp — fallback filename when `DefaultWallpaperId` has no match in `Wallpapers`.
Config.DefaultWallpaperFile = 'b9.webp'

Config.Wallpapers           = {}
for i = 1, 34 do
    Config.Wallpapers[#Config.Wallpapers + 1] = {
        id = 'b' .. i,
        image = 'wallpapers/b' .. i .. '.webp',
    }
end
Config.DefaultWallpaperId = 'b9'

local function resolveDefaultWallpaperImagePath()
    local id = Config.DefaultWallpaperId
    if type(id) == 'string' and id ~= '' and type(Config.Wallpapers) == 'table' then
        for idx = 1, #Config.Wallpapers do
            local row = Config.Wallpapers[idx]
            if type(row) == 'table' and row.id == id and type(row.image) == 'string' and row.image ~= '' then
                return row.image
            end
        end
    end
    return 'wallpapers/' .. Config.DefaultWallpaperFile
end

local defaultWallpaperImagePath = resolveDefaultWallpaperImagePath()
local defaultWallpaperUrl       = Config.ImagePath .. defaultWallpaperImagePath

Config.DefaultSettings          = {
    profile = {
        name = '',
        picture = '',
        phoneNumber = ''
    },
    general = {
        locale = Config.Locale
    },
    appearance = {
        darkMode = false,
        brightness = 100,
        scale = 0.85,
        frameAccent = '#ed5700',
        volume = 100,
        homeAppIconVariant = 'default'
    },
    wallpaper = {
        home = defaultWallpaperUrl,
        lock = defaultWallpaperUrl,
    },
    lockScreenCustomization = {
        timeColor = '#ffffff',
        timeFont = 'quos',
        dateWidget = 'classic',
        widgets = {}
    },
    privacy = {
        streamerMode = false,
        hiddenNumber = false
    },
    security = {
        pinCode = nil,
        faceUnlock = false,
        pinConsecutiveFailures = 0,
        pinLockoutStrikes = 0,
        pinLockoutUntil = nil,
        auraGlobalPeekHotkey = false,
        auraOnLockScreenEnabled = true,
    },
    notifications = {
        silentMode = false,
        type = 'count'
    },
    connectivity = {
        airplane = false,
        bluetooth = false
    },
    display = {
        batteryPercentage = true,
        localTime = false,
        disableBlur = false,
    },
    ringtone = '',
    appNotifications = {},
    onboarding = {
        completed = false,
        passcodeMode = nil,
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Targeting Settings                                                          [EDIT]
-- [INFO] Define interaction method and hitbox dimensions.
--──────────────────────────────────────────────────────────────────────────────
Config.TargetWidth              = 5.0   -- [EDIT] Interaction area width.
Config.TargetHeight             = 5.0   -- [EDIT] Interaction area height.
Config.UseTarget                = false -- [EDIT] true = qb-target/ox_target | false = disable target system.

-- Debug Mode                                                                  [EDIT]
-- [INFO] Enables or disables verbose console logging. Keep off in production.
--──────────────────────────────────────────────────────────────────────────────
Config.Debug                    = false  -- [EDIT]
Config.ZoneDebug                = false
Config.PhoneProfiler            = false -- [EDIT] Dev profiler: API overrides, /phoneprofiler, metrics. Keep false on production.

--──────────────────────────────────────────────────────────────────────────────
-- Phone Opening Settings                                                      [EDIT]
-- [INFO] Controls how the phone can be opened (keybind and/or item usage).
--──────────────────────────────────────────────────────────────────────────────
Config.Phone                    = {
    openKey = 'K',        -- [EDIT] Key to open phone (RegisterKeyMapping).
    openByKeyPress = true, -- [EDIT] Allow opening phone with key press.
    requireItem = true,    -- [EDIT] Require phone item in inventory to open.
    itemName = 'phone',    -- [EDIT] Item name for phone (used if requireItem = true).
}

--──────────────────────────────────────────────────────────────────────────────
-- Aura AI (optional DLC: ensure [addons]/qs-smartphone-aura)                  [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.Aura                     = {
    enabled = true,
    addonResource = 'qs-smartphone-aura',
    --- RegisterKeyMapping key for push-to-talk while phone is open (e.g. B).
    pushToTalkKey = 'B',
    maxRecordingSeconds = 30,
    --- MediaRecorder + Blob type (same default as qs-housing STT). Avoid `audio/webm;codecs=opus` if decode fails in NUI.
    mimeType = 'audio/webm',
    --- Minimum PTT hold (ms) before transcribe; matches qs-housing voice `stt.minRecordMs` default.
    minRecordMs = 450,
    --- Whisper / worker language hint: turkish, english, etc. Use `auto` to omit language hint.
    whisperLanguage = 'auto',
}

-- [EDIT] Face Unlock mask detection (ped component drawable). Tune for your clothing pack.
Config.FaceUnlock               = {
    maskComponent = 1,      -- [INFO] GTA component id for masks (usually 1).
    minDrawableForMask = 1, -- [INFO] drawable >= this counts as wearing a mask (0 = none for most packs).
}

--──────────────────────────────────────────────────────────────────────────────
-- Phone Call Behavior                                                         [EDIT]
-- [INFO] Controls ringing timeout and voicemail behavior for unanswered calls.
--──────────────────────────────────────────────────────────────────────────────
Config.PhoneCall                = {
    ringTimeoutMs = 10000,                -- [EDIT] Unanswered call timeout in milliseconds.
    playVoicemailOnTimeout = true,        -- [EDIT] Play voicemail prompt for caller on timeout.
    voicemailSound = 'call/voicemail_en', -- [EDIT] Relative sound path under web/sounds (without .ogg).
}

--──────────────────────────────────────────────────────────────────────────────
-- Radio app                     [EDIT]
-- [INFO] Used when the optional `phone-radio` resource registers the store listing.
--──────────────────────────────────────────────────────────────────────────────
Config.RadioPrivateChannels     = {
    {
        label = 'Ambulance Channel',
        frequency = 112,
        password = '1983221',
    },
    {
        label = 'Police Channel',
        frequency = 113,
        password = '3983221',
    },
}

-- Public phone booth (applications/phone-booth): outbound anonymous caller id from a booth (with or without a phone item).
Config.PhoneBooth               = {
    publicCallerNumber = '555-0199', -- [EDIT] Must match PhoneBoothConfig.publicCallerNumber in phone-booth resource.
    chargeMaxDistance = 6.0,         -- [EDIT] Max distance from a booth (GlobalState coords) for bank charges.
}

--──────────────────────────────────────────────────────────────────────────────
-- Share sheet (Bluetooth + proximity, AirDrop-style)                           [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.ShareSheet               = {
    radius = 10.0,             -- [EDIT] Max distance (meters) between sender and receiver.
    sendTimeoutMs = 60000,     -- [EDIT] How long the sender waits for accept/reject.
    maxPayloadChars = 8000,    -- [EDIT] Max JSON size for share body (approximate).
    maxGalleryShareItems = 20, -- [EDIT] Max gallery items per single group-share request.
}

--──────────────────────────────────────────────────────────────────────────────
-- Proximity capture (WebRTC mesh for nearby player mics during recording)     [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.ProximityCapture         = {
    enabled = true,         -- [EDIT] Master switch for proximity audio in camera/voice recordings.
    radius = 12.0,          -- [EDIT] Max distance (meters) between recorder and publisher mic.
    maxPublishers = 8,      -- [EDIT] Max simultaneous nearby publishers per recording session.
    requireTalking = false, -- [EDIT] When true, publishers only stream while Mumble reports talking.
    evalIntervalMs = 1500,  -- [EDIT] Server re-evaluates nearby players while a session is active.
}

--──────────────────────────────────────────────────────────────────────────────
-- Ringtones (incoming call + settings)                                       [EDIT]
-- [INFO] Full NUI URLs for ringtones (server audio: qs-3dsound or mx-surround preferred; xsound only if neither is running).
--──────────────────────────────────────────────────────────────────────────────
local ringtoneBase              = Config.Path .. 'sounds/ringtones/'
Config.Ringtones                = {
    defaultRingtone = ringtoneBase .. 'default.mp3',
    ringtones = {
        { url = ringtoneBase .. 'default.mp3',   name = 'Pear' },
        { url = ringtoneBase .. 'classic.mp3',   name = 'Classic' },
        { url = ringtoneBase .. 'XianNomi.mp3',  name = 'XianNomi' },
        { url = ringtoneBase .. 'yourphone.mp3', name = 'Your Phone Ringing' },
        { url = ringtoneBase .. 'osito.mp3',     name = 'Osito Gominola' },
        { url = ringtoneBase .. 'faded.mp3',     name = 'Faded' },
        { url = ringtoneBase .. 'missyou.mp3',   name = 'Miss You' },
        { url = ringtoneBase .. 'brainrot.mp3',  name = 'Brainrot' },
        { url = ringtoneBase .. 'lifegoes.mp3',  name = 'Life Goes On' },
    },
}

Config.PhoneWebRTC              = {
    debugRelay = true, -- [EDIT] Prints server relay/preflight diagnostics in console.
    -- Cloudflare Realtime TURN (recommended for remote NAT/CGNAT players).
    -- IMPORTANT: This is the Realtime *TURN* product, NOT Realtime SFU. They are separate apps.
    --   1) Open https://dash.cloudflare.com/?to=/:account/calls
    --   2) Go to the "TURN" tab → "Create TURN App".
    --   3) Copy "TURN Token ID" → turnKeyId.
    --      Copy "API Token"    → apiToken (Bearer secret, shown only ONCE on creation).
    --   4) Set enabled = true. Server fetches credentials on start and auto-refreshes before TTL.
    -- DO NOT paste the SFU "App ID / App Secret" here — that endpoint returns 404.
    -- This is open source you can access it in server/modules/cloudflare_turn.lua
    cloudflare = {
        enabled = false,          -- [EDIT] Master switch.
        turnKeyId = '',           -- [EDIT] Cloudflare Realtime TURN Token ID (App ID).
        apiToken = '',            -- [EDIT] Cloudflare Realtime TURN API Token (Bearer).
        ttlSeconds = 86400,       -- [EDIT] Credential TTL in seconds (max 86400 = 24h).
        refreshSkewSeconds = 600, -- [EDIT] Refresh this many seconds before TTL expiry.
        retryOnFailMs = 30000,    -- [EDIT] Retry interval if Cloudflare API call fails.
    },
    iceServers = {
        {
            urls = 'stun:stun.l.google.com:19302'
        },
        -- Example TURN failover (recommended for remote NAT/CGNAT players):
        -- Keep UDP + TCP + TLS endpoints to maximize traversal success.
        -- {
        --     urls = {
        --         'turn:turn-1.example.com:3478?transport=udp',
        --         'turn:turn-1.example.com:3478?transport=tcp',
        --         'turns:turn-1.example.com:5349?transport=tcp',
        --     },
        --     username = 'user',
        --     credential = 'pass'
        -- },
        -- {
        --     urls = {
        --         'turn:turn-2.example.com:3478?transport=udp',
        --         'turn:turn-2.example.com:3478?transport=tcp',
        --         'turns:turn-2.example.com:5349?transport=tcp',
        --     },
        --     username = 'user',
        --     credential = 'pass'
        -- },
    },
    -- captureFps: canvas.captureStream FPS; minCaptureLongEdge: min internal bitmap long edge (px);
    -- maxBitrate / minBitrate: encoder targets (bps); maxFramerate: RTP encoding cap.
    video = {
        captureFps = 30,
        minCaptureLongEdge = 720,
        maxBitrate = 2500000,
        minBitrate = 600000,
        maxFramerate = 30,
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Mail Application                                                            [EDIT]
-- [INFO] Fixed domain suffix for in-game mail addresses (NUI shows local part only).
--──────────────────────────────────────────────────────────────────────────────
Config.Mail                     = {
    emailSuffix = '@cloud.com', -- [EDIT] Must include @ (e.g. @yourserver.com).
    systemFromEmail = 'noreply@smartphone.local',
    systemFromName = 'Mail',
}

--──────────────────────────────────────────────────────────────────────────────
-- Messages (in-app payments)                                                  [EDIT]
-- [INFO] Payment uses framework accounts (ESX: money/bank; QB mapped in custom).
--──────────────────────────────────────────────────────────────────────────────
Config.Messages                 = {
    PaymentAccount = 'bank',
    PaymentMin = 1,
    PaymentMax = 999999,
    PaymentStep = 10,
    PaymentCurrencySymbol = '$',
}

--──────────────────────────────────────────────────────────────────────────────
-- Wallet Application                                                          [EDIT]
-- [INFO] P2P transfers by phone number; recipient must be online (same as Messages payments).
--──────────────────────────────────────────────────────────────────────────────
Config.Wallet                   = {
    account = 'bank',
    minAmount = 1,
    maxAmount = 999999,
    recentLimit = 8,
    transactionsPageSize = 40,
}

--──────────────────────────────────────────────────────────────────────────────
-- Billing Systems                                                             [AUTO]/[EDIT]
-- [INFO] Auto-detects a billing resource. Fallback is standalone (qs_phone_bills).
-- [INFO] icon may be an f7 icon ("f7:shield_fill") or a direct image URL.
--──────────────────────────────────────────────────────────────────────────────
local billings                  = { -- [CORE]
    ['qs-billing']      = 'qs',
    ['okokBilling']     = 'okok',
    ['esx_billing']     = 'esx_billing',
    ['codem-billingv2'] = 'codemv2',
    ['RxBilling']       = 'RxBilling',
}
Config.Billing                  = DependencyCheck(billings) or 'standalone' -- [AUTO]

Config.BillJobs                 = { 'police', 'ambulance' }                 -- [EDIT] Jobs allowed to use /sendbill (standalone)

---@type table<string, { label: string, icon: string }>
Config.BillingJobs              = { -- [EDIT] Job key → label + avatar (f7:… or URL)
    police = { label = 'LSPD', icon = 'f7:shield_fill' },
    ambulance = { label = 'EMS', icon = 'f7:cross_case_fill' },
}

Config.BillingFallbackAvatar    = 'f7:doc_text_fill' -- [EDIT] Used when provider/job has no avatar

--──────────────────────────────────────────────────────────────────────────────
-- Clock Application                                                           [EDIT]
-- [INFO] World clock tab cities (IANA timeZone). offsetLabel is fallback for NUI Intl.
--──────────────────────────────────────────────────────────────────────────────
Config.Clock                    = {
    WorldCities = {
        { id = 'los-santos', name = 'Los Santos', timeZone = 'America/Los_Angeles', offsetLabel = 'Today, GMT-7' },
        { id = 'london',     name = 'London',     timeZone = 'Europe/London',       offsetLabel = 'Today, GMT+0' },
        { id = 'istanbul',   name = 'Istanbul',   timeZone = 'Europe/Istanbul',     offsetLabel = 'Today, GMT+3' },
        { id = 'tokyo',      name = 'Tokyo',      timeZone = 'Asia/Tokyo',          offsetLabel = 'Today, GMT+9' },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Metadata System                                                             [EDIT]
-- [INFO] Controls phone metadata behavior for inventory systems with metadata support.
--        When enabled, each phone item has unique data (id, phoneNumber, owner).
--        When disabled, phone data is tied to player identifier.
--──────────────────────────────────────────────────────────────────────────────
Config.MetaSystem               = {
    enabled = false,            -- [EDIT] Enable unique phone metadata per item.
    phoneNumberPrefix = '01', -- [EDIT] Prefix for generated phone numbers. MUST be a string (use '06' not 06).
    phoneNumberLength = 7,     -- [EDIT] Length of the random part (excluding prefix).
    -- [EDIT] On-screen grouping mask (X = digit). Must match total digits = prefix + phoneNumberLength.
    -- US default (10 digits): '(XXX) XXX-XXXX'
    -- French mobile (06 + 8 = 10 digits): 'XX XX XX XX XX'
    phoneNumberMask = '(XX) XXX-XXXX',
}

--──────────────────────────────────────────────────────────────────────────────
-- Service / emergency numbers                                                 [EDIT]
-- [INFO] Fixed lines (police, EMS, fire…) that route calls to online job members.
-- [INFO] Dialing these numbers does not require a player SIM to own the line.
-- [INFO] Uses the Call Interception API internally (rings all available employees; first to accept is assigned).
-- [INFO] Also injected as read-only Phone contacts (Favorites + Contacts). label/avatar
-- [INFO] override any user contact with the same number. avatar = URL or imagePath path.
--──────────────────────────────────────────────────────────────────────────────
Config.ServiceNumbers           = {
    enabled = true, -- [EDIT] Master toggle for built-in service lines.
    lines = {
        -- US-style emergency (customize numbers/jobs/avatar for your city)
        -- avatar: optional URL or path under Config.ImagePath; empty = initials from label
        { number = '911', label = 'Emergency Services', avatar = '', jobs = { 'police', 'ambulance' }, minGrade = 0 },
        { number = '912', label = 'Police',             avatar = '', jobs = { 'police' },              minGrade = 0 },
        { number = '913', label = 'EMS',                avatar = '', jobs = { 'ambulance' },           minGrade = 0 },
    },
}

-- Backup & transfer (inventory metadata): only effective when Config.MetaSystem.enabled = true
Config.Backup                   = {
    enabled = true,
    maxPerPlayer = 10,
}

--──────────────────────────────────────────────────────────────────────────────
-- Battery & Charging System                                                    [EDIT]
-- [INFO] Battery drain is computed client-side for performance.
-- [INFO] Server only handles persistence checkpoints and charging ownership.
-- [INFO] simulateOfflineClosedDrain: wall-clock drain while disconnected (usually leave false).
--──────────────────────────────────────────────────────────────────────────────
Config.Battery                  = {
    enabled = false,                     -- [EDIT] Master toggle.
    defaultPercent = 100,               -- [EDIT] Fallback battery percent.
    tickMs = 2000,                      -- [EDIT] Local simulation interval while phone open.
    idleDrainPerMinute = 0.30,          -- [EDIT] Base drain per minute.
    closedDrainPerMinute = 0.08,        -- [EDIT] Drain while phone UI is closed (in-game client only).
    simulateOfflineClosedDrain = false, -- [EDIT] If true, also drains across real disconnect time using closedDrainPerMinute.
    lowPowerThreshold = 20,             -- [EDIT] Client hint for low battery state.
    checkpoint = {
        minSeconds = 30,                -- [EDIT] Minimum seconds between server sync checkpoints.
        minPercentDelta = 3.0,          -- [EDIT] Sync if absolute change reaches this value.
    },
    apps = {                            -- [EDIT] Additional drain per minute by foreground app id.
        phone = 0.22,
        messages = 0.24,
        settings = 0.12,
        camera = 0.95,
        gallery = 0.32,
        map = 1.05,
        videocall = 1.40,
        music = 0.58,
        weather = 0.14,
        notes = 0.08,
        wallet = 0.10,
        crypto = 0.22,
        pictagram = 0.92,
        beatzy = 1.05,
        tweedle = 0.44,
        zapp = 0.42,
        zappeats = 0.36,
        marketplace = 0.38,
    },
    powerbank = {
        itemName = 'powerbank',     -- [EDIT] Inventory item used to start charging.
        chargePerMinute = 18.0,     -- [EDIT] Charge rate while powerbank is active.
        consumeOnUse = true,        -- [EDIT] true: consumes powerbank item.
        returnItemWhenDone = false, -- [EDIT] true: gives the powerbank item back when charging ends.
    },
    chargingStations = {
        marker = {
            marker = 2,                     -- [EDIT] Marker type.
            color = { 255, 255, 255, 255 }, -- [EDIT] Marker color RGBA.
            scale = vec3(0.30, 0.30, 0.20), -- [EDIT] Marker scale.
            drawDistance = 8.0,             -- [EDIT] Marker render distance.
            interactDistance = 2.0,         -- [EDIT] Interaction distance.
        },
        broadcastRadius = 80.0,             -- [EDIT] Push state updates only to nearby players.
        tickMs = 3000,                      -- [EDIT] Station charging update interval.
        -- [EDIT] Max distance from station while charging; leaving stops charging (phone removed from dock).
        chargingStayRadius = 5.0,
        -- [EDIT] qs-housing placed chargers (export API); charge rate and snapshot distance for housing-only stations.
        housingChargePerMinute = 48.0,
        housingSnapshotMaxDistance = 200.0,
        points = {
            {
                id = 'grove_ltd',
                coords = vec3(25.882116, -1341.416138, 29.397023),
                chargePerMinute = 60.0,
                enabled = true,
            },
            {
                id = 'vespucci_247',
                coords = vec3(-42.846802, -1755.070435, 29.34313),
                chargePerMinute = 60.0,
                enabled = true,
            },
            {
                id = 'alta_247',
                coords = vec3(-704.892212, -908.886719, 19.115588),
                chargePerMinute = 60.0,
                enabled = true,
            },
            {
                id = 'route68_247',
                coords = vec3(1164.968506, -317.935669, 69.10504),
                chargePerMinute = 60.0,
                enabled = true,
            },
        },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Cellular Signal & Coverage Zones                             [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.Signal                   = {
    enabled = true,
    debug = false,              -- [EDIT] Draw sphere debug (falls back to Config.ZoneDebug when nil).
    enterGraceMs = 350,         -- [EDIT] Delay before zone signal applies on enter.
    exitGraceMs = 500,          -- [EDIT] Delay before zone signal clears on exit.
    serverSyncDebounceMs = 750, -- [EDIT] Debounce client → server level sync.
    defaultLevel = 'full',      -- [EDIT] Level when outside all zones.
    zones = {
        {                       -- Mount Chiliad ridge
            id = 'chiliad_ridge',
            name = 'Mount Chiliad Ridge',
            coords = vec3(1849.0, 362.0, 113.0),
            radius = 520.0,
            level = 'none',
        },
        { -- East Chiliad cliffs
            id = 'chiliad_east',
            name = 'East Chiliad Cliffs',
            coords = vec3(1954.22, -1600.29, 380.28),
            radius = 380.0,
            level = 'none',
        },
        { -- Raton Canyon peaks
            id = 'raton_canyon',
            name = 'Raton Canyon Peaks',
            coords = vec3(747.76, 1232.28, 512.47),
            radius = 420.0,
            level = 'low',
        },
        { -- Banham Highlands
            id = 'banham_highlands',
            name = 'Banham Highlands',
            coords = vec3(-890.03, 1260.05, 490.26),
            radius = 480.0,
            level = 'low',
        },
        { -- Zancudo Ridge
            id = 'zancudo_ridge',
            name = 'Zancudo Ridge',
            coords = vec3(-697.74, 2372.03, 340.43),
            radius = 450.0,
            level = 'low',
        },
        { -- Tongva Wilderness
            id = 'tongva_wilderness',
            name = 'Tongva Wilderness',
            coords = vec3(-2601.10, 1386.12, 340.43),
            radius = 400.0,
            level = 'none',
        },
        { -- Procopio foothills
            id = 'procopio_foothills',
            name = 'Procopio Foothills',
            coords = vec3(-960.78, 4467.55, 560.81),
            radius = 520.0,
            level = 'none',
        },
        { -- North San Chianski
            id = 'san_chianski',
            name = 'North San Chianski',
            coords = vec3(758.52, 5517.47, 856.27),
            radius = 420.0,
            level = 'none',
        },
        { -- Cape Catfish ridge
            id = 'cape_catfish',
            name = 'Cape Catfish Ridge',
            coords = vec3(3204.18, 4860.45, 504.56),
            radius = 360.0,
            level = 'low',
        },
        { -- Alamo Sea east hills
            id = 'alamo_east',
            name = 'Alamo Sea East',
            coords = vec3(1560.16, 3230.91, 181.11),
            radius = 280.0,
            level = 'low',
        },
        { -- Humane Labs underground (example MLO blackout)
            id = 'humane_tunnel',
            name = 'Humane Labs Tunnel',
            coords = vec3(3525.66, 3708.26, 20.99),
            radius = 95.0,
            level = 'none',
        },
        { -- Cayo Perico (offshore dead zone until near tower)
            id = 'cayo_offshore',
            name = 'Cayo Perico Offshore',
            coords = vec3(4840.57, -5174.42, 2.0),
            radius = 650.0,
            level = 'none',
        },
    },
    policy = {
        callsMinLevel = 'low',       -- [EDIT] Minimum level to start/accept calls (`none` blocks all).
        webrtcMinLevel = 'mid',      -- [EDIT] Minimum level for video WebRTC relay.
        dropActiveCallBelow = 'low', -- [EDIT] Drop active calls when level falls below this.
        defaultAppMinLevel = 'mid',  -- [EDIT] Default minimum level for foreground apps.
        offlineApps = {              -- [EDIT] Apps usable even with `none` signal.
            'settings',
            'notes',
            'clock',
            'calculator',
            'camera',
            'gallery',
            'help',
            'backup',
            'ringtone',
            'reminders',
            'calendar',
        },
        appMinLevel = { -- [EDIT] Per-app overrides (must be >= defaultAppMinLevel or lower for offline).
            phone = 'low',
            messages = 'mid',
            mail = 'mid',
            wallet = 'mid',
            map = 'mid',
            weather = 'mid',
            store = 'mid',
            music = 'mid',
            videocall = 'mid',
            pictagram = 'mid',
            tweedle = 'mid',
            beatzy = 'mid',
            zapp = 'mid',
            zappeats = 'mid',
            marketplace = 'mid',
            crypto = 'mid',
            darkchat = 'mid',
            chitchat = 'mid',
            qchat = 'mid',
            youlink = 'mid',
            yellowpages = 'mid',
            weazel = 'mid',
            finder = 'mid',
            jobcenter = 'mid',
            houses = 'mid',
            peachstore = 'mid',
            onionbrowser = 'mid',
            health = 'mid',
            icar = 'mid',
            aventon = 'mid',
            crime = 'mid',
        },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Ambulance System Detection                                                  [AUTO]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Used to hook death/medical flows automatically if a supported resource is running.
--──────────────────────────────────────────────────────────────────────────────
local ambulances                = { -- [CORE]
    ['qb-ambulancejob']      = 'qb',
    ['esx_ambulancejob']     = 'esx',
    ['wasabi_ambulance']     = 'wasabi',
    ['ars_ambulancejob']     = 'ars',
    ['qbx_medical']          = 'qbx',
    ['p_ambulancejob']       = 'piotreq',
    ['qs-medical-creator']   = 'qs',
    ['ak47_qb_ambulancejob'] = 'ak47qb',
    ['ak47_ambulancejob']    = 'ak47',
}
Config.Ambulance                = DependencyCheck(ambulances) or 'standalone' -- [AUTO]

--──────────────────────────────────────────────────────────────────────────────
-- Emergency SOS                                                               [EDIT]
-- [INFO] Automatically messages on-duty EMS players (via the Messages app) when
--        a player dies. Reuses the existing Messages/MessagesSend pipeline, so
--        no new database tables are required.
--        - jobs: Job name(s) that should receive the SOS message.
--        - minGrade: Minimum job grade (inclusive) required to receive it.
--        - healthThreshold: 0 = only trigger on actual death. >0 = also trigger
--          when entity health drops to/below this value (legacy-style "crash" detection).
--        - cooldownSeconds: Minimum time between two SOS sends for the same player.
--        - countdownSeconds: Time the player has to cancel before it auto-sends.
--        - alertSound: Sound key played during the countdown (web/sounds/<name>.ogg).
--──────────────────────────────────────────────────────────────────────────────
Config.SOS                      = {
    enabled = false,
    jobs = { 'ambulance' },
    minGrade = 0,
    healthThreshold = 0,
    cooldownSeconds = 90,
    countdownSeconds = 10,
    alertSound = 'alarm',
}

Config.Earbuds                  = {
    enabled = false,
    itemName = 'wireless_earbuds',
    consumeOnUse = false,
    defaultRouteOnUse = 'earbuds',
    speakerBroadcastRadius = 24.0,
    relayChunkSize = 32,
}

Config.SimCard                  = {
    itemName = 'phone_sim',
    consumeOnUse = true,
}

--──────────────────────────────────────────────────────────────────────────────
-- Map Application                                                             [EDIT]
-- [INFO] Controls map tile source, streaming interval and default app blips.
--──────────────────────────────────────────────────────────────────────────────
Config.Map                      = {
    tileUrl = 'https://s.rsg.sc/sc/images/games/GTAV/map/render/{z}/{x}/{y}.jpg',
    tileStyles = {
        {
            id = 'render',
            label = 'Render',
            url = 'https://s.rsg.sc/sc/images/games/GTAV/map/render/{z}/{x}/{y}.jpg'
        },
        {
            id = 'game',
            label = 'Game',
            url = 'https://s.rsg.sc/sc/images/games/GTAV/map/game/{z}/{x}/{y}.jpg'
        },
        {
            id = 'print',
            label = 'Print',
            url = 'https://s.rsg.sc/sc/images/games/GTAV/map/print/{z}/{x}/{y}.jpg'
        },
    },
    locationTickMs = 500,             -- [EDIT] Player coordinate stream interval while map app is open.
    locationMinDistance = 1.5,        -- [EDIT] Minimum movement delta required before pushing updates.
    -- Phone map route overlay: prefer native GPS polyline (sampled from engine route), then road-snap fallback.
    routeChunkSize = 48,              -- [EDIT] Max points per map:route:chunk message.
    routeMaxPoints = 420,             -- [EDIT] Hard cap on generated polyline nodes.
    routeNativeSampleMeters = 18.0,   -- [EDIT] Base distance between - [EDIT] Midpoint refine passes (1–2); 2 helps corners if routeMaxPoints allows.
    routeNativeWaitMs = 2800,         -- [EDIT] Wait for engine GPS before drawing greedy fallback (0 = off).
    routeNativeMaxEndDist = 135.0,    -- [EDIT] Reject/repair native poly if last point XY farther than this from dest.
    routeNativeMinLengthRatio = 0.28, -- [EDIT] Reject native sample if 2D length < this * GetGpsBlipRouteLength.
    routeStepMeters = 40.0,           -- [EDIT] Greedy step along vector toward destination.
    routeRefreshPlayerMove = 20.0,    -- [EDIT] Min player XY move (m) before rebuilding route.
    routePollMs = 400,                -- [EDIT] Route watcher tick while route overlay is subscribed.
    maxCustomMarkers = 200,           -- [EDIT] Max custom markers per phone.
    defaultBlips = {
        -- Police
        {
            id = 'police-1',
            name = 'Police Station',
            x = 440.03,
            y = -988.05,
            icon = 'police',
        },

        -- Hospital
        {
            id = 'pillbox_hospital',
            name = 'Pillbox Hospital',
            x = -1028.02,
            y = -412.03,
            icon = 'hospital',
        },
    }
}

--──────────────────────────────────────────────────────────────────────────────
-- Zappeats (delivery / courier)                                               [EDIT]
-- [INFO] Delivery job locations, catalog, payouts. Toggle givePhysicalItem to give real inventory items.
--──────────────────────────────────────────────────────────────────────────────
Config.Zappeats                 = {
    payoutAccount = 'bank',
    -- When false, orders are virtual (UI/payout only; no inventory touch).
    -- When true, the catalog item is given on assign and taken on drop-off/cancel.
    -- Requires matching item names in your inventory (see menuItems below).
    givePhysicalItem = false, -- [EDIT]
    priceMultiplier = 1.5,
    tipMin = 30,
    tipMax = 50,
    completeRadius = 3.5,
    assignCooldownSec = 8,
    pointsPerStar = 10,
    starBonusPerStep = 0.05,
    orderCooldownMinMs = 10000,
    orderCooldownMaxMs = 15000,
    earningsChartDays = 14,
    deliveryPoints = {
        { x = 8.69,     y = -243.09,  z = 47.66 },
        { x = 113.74,   y = -277.95,  z = 54.51 },
        { x = 201.56,   y = -148.76,  z = 61.47 },
        { x = -206.84,  y = 159.49,   z = 74.08 },
        { x = 38.83,    y = -71.64,   z = 63.83 },
        { x = 47.84,    y = -29.16,   z = 73.71 },
        { x = -264.41,  y = 98.82,    z = 69.27 },
        { x = -419.34,  y = 221.12,   z = 83.60 },
        { x = -998.43,  y = 158.42,   z = 62.31 },
        { x = -1026.57, y = 360.64,   z = 71.36 },
        { x = 325.10,   y = -229.59,  z = 54.22 },
        { x = 430.85,   y = -941.91,  z = 29.19 },
        { x = 278.81,   y = -1117.96, z = 29.42 },
        { x = 101.82,   y = -819.49,  z = 31.31 },
    },
    menuItems = {
        { item = 'sandwich',     label = 'Sanduiche',     basePrice = 25, deliveryTimeMs = 8 * 60 * 1000 },
        { item = 'water_bottle', label = 'Garrafa', basePrice = 25, deliveryTimeMs = 6 * 60 * 1000 },
        { item = 'repairkit',    label = 'Kit de Reparo',   basePrice = 35, deliveryTimeMs = 7 * 60 * 1000 },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Zapp (rides)                                                                [EDIT]
-- [INFO] Cancel penalty after accept: payer bank transfer to the other party.
--──────────────────────────────────────────────────────────────────────────────
Config.Zapp                     = {
    penaltyAccount = 'bank',   -- [EDIT] ESX/QB account for penalty transfers
    cancelPenaltyPercent = 50, -- [EDIT] Percent of fareEstimate charged on late cancel
    minPenaltyAmount = 1,      -- [EDIT] Minimum penalty (currency units)
    pickupRadius = 12.0,       -- [EDIT] Meters — driver must be this close to pickup to start
    dropoffRadius = 15.0,      -- [EDIT] Meters — driver must be this close to destination to complete
}

--──────────────────────────────────────────────────────────────────────────────
-- Health Application                                                          [EDIT]
-- [INFO] Controls Health app local tracking intervals and warning cooldowns.
--──────────────────────────────────────────────────────────────────────────────
Config.Health                   = {
    stepFactor = 1.31233595800525,   -- [ADV]  Distance-to-step conversion multiplier.
    stepsSyncIntervalMs = 20000,     -- [EDIT] Step sync interval to server DB.
    noticeCheckIntervalMs = 5000,    -- [EDIT] Health warning check tick.
    noticeRefreshIntervalMs = 60000, -- [EDIT] Refresh notice settings from backend.
    noticeCooldownMs = 300000,       -- [EDIT] Minimum delay between same warning pushes.
    enableWarnings = true,           -- [EDIT] Enable low health/hunger/thirst push warnings.
}

--──────────────────────────────────────────────────────────────────────────────
-- Houses (Home app)                                                         [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- Minimum qs-housing version is 5.3.2
local housingProviders          = {
    ['qs-housing'] = 'qs-housing',
    ['qb-houses'] = 'qb-houses',
}
Config.Houses                   = {
    nearbyRadius = 12.0,                                    -- [EDIT] Max distance in meters from the phone owner to include a player.
    provider = DependencyCheck(housingProviders) or 'none', -- [AUTO] qs-housing | qb-houses | none
}

--──────────────────────────────────────────────────────────────────────────────
-- Crypto app                                                                [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.Crypto                   = {
    enabled = false,
    fiatAccount = 'bank',
    holdingsCacheTtlSec = 60,
    historyCacheTtlSec = 60,
    marketAdvanceMinIntervalMs = 8000,
    startingFiat = 25000.0,
    tickIntervalMs = 60000,
    historyLimit = 80,
    global = {
        fiatCurrency = 'USD',
        tradeFeePercent = 0.45,
        transferFeeFlat = 15.0,
        minTradeFiat = 10.0,
        maxTradeFiat = 250000.0,
        maxPositionPerCoin = 5000.0,
    },
    coins = {
        {
            id = 'qsc',
            symbol = 'QSC',
            name = 'Quasar Coin',
            decimals = 4,
            basePrice = 128.5,
            tickUpChance = 0.49,
            volatility = 0.006,
            maxStepPercent = 0.65,
            meanReversion = 0.12,
            spikeChance = 0.0015,
            spikeMultiplierMax = 1.06,
            chartHistoryPoints = 56,
        },
        {
            id = 'los',
            symbol = 'LOS',
            name = 'Los Santos Token',
            decimals = 3,
            basePrice = 2.42,
            tickUpChance = 0.51,
            volatility = 0.014,
            maxStepPercent = 1.1,
            meanReversion = 0.08,
            spikeChance = 0.002,
            spikeMultiplierMax = 1.08,
            chartHistoryPoints = 56,
        },
        {
            id = 'vin',
            symbol = 'VIN',
            name = 'Vinewood Digital',
            decimals = 2,
            basePrice = 0.087,
            tickUpChance = 0.47,
            volatility = 0.022,
            maxStepPercent = 1.4,
            meanReversion = 0.06,
            spikeChance = 0.0025,
            spikeMultiplierMax = 1.1,
            chartHistoryPoints = 56,
        },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Weazel                                                              [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.Weazel                   = {
    categories = {
        { id = 'all',      label = 'All',      kind = 'meta' },
        { id = 'breaking', label = 'Breaking', kind = 'filter' },
        { id = 'local',    label = 'Local',    kind = 'content' },
        { id = 'politics', label = 'Politics', kind = 'content' },
        { id = 'sports',   label = 'Sports',   kind = 'content' },
    },
    ---@type { name: string, grades: number[], categories?: string[] }[]
    publishJobs = {
        { name = 'police', grades = { 0, 1, 2, 3, 4 } },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Aventon                                                   [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.Aventon                  = {
    pickup = vector4(-1034.82, -2730.87, 20.17, 324.5),
    requireNearby = true,
    maxDistance = 35.0,
    paymentAccount = 'bank',
    warpIntoVehicle = true,
    rentCooldownMs = 5000,
    categories = {
        { id = 'all',        label = 'All' },
        { id = 'sports',     label = 'Sports' },
        { id = 'motorcycle', label = 'Motorcycle' },
        { id = 'bicycle',    label = 'Bicycle' },
    },
    ---@type { id: string, categoryId: string, label: string, model: string, image: string, price: number, description?: string }[]
    vehicles = {
        -- sports
        {
            id = 'stanier',
            categoryId = 'sports',
            label = 'Stanier',
            model = 'stanier',
            image = 'https://docs.fivem.net/vehicles/stanier.webp',
            price = 280,
            description = 'Classic four-door patrol favorite; roomy and predictable.',
        },
        {
            id = 'asterope',
            categoryId = 'sports',
            label = 'Asterope',
            model = 'asterope',
            image = 'https://docs.fivem.net/vehicles/asterope.webp',
            price = 320,
            description = 'Quiet executive sports for daily commutes.',
        },
        {
            id = 'washington',
            categoryId = 'sports',
            label = 'Washington',
            model = 'washington',
            image = 'https://docs.fivem.net/vehicles/washington.webp',
            price = 340,
            description = 'Understated luxury with a soft ride.',
        },
        {
            id = 'warrener',
            categoryId = 'sports',
            label = 'Warrener',
            model = 'warrener',
            image = 'https://docs.fivem.net/vehicles/warrener.webp',
            price = 260,
            description = 'Boxy JDM sports; light and easy in traffic.',
        },
        {
            id = 'intruder',
            categoryId = 'sports',
            label = 'Intruder',
            model = 'intruder',
            image = 'https://docs.fivem.net/vehicles/intruder.webp',
            price = 300,
            description = 'Low-key sports with a bit of attitude.',
        },
        {
            id = 'premier',
            categoryId = 'sports',
            label = 'Premier',
            model = 'premier',
            image = 'https://docs.fivem.net/vehicles/premier.webp',
            price = 250,
            description = 'Budget four-door; reliable A-to-B.',
        },
        -- Motorcycle
        {
            id = 'sanchez',
            categoryId = 'motorcycle',
            label = 'Sanchez',
            model = 'sanchez',
            image = 'https://docs.fivem.net/vehicles/sanchez.webp',
            price = 380,
            description = 'Dirt-friendly dual-sport for shortcuts.',
        },
        {
            id = 'faggio2',
            categoryId = 'motorcycle',
            label = 'Faggio Sport',
            model = 'faggio2',
            image = 'https://docs.fivem.net/vehicles/faggio2.webp',
            price = 120,
            description = 'Scooter-class; cheap hops across the block.',
        },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- YouLink (in-game video browser)                                            [EDIT]
-- [INFO] Home feed URLs are enriched in NUI via noembed. For keyword search,
--        set videoSearchApiKey (Google video catalog API v3) — server-side only.
--──────────────────────────────────────────────────────────────────────────────
Config.YouLink                  = {
    ---@type { url: string }[]
    videos = {
        { url = 'https://www.youtube.com/watch?v=xrgLYedBTzE' },
        { url = 'https://www.youtube.com/watch?v=QQklYkC4lzs' },
        { url = 'https://www.youtube.com/watch?v=C5nqgamRNJ4' },
        { url = 'https://www.youtube.com/watch?v=xHA5S9BJYG4' },
        { url = 'https://www.youtube.com/watch?v=vG8L02dPcgg' },
        { url = 'https://www.youtube.com/watch?v=gCtBb_y0Gmg' },
        { url = 'https://www.youtube.com/watch?v=GsTDsvcqttQ' },
        { url = 'https://www.youtube.com/watch?v=RcGDoJzXfmQ' },
        { url = 'https://www.youtube.com/watch?v=Iq96RUkoadw' },
        { url = 'https://www.youtube.com/watch?v=AqJay1olF2Q' },
        { url = 'https://www.youtube.com/watch?v=zv7qMFQ1uXo' },
    },
    --- Paste a Google video catalog API v3 key (server only). Leave empty to disable keyword search (URL paste still works).
    videoSearchApiKey = '',
    maxSearchResults = 15,
}

-- Garage detection ------------------------------------------------------------ [AUTO]
-- [INFO] Detects a supported garage script by resource name. If none is running,
--        'default' disables deep integration and uses basic fallbacks.
local garages                   = { -- [CORE] resourceName -> alias
    ['qs-advancedgarages'] = 'qs-advancedgarages',
    ['jg-advancedgarages'] = 'jg-advancedgarages',
    ['cd_garage']          = 'cd_garage',
    ['loaf_garage']        = 'loaf_garage',
    ['okokGarage']         = 'okokGarage',
    ['codem-garage']       = 'codem-garage',
    ['vms_garagesv2']      = 'vms_garagesv2',
    ['lunar_garage']       = 'lunar_garage',
    ['RxGarages']          = 'RxGarages'
}
Config.Garage                   = DependencyCheck(garages) or 'default' -- [AUTO]

-- iCar / valet ---------------------------------------------------------------- [EDIT]
-- [INFO] Valet delivers a vehicle from the garage to the player (client-side NPC drive).
Config.Valet                    = false                           -- [EDIT] true: enable valet in the iCar app.
Config.ValetPrice               = 1000                           -- [EDIT] Charged from IcarValetPaymentAccount when valet runs.
Config.IcarValetPaymentAccount  = 'bank'                         -- [EDIT] ESX/QB account name (same idea as Aventon paymentAccount).
Config.IcarDealershipLocation   = vec2(-33.784615, -1102.021973) -- [EDIT] SetNewWaypoint target for dealership GPS.

-- Job Center ----------------------------------------------------------------- [EDIT]
-- [INFO] Listings shown in the Job Center app (job name must exist in your framework jobs).
--        description = Short text shown under the job title in the phone UI.
Config.JobCenter                = {
    { job = 'trucker',  label = 'Trucker',         description = 'Haul cargo and containers across the map for steady pay.', Coords = vec2(141.18, -3204.59) },
    { job = 'taxi',     label = 'Taxi Driver',     description = 'Pick up riders and earn fares anywhere in the city.',      Coords = vec2(909.49, -177.24) },
    { job = 'tow',      label = 'Towing',          description = 'Recover broken-down vehicles and impounds for clients.',   Coords = vec2(489.67, -1331.82) },
    { job = 'reporter', label = 'News Reporter',   description = 'Cover stories and live hits for the city news desk.',      Coords = vec2(-552.29, -925.59) },
    { job = 'garbage',  label = 'Trash Collector', description = 'Keep districts clean on scheduled sanitation routes.',     Coords = vec2(-313.85, -1522.82) },
    { job = 'bus',      label = 'Bus Driver',      description = 'Operate public bus lines and fixed stops around town.',    Coords = vec2(462.22, -641.15) },
}

--──────────────────────────────────────────────────────────────────────────────
-- Phone Applications                                                          [EDIT]
-- [INFO] Default installed apps shown on the home screen.
--        id    = Internal app identifier (must be unique).
--        label = Display name shown under the icon.
--        icon  = PNG filename inside web/public/apps/.
--        category = App Store category grouping.
--        job   = Optional required job (string or table of strings).
--        minGrade = Optional minimum job grade (inclusive, default 0).
--        grades = Optional grade whitelist; overrides minGrade when set.
--        iframe = Optional embedded web UI: string URL or table { url, css?, rotate? }.
--──────────────────────────────────────────────────────────────────────────────
Config.PhoneApplications        = {
    { id = 'weather',    label = 'Weather',     icon = 'weather.webp',    category = 'Information & Reading',  sizeMb = 48 },
    { id = 'calendar',   label = 'Calendar',    icon = 'calendar.webp',   category = 'Productivity & Finance', sizeMb = 92 },
    { id = 'gallery',    label = 'Gallery',     icon = 'gallery.webp',    category = 'Creativity',             sizeMb = 425 },
    { id = 'camera',     label = 'Camera',      icon = 'camera.webp',     category = 'Creativity',             sizeMb = 285 },
    { id = 'videocall',  label = 'Video Call',  icon = 'videocall.webp',  category = 'Social',                 sizeMb = 315 },
    { id = 'mail',       label = 'Mail',        icon = 'mail.webp',       category = 'Productivity & Finance', sizeMb = 198 },
    { id = 'notes',      label = 'Notes',       icon = 'notes.webp',      category = 'Productivity & Finance', sizeMb = 78 },
    { id = 'reminders',  label = 'Reminders',   icon = 'reminders.webp',  category = 'Productivity & Finance', sizeMb = 94 },
    { id = 'clock',      label = 'Clock',       icon = 'clock.webp',      category = 'Utilities',              sizeMb = 38 },
    { id = 'weazel',     label = 'News',        icon = 'news.webp',       category = 'Other',                  sizeMb = 158 },
    { id = 'tips',       label = 'Tips',        icon = 'tips.webp',       category = 'Information & Reading',  sizeMb = 68 },
    { id = 'music',      label = 'Music',       icon = 'music.webp',      category = 'Entertainment',          sizeMb = 385 },
    { id = 'store',      label = 'App Store',   icon = 'store.webp',      category = 'Utilities',              sizeMb = 148 },
    { id = 'peachstore', label = 'Peach Store', icon = 'peachstore.webp', category = 'Utilities',              sizeMb = 98 },
    { id = 'map',        label = 'Maps',        icon = 'maps.webp',       category = 'Utilities',              sizeMb = 895 },
    { id = 'health',     label = 'Health',      icon = 'health.webp',     category = 'Creativity',             sizeMb = 125 },
    { id = 'settings',   label = 'Settings',    icon = 'settings.webp',   category = 'Utilities',              sizeMb = 215 },
    { id = 'contacts',   label = 'Contacts',    icon = 'contacts.webp',   category = 'Social',                 sizeMb = 188 },
    { id = 'crypto',     label = 'Crypto',      icon = 'crypto.webp',     category = 'Productivity & Finance', sizeMb = 245 },
    { id = 'calculator', label = 'Calculator',  icon = 'calculator.webp', category = 'Utilities',              sizeMb = 32 },
    { id = 'houses',     label = 'Home',        icon = 'houses.webp',     category = 'Utilities',              sizeMb = 138 },
    { id = 'phone',      label = 'Phone',       icon = 'phone.webp',      category = 'Social',                 sizeMb = 225 },
    { id = 'messages',   label = 'Messages',    icon = 'messages.webp',   category = 'Social',                 sizeMb = 345 },
}

--──────────────────────────────────────────────────────────────────────────────
-- Home Screen Defaults                                                        [EDIT]
-- [INFO] Applied only for brand-new phones (when no saved home layout exists).
--        - dockApps: Optional fixed dock app IDs.
--        - folders: Create default folders from app IDs.
--        - firstPageItems: Ordered top-left items for page 1.
--          You can pass app IDs directly or widget IDs with either:
--          'weather' OR 'widget:weather'
--──────────────────────────────────────────────────────────────────────────────
Config.HomeScreenDefaults       = {
    enabled = true,
    folders = {
        {
            id = 'utilities',
            title = 'Utilities',
            apps = { 'calculator', 'clock', 'settings' },
        },
        {
            id = 'finance',
            title = 'Finance',
            apps = { 'crypto' },
        },
        {
            id = 'social',
            title = 'Social',
            apps = { 'contacts', 'videocall' },
        },
        {
            id = 'home',
            title = 'Home',
            apps = { 'houses' },
        },
    },
    firstPageItems = {
        'weather',
        'calendar',
    },
    dockApps = {
        'phone',
        'messages',
        'music',
        'camera',
    }
}

--──────────────────────────────────────────────────────────────────────────────
-- Store Download                                                              [EDIT]
-- [INFO] Simulated download speed. secondsPerMb = how many seconds per 1 MB.
--        Total download time = sizeMb * secondsPerMb (e.g. 150 MB * 0.02 = 4.5s).
--──────────────────────────────────────────────────────────────────────────────
Config.StoreDownload            = {
    secondsPerMb = 0.02,
}

Config.OnionBrowser             = {
    pedModel   = 'a_m_m_afriamer_01',
    blipLabel  = 'Onion delivery',
    blipSprite = 84,
    blipColor  = 2,
    blipScale  = 0.5,
    List       = {
        [1]  = { item = 'weapon_snspistol', label = 'SNS Pistol', price = 25000000, isWeapon = true, deliveryTime = 1 * 60 * 1000 },
    },
    coords     = {
        vec4(93.45, -1928.67, 20.79, 0.0),
        vec4(1134.81, -416.30, 67.05, 0.0),
    },
}

Config.Camera                   = {
    Recording = {
        MaxDurationSeconds = 60
    }
}

Config.SoundPanner              = { -- [ADV] Custom 3D panner (qs-3dsound / mx-surround server Play only; ignored for xsound).
    panningModel  = 'HRTF',         -- [INFO] Spatialization model.
    refDistance   = 1.5,            -- [INFO] Start distance for volume falloff.
    rolloffFactor = 3.0,            -- [INFO] Falloff curve intensity (avoid 0.1).
    distanceModel = 'exponential',  -- [INFO] 'linear' | 'inverse' | 'exponential'
}
