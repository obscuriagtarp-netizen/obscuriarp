const { randomUUID, createHash } = require('crypto');

function createActions({ snapshot, screenshot, apply, profile, admin, delay, now = Date.now }) {
    const evidence = new Map();
    const locks = new Set();
    const recent = new Map();

    async function read(request) {
        const state = await snapshot(request.targetId);
        if (state.error) throw new Error(state.error);
        if (request.mode === 'self' && state.discordId !== request.ownerId) throw new Error('identity_mismatch');
        return state;
    }

    return async request => {
        if (locks.has(request.targetId)) return { error: 'busy' };
        locks.add(request.targetId);
        try {
            if (request.operation === 'admin') {
                if (request.mode !== 'staff' || typeof admin !== 'function') return { error: 'disabled' };
                return await admin(request);
            }
            if (request.revive || request.action === 'revive') return { error: 'revive_disabled' };
            if (request.operation === 'profile') return await profile(request);
            for (const [key, value] of evidence) if (value.expires < now()) evidence.delete(key);
            for (const [key, expiry] of recent) if (expiry < now()) recent.delete(key);
            if (request.operation === 'inspect') {
                if ((recent.get(request.targetId) || 0) > now()) return { error: 'capture_cooldown' };
                const before = await read(request);
                if (before.blocked) return { error: before.blocked };
                recent.set(request.targetId, now() + 20000);
                await delay(3000);
                const sampled = await read(request);
                if (sampled.session !== before.session) return { error: 'session_changed' };
                const image = await screenshot(request.targetId);
                if (typeof image !== 'string' || image.length > 2800000
                    || !/^data:image\/(?:jpeg|jpg);base64,[A-Za-z0-9+/]+={0,2}$/.test(image)) return { error: 'screenshot_failed' };
                const after = await read(request);
                if (after.session !== before.session || after.blocked) return { error: 'session_changed' };
                const evidenceId = randomUUID();
                evidence.set(evidenceId, {
                    request, session: after.session, expires: now() + 90000,
                    limbo: before.limbo && sampled.limbo && after.limbo,
                    dead: after.dead || after.down,
                });
                return {
                    ok: true, evidenceId, image, capturedAt: new Date(now()).toISOString(),
                    imageHash: createHash('sha256').update(image).digest('hex'),
                    player: { source: after.source, coords: after.coords, dead: after.dead, down: after.down,
                        limbo: before.limbo && sampled.limbo && after.limbo, cooldown: after.cooldown },
                };
            }
            const record = evidence.get(request.evidenceId);
            if (!record || record.expires < now()) return { error: 'evidence_expired' };
            if (!['targetId', 'guildId', 'ticketId', 'actorId', 'ownerId', 'mode'].every(key => record.request[key] === request[key])) {
                return { error: 'evidence_mismatch' };
            }
            const current = await read(request);
            if (current.session !== record.session) return { error: 'session_changed' };
            if (current.blocked) return { error: current.blocked };
            if (request.mode === 'self') {
                if (!current.autoEnabled) return { error: 'disabled' };
                if (current.cooldown > 0) return { error: 'rescue_cooldown' };
            } else if (!current.staffEnabled) return { error: 'disabled' };
            if (request.destination && !current.customDestination) return { error: 'forbidden_destination' };
            evidence.delete(request.evidenceId);
            try { return await apply({ ...request, session: record.session }); }
            catch { return { error: 'uncertain' }; }
        } catch (error) {
            const known = ['offline', 'not_ready', 'identity_mismatch', 'screenshot_failed', 'screenshot_offline'];
            return { error: known.includes(error.message) ? error.message : 'internal' };
        } finally {
            locks.delete(request.targetId);
        }
    };
}

module.exports = { createActions };
