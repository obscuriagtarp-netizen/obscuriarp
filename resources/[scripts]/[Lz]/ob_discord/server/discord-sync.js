(() => {
const crypto = require('crypto');
const http = require('http');
const https = require('https');

const resource = GetCurrentResourceName();
const secret = GetConvar('ob_discord_secret', '');
const baseUrl = GetConvar('ob_discord_bot_url', 'http://127.0.0.1:30121').replace(/\/$/, '');
const whitelistEnabled = GetConvar('ob_discord_whitelist_enabled', 'false') === 'true';
const failOpen = GetConvar('ob_discord_whitelist_fail_open', 'false') === 'true';
const roleSyncEnabled = GetConvar('ob_discord_role_sync_enabled', 'true') === 'true';
const configured = secret.length >= 32 && validBaseUrl(baseUrl);
const pendingSync = new Map();
let unavailableWarningShown = false;

function validBaseUrl(value) {
    try {
        const url = new URL(value);
        if (url.protocol === 'https:') return true;
        return url.protocol === 'http:' && ['127.0.0.1', 'localhost', '::1'].includes(url.hostname);
    } catch { return false; }
}

function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function finishConnection(deferrals, failureReason) {
    if (failureReason) deferrals.done(failureReason);
    else deferrals.done();
}

function discordId(source) {
    return String(GetPlayerIdentifierByType(String(source), 'discord') || '').replace(/^discord:/, '');
}

function sign(path, timestamp, body) {
    return crypto.createHmac('sha256', secret)
        .update(`POST\n${path}\n${timestamp}\n${body}`)
        .digest('hex');
}

function perform(path, payload, timeoutMs = 12000) {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify({ requestId: crypto.randomUUID(), ...payload });
        const timestamp = String(Date.now());
        const target = new URL(`${baseUrl}${path}`);
        const transport = target.protocol === 'https:' ? https : http;
        const request = transport.request(target, {
            method: 'POST',
            agent: false,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
                Connection: 'close',
                'X-OB-Time': timestamp,
                'X-OB-Signature': sign(path, timestamp, body),
            },
        }, response => {
            let responseBody = '';
            response.setEncoding('utf8');
            response.on('data', chunk => {
                responseBody += chunk;
                if (Buffer.byteLength(responseBody) > 65536) {
                    request.destroy(new Error('response_too_large'));
                }
            });
            response.on('end', () => {
                let data;
                try { data = JSON.parse(responseBody || '{}'); } catch { data = {}; }
                const statusCode = response.statusCode || 0;
                if (statusCode >= 200 && statusCode < 300) resolve(data);
                else reject(new Error(data.error || `http_${statusCode}`));
            });
        });
        request.setTimeout(timeoutMs, () => request.destroy(new Error('timeout')));
        request.on('error', reject);
        request.end(body);
    });
}

function isRetryableConnectionError(error) {
    return ['ECONNABORTED', 'ECONNREFUSED', 'ECONNRESET', 'EPIPE', 'ETIMEDOUT'].includes(error?.code)
        || ['timeout', 'socket hang up'].includes(error?.message);
}

function cleanDisplayName(value) {
    if (typeof value !== 'string') return '';
    const cleaned = value.normalize('NFKC')
        .replace(/[\u0000-\u001f\u007f]/g, '')
        .replace(/\s+/gu, ' ')
        .trim();
    return [...cleaned].slice(0, 64).join('');
}

async function checkWhitelistAccess(discord) {
    const retryDelays = [0, 300, 900];
    let lastError;
    for (let attempt = 0; attempt < retryDelays.length; attempt += 1) {
        if (retryDelays[attempt]) await wait(retryDelays[attempt]);
        try {
            return await perform('/v1/city/access', { discordId: discord }, 6000);
        } catch (error) {
            lastError = error;
            const hasAnotherAttempt = attempt + 1 < retryDelays.length;
            if (!hasAnotherAttempt || !isRetryableConnectionError(error)) throw error;
            console.warn(`[${resource}] Consulta da whitelist interrompida (${error.code || error.message}); nova tentativa ${attempt + 2}/${retryDelays.length}.`);
        }
    }
    throw lastError;
}

on('playerConnecting', async (_name, _setKickReason, deferrals) => {
    if (!whitelistEnabled) return;
    const playerSource = global.source;
    deferrals.defer();
    await wait(0);
    deferrals.update('Consultando sua whitelist no Discord...');

    if (!configured) {
        const message = 'A validação da whitelist está indisponível. Avise a equipe da Obscuria.';
        console.error(`[${resource}] Conexao bloqueada: integração Discord inválida.`);
        finishConnection(deferrals, failOpen ? null : message);
        return;
    }
    const discord = discordId(playerSource);
    if (!/^\d{17,20}$/.test(discord)) {
        deferrals.done('Abra o Discord, entre no servidor da Obscuria e vincule-o ao FiveM antes de conectar.');
        return;
    }
    try {
        const result = await checkWhitelistAccess(discord);
        finishConnection(deferrals, result.allowed === true ? null : 'Sua whitelist ainda não está liberada no Discord.');
    } catch (error) {
        console.error(`[${resource}] Falha ao consultar whitelist: ${error.message}`);
        finishConnection(deferrals, failOpen ? null : 'Não foi possível validar sua whitelist agora. Tente novamente em instantes.');
    }
});

async function sendRoleSync(payload, attempt = 0) {
    if (!roleSyncEnabled) return;
    if (!configured) {
        if (!unavailableWarningShown) {
            unavailableWarningShown = true;
            console.error(`[${resource}] Cargos Discord não sincronizados: configure ob_discord_secret e ob_discord_bot_url.`);
        }
        return;
    }
    try {
        const result = await perform('/v1/city/sync', payload);
        if (!result.ok) throw new Error(result.error || 'sync_rejected');
        if (result.added || result.removed) {
            console.log(`[${resource}] Cargos sincronizados para Discord final ${payload.discordId.slice(-4)}: +${result.added || 0} -${result.removed || 0}.`);
        }
        if (result.nicknameUpdated) {
            console.log(`[${resource}] Nome do primeiro personagem sincronizado para Discord final ${payload.discordId.slice(-4)}.`);
        }
        if (result.warnings?.length) console.warn(`[${resource}] Sincronização com avisos: ${result.warnings.join(', ')}`);
    } catch (error) {
        const delays = [5000, 15000, 30000, 60000, 120000];
        if (attempt < delays.length) {
            setTimeout(() => sendRoleSync(payload, attempt + 1), delays[attempt]);
        } else {
            console.error(`[${resource}] Cargos Discord não sincronizados após tentativas: ${error.message}`);
        }
    }
}

on('ob_discord:internal:syncRoles', raw => {
    if (!roleSyncEnabled) return;
    let payload;
    try { payload = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return; }
    if (!payload || !/^\d{17,20}$/.test(payload.discordId || '')
        || !/^[A-Za-z0-9_-]{1,64}$/.test(payload.citizenid || '')
        || !Array.isArray(payload.vips)) return;
    const clean = {
        discordId: payload.discordId,
        citizenid: payload.citizenid,
        class: typeof payload.class === 'string' ? payload.class.toLowerCase().slice(0, 50) : '',
        vips: [...new Set(payload.vips.map(value => String(value).toLowerCase()).filter(value => /^[a-z0-9_-]{1,50}$/.test(value)))].slice(0, 16),
        displayName: cleanDisplayName(payload.displayName),
    };
    const previous = pendingSync.get(clean.discordId);
    if (previous) clearTimeout(previous.timer);
    const timer = setTimeout(() => {
        pendingSync.delete(clean.discordId);
        sendRoleSync(clean);
    }, 1000);
    pendingSync.set(clean.discordId, { payload: clean, timer });
});

if (!configured) console.warn(`[${resource}] URL/chave do bot inválida; whitelist e sincronização externa indisponíveis.`);
console.log(`[${resource}] Whitelist Discord ${whitelistEnabled ? 'ativa' : 'desativada'}; sincronização de cargos ${roleSyncEnabled ? 'ativa' : 'desativada'}.`);
})();
