const app = document.getElementById('wingApp');
const panel = document.querySelector('.wing-panel');
const closeMenu = document.getElementById('closeMenu');
const wingVisual = document.getElementById('wingVisual');
const wingImage = document.getElementById('wingImage');
const wingName = document.getElementById('wingName');
const wingDescription = document.getElementById('wingDescription');
const wingState = document.getElementById('wingState');
const wingTier = document.getElementById('wingTier');
const wingColorLabel = document.getElementById('wingColorLabel');
const colorSwatch = document.getElementById('colorSwatch');
const collectionCount = document.getElementById('collectionCount');
const lockNotice = document.getElementById('lockNotice');
const lockTitle = document.getElementById('lockTitle');
const lockDescription = document.getElementById('lockDescription');
const wingList = document.getElementById('wingList');
const wingSelector = document.getElementById('wingSelector');
const equipWing = document.getElementById('equipWing');
const equipLabel = document.getElementById('equipLabel');
const previousWing = document.getElementById('previousWing');
const nextWing = document.getElementById('nextWing');
const feedback = document.getElementById('menuFeedback');
const actionButtons = [...document.querySelectorAll('[data-action]')];
const query = new URLSearchParams(window.location.search);
const isPreview = query.has('preview');
const pageSize = 7;

app.classList.remove('is-visible');
app.setAttribute('aria-hidden', 'true');
document.documentElement.style.background = 'transparent';
document.body.style.background = 'transparent';
document.body.classList.remove('nui-booting');

const state = {
    wings: [],
    selectedIndex: 0,
    equippedId: null,
    busy: false,
    feedbackTimer: 0,
    runeBalance: 0,
};

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'ob_curandeiras';

function post(name, payload = {}) {
    return fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).then((response) => response.json()).catch(() => isPreview
        ? { success: true }
        : { success: false, message: 'A ligação com as asas falhou.' });
}

function resolveImage(source) {
    if (!source) return 'assets/wings/aurora.png';
    if (isPreview && source.startsWith('https://cfx-nui-MathStoreFairyWing-V7/')) {
        return source.replace(
            'https://cfx-nui-MathStoreFairyWing-V7/',
            '../../MathStoreFairyWing-V7/'
        );
    }
    return source;
}

function selectedWing() {
    return state.wings[state.selectedIndex] || null;
}

function wingPrice(wing) {
    return Math.max(0, Math.floor(Number(wing?.priceRunes) || 0));
}

function canPurchase(wing) {
    return Boolean(
        wing
        && wing.unlocked !== true
        && wing.modelAvailable !== false
        && wingPrice(wing) > 0
    );
}

function rgbChannels(wing) {
    const channels = Array.isArray(wing?.effectColor) ? wing.effectColor : [0.35, 0.9, 0.55];
    return channels.map((value) => Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 255));
}

function setTheme(wing) {
    const [red, green, blue] = rgbChannels(wing);
    panel.style.setProperty('--accent-rgb', `${red}, ${green}, ${blue}`);
    const pale = [red, green, blue]
        .map((channel) => Math.round(channel + ((255 - channel) * 0.5)))
        .join(', ');
    panel.style.setProperty('--accent-pale', `rgb(${pale})`);
}

function showFeedback(message) {
    window.clearTimeout(state.feedbackTimer);
    feedback.textContent = message || '';
    feedback.classList.toggle('is-visible', Boolean(message));
    if (message) {
        state.feedbackTimer = window.setTimeout(() => {
            feedback.classList.remove('is-visible');
        }, 2200);
    }
}

function prefetchImages(centerIndex) {
    const start = Math.max(0, centerIndex - 2);
    const end = Math.min(state.wings.length, centerIndex + pageSize + 2);
    state.wings.slice(start, end).forEach((wing) => {
        const image = new Image();
        image.src = resolveImage(wing.image);
    });
}

function setBusy(busy) {
    state.busy = busy;
    const wing = selectedWing();
    const equipped = Boolean(wing && state.equippedId === wing.id);
    const availableAction = wing?.unlocked === true || canPurchase(wing);
    equipWing.disabled = busy || !wing || !availableAction || equipped;
    actionButtons.forEach((button) => {
        button.disabled = busy || !equipped;
    });
}

function renderSelector() {
    wingList.replaceChildren();
    if (!state.wings.length) return;

    const pageStart = Math.floor(state.selectedIndex / pageSize) * pageSize;
    const page = state.wings.slice(pageStart, pageStart + pageSize);
    page.forEach((wing, offset) => {
        const index = pageStart + offset;
        const button = document.createElement('button');
        button.type = 'button';
        button.className = [
            'wing-dot',
            index === state.selectedIndex ? 'is-selected' : '',
            wing.unlocked === true ? '' : 'is-locked',
        ].filter(Boolean).join(' ');
        button.setAttribute('role', 'option');
        button.setAttribute('aria-selected', String(index === state.selectedIndex));
        button.setAttribute('aria-label', `${wing.label}, ${wing.unlocked ? 'liberada' : 'bloqueada'}`);
        button.title = wing.label;

        const image = document.createElement('img');
        image.src = resolveImage(wing.image);
        image.alt = '';
        image.draggable = false;
        button.appendChild(image);
        button.addEventListener('click', () => {
            state.selectedIndex = index;
            render();
        });
        wingList.appendChild(button);
    });

    previousWing.disabled = state.wings.length < 2;
    nextWing.disabled = state.wings.length < 2;
    prefetchImages(pageStart);
}

function renderEmpty() {
    wingName.textContent = 'Nenhuma manifestação';
    wingDescription.textContent = 'As coleções etéreas não responderam.';
    wingState.textContent = 'Indisponível';
    wingTier.textContent = 'Coleções';
    collectionCount.textContent = '000 / 000';
    wingImage.src = 'assets/wings/aurora.png';
    wingVisual.classList.add('is-locked');
    wingState.classList.add('is-locked');
    colorSwatch.classList.add('is-locked');
    colorSwatch.classList.add('is-locked');
    lockNotice.hidden = false;
    lockTitle.textContent = 'Coleções indisponíveis';
    lockDescription.textContent = 'Tente abrir o vínculo novamente.';
    equipLabel.textContent = 'Indisponível';
    renderSelector();
    setBusy(state.busy);
}

function render() {
    const wing = selectedWing();
    if (!wing) {
        renderEmpty();
        return;
    }

    const equipped = state.equippedId === wing.id;
    const unavailable = wing.modelAvailable === false;
    const unlocked = wing.unlocked === true;
    setTheme(wing);

    const nextImage = resolveImage(wing.image);
    if (wingImage.getAttribute('src') !== nextImage) {
        wingImage.style.opacity = '0';
        const preload = new Image();
        preload.onload = () => {
            wingImage.src = nextImage;
            requestAnimationFrame(() => { wingImage.style.opacity = ''; });
        };
        preload.onerror = () => {
            wingImage.src = 'assets/wings/aurora.png';
            wingImage.style.opacity = '';
        };
        preload.src = nextImage;
    }

    wingName.textContent = wing.label;
    wingDescription.textContent = wing.description
        || 'Uma manifestação etérea vinculada à essência de sua portadora.';
    wingTier.textContent = unlocked
        ? (wingPrice(wing) > 0 ? 'Liberada' : (wing.tier || 'Liberada'))
        : 'Bloqueado';
    wingColorLabel.textContent = `Cor ${String(wing.color || 0).padStart(3, '0')}`;
    collectionCount.textContent = `${String(state.selectedIndex + 1).padStart(3, '0')} / ${String(state.wings.length).padStart(3, '0')}`;
    wingVisual.classList.toggle('is-locked', !unlocked);
    wingState.classList.toggle('is-locked', !unlocked);
    colorSwatch.classList.toggle('is-locked', !unlocked);

    if (equipped) {
        wingState.textContent = 'Manifestada';
        equipLabel.textContent = 'Asas manifestadas';
    } else if (unlocked) {
        wingState.textContent = 'Liberada';
        equipLabel.textContent = 'Manifestar asas';
    } else if (unavailable) {
        wingState.textContent = 'Bloqueada';
        equipLabel.textContent = 'Modelo indisponível';
    } else {
        wingState.textContent = 'Bloqueada';
        equipLabel.textContent = `Desbloquear · ${wingPrice(wing)} Runas`;
    }

    lockNotice.hidden = unlocked;
    if (!unlocked) {
        lockTitle.textContent = 'Bloqueado';
        lockDescription.textContent = unavailable
            ? 'O modelo desta asa ainda não está disponível.'
            : `Saldo disponível: ${state.runeBalance} Runas.`;
    }

    renderSelector();
    setBusy(state.busy);
}

function open(payload) {
    state.wings = Array.isArray(payload.wings) ? payload.wings : [];
    state.equippedId = payload.equippedId || null;
    state.runeBalance = Math.max(0, Math.floor(Number(payload.runeBalance) || 0));
    const equippedIndex = state.wings.findIndex((wing) => wing.id === state.equippedId);
    const freeIndex = state.wings.findIndex((wing) => wing.unlocked === true);
    state.selectedIndex = equippedIndex >= 0 ? equippedIndex : Math.max(0, freeIndex);
    state.busy = false;
    app.classList.add('is-visible');
    app.setAttribute('aria-hidden', 'false');
    render();
}

function close() {
    app.classList.remove('is-visible');
    app.setAttribute('aria-hidden', 'true');
    post('close');
}

async function runAction(action) {
    const wing = selectedWing();
    if (!wing || state.busy) return;
    if (wing.unlocked !== true) {
        showFeedback(wing.lockReason || 'Esta manifestação ainda está bloqueada.');
        return;
    }

    setBusy(true);
    const result = await post('wingAction', { action, wingId: wing.id });
    if (result && result.success) {
        if (action === 'equip') state.equippedId = wing.id;
        if (action === 'hide') state.equippedId = null;
        showFeedback(result.message || 'A essência respondeu.');
        const settleMs = Math.max(0, Number(result.settleMs) || 0);
        if (settleMs > 0) {
            await new Promise((resolve) => window.setTimeout(resolve, settleMs));
        }
    } else {
        showFeedback(result?.message || 'A asa não respondeu.');
    }
    setBusy(false);
    render();
}

async function purchaseWing() {
    const wing = selectedWing();
    if (!canPurchase(wing) || state.busy) return;

    setBusy(true);
    const result = await post('buyWing', { wingId: wing.id });
    if (result?.success) {
        const purchasedId = wing.id;
        wing.unlocked = true;
        wing.locked = false;
        wing.lockReason = null;
        wing.tier = result.tier || 'Liberada';
        state.runeBalance = Math.max(0, Math.floor(Number(result.balance) || 0));
        state.wings = state.wings
            .map((entry, index) => ({ entry, index }))
            .sort((left, right) => {
                if (left.entry.unlocked !== right.entry.unlocked) {
                    return left.entry.unlocked ? -1 : 1;
                }
                return left.index - right.index;
            })
            .map(({ entry }) => entry);
        state.selectedIndex = state.wings.findIndex((entry) => entry.id === purchasedId);
        showFeedback(result.message || 'Asa adicionada às suas coleções.');
    } else {
        showFeedback(result?.message || 'Não foi possível desbloquear esta asa.');
    }
    setBusy(false);
    render();
}

function moveSelection(direction) {
    if (!state.wings.length) return;
    state.selectedIndex = (state.selectedIndex + direction + state.wings.length) % state.wings.length;
    render();
}

equipWing.addEventListener('click', () => {
    const wing = selectedWing();
    if (wing?.unlocked === true) {
        runAction('equip');
    } else {
        purchaseWing();
    }
});
actionButtons.forEach((button) => {
    button.addEventListener('click', () => runAction(button.dataset.action));
});
closeMenu.addEventListener('click', close);
previousWing.addEventListener('click', () => moveSelection(-1));
nextWing.addEventListener('click', () => moveSelection(1));

wingSelector.addEventListener('wheel', (event) => {
    event.preventDefault();
    moveSelection(event.deltaY > 0 || event.deltaX > 0 ? 1 : -1);
}, { passive: false });

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' || event.key === 'F6') close();
    if (event.key === 'ArrowLeft') moveSelection(-1);
    if (event.key === 'ArrowRight') moveSelection(1);
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data);
    if (data.action === 'close') {
        app.classList.remove('is-visible');
        app.setAttribute('aria-hidden', 'true');
    }
    if (data.action === 'state') {
        state.equippedId = data.equippedId || null;
        render();
    }
});

async function openPreview() {
    let catalog = [];
    try {
        catalog = await fetch('assets/wings/catalog.json?v=3').then((response) => response.json());
    } catch (_) {
        catalog = [];
    }

    const installed = new Set([1, 2, 36, 37, 40, 51, 79, 105, 106, 114]);
    const requestedColors = (query.get('colors') || '79,103,1,106,36,114,105,37,51,40,2')
        .split(',')
        .map((value) => Number.parseInt(value.trim(), 10))
        .filter(Number.isFinite);
    const wingByColor = new Map(catalog.map((wing) => [wing.color, wing]));
    const wings = requestedColors.map((color) => wingByColor.get(color)).filter(Boolean).map((wing) => ({
        ...wing,
        label: wing.color === 79
            ? 'Asas da Aurora'
            : (wing.color === 103 ? 'Asas do Crepúsculo' : wing.label),
        description: wing.color === 79
            ? 'A manifestação vital concedida a todas as Curandeiras.'
            : (wing.color === 103
                ? 'Uma manifestação rosada marcada por olhos etéreos.'
                : 'Uma manifestação etérea rara, aguardando um novo vínculo.'),
        tier: wing.color === 79 ? 'Curandeira' : (installed.has(wing.color) ? 'Bloqueado' : 'Em breve'),
        modelAvailable: installed.has(wing.color),
        unlocked: wing.color === 79,
        locked: wing.color !== 79,
        lockReason: installed.has(wing.color)
            ? 'Esta asa ainda não foi desbloqueada.'
            : 'Modelo aguardando disponibilidade.',
        priceRunes: wing.color === 79 ? 0 : 750,
    }));

    open({
        wings,
        runeBalance: Number.parseInt(query.get('runes') || '2450', 10),
        equippedId: query.get('equipped') === '1' ? 'asa_079' : null,
    });
}

window.addEventListener('load', () => {
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
});

if (isPreview) openPreview();
