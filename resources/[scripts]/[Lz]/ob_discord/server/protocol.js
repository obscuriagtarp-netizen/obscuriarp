const crypto = require('crypto');

const ID = /^\d{17,20}$/;
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;

function sign(secret, timestamp, body) {
    return crypto.createHmac('sha256', secret).update(`POST\n/v1/action\n${timestamp}\n${body}`).digest('hex');
}

function authorize(secret, headers, body, now = Date.now()) {
    if (!secret || secret.length < 32 || Buffer.byteLength(body) > 8192) return false;
    const timestamp = headers['x-ob-time'];
    const signature = headers['x-ob-signature'];
    if (typeof timestamp !== 'string' || !/^\d{13}$/.test(timestamp)
        || Math.abs(now - Number(timestamp)) > 60000
        || typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature)) return false;
    return crypto.timingSafeEqual(Buffer.from(sign(secret, timestamp, body), 'hex'), Buffer.from(signature, 'hex'));
}

function validate(data, guildId) {
    if (!data || typeof data !== 'object' || Array.isArray(data)) return false;
    const keys = ['requestId', 'operation', 'guildId', 'ticketId', 'ownerId', 'actorId', 'targetId',
        'mode', 'evidenceId', 'evidenceMessageId', 'action', 'revive', 'destination', 'visual'];
    if (Object.keys(data).some(key => !keys.includes(key))) return false;
    if (!UUID.test(data.requestId) || !ID.test(data.guildId) || data.guildId !== guildId
        || !['ticketId', 'ownerId', 'actorId'].every(key => ID.test(data[key]))
        || !(data.operation === 'profile' && data.mode === 'self' && data.targetId === 0)
            && (!Number.isInteger(data.targetId) || data.targetId < 1 || data.targetId > 65535)
        || !['self', 'staff'].includes(data.mode)
        || (data.mode === 'self' && data.actorId !== data.ownerId)) return false;
    if (data.operation === 'inspect' || data.operation === 'profile') {
        return !['evidenceId', 'evidenceMessageId', 'action', 'revive', 'destination', 'visual'].some(key => key in data);
    }
    if (data.operation !== 'execute' || !UUID.test(data.evidenceId) || !ID.test(data.evidenceMessageId)
        || !['rescue', 'teleport'].includes(data.action) || data.revive !== false) return false;
    if (data.mode === 'self' && (data.action !== 'rescue' || data.destination)) return false;
    if (data.destination) {
        const d = data.destination;
        if (Object.keys(d).sort().join(',') !== 'w,x,y,z' || !Object.values(d).every(Number.isFinite)
            || Math.abs(d.x) > 12000 || Math.abs(d.y) > 12000 || d.z < -200 || d.z > 2000
            || d.w < 0 || d.w > 360) return false;
    }
    if (data.visual && (!['yes', 'no', 'unclear'].includes(data.visual.death)
        || !['yes', 'no', 'unclear'].includes(data.visual.limbo))) return false;
    return true;
}

// Persist first, execute once. An interrupted mutation is never replayed after restart.
function createJournal(entries, persist, dispatch, now = Date.now) {
    const cache = new Map();
    return async (data, body) => {
        const hash = crypto.createHash('sha256').update(body).digest('hex');
        const previous = entries[data.requestId];
        if (previous) {
            if (previous.hash !== hash) return { error: 'request_conflict' };
            return cache.get(data.requestId) || previous.result || { error: 'uncertain' };
        }
        // HMAC timestamps expire after one minute; keep replay protection for a full day.
        for (const [key, entry] of Object.entries(entries)) {
            if (entry.at < now() - 86400000) { delete entries[key]; cache.delete(key); }
        }
        if (Object.keys(entries).length >= 5000) return { error: 'busy' };
        entries[data.requestId] = { hash, at: now(), status: 'pending', request: data };
        persist(entries);
        let output;
        try { output = await dispatch(data); } catch { output = { error: 'internal' }; }
        entries[data.requestId].status = 'complete';
        entries[data.requestId].result = output.image || data.operation === 'profile' ? { error: 'evidence_expired' } : output;
        persist(entries);
        if (cache.size >= 32) cache.delete(cache.keys().next().value);
        cache.set(data.requestId, output);
        const timer = setTimeout(() => cache.delete(data.requestId), 120000);
        timer.unref?.();
        return output;
    };
}

module.exports = { authorize, sign, validate, createJournal };
