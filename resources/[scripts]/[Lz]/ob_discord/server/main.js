const fs = require('fs');
const path = require('path');
const resource = GetCurrentResourceName();
const { authorize, validate, createJournal } = require(path.join(GetResourcePath(resource), 'server/protocol.js'));
const { createActions } = require(path.join(GetResourcePath(resource), 'server/actions.js'));
const secret = GetConvar('ob_discord_secret', '');
const guildId = GetConvar('ob_discord_guild', '');
const allowedAddresses = GetConvar('ob_discord_addresses', '127.0.0.1,::1').split(',').map(value => value.trim());
const enabled = secret.length >= 32 && /^\d{17,20}$/.test(guildId);
const dataDir = path.join(GetResourcePath(resource), 'data');
const journalPath = path.join(dataDir, 'requests.json');
let journal;
let startupError;

function game(operation, data) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('game_timeout')), 12000);
        global.exports[resource].TicketBridge(operation, JSON.stringify(data), result => {
            clearTimeout(timer);
            try { resolve(JSON.parse(result)); } catch (error) { reject(error); }
        });
    });
}

function screenshot(target) {
    if (GetResourceState('screenshot-basic') !== 'started') return Promise.reject(new Error('screenshot_offline'));
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('screenshot_failed')), 15000);
        global.exports['screenshot-basic'].requestClientScreenshot(target, { encoding: 'jpg', quality: 0.7 }, (err, data) => {
            clearTimeout(timer);
            if (err) reject(new Error('screenshot_failed'));
            else resolve(data);
        });
    });
}

try {
    fs.mkdirSync(dataDir, { recursive: true });
    const entries = fs.existsSync(journalPath) ? JSON.parse(fs.readFileSync(journalPath, 'utf8')) : {};
    if (!entries || Array.isArray(entries) || typeof entries !== 'object') throw new Error('invalid_journal');
    const dispatch = createActions({
        snapshot: targetId => game('snapshot', { targetId }), screenshot,
        apply: request => game('apply', request),
        profile: request => game('profile', request),
        delay: ms => new Promise(resolve => setTimeout(resolve, ms)),
    });
    journal = createJournal(entries, data => {
        fs.writeFileSync(`${journalPath}.tmp`, JSON.stringify(data));
        fs.renameSync(`${journalPath}.tmp`, journalPath);
    }, dispatch);
} catch (error) {
    startupError = true;
    console.error(`[${resource}] Diario indisponivel; ponte bloqueada: ${error.message}`);
}

let active = 0;
SetHttpHandler((req, res) => {
    let finished = false;
    let slot = false;
    const finish = (status, data) => {
        if (finished) return;
        finished = true;
        if (slot) active -= 1;
        clearTimeout(timer);
        res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        res.send(JSON.stringify(data));
    };
    const timer = setTimeout(() => finish(408, { error: 'timeout' }), 35000);
    req.setCancelHandler(() => {
        if (finished) return;
        finished = true;
        if (slot) active -= 1;
        clearTimeout(timer);
    });
    const rawAddress = String(req.address || '');
    const address = rawAddress.startsWith('[') ? rawAddress.slice(1, rawAddress.indexOf(']'))
        : rawAddress.startsWith('::ffff:') ? rawAddress.slice(7).replace(/:\d+$/, '')
            : rawAddress.includes('.') ? rawAddress.replace(/:\d+$/, '') : rawAddress;
    if (!allowedAddresses.includes(address)) return finish(403, { error: 'forbidden' });
    if (!enabled || startupError) return finish(503, { error: 'disabled' });
    if (req.method !== 'POST' || req.path !== '/v1/action') return finish(404, { error: 'not_found' });
    const length = Object.entries(req.headers || {}).find(([key]) => key.toLowerCase() === 'content-length')?.[1];
    if (length && (!/^\d+$/.test(length) || Number(length) > 8192)) return finish(413, { error: 'too_large' });
    if (active >= 8) return finish(429, { error: 'busy' });
    slot = true;
    active += 1;
    let consumed = false;
    req.setDataHandler(async body => {
        if (consumed || finished) return;
        consumed = true;
        const headers = Object.fromEntries(Object.entries(req.headers || {}).map(([key, value]) => [key.toLowerCase(), value]));
        if (typeof body !== 'string' || !authorize(secret, headers, body)) return finish(401, { error: 'unauthorized' });
        let data;
        try { data = JSON.parse(body); } catch { return finish(400, { error: 'invalid_request' }); }
        if (!validate(data, guildId)) return finish(400, { error: 'invalid_request' });
        try {
            const result = await journal(data, body);
            console.log(`[${resource}] ${data.requestId} ticket=${data.ticketId} ator=${data.actorId} alvo=${data.targetId} ${data.operation} ${result.error || 'ok'}`);
            finish(200, result);
        } catch {
            finish(500, { error: 'uncertain' });
        }
    });
});

console.log(`[${resource}] ${enabled && !startupError ? 'Ponte configurada' : 'Desativada: configure as convars server-side'}. discord: lzdv_`);
