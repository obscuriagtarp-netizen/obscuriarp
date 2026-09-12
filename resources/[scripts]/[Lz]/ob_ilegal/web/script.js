const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'ob_ilegal';

const app = document.getElementById('ritual-app');
const panel = document.getElementById('ritual-panel');
const eyebrow = document.getElementById('ritual-eyebrow');
const title = document.getElementById('ritual-title');
const timerLabel = document.getElementById('ritual-timer');
const stateLabel = document.getElementById('ritual-state');
const closeButton = document.getElementById('close-button');
const ritualAudio = window.ObIlegalAudio;

const canvases = {
    bruxa: document.getElementById('witch-canvas'),
    vampiro: document.getElementById('vampire-canvas'),
    curandeira: document.getElementById('healer-canvas'),
    fechadura: document.getElementById('lock-canvas'),
    cofre: document.getElementById('vault-canvas'),
};

const modes = {
    bruxa: { eyebrow: 'ESCRITA ARCANA', title: 'Caligrafia Rúnica' },
    vampiro: { eyebrow: 'CIRCUITO HEMÁTICO', title: 'Corrente Carmesim' },
    curandeira: { eyebrow: 'EXTRAÇÃO NATURAL', title: 'Vinhas do Cofre' },
    fechadura: { eyebrow: 'MECANISMO DE ACESSO', title: 'Segredos da Fechadura' },
    cofre: { eyebrow: 'CÂMARA DE SEGURANÇA', title: 'Combinação do Cofre' },
};

const mechanismModes = {
    fechadura: {
        humano: {
            eyebrow: 'MECANISMO DE ACESSO',
            title: 'Mecanismo de Pinos',
            instruction: 'SEGURE PARA ERGUER · SOLTE NA LINHA DE CORTE',
        },
        bruxa: {
            eyebrow: 'FECHADURA ENCANTADA',
            title: 'Lacre Rúnico',
            instruction: 'TRACE CADA SIGILO SEM ROMPER A TRAMA',
        },
        vampiro: {
            eyebrow: 'CONDUTO DA FECHADURA',
            title: 'Pressão Hemática',
            instruction: 'SEGURE PARA ALIMENTAR · SOLTE NA FAIXA',
        },
        curandeira: {
            eyebrow: 'MECANISMO ORGÂNICO',
            title: 'Fecho de Raízes',
            instruction: 'DESPERTE OS BROTOS NA ORDEM DA RAIZ',
        },
    },
    cofre: {
        humano: {
            eyebrow: 'CÂMARA DE SEGURANÇA',
            title: 'Combinação do Cofre',
            instruction: 'GIRE DEVAGAR / ESCUTE O NÚMERO CORRETO',
        },
        bruxa: {
            eyebrow: 'NEXO DA CÂMARA',
            title: 'Ressonância Rúnica',
            instruction: 'DESPERTE O NÚCLEO / ESCUTE AS RUNAS / SELECIONE O TOM PURO',
        },
        vampiro: {
            eyebrow: 'CIRCULAÇÃO DO NÚCLEO',
            title: 'Circuito Hemático',
            instruction: 'CONDUZA O SANGUE PELAS VÁLVULAS CORRETAS',
        },
        curandeira: {
            eyebrow: 'SELO VIVO DO COFRE',
            title: 'Rito da Floração',
            instruction: 'MEMORIZE E REPRODUZA A ORDEM DOS BROTOS',
        },
    },
};

const runeShapes = [
    [[0.20, 0.76], [0.33, 0.20], [0.49, 0.63], [0.66, 0.20], [0.79, 0.76], [0.50, 0.48], [0.20, 0.48]],
    [[0.25, 0.22], [0.25, 0.78], [0.70, 0.78], [0.48, 0.52], [0.73, 0.22], [0.25, 0.22], [0.50, 0.52]],
    [[0.21, 0.28], [0.50, 0.18], [0.79, 0.28], [0.62, 0.51], [0.77, 0.77], [0.50, 0.64], [0.23, 0.77], [0.38, 0.51], [0.21, 0.28]],
    [[0.24, 0.20], [0.50, 0.80], [0.76, 0.20], [0.50, 0.40], [0.24, 0.20], [0.50, 0.20], [0.50, 0.80]],
    [[0.18, 0.58], [0.38, 0.20], [0.70, 0.24], [0.82, 0.55], [0.58, 0.80], [0.27, 0.72], [0.18, 0.58], [0.52, 0.55], [0.70, 0.24]],
    [[0.18, 0.76], [0.50, 0.18], [0.82, 0.76], [0.50, 0.58], [0.18, 0.76], [0.82, 0.76]],
    [[0.22, 0.22], [0.22, 0.78], [0.50, 0.52], [0.78, 0.78], [0.78, 0.22], [0.50, 0.48], [0.22, 0.22]],
    [[0.24, 0.82], [0.24, 0.20], [0.76, 0.20], [0.24, 0.46], [0.66, 0.46]],
    [[0.20, 0.20], [0.76, 0.20], [0.42, 0.48], [0.78, 0.48], [0.24, 0.80], [0.80, 0.80]],
    [[0.22, 0.20], [0.78, 0.20], [0.50, 0.50], [0.78, 0.80], [0.22, 0.80], [0.50, 0.50], [0.22, 0.20]],
    [[0.18, 0.27], [0.35, 0.47], [0.50, 0.18], [0.65, 0.47], [0.82, 0.27], [0.50, 0.66], [0.50, 0.84]],
    [[0.50, 0.15], [0.75, 0.38], [0.59, 0.38], [0.59, 0.81], [0.41, 0.81], [0.41, 0.38], [0.25, 0.38], [0.50, 0.15]],
];

const bloodNodes = [
    [0.13, 0.50], [0.27, 0.27], [0.27, 0.72], [0.41, 0.16], [0.41, 0.42],
    [0.41, 0.79], [0.57, 0.27], [0.57, 0.54], [0.57, 0.82], [0.72, 0.17],
    [0.72, 0.48], [0.72, 0.76], [0.88, 0.25], [0.88, 0.50], [0.88, 0.75],
];

const bloodLinks = [
    [0, 1], [0, 2], [1, 3], [1, 4], [2, 4], [2, 5], [3, 6], [4, 6], [4, 7],
    [5, 7], [5, 8], [6, 9], [6, 10], [7, 9], [7, 10], [7, 11], [8, 10], [8, 11],
    [9, 12], [9, 13], [10, 12], [10, 13], [10, 14], [11, 13], [11, 14],
];

const bloodRoutes = [
    [0, 1, 3, 6, 9, 12],
    [0, 2, 4, 7, 10, 13],
    [0, 2, 5, 8, 11, 14],
];

const bloodLootRoutes = [
    [0, 1, 3, 6, 9, 13],
    [0, 1, 3, 6, 10, 14],
    [0, 1, 4, 6, 9, 12],
    [0, 1, 4, 7, 11, 14],
    [0, 2, 4, 6, 10, 12],
    [0, 2, 4, 7, 9, 13],
    [0, 2, 5, 7, 10, 14],
    [0, 2, 5, 8, 10, 13],
    [0, 2, 5, 8, 11, 14],
    [0, 1, 4, 7, 10, 12],
];

const vinePaths = [
    [[0.22, 0.84], [0.18, 0.69], [0.32, 0.59], [0.25, 0.44], [0.42, 0.34], [0.46, 0.17]],
    [[0.50, 0.88], [0.42, 0.73], [0.56, 0.62], [0.45, 0.48], [0.56, 0.34], [0.50, 0.17]],
    [[0.78, 0.84], [0.83, 0.69], [0.69, 0.58], [0.78, 0.44], [0.60, 0.33], [0.54, 0.17]],
];

let game = null;
let timerInterval = null;
let animationFrame = null;
const lastOrders = new Map();

const postNui = (eventName, data) => fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
}).catch(() => null);

function shuffle(items) {
    const result = [...items];
    for (let index = result.length - 1; index > 0; index -= 1) {
        const next = Math.floor(Math.random() * (index + 1));
        [result[index], result[next]] = [result[next], result[index]];
    }
    return result;
}

function uniqueRandomOrder(length, count, key) {
    let order;
    let signature;
    const previous = lastOrders.get(key);
    for (let attempt = 0; attempt < 8; attempt += 1) {
        order = shuffle(Array.from({ length }, (_, index) => index)).slice(0, count);
        signature = order.join(':');
        if (signature !== previous) break;
    }
    lastOrders.set(key, signature);
    return order;
}

function stopRuntime() {
    if (timerInterval) window.clearInterval(timerInterval);
    if (animationFrame) window.cancelAnimationFrame(animationFrame);
    timerInterval = null;
    animationFrame = null;
    game = null;
}

function finish(success, reason = '') {
    if (!game || game.finished) return;
    game.finished = true;
    ritualAudio?.cue(success ? 'success' : 'failure');
    panel.classList.add(success ? 'is-success' : 'is-failure');
    stateLabel.textContent = success ? 'MECANISMO VIOLADO' : (reason || 'RITUAL ROMPIDO');

    const previewMode = game.preview;
    window.setTimeout(() => {
        if (previewMode) return;
        app.classList.add('is-hidden');
        app.style.display = 'none';
        app.setAttribute('aria-hidden', 'true');
        panel.className = 'ritual-panel';
        stopRuntime();
        void postNui('atmMinigameResult', { success, reason });
    }, success ? 900 : 520);
}

function updateClock() {
    if (!game || game.finished) return;
    const remaining = Math.max(0, game.deadline - Date.now());
    const seconds = Math.ceil(remaining / 1000);
    const minutes = Math.floor(seconds / 60);
    timerLabel.textContent = `${String(minutes).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    if (remaining <= 0) finish(false, 'TEMPO ESGOTADO');
}

function startClock(timeLimit) {
    game.deadline = Date.now() + timeLimit;
    updateClock();
    timerInterval = window.setInterval(updateClock, 100);
}

function fitCanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const ratio = Math.min(2, window.devicePixelRatio || 1);
    const width = Math.max(1, Math.round(rect.width));
    const height = Math.max(1, Math.round(rect.height));
    if (canvas.width !== Math.round(width * ratio) || canvas.height !== Math.round(height * ratio)) {
        canvas.width = Math.round(width * ratio);
        canvas.height = Math.round(height * ratio);
    }
    const context = canvas.getContext('2d');
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    return { context, width, height };
}

function pointerPosition(event, canvas) {
    const rect = canvas.getBoundingClientRect();
    return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y);
}

function pathLength(points) {
    let total = 0;
    for (let index = 1; index < points.length; index += 1) total += distance(points[index - 1], points[index]);
    return total;
}

function distanceToSegment(point, start, end) {
    const x = end.x - start.x;
    const y = end.y - start.y;
    const lengthSquared = (x * x) + (y * y);
    if (lengthSquared === 0) return distance(point, start);
    const ratio = Math.max(0, Math.min(1, (((point.x - start.x) * x) + ((point.y - start.y) * y)) / lengthSquared));
    return distance(point, { x: start.x + (x * ratio), y: start.y + (y * ratio) });
}

function pointFor(normalized, width, height) {
    return { x: normalized[0] * width, y: normalized[1] * height };
}

function samplePath(shape, width, height) {
    const points = [];
    for (let index = 0; index < shape.length - 1; index += 1) {
        const from = pointFor(shape[index], width, height);
        const to = pointFor(shape[index + 1], width, height);
        const steps = Math.max(8, Math.ceil(distance(from, to) / 7));
        for (let step = 0; step < steps; step += 1) {
            const ratio = step / steps;
            points.push({
                x: from.x + ((to.x - from.x) * ratio),
                y: from.y + ((to.y - from.y) * ratio),
            });
        }
    }
    points.push(pointFor(shape[shape.length - 1], width, height));
    return points;
}

function strokePolyline(context, points) {
    if (!points || points.length < 2) return;
    context.beginPath();
    context.moveTo(points[0].x, points[0].y);
    for (let index = 1; index < points.length; index += 1) context.lineTo(points[index].x, points[index].y);
    context.stroke();
}

function spawnParticles(x, y, color, count = 4) {
    if (!game) return;
    game.particles ||= [];
    for (let index = 0; index < count; index += 1) {
        const angle = Math.random() * Math.PI * 2;
        const speed = 0.25 + (Math.random() * 0.8);
        game.particles.push({
            x,
            y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 1,
            size: 1 + (Math.random() * 2.2),
            color,
        });
    }
    if (game.particles.length > 180) game.particles.splice(0, game.particles.length - 180);
}

function renderParticles(context) {
    if (!game?.particles) return;
    context.save();
    context.globalCompositeOperation = 'lighter';
    game.particles = game.particles.filter((particle) => {
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.vy -= 0.006;
        particle.life -= 0.025;
        if (particle.life <= 0) return false;
        context.globalAlpha = particle.life;
        context.fillStyle = particle.color;
        context.beginPath();
        context.arc(particle.x, particle.y, particle.size * particle.life, 0, Math.PI * 2);
        context.fill();
        return true;
    });
    context.restore();
}

function setFlash(type, duration = 300, playSound = true) {
    if (!game) return;
    game.flash = type;
    game.flashUntil = performance.now() + duration;
    if (playSound) ritualAudio?.cue(type === 'wrong' ? 'wrong' : 'hit');
}

function renderFlash(context, width, height, now) {
    if (!game?.flash || now > game.flashUntil) return;
    const alpha = Math.max(0, (game.flashUntil - now) / 300) * 0.18;
    context.save();
    if (game.mode === 'cofre' && !game.variantController) {
        context.beginPath();
        context.arc(width / 2, height / 2, Math.min(width, height) * 0.44, 0, Math.PI * 2);
        context.clip();
    }
    context.fillStyle = game.flash === 'wrong' ? `rgba(255, 28, 51, ${alpha})` : `rgba(192, 116, 255, ${alpha})`;
    context.fillRect(0, 0, width, height);
    context.restore();
}

function prepareWitchRune() {
    if (!game || game.mode !== 'bruxa') return;
    const { width, height } = fitCanvas(canvases.bruxa);
    const shapeIndex = game.runeOrder[game.runeIndex];
    const shape = runeShapes[shapeIndex];
    game.witchTarget = samplePath(shape, width, height);
    game.witchAnchors = shape.map((point) => pointFor(point, width, height));
    game.anchorIndex = 1;
    game.covered = new Uint8Array(game.witchTarget.length);
    game.coveredCount = 0;
    game.traceLength = 0;
    game.guideHits = 0;
    game.guideChecks = 0;
    game.trace = [];
    game.drawing = false;
    game.locked = false;
    stateLabel.textContent = 'INICIE NO FOCO LUMINOSO';
    document.getElementById('witch-progress').textContent = `RUNA ${game.runeIndex + 1} / ${game.runeCount}`;
}

function witchFailure(reason) {
    if (!game || game.mode !== 'bruxa' || game.locked) return;
    game.errors += 1;
    game.drawing = false;
    game.trace = [];
    game.covered = new Uint8Array(game.witchTarget.length);
    game.coveredCount = 0;
    game.anchorIndex = 1;
    game.traceLength = 0;
    game.guideHits = 0;
    game.guideChecks = 0;
    setFlash('wrong', 360);
    stateLabel.textContent = reason;
    document.getElementById('witch-errors').textContent = `${3 - game.errors} TENTATIVAS`;
    if (game.errors >= 3) finish(false, 'RUNAS DISSIPADAS');
}

function completeWitchRune() {
    if (!game || game.locked) return;
    game.locked = true;
    game.drawing = false;
    game.completedTrace = [...game.witchTarget];
    game.completedAt = performance.now();
    game.runeIndex += 1;
    setFlash('hit', 520);
    stateLabel.textContent = 'RUNA INSCRITA';
    if (game.runeIndex >= game.runeCount) {
        window.setTimeout(() => finish(true), 760);
        return;
    }
    window.setTimeout(prepareWitchRune, 620);
}

function handleWitchDown(event) {
    if (!game || game.mode !== 'bruxa' || game.finished || game.locked) return;
    const canvas = canvases.bruxa;
    const point = pointerPosition(event, canvas);
    const start = game.witchTarget?.[0];
    if (!start || distance(point, start) > 44) {
        witchFailure('COMECE PELO FOCO');
        return;
    }
    canvas.setPointerCapture?.(event.pointerId);
    game.drawing = true;
    game.trace = [start];
    coverWitchSamples(start);
    game.guideHits = 1;
    game.guideChecks = 1;
    stateLabel.textContent = 'MANTENHA O TRAÇO';
    spawnParticles(start.x, start.y, '#d9a3ff', 9);
}

function coverWitchSamples(point) {
    game.witchTarget.forEach((targetPoint, index) => {
        if (!game.covered[index] && distance(point, targetPoint) <= 20) {
            game.covered[index] = 1;
            game.coveredCount += 1;
        }
    });
}

function handleWitchMove(event) {
    if (!game || game.mode !== 'bruxa' || !game.drawing || game.finished) return;
    const point = pointerPosition(event, canvases.bruxa);
    const lastPoint = game.trace[game.trace.length - 1];
    if (!lastPoint || distance(point, lastPoint) >= 2) {
        const movement = lastPoint ? distance(point, lastPoint) : 0;
        game.traceLength += movement;
        game.trace.push(point);
        coverWitchSamples(point);

        let guideDistance = Number.POSITIVE_INFINITY;
        game.witchTarget.forEach((targetPoint) => {
            guideDistance = Math.min(guideDistance, distance(point, targetPoint));
        });
        game.guideChecks += 1;
        if (guideDistance <= 25) game.guideHits += 1;

        while (game.anchorIndex < game.witchAnchors.length) {
            const anchor = game.witchAnchors[game.anchorIndex];
            if (distanceToSegment(anchor, lastPoint || point, point) > 28) break;
            game.anchorIndex += 1;
        }
        spawnParticles(point.x, point.y, '#b45cff', 3);
    }
}

function handleWitchUp() {
    if (!game || game.mode !== 'bruxa' || !game.drawing || game.finished) return;
    game.drawing = false;
    const coverage = game.coveredCount / Math.max(1, game.witchTarget.length);
    const guideAccuracy = game.guideHits / Math.max(1, game.guideChecks);
    const lengthRatio = game.traceLength / Math.max(1, pathLength(game.witchTarget));
    const anchorsComplete = game.anchorIndex >= game.witchAnchors.length;
    const validLength = lengthRatio >= 0.72 && lengthRatio <= 1.45;
    if (coverage >= 0.78 && guideAccuracy >= 0.78 && anchorsComplete && validLength) completeWitchRune();
    else witchFailure('RUNA INCORRETA');
}

function startWitch() {
    const loot = game.options.context === 'loot';
    game.runeCount = loot ? 4 : 3;
    game.runeOrder = uniqueRandomOrder(runeShapes.length, game.runeCount, loot ? 'witch-loot' : 'witch-atm');
    game.runeIndex = 0;
    game.errors = 0;
    game.particles = [];
    document.getElementById('witch-errors').textContent = 'TRAMA ESTÁVEL';
    prepareWitchRune();
}

function renderWitch(now) {
    const { context, width, height } = fitCanvas(canvases.bruxa);
    context.clearRect(0, 0, width, height);
    const target = game.witchTarget || [];

    context.save();
    context.lineCap = 'round';
    context.lineJoin = 'round';
    context.setLineDash([4, 9]);
    context.lineWidth = 2;
    context.strokeStyle = 'rgba(210, 181, 230, 0.27)';
    strokePolyline(context, target);
    context.setLineDash([]);

    if (game.trace?.length > 1) {
        context.shadowColor = '#9d3dff';
        context.shadowBlur = 13;
        context.lineWidth = 8;
        context.strokeStyle = 'rgba(130, 47, 219, 0.42)';
        strokePolyline(context, game.trace);
        context.shadowBlur = 5;
        context.lineWidth = 3;
        context.strokeStyle = '#ebd5ff';
        strokePolyline(context, game.trace);
    }

    if (game.completedTrace && now - game.completedAt < 620) {
        const alpha = 1 - ((now - game.completedAt) / 620);
        context.globalAlpha = alpha;
        context.shadowColor = '#c16bff';
        context.shadowBlur = 22;
        context.lineWidth = 6;
        context.strokeStyle = '#f3dfff';
        strokePolyline(context, game.completedTrace);
    }
    context.restore();

    if (!game.locked && target.length) {
        const current = game.drawing && game.trace.length
            ? game.trace[game.trace.length - 1]
            : target[0];
        const pulse = 7 + (Math.sin(now / 150) * 2);
        context.save();
        context.fillStyle = '#f4e5ff';
        context.shadowColor = '#b34dff';
        context.shadowBlur = 16;
        context.beginPath();
        context.arc(current.x, current.y, pulse, 0, Math.PI * 2);
        context.fill();
        context.restore();
    }
    renderParticles(context);
    renderFlash(context, width, height, now);
}

function nodePoint(index, width, height) {
    return pointFor(bloodNodes[index], width, height);
}

function bloodLinkKey(a, b) {
    return a < b ? `${a}:${b}` : `${b}:${a}`;
}

function isBloodLinked(a, b) {
    const key = bloodLinkKey(a, b);
    return bloodLinks.some((link) => bloodLinkKey(link[0], link[1]) === key);
}

function resetBloodRoute(afterMistake = false) {
    if (!game || game.mode !== 'vampiro') return;
    game.routeIndex = 0;
    game.activeBlood = [];
    game.locked = false;
    stateLabel.textContent = afterMistake ? 'RETOME PELO RESERVATÓRIO' : 'ATIVE O RESERVATÓRIO';
    const circuit = game.routeQueue.length > 1 ? `CIRCUITO ${game.circuitIndex + 1}/${game.routeQueue.length} · ` : '';
    document.getElementById('vampire-progress').textContent = `${circuit}0 / ${game.route.length - 1} CONTATOS`;
}

function vampireFailure() {
    if (!game || game.locked) return;
    game.errors += 1;
    game.locked = true;
    setFlash('wrong', 380);
    stateLabel.textContent = 'CANAL ROMPIDO';
    document.getElementById('vampire-errors').textContent = `${3 - game.errors} TENTATIVAS`;
    if (game.errors >= 3) {
        finish(false, 'PRESSÃO HEMÁTICA PERDIDA');
        return;
    }
    window.setTimeout(() => resetBloodRoute(true), 430);
}

function completeBloodCircuit() {
    if (game.circuitIndex + 1 < game.routeQueue.length) {
        game.locked = true;
        stateLabel.textContent = 'CIRCUITO ABSORVIDO / PREPARE O PRÓXIMO';
        document.getElementById('vampire-errors').textContent = 'FLUXO PRESERVADO';
        window.setTimeout(() => {
            if (!game || game.finished) return;
            game.circuitIndex += 1;
            game.route = [...game.routeQueue[game.circuitIndex]];
            resetBloodRoute(false);
        }, 620);
        return;
    }
    game.locked = true;
    game.ejectStartedAt = performance.now();
    stateLabel.textContent = 'TERMINAL DE PAGAMENTO ABERTO';
    document.getElementById('vampire-errors').textContent = 'FLUXO COMPLETO';
    window.setTimeout(() => finish(true), 1350);
}

function handleVampireDown(event) {
    if (!game || game.mode !== 'vampiro' || game.finished || game.locked) return;
    const { width, height } = fitCanvas(canvases.vampiro);
    const point = pointerPosition(event, canvases.vampiro);
    let selected = -1;
    let nearest = 34;
    bloodNodes.forEach((_, index) => {
        const hitDistance = distance(point, nodePoint(index, width, height));
        if (hitDistance < nearest) {
            selected = index;
            nearest = hitDistance;
        }
    });
    if (selected < 0) return;

    if (game.routeIndex === 0) {
        if (selected !== game.route[0]) {
            vampireFailure();
            return;
        }
        game.routeIndex = 1;
        stateLabel.textContent = 'SIGA A CORRENTE VIVA';
        spawnParticles(point.x, point.y, '#ff3654', 12);
        return;
    }

    const previous = game.route[game.routeIndex - 1];
    const expected = game.route[game.routeIndex];
    if (!isBloodLinked(previous, selected) || selected !== expected) {
        vampireFailure();
        return;
    }

    game.activeBlood.push([previous, selected]);
    game.routeIndex += 1;
    game.segmentStartedAt = performance.now();
    spawnParticles(point.x, point.y, '#d30a2b', 10);
    const circuit = game.routeQueue.length > 1 ? `CIRCUITO ${game.circuitIndex + 1}/${game.routeQueue.length} · ` : '';
    document.getElementById('vampire-progress').textContent = `${circuit}${game.routeIndex - 1} / ${game.route.length - 1} CONTATOS`;
    stateLabel.textContent = 'SANGUE EM CIRCULAÇÃO';
    if (game.routeIndex >= game.route.length) completeBloodCircuit();
}

function startVampire() {
    const loot = game.options.context === 'loot';
    const source = loot ? bloodLootRoutes : bloodRoutes;
    const selected = uniqueRandomOrder(source.length, loot ? 2 : 1, loot ? 'vampire-loot' : 'vampire-atm');
    game.routeQueue = selected.map((index) => [...source[index]]);
    game.circuitIndex = 0;
    game.route = [...game.routeQueue[0]];
    game.errors = 0;
    game.particles = [];
    game.ejectStartedAt = 0;
    document.getElementById('vampire-errors').textContent = 'PRESSÃO ESTÁVEL';
    resetBloodRoute(false);
}

function drawBloodLink(context, from, to, color, width, glow = 0) {
    context.save();
    context.lineCap = 'round';
    context.strokeStyle = color;
    context.lineWidth = width;
    if (glow) {
        context.shadowColor = color;
        context.shadowBlur = glow;
    }
    context.beginPath();
    context.moveTo(from.x, from.y);
    context.lineTo(to.x, to.y);
    context.stroke();
    context.restore();
}

function drawMoneyEjection(context, origin, now) {
    const elapsed = Math.min(1, (now - game.ejectStartedAt) / 1050);
    for (let index = 0; index < 7; index += 1) {
        const local = Math.max(0, Math.min(1, (elapsed * 1.7) - (index * 0.10)));
        if (local <= 0) continue;
        const angle = -0.8 + (index * 0.27);
        const travel = 28 + (local * 105);
        const x = origin.x + (Math.cos(angle) * travel);
        const y = origin.y + (Math.sin(angle) * travel) + (local * local * 42);
        context.save();
        context.translate(x, y);
        context.rotate(angle + (local * 2.4));
        context.globalAlpha = 1 - (local * 0.32);
        context.fillStyle = '#d6c27a';
        context.strokeStyle = '#5f4e24';
        context.lineWidth = 1;
        context.fillRect(-12, -5, 24, 10);
        context.strokeRect(-12, -5, 24, 10);
        context.restore();
    }
}

function renderVampire(now) {
    const { context, width, height } = fitCanvas(canvases.vampiro);
    context.clearRect(0, 0, width, height);

    bloodLinks.forEach(([a, b]) => {
        drawBloodLink(context, nodePoint(a, width, height), nodePoint(b, width, height), 'rgba(151, 118, 74, 0.25)', 2);
    });

    game.activeBlood.forEach(([a, b], index) => {
        const from = nodePoint(a, width, height);
        const to = nodePoint(b, width, height);
        drawBloodLink(context, from, to, '#b50726', 7, 10);
        drawBloodLink(context, from, to, '#ff6477', 2);
        const flow = ((now / 650) + (index * 0.19)) % 1;
        const bead = { x: from.x + ((to.x - from.x) * flow), y: from.y + ((to.y - from.y) * flow) };
        context.save();
        context.fillStyle = '#ffd4d8';
        context.shadowColor = '#ff183d';
        context.shadowBlur = 12;
        context.beginPath();
        context.arc(bead.x, bead.y, 4, 0, Math.PI * 2);
        context.fill();
        context.restore();
    });

    bloodNodes.forEach((_, index) => {
        const point = nodePoint(index, width, height);
        const isTerminal = index >= 12;
        const isRoute = game.route.includes(index);
        const isCurrent = game.routeIndex > 0 && index === game.route[game.routeIndex - 1];
        const isExpected = !game.locked && index === game.route[game.routeIndex];
        const pulse = 1 + ((Math.sin((now / 170) + index) + 1) * 0.12);
        context.save();
        context.translate(point.x, point.y);
        context.scale(isExpected ? pulse : 1, isExpected ? pulse : 1);
        context.fillStyle = isCurrent ? '#e41e3f' : (isTerminal ? '#2a170f' : '#12090b');
        context.strokeStyle = isExpected ? '#ff9aaa' : (isRoute ? '#9f3444' : '#604c3f');
        context.lineWidth = isExpected ? 3 : 2;
        if (isExpected) {
            context.shadowColor = '#ff2449';
            context.shadowBlur = 16;
        }
        context.beginPath();
        context.arc(0, 0, isTerminal ? 13 : 9, 0, Math.PI * 2);
        context.fill();
        context.stroke();
        context.beginPath();
        context.arc(0, 0, isTerminal ? 5 : 3, 0, Math.PI * 2);
        context.fillStyle = isExpected ? '#ffe0e2' : '#8b2333';
        context.fill();
        context.restore();
    });

    if (game.ejectStartedAt) {
        const terminal = nodePoint(game.route[game.route.length - 1], width, height);
        drawMoneyEjection(context, terminal, now);
    }
    renderParticles(context);
    renderFlash(context, width, height, now);
}

function healerTarget() {
    if (!game || game.orderIndex >= game.vineOrder.length) return null;
    const vineIndex = game.vineOrder[game.orderIndex];
    const vine = game.vines[vineIndex];
    return { vineIndex, pointIndex: vine.grown + 1 };
}

function healerFailure() {
    if (!game || game.growing || game.ejectStartedAt) return;
    game.errors += 1;
    setFlash('wrong', 360);
    stateLabel.textContent = 'A SEIVA RECUOU';
    document.getElementById('healer-errors').textContent = `${3 - game.errors} TENTATIVAS`;
    if (game.errors >= 3) finish(false, 'VINHAS RESSECADAS');
}

function beginCashPull() {
    game.ejectStartedAt = performance.now();
    stateLabel.textContent = 'COFRE PRESO PELAS VINHAS';
    document.getElementById('healer-errors').textContent = 'EXTRAÇÃO EM CURSO';
    window.setTimeout(() => finish(true), 1550);
}

function commitHealerGrowth() {
    const pending = game.pendingGrowth;
    if (!pending) return;
    const vine = game.vines[pending.vineIndex];
    vine.grown = pending.pointIndex;
    game.growing = false;
    game.pendingGrowth = null;
    if (vine.grown >= vine.path.length - 1) {
        game.orderIndex += 1;
        document.getElementById('healer-progress').textContent = `${game.orderIndex} / 3 VINHAS`;
        stateLabel.textContent = 'VINHA ANCORADA';
        if (game.orderIndex >= game.vineOrder.length) {
            beginCashPull();
            return;
        }
    } else {
        stateLabel.textContent = 'A VINHA PROCURA LUZ';
    }
}

function handleHealerDown(event) {
    if (!game || game.mode !== 'curandeira' || game.finished || game.growing || game.ejectStartedAt) return;
    const target = healerTarget();
    if (!target) return;
    const { width, height } = fitCanvas(canvases.curandeira);
    const click = pointerPosition(event, canvases.curandeira);
    const expected = pointFor(game.vines[target.vineIndex].path[target.pointIndex], width, height);
    if (distance(click, expected) > 34) {
        healerFailure();
        return;
    }
    game.growing = true;
    game.growthStartedAt = performance.now();
    game.pendingGrowth = target;
    stateLabel.textContent = 'SEIVA EM MOVIMENTO';
    spawnParticles(expected.x, expected.y, '#b8ff9e', 12);
}

function startHealer() {
    game.vines = vinePaths.map((path) => ({ path, grown: 0 }));
    game.vineOrder = shuffle([0, 1, 2]);
    game.orderIndex = 0;
    game.errors = 0;
    game.growing = false;
    game.pendingGrowth = null;
    game.ejectStartedAt = 0;
    game.particles = [];
    document.getElementById('healer-progress').textContent = '0 / 3 VINHAS';
    document.getElementById('healer-errors').textContent = 'RAÍZES DESPERTAS';
    stateLabel.textContent = 'ATIVE O PRIMEIRO BROTO';
}

function smoothVinePath(context, points) {
    if (!points || points.length < 2) return;
    context.beginPath();
    context.moveTo(points[0].x, points[0].y);
    for (let index = 1; index < points.length - 1; index += 1) {
        const middleX = (points[index].x + points[index + 1].x) / 2;
        const middleY = (points[index].y + points[index + 1].y) / 2;
        context.quadraticCurveTo(points[index].x, points[index].y, middleX, middleY);
    }
    const last = points[points.length - 1];
    context.lineTo(last.x, last.y);
    context.stroke();
}

function drawLeaf(context, point, angle, alpha = 1) {
    context.save();
    context.translate(point.x, point.y);
    context.rotate(angle);
    context.globalAlpha = alpha;
    context.fillStyle = '#65c875';
    context.beginPath();
    context.ellipse(0, 0, 7, 3, 0, 0, Math.PI * 2);
    context.fill();
    context.restore();
}

function drawCashBundle(context, progress, width, height) {
    const start = { x: width * 0.50, y: height * 0.17 };
    const end = { x: width * 0.50, y: height * 0.81 };
    const eased = 1 - Math.pow(1 - progress, 3);
    const point = {
        x: start.x + ((end.x - start.x) * eased),
        y: start.y + ((end.y - start.y) * eased),
    };
    context.save();
    context.translate(point.x, point.y);
    context.rotate(Math.sin(progress * 12) * 0.08);
    context.shadowColor = '#90e77c';
    context.shadowBlur = 18;
    context.fillStyle = '#c8b66e';
    context.strokeStyle = '#5f5429';
    context.lineWidth = 2;
    context.fillRect(-30, -13, 60, 26);
    context.strokeRect(-30, -13, 60, 26);
    context.fillStyle = '#526b36';
    context.fillRect(-4, -13, 8, 26);
    context.restore();
}

function renderHealer(now) {
    const { context, width, height } = fitCanvas(canvases.curandeira);
    context.clearRect(0, 0, width, height);

    game.vines.forEach((vine, vineIndex) => {
        const guide = vine.path.map((point) => pointFor(point, width, height));
        context.save();
        context.lineCap = 'round';
        context.setLineDash([2, 10]);
        context.strokeStyle = 'rgba(146, 187, 102, 0.20)';
        context.lineWidth = 2;
        smoothVinePath(context, guide);
        context.restore();

        const grownPoints = guide.slice(0, vine.grown + 1);
        if (game.growing && game.pendingGrowth?.vineIndex === vineIndex) {
            const progress = Math.min(1, (now - game.growthStartedAt) / 330);
            const from = guide[vine.grown];
            const to = guide[vine.grown + 1];
            grownPoints.push({
                x: from.x + ((to.x - from.x) * progress),
                y: from.y + ((to.y - from.y) * progress),
            });
            if (progress >= 1) window.setTimeout(commitHealerGrowth, 0);
        }

        if (grownPoints.length > 1) {
            context.save();
            context.lineCap = 'round';
            context.lineJoin = 'round';
            context.shadowColor = '#55c96d';
            context.shadowBlur = 11;
            context.strokeStyle = vineIndex === 1 ? '#78d886' : '#4daf65';
            context.lineWidth = 7;
            smoothVinePath(context, grownPoints);
            context.shadowBlur = 0;
            context.strokeStyle = '#b2e58d';
            context.lineWidth = 1.5;
            smoothVinePath(context, grownPoints);
            context.restore();
            grownPoints.slice(1).forEach((point, index) => drawLeaf(context, point, index % 2 ? -0.8 : 0.8));
        }
    });

    if (!game.ejectStartedAt) {
        const target = healerTarget();
        if (target && !game.growing) {
            const point = pointFor(game.vines[target.vineIndex].path[target.pointIndex], width, height);
            const pulse = 11 + ((Math.sin(now / 150) + 1) * 3);
            context.save();
            context.fillStyle = '#e8ffd4';
            context.strokeStyle = '#62dc76';
            context.lineWidth = 3;
            context.shadowColor = '#72e98a';
            context.shadowBlur = 18;
            context.beginPath();
            context.arc(point.x, point.y, pulse, 0, Math.PI * 2);
            context.fill();
            context.stroke();
            context.restore();
        }
    } else {
        const progress = Math.min(1, (now - game.ejectStartedAt) / 1250);
        drawCashBundle(context, progress, width, height);
    }

    renderParticles(context);
    renderFlash(context, width, height, now);
}

function clampNumber(value, minimum, maximum, fallback) {
    value = Number(value);
    return Number.isFinite(value) ? Math.min(maximum, Math.max(minimum, value)) : fallback;
}

function startLock() {
    const pinCount = Math.round(clampNumber(game.options.pins, 3, 7, 5));
    game.lockPins = Array.from({ length: pinCount }, () => ({
        lift: 0,
        target: 0.38 + (Math.random() * 0.45),
        locked: false,
    }));
    game.lockIndex = 0;
    game.lockAttempts = Math.round(clampNumber(game.options.attempts, 1, 6, 3));
    game.lockTolerance = clampNumber(game.options.tolerance, 0.035, 0.14, 0.075);
    game.lockHolding = false;
    game.lastFrameAt = performance.now();
    document.getElementById('lock-progress').textContent = `PINO 1 / ${pinCount}`;
    document.getElementById('lock-errors').textContent = 'GAZUA INTACTA';
    stateLabel.textContent = 'ENCONTRE A LINHA DE CORTE';
}

function lockFailure(reason) {
    if (!game || game.mode !== 'fechadura') return;
    game.lockHolding = false;
    game.lockAttempts -= 1;
    const pin = game.lockPins[game.lockIndex];
    if (pin) pin.lift = 0;
    setFlash('wrong', 380);
    stateLabel.textContent = reason;
    document.getElementById('lock-errors').textContent = `${game.lockAttempts} TENTATIVAS`;
    if (game.lockAttempts <= 0) finish(false, 'GAZUA ROMPIDA');
}

function handleLockDown(event) {
    if (game?.variantController) {
        if (!game.finished) game.variantController.pointerDown?.(event);
        return;
    }
    if (!game || game.mode !== 'fechadura' || game.finished || game.lockHolding) return;
    const { width } = fitCanvas(canvases.fechadura);
    const point = pointerPosition(event, canvases.fechadura);
    const selected = Math.min(game.lockPins.length - 1, Math.max(0, Math.floor(point.x / (width / game.lockPins.length))));
    if (selected !== game.lockIndex) {
        lockFailure('TRABALHE OS PINOS EM SEQUÊNCIA');
        return;
    }
    canvases.fechadura.setPointerCapture?.(event.pointerId);
    game.lockHolding = true;
    stateLabel.textContent = 'SOLTE NA MARCA';
}

function handleLockMove(event) {
    if (!game?.variantController || game.finished) return;
    game.variantController.pointerMove?.(event);
}

function handleLockUp() {
    if (game?.variantController) {
        if (!game.finished) game.variantController.pointerUp?.();
        return;
    }
    if (!game || game.mode !== 'fechadura' || !game.lockHolding || game.finished) return;
    game.lockHolding = false;
    const pin = game.lockPins[game.lockIndex];
    if (Math.abs(pin.lift - pin.target) > game.lockTolerance) {
        lockFailure(pin.lift > pin.target ? 'PINO ULTRAPASSOU O CORTE' : 'PINO ABAIXO DO CORTE');
        return;
    }

    pin.lift = pin.target;
    pin.locked = true;
    game.lockIndex += 1;
    setFlash('hit', 300);
    if (game.lockIndex >= game.lockPins.length) {
        stateLabel.textContent = 'CILINDRO LIBERADO';
        window.setTimeout(() => finish(true), 650);
        return;
    }
    document.getElementById('lock-progress').textContent = `PINO ${game.lockIndex + 1} / ${game.lockPins.length}`;
    stateLabel.textContent = 'PRÓXIMO PINO';
}

function renderLock(now) {
    const { context, width, height } = fitCanvas(canvases.fechadura);
    const elapsed = Math.min(40, now - (game.lastFrameAt || now));
    game.lastFrameAt = now;
    if (game.lockHolding) {
        const pin = game.lockPins[game.lockIndex];
        pin.lift = Math.min(1, pin.lift + (elapsed * 0.00058));
        if (pin.lift >= 1) lockFailure('PINO FORÇADO DEMAIS');
    }

    context.clearRect(0, 0, width, height);
    const cellWidth = width / game.lockPins.length;
    game.lockPins.forEach((pin, index) => {
        const x = (cellWidth * index) + (cellWidth / 2);
        const targetY = height * (0.82 - (pin.target * 0.58));
        const pinY = height * (0.82 - (pin.lift * 0.58));
        const active = index === game.lockIndex;

        context.save();
        context.strokeStyle = active ? 'rgba(199, 150, 255, 0.82)' : 'rgba(191, 174, 148, 0.25)';
        context.lineWidth = active ? 2 : 1;
        context.beginPath();
        context.moveTo(x - (cellWidth * 0.34), targetY);
        context.lineTo(x + (cellWidth * 0.34), targetY);
        context.stroke();

        context.fillStyle = pin.locked ? '#a772df' : '#9b8e79';
        context.strokeStyle = pin.locked ? '#ead7ff' : '#d3c4aa';
        context.lineWidth = 1.5;
        context.fillRect(x - (cellWidth * 0.18), pinY, cellWidth * 0.36, height - pinY);
        context.strokeRect(x - (cellWidth * 0.18), pinY, cellWidth * 0.36, height - pinY);
        context.fillStyle = pin.locked ? '#e8d5ff' : '#b6a68b';
        context.fillRect(x - (cellWidth * 0.27), pinY - 7, cellWidth * 0.54, 8);
        context.restore();
    });

    const current = game.lockPins[Math.min(game.lockIndex, game.lockPins.length - 1)];
    if (current && !current.locked) {
        const x = (cellWidth * game.lockIndex) + (cellWidth / 2);
        const pinY = height * (0.82 - (current.lift * 0.58));
        context.save();
        context.strokeStyle = '#d8c6a4';
        context.lineWidth = 3;
        context.beginPath();
        context.moveTo(width * 0.06, height * 0.93);
        context.lineTo(x, pinY + 12);
        context.stroke();
        context.restore();
    }
    renderFlash(context, width, height, now);
}

function circularDistance(first, second) {
    const difference = Math.abs(first - second) % 100;
    return Math.min(difference, 100 - difference);
}

function startVault() {
    const tumblerCount = 3;
    game.vaultCombination = [];
    while (game.vaultCombination.length < tumblerCount) {
        const value = Math.floor(8 + (Math.random() * 84));
        const previous = game.vaultCombination[game.vaultCombination.length - 1];
        if (previous === undefined || circularDistance(value, previous) >= 16) game.vaultCombination.push(value);
    }
    game.vaultIndex = 0;
    game.vaultValue = 0;
    game.vaultDragging = false;
    game.vaultMotion = 0;
    game.vaultContactLatched = false;
    game.vaultAttempts = Math.round(clampNumber(game.options.attempts, 1, 6, 3));
    game.vaultTolerance = clampNumber(game.options.tolerance, 2, 9, 4);
    updateVaultLocks();
    updateVaultLabels();
    stateLabel.textContent = 'GIRE DEVAGAR E ESCUTE O MECANISMO';
}

function updateVaultLabels() {
    document.getElementById('vault-progress').textContent = `FECHADURA ${game.vaultIndex + 1} / ${game.vaultCombination.length}`;
    document.getElementById('vault-target').textContent = 'ENCONTRE O NÚMERO / ESCUTE';
}

function updateVaultLocks() {
    document.querySelectorAll('[data-vault-lock]').forEach((element, index) => {
        element.classList.toggle('is-unlocked', index < game.vaultIndex);
        element.classList.toggle('is-active', index === game.vaultIndex);
        element.classList.remove('is-error');
    });
}

function vaultFailure(reason) {
    game.vaultDragging = false;
    game.vaultAttempts -= 1;
    game.vaultMotion = 0;
    const activeLock = document.querySelector(`[data-vault-lock="${game.vaultIndex}"]`);
    activeLock?.classList.add('is-error');
    window.setTimeout(() => activeLock?.classList.remove('is-error'), 420);
    setFlash('wrong', 380, false);
    stateLabel.textContent = reason;
    if (game.vaultAttempts <= 0) finish(false, 'MECANISMO BLOQUEADO');
}

function handleVaultDown(event) {
    if (game?.variantController) {
        if (!game.finished) game.variantController.pointerDown?.(event);
        return;
    }
    if (!game || game.mode !== 'cofre' || game.finished) return;
    const point = pointerPosition(event, canvases.cofre);
    const { width, height } = fitCanvas(canvases.cofre);
    game.vaultLastAngle = Math.atan2(point.y - (height / 2), point.x - (width / 2));
    game.vaultMotion = 0;
    game.vaultDragging = true;
    canvases.cofre.setPointerCapture?.(event.pointerId);
    stateLabel.textContent = 'ESCUTE OS DISCOS INTERNOS';
}

function handleVaultMove(event) {
    if (game?.variantController) {
        if (!game.finished) game.variantController.pointerMove?.(event);
        return;
    }
    if (!game || game.mode !== 'cofre' || !game.vaultDragging || game.finished) return;
    const point = pointerPosition(event, canvases.cofre);
    const { width, height } = fitCanvas(canvases.cofre);
    const angle = Math.atan2(point.y - (height / 2), point.x - (width / 2));
    let delta = angle - game.vaultLastAngle;
    if (delta > Math.PI) delta -= Math.PI * 2;
    if (delta < -Math.PI) delta += Math.PI * 2;
    game.vaultLastAngle = angle;
    game.vaultMotion += delta;
    game.vaultValue = (game.vaultValue + ((delta / (Math.PI * 2)) * 100) + 100) % 100;

    const target = game.vaultCombination[game.vaultIndex];
    const currentNumber = Math.round(game.vaultValue) % 100;
    if (currentNumber === target && !game.vaultContactLatched) {
        game.vaultContactLatched = true;
        ritualAudio?.cue('vaultContact');
        stateLabel.textContent = 'CLIQUE ENCONTRADO / SOLTE O DISCO';
    } else if (currentNumber !== target) {
        game.vaultContactLatched = false;
        stateLabel.textContent = 'GIRE DEVAGAR E ESCUTE O MECANISMO';
    }
}

function handleVaultUp() {
    if (game?.variantController) {
        if (!game.finished) game.variantController.pointerUp?.();
        return;
    }
    if (!game || game.mode !== 'cofre' || !game.vaultDragging || game.finished) return;
    game.vaultDragging = false;
    const target = game.vaultCombination[game.vaultIndex];
    const currentNumber = Math.round(game.vaultValue) % 100;
    if (!game.vaultContactLatched || currentNumber !== target) {
        vaultFailure('DISCO FORA DA MARCA');
        return;
    }

    game.vaultValue = target;
    game.vaultIndex += 1;
    game.vaultContactLatched = false;
    updateVaultLocks();
    setFlash('hit', 360, false);
    if (game.vaultIndex >= game.vaultCombination.length) {
        stateLabel.textContent = 'TRÊS FECHADURAS LIBERADAS';
        window.setTimeout(() => finish(true), 720);
        return;
    }
    updateVaultLabels();
    stateLabel.textContent = 'FECHADURA LIBERADA / CONTINUE';
}

function renderVault(now) {
    const { context, width, height } = fitCanvas(canvases.cofre);
    const centerX = width / 2;
    const centerY = height / 2;
    const radius = Math.min(width, height) * 0.43;
    const angle = (game.vaultValue / 100) * Math.PI * 2;
    context.clearRect(0, 0, width, height);

    context.save();
    context.translate(centerX, centerY);
    context.rotate(angle);
    context.fillStyle = '#11151a';
    context.strokeStyle = '#b5a17d';
    context.lineWidth = 3;
    context.beginPath();
    context.arc(0, 0, radius, 0, Math.PI * 2);
    context.fill();
    context.stroke();
    for (let index = 0; index < 50; index += 1) {
        const tickAngle = (index / 50) * Math.PI * 2;
        const inner = radius * (index % 5 === 0 ? 0.76 : 0.84);
        context.strokeStyle = index % 5 === 0 ? '#d1bf9e' : '#716958';
        context.lineWidth = index % 5 === 0 ? 2 : 1;
        context.beginPath();
        context.moveTo(Math.cos(tickAngle) * inner, Math.sin(tickAngle) * inner);
        context.lineTo(Math.cos(tickAngle) * radius * 0.94, Math.sin(tickAngle) * radius * 0.94);
        context.stroke();
    }
    context.restore();

    context.save();
    context.fillStyle = '#090c10';
    context.strokeStyle = game.vaultDragging ? '#70e1ec' : '#a9895b';
    context.lineWidth = 2;
    context.beginPath();
    context.arc(centerX, centerY, radius * 0.52, 0, Math.PI * 2);
    context.fill();
    context.stroke();
    context.fillStyle = '#eee4d1';
    context.font = `600 ${Math.floor(radius * 0.34)}px Georgia`;
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(String(Math.round(game.vaultValue) % 100).padStart(2, '0'), centerX, centerY);
    context.fillStyle = '#6ee0eb';
    context.beginPath();
    context.moveTo(centerX, centerY - radius - 4);
    context.lineTo(centerX - 8, centerY - radius + 12);
    context.lineTo(centerX + 8, centerY - radius + 12);
    context.closePath();
    context.fill();
    context.restore();
    renderFlash(context, width, height, now);
}

function createVariantController(mode, variant, options) {
    if (variant === 'humano' || !window.ObIlegalVariantGames) return null;
    const canvas = canvases[mode];
    const prefix = mode === 'fechadura' ? 'lock' : 'vault';
    return window.ObIlegalVariantGames.create(mode === 'fechadura' ? 'lock' : 'vault', variant, {
        canvas,
        options,
        fit: () => fitCanvas(canvas),
        position: (event) => pointerPosition(event, canvas),
        capture: (event) => canvas.setPointerCapture?.(event.pointerId),
        progress: (value) => { document.getElementById(`${prefix}-progress`).textContent = value; },
        secondary: (value) => {
            document.getElementById(mode === 'fechadura' ? 'lock-errors' : 'vault-target').textContent = value;
        },
        state: (value) => { stateLabel.textContent = value; },
        flash: setFlash,
        sound: (name, detail) => ritualAudio?.cue(name, detail),
        finish,
    });
}

function renderFrame(now) {
    if (!game) return;
    if (game.variantController) game.variantController.render(now);
    else if (game.mode === 'vampiro') renderVampire(now);
    else if (game.mode === 'curandeira') renderHealer(now);
    else if (game.mode === 'fechadura') renderLock(now);
    else if (game.mode === 'cofre') renderVault(now);
    else renderWitch(now);
    animationFrame = window.requestAnimationFrame(renderFrame);
}

function openGame(mode, timeLimit, preview = false, options = {}) {
    stopRuntime();
    const requestedVariant = String(options?.classId || 'humano').toLowerCase();
    const variant = ['humano', 'bruxa', 'vampiro', 'curandeira'].includes(requestedVariant) ? requestedVariant : 'humano';
    const mechanismDefinition = mechanismModes[mode]?.[variant];
    const definition = mechanismDefinition || modes[mode] || modes.bruxa;
    game = { mode, variant, preview, finished: false, particles: [], options: options || {} };
    game.variantController = createVariantController(mode, variant, game.options);
    panel.className = `ritual-panel mode-${mode}${mechanismDefinition ? ` variant-${variant}` : ''}`;
    eyebrow.textContent = definition.eyebrow;
    title.textContent = definition.title;
    if (mode === 'fechadura') document.getElementById('lock-instruction').textContent = definition.instruction;
    if (mode === 'cofre') document.getElementById('vault-instruction').textContent = definition.instruction;
    app.classList.remove('is-hidden');
    app.style.display = 'grid';
    app.setAttribute('aria-hidden', 'false');
    ritualAudio?.unlock();

    window.requestAnimationFrame(() => {
        if (!game) return;
        if (game.variantController) game.variantController.start();
        else if (mode === 'vampiro') startVampire();
        else if (mode === 'curandeira') startHealer();
        else if (mode === 'fechadura') startLock();
        else if (mode === 'cofre') startVault();
        else startWitch();
        startClock(Math.max(15000, Number(timeLimit) || 24000));
        animationFrame = window.requestAnimationFrame(renderFrame);
    });
}

canvases.bruxa.addEventListener('pointerdown', handleWitchDown);
canvases.bruxa.addEventListener('pointermove', handleWitchMove);
canvases.bruxa.addEventListener('pointerup', handleWitchUp);
canvases.bruxa.addEventListener('pointercancel', handleWitchUp);
canvases.vampiro.addEventListener('pointerdown', handleVampireDown);
canvases.curandeira.addEventListener('pointerdown', handleHealerDown);
canvases.fechadura.addEventListener('pointerdown', handleLockDown);
canvases.fechadura.addEventListener('pointermove', handleLockMove);
canvases.fechadura.addEventListener('pointerup', handleLockUp);
canvases.fechadura.addEventListener('pointercancel', handleLockUp);
canvases.cofre.addEventListener('pointerdown', handleVaultDown);
canvases.cofre.addEventListener('pointermove', handleVaultMove);
canvases.cofre.addEventListener('pointerup', handleVaultUp);
canvases.cofre.addEventListener('pointercancel', handleVaultUp);

window.addEventListener('pointerdown', () => {
    ritualAudio?.unlock();
    if (!(game?.mode === 'cofre' && !game.variantController)) ritualAudio?.cue('touch');
}, { capture: true });

closeButton?.addEventListener('click', () => finish(false, 'RITUAL CANCELADO'));

window.addEventListener('keydown', (event) => {
    if (!game || game.finished) return;
    if (event.code === 'Escape') {
        event.preventDefault();
        finish(false, 'RITUAL CANCELADO');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openAtmMinigame') {
        openGame(data.mode, data.timeLimit, false, data.options);
    } else if (data.action === 'closeAtmMinigame') {
        app.classList.add('is-hidden');
        app.style.display = 'none';
        app.setAttribute('aria-hidden', 'true');
        stopRuntime();
    }
});

const previewParams = new URLSearchParams(window.location.search);
const previewMode = previewParams.get('preview');
if (previewMode && modes[previewMode]) {
    openGame(previewMode, 90000, true, {
        pins: Number(previewParams.get('pins')) || 5,
        tumblers: Number(previewParams.get('tumblers')) || 3,
        classId: previewParams.get('class') || 'humano',
        context: previewParams.get('context') || 'atm',
    });
}
