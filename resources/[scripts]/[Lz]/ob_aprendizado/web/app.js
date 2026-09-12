const lessonRoot = document.getElementById('lesson');
const stage = document.querySelector('.trace-stage');
const canvas = document.getElementById('traceCanvas');
const ctx = canvas.getContext('2d');
const spellName = document.getElementById('spellName');
const spellIndex = document.getElementById('spellIndex');
const spellIcon = document.getElementById('spellIcon');
const resultSpellName = document.getElementById('resultSpellName');
const currentKeyImage = document.getElementById('currentKeyImage');
const statusText = document.getElementById('statusText');
const resultSeal = document.getElementById('resultSeal');

const PURPLE = '#a96bff';
const PURPLE_LIGHT = '#eadcff';
const DEFAULT_STEP_TIMEOUT_MS = 2000;
const roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
const keyLabels = {
    SPACE: { full: 'Espaco', image: 'assets/key-space.svg' },
    MOUSE_LEFT: { full: 'Mouse esquerdo', image: 'assets/key-mouse-left.svg' },
    X: { full: 'X', image: 'assets/key-x.png' },
    H: { full: 'H', image: 'assets/key-h.png' },
    E: { full: 'E', image: 'assets/key-e.png' },
    Q: { full: 'Q', image: 'assets/key-q.png' },
    R: { full: 'R', image: 'assets/key-r.png' },
    F: { full: 'F', image: 'assets/key-f.png' },
};

const keyImages = Object.fromEntries(Object.entries(keyLabels).map(([key, data]) => {
    const image = new Image();
    image.src = data.image;
    return [key, image];
}));

const runeDefinitions = {
    f_blink: {
        path: [[26, 90], [25, 72], [26, 53], [25, 34], [28, 13], [49, 10], [72, 14], [61, 19], [35, 19], [30, 42], [50, 41], [66, 46], [53, 50], [30, 49]],
        sequence: ['SPACE', 'MOUSE_LEFT', 'E', 'X', 'Q', 'H'],
        seal: [40, 58],
    },
    u_reparatio: {
        path: [[19, 16], [20, 39], [21, 62], [27, 78], [39, 88], [53, 91], [67, 86], [77, 75], [81, 59], [81, 36], [82, 14]],
        sequence: ['R', 'X', 'SPACE', 'F', 'MOUSE_LEFT', 'Q'],
        seal: [91, 12],
        smooth: true,
    },
    r_vitae: {
        path: [[24, 90], [24, 69], [25, 47], [25, 27], [27, 12], [49, 10], [65, 15], [73, 27], [69, 39], [57, 47], [30, 48], [48, 49], [70, 89]],
        sequence: ['H', 'E', 'MOUSE_LEFT', 'R', 'SPACE', 'F'],
        seal: [88, 90],
    },
    u_petrificus: {
        path: [[16, 13], [18, 35], [21, 59], [27, 75], [39, 87], [52, 91], [66, 86], [76, 74], [80, 57], [82, 34], [84, 12]],
        sequence: ['Q', 'MOUSE_LEFT', 'X', 'E', 'H', 'SPACE'],
        seal: [92, 12],
        smooth: true,
    },
    s_portus: {
        path: [[78, 17], [67, 10], [49, 8], [33, 12], [22, 22], [20, 34], [29, 43], [47, 47], [66, 51], [79, 61], [78, 74], [67, 86], [49, 92], [31, 89], [18, 80]],
        sequence: ['SPACE', 'R', 'F', 'MOUSE_LEFT', 'Q', 'E'],
        seal: [9, 90],
        smooth: true,
    },
    a_invulneris: {
        path: [[14, 90], [23, 70], [32, 49], [41, 28], [50, 9], [59, 28], [68, 49], [77, 70], [86, 90], [74, 62], [27, 62]],
        sequence: ['MOUSE_LEFT', 'E', 'H', 'Q', 'X', 'F'],
        seal: [90, 62],
    },
    t_ignis: {
        path: [[13, 17], [34, 14], [56, 14], [85, 18], [68, 22], [52, 20], [50, 42], [50, 65], [48, 91]],
        sequence: ['X', 'F', 'MOUSE_LEFT', 'SPACE', 'R', 'E'],
        seal: [50, 94],
    },
    o_fauna: {
        path: [[51, 8], [67, 11], [80, 22], [88, 38], [90, 53], [84, 70], [72, 84], [56, 91], [40, 90], [25, 81], [15, 67], [11, 50], [15, 33], [25, 19], [39, 10], [51, 8]],
        sequence: ['H', 'MOUSE_LEFT', 'Q', 'F', 'SPACE', 'R'],
        seal: [94, 4],
        smooth: true,
    },
};

let lesson = null;
let definition = runeDefinitions.f_blink;
let samples = [];
let checkpointIndices = [];
let sequenceStep = 0;
let progress = 0;
let finished = false;
let inputLocked = false;
let inputQueue = [];
let openedAt = 0;
let animationFrame = 0;
let progressFrame = 0;
let stepTimerId = 0;
let stepDeadline = 0;
let stepTimeoutMs = DEFAULT_STEP_TIMEOUT_MS;

function postNui(eventName, payload = {}) {
    if (typeof GetParentResourceName !== 'function') {
        return Promise.resolve({ ok: true, preview: true });
    }

    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).then((response) => response.json());
}

function densify(source, spacing = 0.8) {
    const dense = [];
    for (let index = 0; index < source.length - 1; index += 1) {
        const start = source[index];
        const end = source[index + 1];
        const distance = Math.hypot(end[0] - start[0], end[1] - start[1]);
        const steps = Math.max(3, Math.ceil(distance / spacing));

        for (let step = 0; step < steps; step += 1) {
            const amount = step / steps;
            dense.push([
                start[0] + ((end[0] - start[0]) * amount),
                start[1] + ((end[1] - start[1]) * amount),
            ]);
        }
    }
    dense.push(source[source.length - 1]);
    return dense;
}

function smoothPath(source, steps = 15) {
    const result = [];
    for (let index = 0; index < source.length - 1; index += 1) {
        const p0 = source[Math.max(0, index - 1)];
        const p1 = source[index];
        const p2 = source[index + 1];
        const p3 = source[Math.min(source.length - 1, index + 2)];

        for (let step = 0; step < steps; step += 1) {
            const t = step / steps;
            const t2 = t * t;
            const t3 = t2 * t;
            result.push([
                0.5 * ((2 * p1[0]) + ((-p0[0] + p2[0]) * t) + ((2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2) + ((-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)),
                0.5 * ((2 * p1[1]) + ((-p0[1] + p2[1]) * t) + ((2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2) + ((-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)),
            ]);
        }
    }
    result.push(source[source.length - 1]);
    return result;
}

function buildCheckpointIndices(count) {
    const indices = [];
    const maxIndex = Math.max(0, Math.floor((samples.length - 1) * 0.86));

    for (let index = 0; index < count; index += 1) {
        const ratio = 0.06 + ((index / Math.max(1, count - 1)) * 0.78);
        let candidate = Math.min(maxIndex, Math.round((samples.length - 1) * ratio));

        while (candidate < maxIndex) {
            const point = samples[candidate];
            const separated = indices.every((existing) => {
                const other = samples[existing];
                return Math.hypot(point[0] - other[0], point[1] - other[1]) >= 10;
            });
            if (separated) break;
            candidate += 1;
        }

        indices.push(candidate);
    }
    return indices;
}

function resizeCanvas() {
    const bounds = canvas.getBoundingClientRect();
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    const width = Math.max(1, Math.round(bounds.width * scale));
    const height = Math.max(1, Math.round(bounds.height * scale));
    if (canvas.width === width && canvas.height === height) return;
    canvas.width = width;
    canvas.height = height;
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
}

function toCanvas(point) {
    const bounds = canvas.getBoundingClientRect();
    const size = Math.min(bounds.width * 0.68, bounds.height * 0.84);
    return [
        ((bounds.width - size) / 2) + ((point[0] / 100) * size),
        ((bounds.height - size) / 2) + ((point[1] / 100) * size),
    ];
}

function drawPath(path, count, color, width, glow = 0) {
    if (!path.length || count < 1) return;
    ctx.save();
    ctx.beginPath();
    const first = toCanvas(path[0]);
    ctx.moveTo(first[0], first[1]);

    for (let index = 1; index <= Math.min(Math.floor(count), path.length - 1); index += 1) {
        const point = toCanvas(path[index]);
        ctx.lineTo(point[0], point[1]);
    }

    const fraction = count - Math.floor(count);
    const nextIndex = Math.min(path.length - 1, Math.floor(count) + 1);
    if (fraction > 0 && path[nextIndex]) {
        const current = toCanvas(path[Math.floor(count)]);
        const next = toCanvas(path[nextIndex]);
        ctx.lineTo(current[0] + ((next[0] - current[0]) * fraction), current[1] + ((next[1] - current[1]) * fraction));
    }

    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.shadowColor = color;
    ctx.shadowBlur = glow;
    ctx.stroke();
    ctx.restore();
}

function drawKeyNode(sampleIndex, index, time) {
    const point = samples[sampleIndex];
    if (!point) return;
    const [x, y] = toCanvas(point);
    const done = index < sequenceStep;
    const current = index === sequenceStep && !finished;
    const pulse = current ? Math.sin(time / 210) * 1.4 : 0;
    const radius = 21 + pulse;

    ctx.save();
    ctx.beginPath();
    ctx.arc(x, y, radius + 5, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(5, 9, 11, 0.95)';
    ctx.fill();
    ctx.strokeStyle = current || done ? PURPLE_LIGHT : 'rgba(203, 187, 135, 0.72)';
    ctx.lineWidth = current ? 2.2 : 1.4;
    ctx.shadowColor = current ? PURPLE : 'rgba(198, 180, 120, 0.35)';
    ctx.shadowBlur = current ? 18 : 5;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(x, y, radius - 1, 0, Math.PI * 2);
    ctx.strokeStyle = done ? 'rgba(169, 107, 255, 0.82)' : 'rgba(225, 215, 181, 0.28)';
    ctx.lineWidth = 1;
    ctx.stroke();

    if (current && sequenceStep > 0 && stepDeadline > 0) {
        const remaining = Math.max(0, (stepDeadline - time) / stepTimeoutMs);
        ctx.beginPath();
        ctx.arc(x, y, radius + 9, -Math.PI / 2, (-Math.PI / 2) + (Math.PI * 2 * remaining));
        ctx.strokeStyle = remaining < 0.28 ? '#ff7585' : PURPLE_LIGHT;
        ctx.lineWidth = 2.4;
        ctx.shadowColor = remaining < 0.28 ? '#ff394f' : PURPLE;
        ctx.shadowBlur = 12;
        ctx.stroke();
    }

    const input = definition.sequence[index];
    const keyImage = keyImages[input];
    if (keyImage && keyImage.complete && keyImage.naturalWidth > 0) {
        const isSpace = input === 'SPACE';
        const isMouse = input === 'MOUSE_LEFT';
        const width = isSpace ? 48 : isMouse ? 30 : 29;
        const height = isSpace ? 25 : isMouse ? 42 : 29;
        ctx.globalAlpha = done || current ? 1 : 0.9;
        ctx.drawImage(keyImage, x - (width / 2), y - (height / 2), width, height);
    }
    ctx.restore();
}

function drawPersistentFlames(time) {
    if (progress <= 4) return;
    const head = Math.min(samples.length - 1, Math.floor(progress));
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';

    for (let tendril = 0; tendril < 4; tendril += 1) {
        ctx.beginPath();
        for (let index = 0; index <= head; index += 2) {
            const point = toCanvas(samples[index]);
            const before = toCanvas(samples[Math.max(0, index - 1)]);
            const after = toCanvas(samples[Math.min(samples.length - 1, index + 1)]);
            const tangentX = after[0] - before[0];
            const tangentY = after[1] - before[1];
            const tangentLength = Math.max(1, Math.hypot(tangentX, tangentY));
            const normalX = -tangentY / tangentLength;
            const normalY = tangentX / tangentLength;
            const wave = Math.sin((time * 0.022) + (index * 0.38) + (tendril * 1.7));
            const offset = wave * (1.8 + (tendril * 1.25));
            const x = point[0] + (normalX * offset);
            const y = point[1] + (normalY * offset);
            if (index === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = tendril === 0
            ? 'rgba(239, 218, 255, 0.68)'
            : `rgba(165, 77, 255, ${0.22 + (tendril * 0.07)})`;
        ctx.lineWidth = tendril === 0 ? 1.8 : 1 + (tendril * 0.3);
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.shadowColor = PURPLE;
        ctx.shadowBlur = 10 + (tendril * 2);
        ctx.stroke();
    }

    for (let index = 10; index < head; index += 18) {
        const point = toCanvas(samples[index]);
        const before = toCanvas(samples[Math.max(0, index - 3)]);
        const after = toCanvas(samples[Math.min(samples.length - 1, index + 3)]);
        const angle = Math.atan2(after[1] - before[1], after[0] - before[0]);
        const phase = (time * 0.025) + (index * 0.41);
        const flameLength = 13 + (Math.sin(phase) * 3);
        const flameWidth = 3.2 + (Math.cos(phase * 1.2) * 0.8);
        const wave = Math.sin(phase * 1.35) * 3;

        ctx.save();
        ctx.translate(point[0], point[1]);
        ctx.rotate(angle);
        const gradient = ctx.createLinearGradient(-flameLength, 0, 4, 0);
        gradient.addColorStop(0, 'rgba(113, 33, 204, 0)');
        gradient.addColorStop(0.45, 'rgba(142, 52, 232, 0.32)');
        gradient.addColorStop(0.82, 'rgba(196, 115, 255, 0.78)');
        gradient.addColorStop(1, 'rgba(248, 231, 255, 0.96)');
        ctx.beginPath();
        ctx.moveTo(4, 0);
        ctx.bezierCurveTo(-3, -flameWidth, -flameLength * 0.58, -flameWidth - wave, -flameLength, wave * 0.25);
        ctx.bezierCurveTo(-flameLength * 0.58, flameWidth - wave, -3, flameWidth, 4, 0);
        ctx.fillStyle = gradient;
        ctx.shadowColor = PURPLE;
        ctx.shadowBlur = 14;
        ctx.fill();
        ctx.restore();
    }
    ctx.restore();
}

function drawArcaneFlame(time) {
    if (progress <= 2 || finished) return;
    const head = Math.min(samples.length - 1, Math.floor(progress));

    ctx.save();
    ctx.globalCompositeOperation = 'lighter';

    const headPoint = toCanvas(samples[head]);
    const beforeHead = toCanvas(samples[Math.max(0, head - 4)]);
    const angle = Math.atan2(headPoint[1] - beforeHead[1], headPoint[0] - beforeHead[0]);
    ctx.save();
    ctx.translate(headPoint[0], headPoint[1]);
    ctx.rotate(angle);
    for (let flame = 0; flame < 5; flame += 1) {
        const phase = (time * 0.026) + (flame * 1.45);
        const length = 30 + (flame * 5) + (Math.sin(phase) * 5);
        const width = 5 + (flame * 1.1);
        const wave = Math.sin(phase * 1.3) * 5;
        const flameGradient = ctx.createLinearGradient(-length, 0, 8, 0);
        flameGradient.addColorStop(0, 'rgba(113, 33, 204, 0)');
        flameGradient.addColorStop(0.42, 'rgba(142, 52, 232, 0.34)');
        flameGradient.addColorStop(0.8, 'rgba(196, 115, 255, 0.82)');
        flameGradient.addColorStop(1, 'rgba(248, 231, 255, 0.98)');
        ctx.beginPath();
        ctx.moveTo(8, 0);
        ctx.bezierCurveTo(-8, -width, -length * 0.58, -width - wave, -length, wave * 0.25);
        ctx.bezierCurveTo(-length * 0.58, width - wave, -8, width, 8, 0);
        ctx.fillStyle = flameGradient;
        ctx.shadowColor = PURPLE;
        ctx.shadowBlur = 18;
        ctx.fill();
    }
    ctx.restore();

    for (let flame = 0; flame < 2; flame += 1) {
        const pulse = 7 + (flame * 5) + (Math.sin((time / 90) + flame) * 1.5);
        ctx.beginPath();
        ctx.arc(headPoint[0], headPoint[1], pulse, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(215, 166, 255, ${0.52 - (flame * 0.16)})`;
        ctx.lineWidth = 1.4;
        ctx.shadowColor = PURPLE;
        ctx.shadowBlur = 18;
        ctx.stroke();
    }
    ctx.restore();
}

function drawEndSpellSeal(time) {
    if (!samples.length) return;
    const pathEndpoint = toCanvas(definition.connectorStart || samples[samples.length - 1]);
    const endpoint = toCanvas(definition.seal || samples[samples.length - 1]);
    const connectorPoints = [
        pathEndpoint,
        ...(definition.connector || []).map((point) => toCanvas(point)),
        endpoint,
    ];
    const complete = finished && sequenceStep >= definition.sequence.length;
    const size = complete ? 62 + (Math.sin(time / 210) * 2) : 54;
    const half = size / 2;

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(connectorPoints[0][0], connectorPoints[0][1]);
    for (let index = 1; index < connectorPoints.length; index += 1) {
        ctx.lineTo(connectorPoints[index][0], connectorPoints[index][1]);
    }
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = complete ? PURPLE : 'rgba(188, 169, 109, 0.62)';
    ctx.lineWidth = complete ? 6 : 4;
    ctx.shadowColor = complete ? PURPLE : 'rgba(186, 167, 108, 0.3)';
    ctx.shadowBlur = complete ? 18 : 4;
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(connectorPoints[0][0], connectorPoints[0][1]);
    for (let index = 1; index < connectorPoints.length; index += 1) {
        ctx.lineTo(connectorPoints[index][0], connectorPoints[index][1]);
    }
    ctx.strokeStyle = complete ? PURPLE_LIGHT : 'rgba(233, 224, 190, 0.46)';
    ctx.lineWidth = 1.1;
    ctx.stroke();
    ctx.restore();

    ctx.save();
    ctx.translate(endpoint[0], endpoint[1]);
    ctx.rotate(Math.PI / 4);
    ctx.fillStyle = complete ? 'rgba(20, 8, 29, 0.98)' : 'rgba(4, 7, 9, 0.96)';
    ctx.strokeStyle = complete ? PURPLE_LIGHT : 'rgba(198, 181, 126, 0.72)';
    ctx.lineWidth = complete ? 2.2 : 1.5;
    ctx.shadowColor = complete ? PURPLE : 'rgba(186, 167, 108, 0.35)';
    ctx.shadowBlur = complete ? 25 : 7;
    ctx.fillRect(-half, -half, size, size);
    ctx.strokeRect(-half, -half, size, size);
    ctx.strokeStyle = complete ? 'rgba(169, 107, 255, 0.58)' : 'rgba(215, 201, 155, 0.28)';
    ctx.lineWidth = 1;
    ctx.strokeRect(-half + 6, -half + 6, size - 12, size - 12);

    ctx.beginPath();
    ctx.rect(-half + 7, -half + 7, size - 14, size - 14);
    ctx.clip();
    ctx.rotate(-Math.PI / 4);
    if (spellIcon.complete && spellIcon.naturalWidth > 0) {
        ctx.globalAlpha = complete ? 1 : 0.38;
        ctx.drawImage(spellIcon, -half * 1.02, -half * 1.02, size * 1.02, size * 1.02);
    }
    ctx.restore();
}

function draw() {
    resizeCanvas();
    const time = performance.now();
    ctx.clearRect(0, 0, canvas.clientWidth, canvas.clientHeight);

    drawPath(samples, samples.length - 1, 'rgba(2, 5, 7, 0.95)', 13);
    drawPath(samples, samples.length - 1, 'rgba(188, 169, 109, 0.62)', 4);
    drawPath(samples, samples.length - 1, 'rgba(233, 224, 190, 0.46)', 1.1);

    if (progress > 0) {
        drawPath(samples, progress, PURPLE, 7, 18);
        drawPath(samples, progress, PURPLE_LIGHT, 1.6, 7);
        drawPersistentFlames(time);
        drawArcaneFlame(time);
    }

    drawEndSpellSeal(time);
    checkpointIndices.forEach((sampleIndex, index) => drawKeyNode(sampleIndex, index, time));

    animationFrame = requestAnimationFrame(draw);
}

function updateSequenceUi() {
    const sequence = definition.sequence;
    const activeInput = sequence[Math.min(sequenceStep, sequence.length - 1)];
    currentKeyImage.src = keyLabels[activeInput].image;
    currentKeyImage.alt = keyLabels[activeInput].full;
}

function createVariedSequence(previous = []) {
    const length = Math.min(6, Object.keys(keyLabels).length);
    let candidate = [];

    for (let attempt = 0; attempt < 12; attempt += 1) {
        const pool = Object.keys(keyLabels);
        for (let index = pool.length - 1; index > 0; index -= 1) {
            const swapIndex = Math.floor(Math.random() * (index + 1));
            [pool[index], pool[swapIndex]] = [pool[swapIndex], pool[index]];
        }

        candidate = pool.slice(0, length);
        const equalPositions = candidate.reduce(
            (total, input, index) => total + (input === previous[index] ? 1 : 0),
            0,
        );
        if (!previous.length || (candidate[0] !== previous[0] && equalPositions <= 1)) break;
    }

    return candidate;
}

function clearStepTimer() {
    if (stepTimerId) window.clearTimeout(stepTimerId);
    stepTimerId = 0;
    stepDeadline = 0;
}

function startStepTimer() {
    clearStepTimer();
    if (!lesson || finished || sequenceStep === 0) return;

    stepDeadline = performance.now() + stepTimeoutMs;
    stepTimerId = window.setTimeout(() => {
        stepTimerId = 0;
        stepDeadline = 0;
        void resetAttempt('Tempo esgotado. A runa mudou suas marcas');
    }, stepTimeoutMs);
}

function animateProgress(target, duration = 160) {
    cancelAnimationFrame(progressFrame);
    const startValue = progress;
    const startedAt = performance.now();

    return new Promise((resolve) => {
        const tick = (time) => {
            const ratio = Math.min(1, (time - startedAt) / duration);
            const eased = 1 - Math.pow(1 - ratio, 3);
            progress = startValue + ((target - startValue) * eased);
            if (ratio < 1) {
                progressFrame = requestAnimationFrame(tick);
                return;
            }
            progress = target;
            resolve();
        };
        progressFrame = requestAnimationFrame(tick);
    });
}

function flashError() {
    lessonRoot.classList.remove('is-error');
    void lessonRoot.offsetWidth;
    lessonRoot.classList.add('is-error');
}

async function resetAttempt(message) {
    if (!lesson || finished) return;

    clearStepTimer();
    inputLocked = true;
    inputQueue = [];
    flashError();
    statusText.textContent = message;
    await animateProgress(0, 240);

    sequenceStep = 0;
    definition.sequence = createVariedSequence(definition.sequence);
    checkpointIndices = buildCheckpointIndices(definition.sequence.length);
    inputQueue = [];
    inputLocked = false;
    statusText.textContent = 'Execute a primeira marca';
    updateSequenceUi();
}

async function handleInput(input) {
    if (!lesson || finished) return;
    if (inputLocked) {
        if (inputQueue.length < 8) inputQueue.push(input);
        return;
    }
    const expected = definition.sequence[sequenceStep];

    if (input !== expected) {
        await resetAttempt('Sequencia rompida. As marcas foram alteradas');
        return;
    }

    clearStepTimer();
    inputLocked = true;
    const target = ((sequenceStep + 1) / definition.sequence.length) * (samples.length - 1);
    statusText.textContent = 'A runa responde ao comando';
    await animateProgress(target);
    sequenceStep += 1;
    updateSequenceUi();
    inputLocked = false;

    if (sequenceStep >= definition.sequence.length) {
        finishTrace();
    } else {
        const seconds = stepTimeoutMs / 1000;
        statusText.textContent = `Execute a proxima marca - ${Number.isInteger(seconds) ? seconds : seconds.toFixed(1)} segundos`;
        startStepTimer();
        if (inputQueue.length) handleInput(inputQueue.shift());
    }
}

function finishTrace() {
    if (finished) return;
    clearStepTimer();
    finished = true;
    inputLocked = true;
    statusText.textContent = 'Validando vinculo runico';
    updateSequenceUi();

    postNui('completeLesson', { elapsed: Math.round(performance.now() - openedAt) })
        .then((response) => {
            if (response && response.preview) showResult(true);
        });
}

function showResult(success) {
    clearStepTimer();
    if (success) {
        stage.classList.add('is-complete');
        resultSeal.classList.add('is-visible');
        resultSeal.setAttribute('aria-hidden', 'false');
        statusText.textContent = 'Feitico incorporado ao grimorio';
        return;
    }

    finished = false;
    inputLocked = false;
    sequenceStep = 0;
    progress = 0;
    definition.sequence = createVariedSequence(definition.sequence);
    checkpointIndices = buildCheckpointIndices(definition.sequence.length);
    stage.classList.remove('is-complete');
    resultSeal.classList.remove('is-visible');
    resultSeal.setAttribute('aria-hidden', 'true');
    flashError();
    statusText.textContent = 'O vinculo falhou. Recomece a sequencia';
    updateSequenceUi();
}

function openLesson(payload) {
    clearStepTimer();
    lesson = payload;
    const baseDefinition = runeDefinitions[payload.rune] || runeDefinitions.f_blink;
    definition = { ...baseDefinition, sequence: [...baseDefinition.sequence] };
    const sourcePath = definition.smooth ? smoothPath(definition.path) : definition.path;
    samples = densify(sourcePath);
    checkpointIndices = buildCheckpointIndices(definition.sequence.length);
    sequenceStep = 0;
    progress = 0;
    finished = false;
    inputLocked = false;
    inputQueue = [];
    openedAt = performance.now();
    stepTimeoutMs = Math.min(10000, Math.max(500, Number(payload.inputTimeout) || DEFAULT_STEP_TIMEOUT_MS));

    spellName.textContent = payload.label || payload.spell || 'Feitico';
    resultSpellName.textContent = payload.label || payload.spell || 'Feitico';
    spellIcon.src = payload.icon || payload.image || 'assets/spell-blink.png';
    spellIcon.onerror = () => {
        spellIcon.onerror = null;
        spellIcon.src = payload.image || 'assets/rune-f-blink.png';
    };

    const position = Math.max(1, Number(payload.position) || 1);
    const total = Math.max(1, Number(payload.total) || 8);
    spellIndex.textContent = `${roman[position - 1] || position} / ${roman[total - 1] || total}`;
    statusText.textContent = 'Execute a primeira marca';
    stage.classList.remove('is-complete');
    resultSeal.classList.remove('is-visible');
    resultSeal.setAttribute('aria-hidden', 'true');
    updateSequenceUi();
    lessonRoot.classList.add('is-visible');
    lessonRoot.setAttribute('aria-hidden', 'false');
    lessonRoot.focus({ preventScroll: true });
    cancelAnimationFrame(animationFrame);
    draw();
}

function closeLesson() {
    clearStepTimer();
    lessonRoot.classList.remove('is-visible', 'is-error');
    lessonRoot.setAttribute('aria-hidden', 'true');
    stage.classList.remove('is-complete');
    cancelAnimationFrame(animationFrame);
    cancelAnimationFrame(progressFrame);
    inputQueue = [];
    lesson = null;
}

document.getElementById('closeButton').addEventListener('click', () => postNui('cancelLesson'));

document.addEventListener('keydown', (event) => {
    if (!lesson) return;
    if (event.key === 'Escape') {
        postNui('cancelLesson');
        return;
    }

    const supportedKeys = ['KeyX', 'KeyH', 'KeyE', 'KeyQ', 'KeyR', 'KeyF'];
    const input = event.code === 'Space'
        ? 'SPACE'
        : supportedKeys.includes(event.code)
            ? event.code.slice(3)
            : null;

    if (input) {
        event.preventDefault();
        handleInput(input);
    }
});

lessonRoot.addEventListener('pointerdown', (event) => {
    if (event.button !== 0 || event.target.closest('button')) return;
    handleInput('MOUSE_LEFT');
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openLesson(data.lesson || {});
    if (data.action === 'close') closeLesson();
    if (data.action === 'result') showResult(data.success === true);
});

const previewParams = new URLSearchParams(window.location.search);
const preview = previewParams.get('preview');
if (preview) {
    document.body.classList.add('preview');
    const previews = {
        blink: { spell: 'blink', label: 'Blink', letter: 'F', rune: 'f_blink', image: 'assets/rune-f-blink.png', icon: 'assets/spell-blink.png', position: 1, total: 8 },
        reparatio: { spell: 'machina_reparatio', label: 'Machina Reparatio', letter: 'U', rune: 'u_reparatio', image: 'assets/rune-u-reparatio.png', icon: 'assets/spell-machina_reparatio.png', position: 2, total: 8 },
        vitae: { spell: 'vitae_restituo', label: 'Vitae Restituo', letter: 'R', rune: 'r_vitae', image: 'assets/rune-r-vitae.png', icon: 'assets/spell-vitae_restituo.png', position: 3, total: 8 },
        petrificus: { spell: 'petrificus', label: 'Glacies', letter: 'U', rune: 'u_petrificus', image: 'assets/rune-u-petrificus.png', icon: 'assets/spell-petrificus.png', position: 4, total: 8 },
        portus: { spell: 'portus', label: 'Portus', letter: 'S', rune: 's_portus', image: 'assets/rune-s-portus.png', icon: 'assets/spell-portus.png', position: 5, total: 8 },
        invulneris: { spell: 'invulneris', label: 'Invulneris', letter: 'A', rune: 'a_invulneris', image: 'assets/rune-a-invulneris.png', icon: 'assets/spell-invulneris.png', position: 6, total: 8 },
        ignis: { spell: 'ignis_conflagratio', label: 'Ignis Conflagratio', letter: 'T', rune: 't_ignis', image: 'assets/rune-t-ignis.png', icon: 'assets/spell-ignis_conflagratio.png', position: 7, total: 8 },
        fauna: { spell: 'metamorphus_fauna', label: 'Metamorphus Fauna', letter: 'O', rune: 'o_fauna', image: 'assets/rune-o-fauna.png', icon: 'assets/spell-metamorphus_fauna.png', position: 8, total: 8 },
    };
    openLesson(previews[preview] || previews.blink);

    if (previewParams.get('autoplay') === '1') {
        setTimeout(async () => {
            for (const input of definition.sequence) {
                await handleInput(input);
                await new Promise((resolve) => setTimeout(resolve, 90));
            }
        }, 350);
    }
}
