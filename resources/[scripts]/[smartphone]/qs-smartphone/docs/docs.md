# QS Smartphone — Developer API

Short reference for integrating external resources with `qs-smartphone`. All exports use the resource name `qs-smartphone`.

**Dependencies:** `ox_lib`, `oxmysql`, `smartphone-prop`, `xsound`

**Starter templates:** `[phone]/[template]/phone-custom-react` and `phone-custom-jquery`

---

## Wallet billing

Unpaid invoices appear in the Wallet app under the **Bills** tab. Provider autodetection:

| Resource | `Config.Billing` |
|----------|------------------|
| *(none)* | `standalone` (`qs_phone_bills`) |
| `qs-billing` | `qs` |
| `okokBilling` | `okok` |
| `esx_billing` | `esx_billing` |
| `codem-billingv2` | `codemv2` |
| `RxBilling` | `RxBilling` |

Job avatars (`Config.BillingJobs`): icon may be `f7:shield_fill` or a direct image URL. Resolution order: provider `avatar` → job match (field or title/subtitle contains job key like `ambulance`) → `Config.BillingFallbackAvatar`.

### Create a bill (standalone only)

```lua
local billId, err = exports['qs-smartphone']:CreateBill(targetSource, {
    title = 'EMS',
    subtitle = 'Medical treatment',
    price = 500,
    job = 'ambulance',           -- uses Config.BillingJobs.ambulance icon when avatar omitted
    avatar = 'f7:cross_case_fill', -- optional; f7:… or https://…
    sender = 'char1:...',        -- optional
})
-- Or pass framework identifier string instead of source.
```

Other providers: create bills with that resource’s own API; phone only lists/pays.

### List unpaid bills

```lua
local bills = exports['qs-smartphone']:GetBills(source)
-- { { id, title, subtitle, price, avatar, job }, ... }
```

### Pay a bill

```lua
local ok = exports['qs-smartphone']:PayBill(source, billId)
```

Standalone also supports `/sendbill [id] [price] [reason]` for jobs in `Config.BillJobs`.

---

## Custom app (iframe)

Register a third-party UI that runs inside the phone. Call from your resource **client** after `qs-smartphone` has started.

```lua
local ui = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/build/'

local ok, err = exports['qs-smartphone']:addCustomApp({
    id = 'my_app',
    label = 'My App',
    icon = ui .. 'icon.webp',
    category = 'Utilities',
    creator = 'Your Name',
    description = 'Short description for the store.',
    appStoreOnly = true, -- false = pre-installed on home screen
    price = 450, -- optional; if > 0 app requires payment in App Store
    sizeMb = 5,
    iframe = { url = ui .. 'index.html' },
    custom = {
        enabled = true,
        bridge = {
            enabled = true,
            allowedOrigins = { 'https://cfx-nui-' .. GetCurrentResourceName() },
        },
    },
})

if not ok then
    print('addCustomApp failed:', err)
end
```

`price` can also be updated later via `updateCustomApp(appId, { price = 900 })`.

| Export | Description |
|--------|-------------|
| `addCustomApp(payload)` | Register one app. Returns `success, errorCode` |
| `addCustomAppsBatch(payloads)` | Register multiple apps |
| `updateCustomApp(appId, patch)` | Patch fields on an existing app |
| `removeCustomApp(appId)` | Remove by id |
| `getCustomApps()` | List all registered custom apps |

Apps are auto-removed when the **owner resource** stops (except built-in native ids like `radio`, `crime`, etc.).

---

## Push notification (server)

Send a lock-screen / banner notification to a player. Requires a valid phone scope (player must have an active phone).

```lua
local scopeId = exports['qs-smartphone']:getPhoneScopeIdentifier(source)
if not scopeId then return end

local ok, err = exports['qs-smartphone']:sendPhoneNotificationToScope(scopeId, {
    appId = 'my_app',
    appName = 'My App',
    title = 'New order',
    subtitle = 'Shop',
    text = 'Your package is ready for pickup.',
    closeTimeout = 5000,
})
```

Or target by server id directly:

```lua
exports['qs-smartphone']:sendPhoneNotification(source, {
    appId = 'my_app',
    title = 'Hello',
    text = 'World',
})
```

Returns `success, errorCode, data` on failure (`INVALID_SOURCE`, `NO_SCOPE`, `INVALID_PAYLOAD`, etc.).

---

## Send message from app (server)

Deliver a text message into the **Messages** app as if it came from a system/app sender (same pipeline as ChitChat verification SMS). Creates or reuses a DM thread titled with `appLabel` and optionally sends a push notification.

**Export:** `SendNewMessageFromApp`

### Quick usage (positional)

```lua
exports['qs-smartphone']:SendNewMessageFromApp('555-0100', 'Bank', 'Your account has been credited with $500.')
```

By player source:

```lua
exports['qs-smartphone']:SendNewMessageFromApp(playerId, 'Job Center', 'Your application has been approved.')
```

### Full payload (table)

```lua
local result = exports['qs-smartphone']:SendNewMessageFromApp({
    source = playerId,              -- or targetPhone = '555-0100'
    appLabel = 'City Hall',
    message = 'Congratulations! You have been hired as a mechanic.',
    requireOnline = false,          -- default: false (message is saved even when offline)
    push = {                        -- omit for default push; set to false to skip notification
        title = 'City Hall',
        text = 'You have a new message',
        closeTimeout = 4500,
        metadata = { reason = 'job_offer' },
    },
})

if not result.ok then
    print('SendNewMessageFromApp failed:', result.error)
end
```

### From an external resource event

```lua
RegisterNetEvent('myjob:notifyHired', function()
    local src = source
    exports['qs-smartphone']:SendNewMessageFromApp({
        source = src,
        appLabel = 'City Hall',
        message = 'Congratulations! You have been hired as a mechanic.',
    })
end)
```

### Online-only (verification-style)

```lua
exports['qs-smartphone']:SendNewMessageFromApp({
    targetPhone = phone,
    appLabel = 'SecureApp',
    message = ('Your code is: %s'):format(code),
    requireOnline = true,
})
```

### Payload fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `targetPhone` | string | if no `source` | Recipient phone number |
| `source` | number | if no `targetPhone` | Player server id; resolved via `GetCurrentPhoneNumber` |
| `appLabel` | string | yes | Sender/app name (thread title + system sender id `sys:<slug>`) |
| `message` | string | yes | Message body (max 4096 characters) |
| `push` | table \| false | no | Push notification options; `false` disables push. Default: title = `appLabel`, text = truncated message |
| `requireOnline` | boolean | no | If `true`, fails when recipient is offline. Default: `false` |

### Return value

**Success:**

```lua
{
    ok = true,
    threadId = 'sys_...',
    message = { id, threadId, senderId, type, text, ... },
}
```

**Failure:**

```lua
{ ok = false, error = 'TARGET_PHONE_NOT_FOUND' }
```

| Error code | Meaning |
|------------|---------|
| `INVALID_PAYLOAD` | Missing or invalid arguments |
| `TARGET_PHONE_NOT_FOUND` | Could not resolve phone from `source` or `targetPhone` |
| `INVALID_MESSAGE` | Empty message body |
| `TARGET_SOURCE_NOT_FOUND` | `requireOnline = true` but player is offline |
| `TARGET_PARTICIPANT_ERROR` | DB participant creation failed for recipient |
| `SYSTEM_PARTICIPANT_ERROR` | DB participant creation failed for system sender |
| `THREAD_CREATE_FAILED` | Could not create message thread |
| `EMPTY_MESSAGE` | Message rejected at delivery |

---

## Read messages / conversations (server)

Read-only APIs for third-party devices (e.g. smartwatch) to list conversations and message history **without** querying internal tables. Uses the same Messages app data as the phone UI. Access is scoped to the resolved phone number: a thread is only readable if that number is a member.

**Exports:** `GetMessageConversations`, `GetThreadMessages`, `GetMessageUnreadCount`

### List conversations

```lua
-- By player source
local result = exports['qs-smartphone']:GetMessageConversations(playerId)

-- By phone number
local result = exports['qs-smartphone']:GetMessageConversations('555-0100')

-- Full payload (pagination)
local result = exports['qs-smartphone']:GetMessageConversations({
    source = playerId,          -- or targetPhone = '555-0100'
    limit = 30,                 -- 1–60, default 30
    cursor = nil,               -- omit for first page; use pagination.nextCursor for the next
})

if result.ok then
    for _, thread in ipairs(result.threads) do
        print(thread.id, thread.lastMessagePreview, thread.unreadCount)
    end
end
```

**Success:**

```lua
{
    ok = true,
    me = { id, number, displayName, avatar },
    participants = { { id, number, displayName, avatar }, ... },
    threads = {
        {
            id, title, avatar, isGroup, memberIds,
            lastMessagePreview, lastMessageAt,
            unreadCount, pinned, muted,
        },
        ...
    },
    unreadTotal = 0,
    pagination = { cursor, limit, nextCursor, total, hasMore },
}
```

If the phone has never used Messages, returns `ok = true` with empty `threads` (no participant row is created).

### List thread messages

Newest page first. Pass `beforeMessageId` (or `pagination.nextCursor`) to load older messages.

```lua
local result = exports['qs-smartphone']:GetThreadMessages({
    source = playerId,          -- or targetPhone = '555-0100'
    threadId = 'th_...',        -- from GetMessageConversations
    limit = 40,                 -- 1–100, default 40
    beforeMessageId = nil,      -- optional; load messages older than this id
})

-- Positional
local result = exports['qs-smartphone']:GetThreadMessages(playerId, threadId, {
    limit = 40,
    beforeMessageId = cursor,
})
```

**Success:**

```lua
{
    ok = true,
    threadId = 'th_...',
    me = { id, number, displayName, avatar },
    participants = { ... },
    items = {
        {
            id, threadId, senderId, type, text,
            imageUrl, thumbnailUrl, location, delivery, createdAt,
        },
        ...
    },
    pagination = { beforeMessageId, nextCursor, hasMore, limit },
}
```

### Unread count

```lua
local result = exports['qs-smartphone']:GetMessageUnreadCount(playerId)
-- result.ok, result.unreadTotal
```

### Sync tip (smartwatch)

1. Call `GetMessageConversations` to render the inbox.
2. On open thread, call `GetThreadMessages` (first page = newest).
3. Poll conversations periodically (or on focus) and compare `lastMessageAt` / `lastMessagePreview`; when changed, refresh that thread’s first page.
4. Live push on the **client** of the phone owner still uses `phone:messages:delta` (same as the Messages app). Bridge that to your watch UI if both run on the same client.

### Error codes

| Error code | Meaning |
|------------|---------|
| `INVALID_PAYLOAD` | Missing or invalid arguments |
| `TARGET_PHONE_NOT_FOUND` | Could not resolve phone from `source` or `targetPhone` |
| `PARTICIPANT_NOT_FOUND` | Phone has no Messages participant (only for thread reads) |
| `INVALID_THREAD_ID` | Empty / missing `threadId` |
| `THREAD_ACCESS_DENIED` | Phone is not a member of that thread |

---

## Send mail from app (server)

Deliver a **system email** into the **Mail** app inbox. Intended for job scripts, fines, admin notices, and other server-side automation. Messages are written only to the recipient’s **inbox** (no sent folder on a player account).

Recipients must have a **registered Mail account** on the phone (created in the Mail app). If the address is unknown or the player has no account, delivery fails.

**Exports:** `SendMail`, `GetMailAccount`

**Config:** [`config/main.lua`](config/main.lua) → `Config.Mail`

| Key | Description |
|-----|-------------|
| `emailSuffix` | Domain suffix for in-game addresses (e.g. `@cloud.com`) |
| `systemFromEmail` | Default sender address for exports (default: `noreply@smartphone.local`) |
| `systemFromName` | Default sender display name (default: `Mail`) |

Push notifications are **enabled by default** when the recipient is online with an active phone. Set `push = false` to skip.

### Quick usage (positional)

Send to a player by server id:

```lua
exports['qs-smartphone']:SendMail(src, 'Parking fine', 'You have been fined $500.', 'City Hall')
```

Send by email address:

```lua
exports['qs-smartphone']:SendMail('player@cloud.com', 'Welcome', 'Thanks for joining the server.')
```

Local part only is also accepted; the suffix from `Config.Mail.emailSuffix` is appended automatically:

```lua
exports['qs-smartphone']:SendMail('player', 'Welcome', 'Your mail account is active.')
-- delivers to player@cloud.com when suffix is @cloud.com
```

### Full payload (table)

```lua
local result = exports['qs-smartphone']:SendMail({
    targetSource = src,                 -- or to / targetIdentifier (see below)
    subject = 'Service notice',
    body = 'Your vehicle impound fee is due.',
    fromName = 'LSPD',                  -- optional; defaults to Config.Mail.systemFromName
    fromEmail = 'police@cloud.com',     -- optional; defaults to Config.Mail.systemFromEmail
    cc = 'supervisor@cloud.com',        -- optional; stored on the message
    push = true,                        -- default: true; false to disable notification
})
```

Multiple recipients:

```lua
exports['qs-smartphone']:SendMail({
    to = { 'alice@cloud.com', 'bob@cloud.com' },
    subject = 'Server maintenance',
    body = 'Restart in 15 minutes.',
    fromName = 'Admin',
})
```

Custom push content:

```lua
exports['qs-smartphone']:SendMail({
    targetSource = src,
    subject = 'Invoice',
    body = 'Your bill is ready.',
    fromName = 'Billing',
    push = {
        title = 'New email',
        text = 'You received an invoice from Billing',
        closeTimeout = 5000,
        metadata = { reason = 'invoice' },
    },
})
```

### Check if a player has a mail account

```lua
local account = exports['qs-smartphone']:GetMailAccount(src)
if account then
    print(account.email, account.displayName)
    exports['qs-smartphone']:SendMail(src, 'Hello', 'Your mail account is active.')
end
```

`GetMailAccount` accepts:

- **Player source** (number) — resolves via framework identifier
- **Framework identifier** (string, no `@`) — character id
- **Email address** (string with `@`) — looks up the account directly

Returns `nil` when no account exists, otherwise:

```lua
{
    id = 1,
    email = 'player@cloud.com',
    displayName = 'John Doe',
    ownerIdentifier = 'char1:...',
}
```

### From an external resource event

```lua
RegisterNetEvent('myjob:sendOfferLetter', function(jobLabel)
    local src = source
    local result = exports['qs-smartphone']:SendMail({
        targetSource = src,
        subject = 'Job offer',
        body = ('Congratulations! You have been hired as %s.'):format(jobLabel),
        fromName = 'City Hall',
    })

    if not result.ok then
        print('SendMail failed:', result.error)
    end
end)
```

### Payload fields (`SendMail`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `to` | string \| string[] | if no `targetSource` / `targetIdentifier` | Recipient email(s). Comma/semicolon lists in a string are supported |
| `targetSource` | number | if no `to` | Player server id; resolves the character’s registered mail address |
| `targetIdentifier` | string | if no `to` / `targetSource` | Framework character identifier |
| `subject` | string | yes* | Email subject (max 500 chars). Empty becomes `(No subject)` |
| `body` | string | yes | Message body (max 60000 chars) |
| `fromName` | string | no | Sender display name |
| `fromEmail` | string | no | Sender address shown in the Mail app |
| `cc` | string | no | CC list (comma/semicolon separated). Stored on the message; same delivery rules as the in-app composer |
| `push` | boolean \| table \| false | no | `true` or omitted = send push when online; `false` = no push; table = custom push payload |

\* Required in table form; positional shorthand passes subject as the second argument.

### Positional shorthand

| Call | Meaning |
|------|---------|
| `SendMail(src, subject, body)` | System mail to player |
| `SendMail(src, subject, body, fromName)` | System mail with custom sender name |
| `SendMail('user@cloud.com', subject, body)` | Mail to email address |
| `SendMail('charIdentifier', subject, body)` | Mail by framework identifier (no `@` in string) |

### Return value

**Success:**

```lua
{
    ok = true,
    id = '123',       -- first delivered inbox message id
    delivered = 1,    -- number of inboxes that received the mail
}
```

Partial delivery (multiple `to` addresses, some without accounts):

```lua
{
    ok = true,
    id = '123',
    delivered = 2,
    requested = 3,
}
```

**Failure:**

```lua
{ ok = false, error = 'MAIL_ACCOUNT_NOT_FOUND' }
```

| Error code | Meaning |
|------------|---------|
| `INVALID_PAYLOAD` | Missing or invalid arguments |
| `INVALID_RECIPIENTS` | No recipient could be resolved |
| `MAIL_ACCOUNT_NOT_FOUND` | Target has no Mail account, or email is not registered |
| `INVALID_BODY` | Empty message body |
| `BODY_TOO_LONG` | Body exceeds 60000 characters |
| `SUBJECT_TOO_LONG` | Subject exceeds 500 characters |
| `SEND_FAILED` | Database insert failed |

### Notes

- Export delivery is **system mail only**. Player-composed mail (with a sent folder entry) still goes through the Mail app UI / `mail:message:send` callback.
- Offline players still receive mail in their inbox; push is skipped when they are not online with an active phone scope.
- Email addresses must match `Config.Mail.emailSuffix` when a full address is provided.
- Built-in resources (e.g. Onion Browser order confirmations) use the same pipeline via `MailSend.sendSystem`.

---

## Marketplace shop duty (server)

Control and query the **Marketplace** app shift system (“Enter service” / “Exit service” in the Profile tab). This is separate from the Settings **Job Duty** toggle (`on_duty`).

Duty is tied to the player’s **active Marketplace session** on their current phone. All exports use **framework job names** (e.g. `'police'`, `'ambulance'`) — the phone resolves the matching shop from `Config.Marketplace.Shops` internally. You never need shop ids.

All exports are **server-side** and use the resource name `qs-smartphone`.

### Quick reference

| Export | Arguments | Returns | Description |
|--------|-----------|---------|-------------|
| `JobExists` | `jobName` | `boolean` | `true` if the job is configured in `Config.Marketplace.Shops` |
| `IsPlayerOnDuty` | `source` | `boolean` | `true` if the player is on duty at any shop |
| `GetDutyJob` | `source` | `string \| nil` | Job name while on duty (e.g. `'police'`), or `nil` |
| `SetDuty` | `source`, `jobName?` | `boolean` | Clock in for `jobName`, or clock out when omitted |
| `IsJobOnDuty` | `jobName` | `boolean` | `true` if at least one staff member is on duty for that job |

Job names are **case-insensitive** (`'Police'` and `'police'` are the same).

### Check if a job is supported

```lua
if exports['qs-smartphone']:JobExists('police') then
    exports['qs-smartphone']:SetDuty(source, 'police')
end
```

### Read duty state

```lua
local src = source

if exports['qs-smartphone']:IsPlayerOnDuty(src) then
    local job = exports['qs-smartphone']:GetDutyJob(src)
    print(('Player is on duty as %s'):format(job))
end

-- Check whether customers can reach staff (e.g. before opening a chat UI)
if exports['qs-smartphone']:IsJobOnDuty('police') then
    print('Police staff is on duty in Marketplace')
end
```

### Set duty from your job script

```lua
-- Clock in — phone finds the shop for 'police' from config
local ok = exports['qs-smartphone']:SetDuty(source, 'police')
if not ok then
    -- Job not in Marketplace config, no session, or player job does not match
    return
end

-- Clock out
exports['qs-smartphone']:SetDuty(source)
```

`SetDuty` returns `false` when:

- `source` is invalid
- The player has no active Marketplace login on their phone
- `jobName` is not configured in `Config.Marketplace.Shops` (`JobExists` would be `false`)
- The player’s framework job does not match that Marketplace job
- Going off duty when already off duty still returns `true` (no-op)

### Listen for duty changes (server)

Fired whenever duty changes (phone UI, export, or internal toggle):

```lua
AddEventHandler('qs-smartphone:marketplace:dutyChanged', function(accountId, dutyJobName, playerSource)
    -- accountId: Marketplace account id
    -- dutyJobName: job name while on duty (e.g. 'police'), or nil when clocked out
    -- playerSource: server id that triggered the change, or nil

    if dutyJobName then
        print(('Marketplace account %s went on duty as %s'):format(accountId, dutyJobName))
    else
        print(('Marketplace account %s went off duty'):format(accountId))
    end
end)
```

### Example: sync with a job clock-in command

```lua
RegisterCommand('clockin', function(src)
    local job = -- your framework job name, e.g. 'police'
    if not exports['qs-smartphone']:JobExists(job) then
        return
    end
    exports['qs-smartphone']:SetDuty(src, job)
end, false)

RegisterCommand('clockout', function(src)
    exports['qs-smartphone']:SetDuty(src)
end, false)
```

### Notes

- Players must be **logged into Marketplace** on the phone (same session the app uses). Duty cannot be set for a player with no Marketplace account session.
- One account can only be on duty at **one shop** at a time. Setting duty for a new job moves them off the previous shop.
- `IsJobOnDuty` is useful for dispatch, NPC scripts, or gating customer features when no staff is available.
- When the phone is open on Marketplace, duty updates refresh the app UI automatically.
- Shop ids are internal only; configure jobs in [`config/marketplace.lua`](config/marketplace.lua) under each shop’s `job` field.

---

## Phone number & scope (server)

```lua
-- Persistent phone scope id (used for notifications, data isolation)
local scopeId = exports['qs-smartphone']:getPhoneScopeIdentifier(source)

-- Active SIM / metadata number for this player
local number = exports['qs-smartphone']:GetCurrentPhoneNumber(source)
```

---

## Phone open / close lifecycle

Fired when a player **successfully opens** or **closes** the phone UI. Use these events in external resources to pause animations, hide HUD elements, block other menus, sync job scripts, etc.

Event names use the `qs-smartphone:` prefix (same pattern as `qs-smartphone:marketplace:dutyChanged`).

### Server

Listen with `AddEventHandler` in any **server** script (after `qs-smartphone` has started):

```lua
AddEventHandler('phone:opened', function(playerSource, payload)
    -- payload.scopeId       — active phone scope (device UUID or owner identifier in legacy mode)
    -- payload.phoneNumber   — active SIM / metadata number
    -- payload.phoneId       — phone metadata UUID
    -- payload.ownerIdentifier — framework character identifier

    print(('Player %s opened phone (%s)'):format(playerSource, payload.phoneNumber))
end)

AddEventHandler('phone:closed', function(playerSource, payload)
    -- payload.reason = 'user' | 'disconnect'
    -- payload.scopeId, payload.phoneNumber, payload.phoneId, payload.ownerIdentifier
    --   (present when the phone instance was still known at close time)

    print(('Player %s closed phone (%s)'):format(playerSource, payload.reason))
end)
```

| When | Event | `payload.reason` (close only) |
|------|--------|-------------------------------|
| `phone:open` callback succeeds (full UI or Aura peek bootstrap) | `phone:opened` | — |
| Player closes phone / NUI `close` / server forces close via `phone:close` | `phone:closed` | `user` |
| Player disconnects while phone UI was active (routing still open) | `phone:closed` | `disconnect` |

Server **opened** is emitted once per successful `phone:open` bootstrap (including peek/Aura). It does not include UI `mode`; use client events if you need `full` vs `peek`.

### Client

Listen with `AddEventHandler` in any **client** script:

```lua
AddEventHandler('phone:opened', function(payload)
    -- payload.mode = 'full' | 'peek'
    -- payload.scopeId, payload.phoneNumber, payload.phoneId, payload.ownerIdentifier

    if payload.mode == 'full' then
        -- e.g. disable weapon wheel, hide minimap overlay
    end
end)

AddEventHandler('phone:closed', function(payload)
    -- payload.mode = previous UI mode ('full' | 'peek')
    -- payload.reason = 'user' | 'logout'
    -- payload.scopeId, payload.phoneNumber, payload.phoneId, payload.ownerIdentifier

    print('Phone closed:', payload.reason)
end)
```

| When | Event | Client `payload.reason` (close only) |
|------|--------|--------------------------------------|
| `Device.open()` — full phone with NUI focus | `phone:opened` | — |
| `Device.openPeekBootstrapped()` — Aura / peek with server bootstrap | `phone:opened` | — |
| Normal close (ESC, home button, NUI close callback) | `phone:closed` | `user` |
| Peek close | `phone:closed` | `user` |
| Character logout / framework unload (`Device.resetForCharacterLogout`) | `phone:closed` | `logout` |

Peek-only transitions (e.g. full → peek without a new bootstrap) do **not** emit a second **opened** event.

### Example: block a command while phone is open (client)

```lua
local phoneOpen = false

AddEventHandler('phone:opened', function()
    phoneOpen = true
end)

AddEventHandler('phone:closed', function()
    phoneOpen = false
end)

RegisterCommand('myaction', function()
    if phoneOpen then
        return
    end
    -- ...
end, false)
```

### Example: server-side activity flag

```lua
local openPhones = {}

AddEventHandler('phone:opened', function(src)
    openPhones[src] = true
end)

AddEventHandler('phone:closed', function(src)
    openPhones[src] = nil
end)

AddEventHandler('playerDropped', function()
    openPhones[source] = nil
end)
```

### Notes

- These are **local** `TriggerEvent` hooks, not net events. Other resources only need `AddEventHandler`; do not register `RegisterNetEvent` for these names.
- Prefer `exports['qs-smartphone']:IsPhoneOpen()` on **client** for a synchronous open check; lifecycle events are for edge-triggered logic (animations, state machines, logging).
- Server **opened** requires a resolvable active phone (`phone:open` returns data). Failed open (no item, revoked device) does not emit.

---

## Call Interception API (server)

Intercept incoming calls **before they ring** on the target phone. This allows external resources to:
- Reject calls programmatically
- Handle calls with custom logic (e.g., business lines, IVR systems)
- Route calls to different handlers

All exports are **server-side** and use the resource name `qs-smartphone`.

### Register an interceptor

Register a callback for a specific phone number. The callback is invoked **before** the call rings.

```lua
local ok, err = exports['qs-smartphone']:registerCallInterceptor('555-BUSINESS', function(callData)
    -- callData fields:
    -- sessionId, callerSource, callerNumber, callerDisplayName
    -- calleeSource, calleeNumber, calleeDisplayName, callType

    print(('Incoming call to business line from %s'):format(callData.callerNumber))

    -- Return action:
    -- { action = 'allow' }   -- Let call ring normally
    -- { action = 'reject' }  -- Reject the call silently
    -- { action = 'handle' }  -- Take over the call (you must accept/reject later)
    -- { action = 'reroute', reroute_target = source } -- Ring a single player
    -- { action = 'reroute', reroute_targets = { src1, src2 }, reroute_label = 'Police' }
    --     Ring all listed players at once; first to accept is assigned.

    return { action = 'handle' }
end, { priority = 10 })
```

Use `'*'` as the number to intercept ALL incoming calls (useful for logging or global rules):

```lua
exports['qs-smartphone']:registerCallInterceptor('*', function(callData)
    print(('[CALL LOG] %s -> %s'):format(callData.callerNumber, callData.calleeNumber))
    return { action = 'allow' }
end)
```

### Unregister an interceptor

```lua
exports['qs-smartphone']:unregisterCallInterceptor('555-BUSINESS')
```

### Handle intercepted calls

When you return `{ action = 'handle' }`, the call is held in a pending state. You **must** resolve it within 30 seconds:

```lua
-- Accept the call (connects voice channel)
local ok, err = exports['qs-smartphone']:acceptInterceptedCall(sessionId)

-- Reject the call
local ok, err = exports['qs-smartphone']:rejectInterceptedCall(sessionId, 'busy')

-- Let it ring through to the original target
local ok = exports['qs-smartphone']:letInterceptedCallRing(sessionId)
```

### Query intercepted call data

```lua
local callData = exports['qs-smartphone']:getInterceptedCallData(sessionId)
if callData then
    print(callData.callerNumber, callData.calleeNumber)
end
```

### Check if a number has an interceptor

```lua
if exports['qs-smartphone']:hasCallInterceptor('555-BUSINESS') then
    print('Business line is monitored')
end
```

### Get all registered interceptors

```lua
local interceptors = exports['qs-smartphone']:getRegisteredCallInterceptors()
-- Returns: { ['555-BUSINESS'] = 1, ['*'] = 2 } (number -> handler count)
```

### Server events (listen in your resource)

| Event | Payload | Description |
|-------|---------|-------------|
| `phone:call:preRing` | `CallInterceptData` | Fired before any interceptor callback runs |
| `phone:call:intercepted` | `CallInterceptData`, `handlerResource` | Call was intercepted with `action = 'handle'` |
| `phone:call:interceptAccepted` | `CallInterceptData` | Intercepted call was accepted |
| `phone:call:interceptRejected` | `CallInterceptData`, `reason` | Intercepted call was rejected |

### Example: Business phone system

```lua
local businessLines = {
    ['555-POLICE'] = { job = 'police', label = 'LSPD Dispatch' },
    ['555-AMBULANCE'] = { job = 'ambulance', label = 'EMS Dispatch' },
}

for number, config in pairs(businessLines) do
    exports['qs-smartphone']:registerCallInterceptor(number, function(callData)
        -- Find an on-duty employee
        local onDutyEmployee = findOnDutyEmployee(config.job)

        if not onDutyEmployee then
            -- No one available, reject the call
            return { action = 'reject' }
        end

        -- Store call for routing
        pendingBusinessCalls[callData.sessionId] = {
            callData = callData,
            targetEmployee = onDutyEmployee,
        }

        -- Handle the call ourselves
        return { action = 'handle' }
    end)
end

-- Later, when employee answers dispatch console:
RegisterNetEvent('dispatch:answerCall', function(sessionId)
    local pending = pendingBusinessCalls[sessionId]
    if not pending then return end

    -- Connect the call
    exports['qs-smartphone']:acceptInterceptedCall(sessionId)
    pendingBusinessCalls[sessionId] = nil
end)
```

### Example: Call logging / recording trigger

```lua
exports['qs-smartphone']:registerCallInterceptor('*', function(callData)
    -- Log all calls
    MySQL.insert('INSERT INTO call_logs (caller, callee, timestamp) VALUES (?, ?, NOW())',
        { callData.callerNumber, callData.calleeNumber })

    -- Allow all calls to proceed normally
    return { action = 'allow' }
end, { priority = -100 }) -- Low priority, runs after specific handlers
```

### Additional call management exports

```lua
-- Check if player is in an active call
local inCall = exports['qs-smartphone']:isPlayerInCall(source)

-- Get active call session data
local session = exports['qs-smartphone']:getActiveCallSession(source)
if session then
    print(session.id, session.phase, session.callerNumber)
end

-- End a player's active call
local ok, err = exports['qs-smartphone']:endCallBySource(source, 'end')
```

### Notes

- Interceptors are automatically unregistered when the owner resource stops
- Pending intercepted calls timeout after 30 seconds if not resolved
- Priority determines callback order (higher = earlier). Default is 0.
- The `'*'` wildcard interceptor runs AFTER specific number interceptors
- `action = 'handle'` blocks the call from ringing until you resolve it

---

## Client helpers

### Is the phone open?

```lua
local open = exports['qs-smartphone']:IsPhoneOpen()
```

### Start a call

```lua
local result = exports['qs-smartphone']:call('555-0100', 'audio', {
    callerNumberOverride = '555-9999', -- optional
})

if result.success then
    print('Call started', json.encode(result.data))
else
    print(result.error, result.message)
end
```

`callType`: `'audio'` or `'video'`.

### Open an app while phone is visible

```lua
-- Returns false if phone is closed or appId is invalid
exports['qs-smartphone']:OpenPhoneApp('messages')
```

---

### Housing battery charger (qs-housing)

```lua
exports['qs-smartphone']:BatteryRegisterHousingCharger(houseId, vector3(x, y, z), 2.0)
exports['qs-smartphone']:BatteryUnregisterHousingCharger(houseId)
```

---

## Custom Dynamic Island (client)

Show a custom Dynamic Island pill from any resource. Call these exports from **client** scripts. Islands compete with built-in sessions (call, share, timer, music, lock) using a numeric `priority`.

### Priority guide

| Kind | Priority (approx.) |
|------|--------------------|
| Call | `100` |
| Share (AirDrop) | `90` |
| Timer / alarm | `70` |
| Music | `60` |
| Custom (default) | `50` |
| Lock screen pill | below custom when custom is active |

Custom islands with `priority >= 70` can appear above the timer; `>= 60` above music; lower values only when no higher native session is active.

### Quick usage

```lua
-- Simple toast-style island (auto-hides after 8s)
exports['qs-smartphone']:showDynamicIsland({
    id = 'police-dispatch',
    icon = 'antenna_radiowaves_left_right', -- Framework7 icon name (or "f7:name")
    title = 'Dispatch',
    subtitle = '10-80 Pursuit in progress',
    color = '#3b82f6',
    duration = 8000,
})

-- Progress island that survives phone close (peek mode)
exports['qs-smartphone']:showDynamicIsland({
    id = 'download-progress',
    icon = 'cloud_download',
    title = 'Downloading...',
    subtitle = 'large_file.zip',
    progress = 45, -- 0–100
    persistent = true,
    priority = 55,
    onClick = function()
        TriggerEvent('myScript:openDownloads')
    end,
    onDismiss = function()
        print('Island dismissed')
    end,
})

exports['qs-smartphone']:updateDynamicIsland('download-progress', {
    progress = 78,
    subtitle = '78% complete',
})

exports['qs-smartphone']:hideDynamicIsland('download-progress')
```

### Expanded layout

```lua
exports['qs-smartphone']:showDynamicIsland({
    id = 'delivery-status',
    icon = 'tram_fill',
    title = 'Delivery',
    subtitle = 'On the way',
    color = '#22c55e',
    priority = 65,
    expandedContent = {
        lines = {
            { label = 'ETA', value = '4 min' },
            { label = 'Driver', value = 'Alex' },
        },
        actions = {
            { id = 'track', label = 'Track', icon = 'map' },
            { id = 'cancel', label = 'Cancel', icon = 'xmark' },
        },
    },
    onClick = function()
        -- Compact pill click
    end,
})
```

When the player taps an expanded action button, your resource receives:

```lua
AddEventHandler('phone:dynamicIsland:action', function(islandId, actionId)
    if islandId == 'delivery-status' and actionId == 'track' then
        -- open map / waypoint
    end
end)
```

### Config fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | **Required.** Unique island id (owner resource scoped) |
| `title` | `string` | **Required.** Primary label |
| `subtitle` | `string?` | Secondary label |
| `icon` | `string?` | Framework7 icon name (`cloud_download`, `f7:antenna_radiowaves_left_right`, …) |
| `progress` | `number?` | `0–100` linear progress |
| `color` | `string?` | Accent hex (`#RRGGBB`) |
| `priority` | `number?` | Stack priority (default `50`) |
| `duration` | `number?` | Auto-hide after ms; omit to keep until `hideDynamicIsland` |
| `persistent` | `boolean?` | Keep session in peek when the phone closes |
| `expandedContent` | `table?` | `lines` + `actions` for hover / expanded UI |
| `onClick` | `function?` | Compact pill click (Lua, same client) |
| `onExpand` | `function?` | Reserved expand callback |
| `onDismiss` | `function?` | Called when the island is hidden |

### Exports

| Export | Returns | Description |
|--------|---------|-------------|
| `showDynamicIsland(config)` | `success, errorCode?` | Create or replace an island |
| `updateDynamicIsland(id, patch)` | `success, errorCode?` | Patch fields on an existing island |
| `hideDynamicIsland(id)` | `success, errorCode?` | Hide and clear callbacks |
| `getDynamicIsland(id)` | `table?` | Public snapshot of one island |
| `getAllDynamicIslands()` | `table[]` | All active custom islands |
| `hasDynamicIsland()` | `boolean` | Whether any custom island is active |

Common error codes: `missing_id`, `missing_title`, `config_must_be_table`, `island_not_found`, `patch_must_be_table`.

Islands owned by a resource are removed automatically when that resource stops.

### From a custom app iframe (JS bridge)

```javascript
const { bridge, api } = QSPhoneBridge.create({
    appId: 'my_app',
    targetOrigin: 'https://cfx-nui-qs-smartphone',
})

await api.showDynamicIsland({
    id: 'my-island',
    title: 'Processing',
    subtitle: 'Please wait...',
    progress: 30,
    color: '#3b82f6',
})

await api.updateDynamicIsland('my-island', { progress: 80 })

const current = await api.getDynamicIsland('my-island')

await api.hideDynamicIsland('my-island')
```

Low-level equivalents (same as other bridge methods):

```javascript
await bridge.request('phone.ui.island.show', { id: 'my-island', title: 'Hello' })
await bridge.request('phone.ui.island.update', { id: 'my-island', progress: 50 })
await bridge.request('phone.ui.island.hide', { id: 'my-island' })
await bridge.request('phone.ui.island.get', { id: 'my-island' })
```

> Note: iframe / bridge calls update the React island store directly. Lua `onClick` / `onDismiss` callbacks only work when the island is created via the Lua exports above. Bridge islands should handle UI feedback inside your iframe.

---

## Iframe JavaScript bridge

Load the SDK in your custom app HTML (served from your resource or from the phone build):

```html
<script src="https://cfx-nui-qs-smartphone/web/build/bridge/qs-phone-bridge.js"></script>
```

```javascript
const { bridge, api } = QSPhoneBridge.create({
    appId: 'my_app',
    targetOrigin: 'https://cfx-nui-qs-smartphone',
})

api.onReady(() => {
    console.log('Phone bridge ready')
})

const state = await api.getPhoneState()
// { visible, mode, activeApp, screen }

const locale = await api.getPhoneLocale()
// e.g. "tr", "en", "de"

await api.showToastNotification({
    title: 'Done',
    text: 'Saved successfully',
})

const value = await api.openTextPrompt({
    title: 'Rename',
    placeholder: 'Name',
})

const media = await api.pickGalleryMedia({ mediaFilter: 'photos' })

const photo = await api.pickCameraMedia()
// Opens Camera → capture → returns full gallery row { id, url, location, ... } or null on cancel
```

Common `api` methods: `getPhoneState`, `getPhoneLocale`, `openPhoneApp`, `closeCurrentPhoneApp`, `getThemeMode`, `translateText`, `showToastNotification`, `openTextPrompt`, `openOptionPicker`, `pickGalleryMedia`, `pickCameraMedia`, `pickGif`, `showDynamicIsland`, `updateDynamicIsland`, `hideDynamicIsland`, `getDynamicIsland`, `startRecorder`, `stopRecorder`.

See [Custom Dynamic Island](#custom-dynamic-island-client) for full island payloads and priority rules.

### Templates usage (`[template]`)

Both starter templates use the same bridge API:

```javascript
const { api } = QSPhoneBridge.create({
    appId: 'my_app',
    targetOrigin: 'https://cfx-nui-qs-smartphone',
})

const locale = await api.getPhoneLocale()
const title = await api.translateText('apps.settings.language')
console.log('active locale', locale, 'sample translation', title)
```

Use `bridge.emit('my:event', data)` and `bridge.onEvent((event, data) => {})` for custom events between your UI and Lua (via NUI in your addon).

Built-in bridge events for `bridge.onEvent(...)`:
- `phone.theme.changed` → `{ mode: 'light' | 'dark', darkMode: boolean }`
- `phone.locale.changed` → `{ language: string }` (fires when player changes phone language in Settings)
- `app:opened` / `app:closed`

---

## Client events (listen in your resource)

| Event | Use |
|-------|-----|
| `phone:opened` | Phone UI opened (client). Payload: `mode`, `phoneNumber`, `scopeId`, … — see [Phone open / close lifecycle](#phone-open--close-lifecycle) |
| `phone:closed` | Phone UI closed (client). Payload: `mode`, `reason`, `phoneNumber`, … |
| `phone:pushNotification` | Same payload as server push; shows in UI |
| `phone:notification` | Simple ox_lib / qs-interface toast (`msg`, `type`) |
| `phone:usable:open` | Player used phone item — open UI if needed |
| `phone:incomingCall` | Incoming call payload |
| `phone:callState` | Call session updates |
| `phone:device:phoneChanged` | Active device UUID changed (swap phone item) |
| `phone:dynamicIsland:action` | Custom island expanded action tapped (`islandId`, `actionId`) |

### Server events (listen in your resource)

| Event | Use |
|-------|-----|
| `phone:opened` | Phone bootstrap succeeded. Args: `playerSource`, `payload` — see [Phone open / close lifecycle](#phone-open--close-lifecycle) |
| `phone:closed` | Phone closed or player disconnected with UI active. Args: `playerSource`, `payload` |
| `qs-smartphone:marketplace:dutyChanged` | Marketplace duty toggled — see [Marketplace shop duty](#marketplace-shop-duty-server) |

Trigger server push from Lua without exports:

```lua
TriggerClientEvent('phone:pushNotification', source, {
    appId = 'my_app',
    title = 'Title',
    text = 'Body text',
})
```