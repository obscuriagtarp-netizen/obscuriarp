const hud = document.getElementById('hud');
const cluster = document.getElementById('abilityCluster');
const essenceMeter = document.getElementById('essenceMeter');
const essenceValue = document.getElementById('essenceValue');
const essenceLabel = document.getElementById('essenceLabel');
const overloadMeter = document.getElementById('overloadMeter');
const overloadValue = document.getElementById('overloadValue');
const keybindBackdrop = document.getElementById('keybindBackdrop');
const keybindRows = document.getElementById('keybindRows');
const keybindFeedback = document.getElementById('keybindFeedback');
const keybindProvider = document.getElementById('keybindProvider');
const keybindClose = document.getElementById('keybindClose');
const keybindDefaults = document.getElementById('keybindDefaults');
const keybindCancel = document.getElementById('keybindCancel');
const keybindSave = document.getElementById('keybindSave');
const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'obscuriaHud';

const state = {
  provider: null,
  visible: false,
  essence: null,
  overload: null,
  status: null,
  cooldowns: new Map(),
};

const keybindState = {
  open: false,
  provider: null,
  bindings: {},
  listeningId: null,
  allowedKeys: new Set(),
};

const slotElements = new Map();
let cooldownTimer = null;

function postNui(endpoint, payload = {}) {
  return fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload),
  })
    .then((response) => response.json())
    .catch(() => null);
}

function resolveIcon(icon) {
  if (!icon) return '';

  return String(icon).replace(/^nui:\/\/([^/]+)\//, 'https://cfx-nui-$1/');
}

function applyTheme(theme = {}) {
  hud.style.setProperty('--accent', theme.accent || '#a39b91');
  hud.style.setProperty('--accent-soft', theme.accentSoft || '#24211f');
  hud.style.setProperty('--essence-color', theme.essenceColor || theme.accent || '#a39b91');
  hud.style.setProperty('--essence-dark', theme.essenceDark || theme.accentSoft || '#292622');
  hud.style.setProperty('--essence-highlight', theme.essenceHighlight || theme.essenceColor || theme.accent || '#c7c1b8');
  hud.style.setProperty('--frame-hue', theme.frameHue || '0deg');
}

function applyPosition(position = {}) {
  ['right', 'bottom', 'left', 'top'].forEach((property) => {
    hud.style[property] = position[property] || '';
  });

  hud.style.setProperty('--hud-scale', Number(position.scale) || 0.9);
}

function createSlot(slot) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'ability-slot is-disabled';
  button.dataset.slot = String(slot);
  button.setAttribute('aria-label', `Poder ${slot}`);
  button.innerHTML = `
    <span class="slot-surface"></span>
    <span class="slot-icon-mask">
      <img class="slot-icon" alt="" draggable="false" />
    </span>
    <span class="cooldown-fill"></span>
    <span class="lock-fill"></span>
    <span class="cooldown-text"></span>
    <span class="slot-key">${slot}</span>
    <img class="slot-frame" src="assets/ability-slot-frame.png" alt="" draggable="false" />
  `;

  button.addEventListener('click', () => postNui('activate', { slot }));
  cluster.appendChild(button);
  slotElements.set(slot, button);
}

for (let slot = 1; slot <= 4; slot += 1) {
  createSlot(slot);
}

function normalizeEssence(data) {
  const max = Math.max(0, Number(data?.max) || 0);
  const value = Math.max(0, Math.min(max, Number(data?.value) || 0));

  return {
    value,
    max,
    label: String(data?.label || 'Essencia'),
    key: data?.key || null,
    class: data?.class || null,
  };
}

function renderEssence(changeDirection = null) {
  const essence = normalizeEssence(state.essence);
  const available = essence.max > 0;
  const ratio = available ? essence.value / essence.max : 0;
  const percentage = Math.round(ratio * 100);

  essenceMeter.classList.remove('is-changing', 'is-spending', 'is-restoring');
  if (available && changeDirection) {
    essenceMeter.classList.add(
      'is-changing',
      changeDirection === 'restore' ? 'is-restoring' : 'is-spending',
    );
    void essenceMeter.offsetWidth;
  }

  essenceMeter.classList.toggle('is-empty', !available);
  essenceMeter.style.setProperty('--essence-offset', `${100 - percentage}%`);
  essenceValue.textContent = available ? `${Math.round(essence.value)}` : '0';
  essenceLabel.textContent = essence.label;
  essenceMeter.setAttribute(
    'aria-label',
    available
      ? `${essence.label}: ${Math.round(essence.value)} de ${Math.round(essence.max)}`
      : 'Essencia indisponivel',
  );

  if (changeDirection && available) {
    window.setTimeout(() => {
      essenceMeter.classList.remove('is-changing', 'is-spending', 'is-restoring');
    }, changeDirection === 'restore' ? 900 : 680);
  }
}

function normalizeOverload(data) {
  const max = Math.max(1, Number(data?.max) || 100);
  return {
    success: data?.success === true,
    class: String(data?.class || ''),
    value: Math.max(0, Math.min(max, Number(data?.value) || 0)),
    max,
    tier: String(data?.tier || 'stable'),
    tierLabel: String(data?.tierLabel || 'Estavel'),
  };
}

function normalizeClassId(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

function resolveOverloadColor(overload) {
  const colors = {
    bruxa: '#a64ce6',
    witch: '#a64ce6',
    vampiro: '#df334d',
    vampire: '#df334d',
    curandeira: '#45bf72',
    healer: '#45bf72',
  };
  const candidates = [
    overload.class,
    state.essence?.class,
    state.provider?.archetype,
  ];

  for (const candidate of candidates) {
    const color = colors[normalizeClassId(candidate)];
    if (color) return color;
  }

  return state.provider?.theme?.essenceColor || state.provider?.theme?.accent || '#927f9e';
}

function renderOverload() {
  const overload = normalizeOverload(state.overload);
  const available = overload.success && overload.class !== 'humano';
  const percentage = Math.round((overload.value / overload.max) * 100);

  overloadMeter.classList.toggle('is-hidden', !available);
  overloadMeter.classList.remove('is-strained', 'is-unstable', 'is-critical', 'is-rupture');
  if (available && overload.tier !== 'stable') {
    overloadMeter.classList.add(`is-${overload.tier}`);
  }

  overloadMeter.style.setProperty('--overload-angle', `${percentage * 3.6}deg`);
  overloadMeter.style.setProperty('--overload-color', resolveOverloadColor(overload));
  overloadValue.textContent = `${percentage}`;
  overloadMeter.setAttribute(
    'aria-label',
    `Excesso sobrenatural: ${percentage}%. Estado: ${overload.tierLabel}`,
  );
}

function renderSlot(slot, ability) {
  const element = slotElements.get(slot);
  const icon = element.querySelector('.slot-icon');
  const key = element.querySelector('.slot-key');

  const activeAbilityId = state.status?.activeAbilityId || null;
  const isActiveTransformation = Boolean(ability && activeAbilityId === ability.id);
  const runtimeLocked = state.status?.blocked === true && !isActiveTransformation;
  const locked = Boolean(ability && !isActiveTransformation && (ability.enabled === false || runtimeLocked));

  element.classList.toggle('is-empty', !ability);
  element.classList.toggle('is-disabled', !ability || ability.enabled === false);
  element.classList.toggle('is-locked', locked);
  element.classList.toggle('is-transformation-active', isActiveTransformation);
  element.classList.toggle('is-selected', ability?.selected === true);
  const cooldownText = element.querySelector('.cooldown-text');
  element.setAttribute('aria-label', ability?.label || `Poder ${slot}`);
  element.title = ability?.description || ability?.label || '';

  key.textContent = ability?.key || String(slot);
  icon.hidden = true;

  if (ability?.icon) {
    icon.onload = () => {
      icon.hidden = false;
    };
    icon.onerror = () => {
      icon.hidden = true;
    };
    icon.src = resolveIcon(ability.icon);
  } else {
    icon.removeAttribute('src');
  }

  if (ability?.cooldownRemaining > 0) {
    const remaining = Number(ability.cooldownRemaining || 0);
    const duration = Math.max(
      Number(ability.cooldownDuration || 0),
      remaining,
    );
    state.cooldowns.set(ability.id, {
      end: performance.now() + remaining,
      duration,
      slot,
    });
    const ratio = duration > 0 ? remaining / duration : 0;
    element.classList.add('is-cooling');
    element.style.setProperty('--cooldown-ratio', ratio.toFixed(4));
    element.style.setProperty('--cooldown-offset', `${((1 - ratio) * 100).toFixed(2)}%`);
    cooldownText.textContent = Math.ceil(remaining / 1000);
  } else {
    element.classList.remove('is-cooling');
    element.style.setProperty('--cooldown-ratio', '0');
    element.style.setProperty('--cooldown-offset', '100%');
    cooldownText.textContent = '';
    if (ability?.id) state.cooldowns.delete(ability.id);
  }
}

function getProviderAbilities(provider = keybindState.provider) {
  return [...(provider?.abilities || [])]
    .filter((ability) => ability && ability.id)
    .sort((left, right) => {
      const leftOrder = Number(left.defaultKey);
      const rightOrder = Number(right.defaultKey);

      if (Number.isFinite(leftOrder) && Number.isFinite(rightOrder)) {
        return leftOrder - rightOrder;
      }

      return Number(left.slot) - Number(right.slot);
    });
}

function setKeybindFeedback(message = '', isError = false) {
  keybindFeedback.textContent = message;
  keybindFeedback.classList.toggle('is-error', isError);
}

function renderKeybindRows() {
  keybindRows.replaceChildren();

  getProviderAbilities().forEach((ability, abilityIndex) => {
    const row = document.createElement('div');
    const listening = keybindState.listeningId === ability.id;
    row.className = `keybind-row${listening ? ' is-listening' : ''}`;

    const index = document.createElement('span');
    index.className = 'keybind-index';
    index.textContent = String(abilityIndex + 1).padStart(2, '0');

    const iconWrap = document.createElement('span');
    iconWrap.className = 'keybind-icon';
    const icon = document.createElement('img');
    icon.alt = '';
    icon.draggable = false;
    icon.src = resolveIcon(ability.icon);
    iconWrap.appendChild(icon);

    const label = document.createElement('span');
    label.className = 'keybind-name';
    label.textContent = ability.label;

    const keyButton = document.createElement('button');
    keyButton.type = 'button';
    keyButton.className = 'keybind-key';
    keyButton.dataset.abilityId = ability.id;
    keyButton.textContent = listening ? '...' : (keybindState.bindings[ability.id] || ability.key);
    keyButton.setAttribute('aria-label', `Alterar tecla de ${ability.label}`);
    keyButton.addEventListener('click', () => {
      keybindState.listeningId = ability.id;
      setKeybindFeedback('Pressione uma das teclas permitidas.');
      renderKeybindRows();
    });

    row.append(index, iconWrap, label, keyButton);
    keybindRows.appendChild(row);
  });
}

function closeKeybindPanel(notifyGame = true) {
  keybindState.open = false;
  keybindState.provider = null;
  keybindState.bindings = {};
  keybindState.listeningId = null;
  keybindBackdrop.classList.add('is-hidden');
  keybindBackdrop.setAttribute('aria-hidden', 'true');
  setKeybindFeedback();

  if (notifyGame) postNui('closeKeybinds');
}

function openKeybindPanel(provider, allowedKeys = []) {
  if (!provider) return;

  keybindState.open = true;
  keybindState.provider = provider;
  keybindState.listeningId = null;
  keybindState.allowedKeys = new Set(
    allowedKeys.map((entry) => String(entry?.key || entry || '').toUpperCase()).filter(Boolean),
  );
  keybindState.bindings = Object.fromEntries(
    getProviderAbilities(provider).map((ability) => [ability.id, String(ability.key || ability.defaultKey || ability.slot)]),
  );

  keybindProvider.textContent = String(provider.label || provider.archetype || 'Poderes sobrenaturais').toUpperCase();

  keybindBackdrop.classList.remove('is-hidden');
  keybindBackdrop.setAttribute('aria-hidden', 'false');
  setKeybindFeedback();
  renderKeybindRows();
}

function keyFromEvent(event) {
  if (/^Digit[1-9]$/.test(event.code)) return event.code.slice(-1);
  if (/^Numpad[1-9]$/.test(event.code)) return event.code.slice(-1);
  if (/^Key[A-Z]$/.test(event.code)) return event.code.slice(-1);
  return '';
}

function captureKeybind(event) {
  if (!keybindState.open) return;

  if (event.key === 'Escape') {
    event.preventDefault();
    if (keybindState.listeningId) {
      keybindState.listeningId = null;
      setKeybindFeedback();
      renderKeybindRows();
    } else {
      closeKeybindPanel();
    }
    return;
  }

  if (!keybindState.listeningId) return;

  event.preventDefault();
  const nextKey = keyFromEvent(event);
  if (!nextKey || !keybindState.allowedKeys.has(nextKey)) {
    setKeybindFeedback('Essa tecla nao esta disponivel para habilidades.', true);
    return;
  }

  const abilityId = keybindState.listeningId;
  const previousKey = keybindState.bindings[abilityId];
  const conflict = Object.entries(keybindState.bindings)
    .find(([id, key]) => id !== abilityId && key === nextKey);

  if (conflict) {
    keybindState.bindings[conflict[0]] = previousKey;
  }

  keybindState.bindings[abilityId] = nextKey;
  keybindState.listeningId = null;
  setKeybindFeedback(conflict ? 'As duas teclas foram trocadas.' : 'Nova tecla selecionada.');
  renderKeybindRows();
}

document.addEventListener('keydown', captureKeybind);
keybindClose.addEventListener('click', () => closeKeybindPanel());
keybindCancel.addEventListener('click', () => closeKeybindPanel());
keybindDefaults.addEventListener('click', () => {
  getProviderAbilities().forEach((ability) => {
    keybindState.bindings[ability.id] = String(ability.defaultKey || ability.slot);
  });
  keybindState.listeningId = null;
  setKeybindFeedback('Teclas padrao restauradas. Salve para confirmar.');
  renderKeybindRows();
});
keybindSave.addEventListener('click', async () => {
  keybindState.listeningId = null;
  const result = await postNui('saveKeybinds', { bindings: keybindState.bindings });
  if (!window.GetParentResourceName || result?.ok) {
    closeKeybindPanel(false);
  } else {
    setKeybindFeedback('Nao foi possivel salvar essas teclas.', true);
    renderKeybindRows();
  }
});

function render() {
  const provider = state.provider;
  hud.classList.toggle('is-hidden', !state.visible || !provider);

  if (!provider) return;

  applyTheme(provider.theme);
  renderEssence();
  renderOverload();

  const bySlot = new Map((provider.abilities || []).map((ability) => [Number(ability.slot), ability]));
  for (let slot = 1; slot <= 4; slot += 1) {
    renderSlot(slot, bySlot.get(slot));
  }

  ensureCooldownUpdates();
}

function updateCooldowns(now) {
  cooldownTimer = null;
  state.cooldowns.forEach((cooldown, abilityId) => {
    const element = slotElements.get(cooldown.slot);
    if (!element) return;

    const remaining = Math.max(0, cooldown.end - now);
    const ratio = cooldown.duration > 0 ? remaining / cooldown.duration : 0;
    const text = element.querySelector('.cooldown-text');

    element.classList.toggle('is-cooling', remaining > 0);
    element.style.setProperty('--cooldown-ratio', ratio.toFixed(4));
    element.style.setProperty('--cooldown-offset', `${((1 - ratio) * 100).toFixed(2)}%`);
    text.textContent = remaining > 0 ? Math.ceil(remaining / 1000) : '';

    if (remaining <= 0) {
      element.style.setProperty('--cooldown-offset', '100%');
      state.cooldowns.delete(abilityId);
    }
  });

  ensureCooldownUpdates();
}

function ensureCooldownUpdates() {
  if (cooldownTimer !== null || !state.visible || !state.provider || state.cooldowns.size === 0) {
    return;
  }

  cooldownTimer = window.setTimeout(() => updateCooldowns(performance.now()), 100);
}

function stopCooldownUpdates() {
  if (cooldownTimer !== null) {
    window.clearTimeout(cooldownTimer);
    cooldownTimer = null;
  }
}

window.addEventListener('message', ({ data }) => {
  if (!data || !data.action) return;

  if (data.action === 'hydrate') {
    state.visible = data.visible === true;
    state.provider = data.provider || null;
    state.essence = data.essence || null;
    state.overload = data.overload || null;
    state.status = data.status || null;
    state.cooldowns.clear();
    applyPosition(data.position);
    render();
    if (!state.visible) stopCooldownUpdates();
    return;
  }

  if (data.action === 'keybindsOpen') {
    openKeybindPanel(data.provider, data.allowedKeys || []);
    return;
  }

  if (data.action === 'keybindsClose') {
    closeKeybindPanel(false);
    return;
  }

  if (data.action === 'essence') {
    const previous = Number(state.essence?.value);
    state.essence = data.essence || null;
    const next = Number(state.essence?.value);
    const direction = Number.isFinite(previous) && Number.isFinite(next) && previous !== next
      ? (next > previous ? 'restore' : 'spend')
      : null;
    renderEssence(direction);
    return;
  }

  if (data.action === 'overload') {
    state.overload = data.overload || null;
    renderOverload();
    return;
  }

  if (data.action === 'cooldown' && state.provider) {
    const ability = state.provider.abilities.find((entry) => entry.id === data.abilityId);
    if (ability) {
      state.cooldowns.set(data.abilityId, {
        end: performance.now() + Number(data.duration || 0),
        duration: Number(data.duration || 0),
        slot: Number(ability.slot),
      });
      ensureCooldownUpdates();
    }
    return;
  }

  if (data.action === 'pulse') {
    const ability = state.provider?.abilities.find((entry) => entry.id === data.abilityId);
    const element = ability && slotElements.get(Number(ability.slot));
    if (element) {
      element.classList.remove('is-pulsing', 'is-error');
      void element.offsetWidth;
      element.classList.toggle('is-error', data.variant === 'error');
      element.classList.add('is-pulsing');
      window.setTimeout(() => element.classList.remove('is-pulsing', 'is-error'), data.variant === 'error' ? 620 : 280);
    }
  }
});

postNui('ready');

if (!window.GetParentResourceName) {
  const previewParams = new URLSearchParams(window.location.search);
  const previewWithGrimoire = previewParams.has('grimoire');
  const previewArchetype = String(previewParams.get('archetype') || 'witch').toLowerCase();
  const previewClasses = {
    witch: 'bruxa',
    vampire: 'vampiro',
    healer: 'curandeira',
    human: 'humano',
  };
  const previewThemes = {
    witch: { accent: '#a878d0', accentSoft: '#261832', essenceColor: '#934bd3', essenceDark: '#321447', essenceHighlight: '#c985ef', frameHue: '0deg' },
    vampire: { accent: '#c35a68', accentSoft: '#32151b', essenceColor: '#a80e27', essenceDark: '#3a050d', essenceHighlight: '#e34a61', frameHue: '305deg' },
    healer: { accent: '#83b77a', accentSoft: '#182b1b', essenceColor: '#3a9c61', essenceDark: '#123a22', essenceHighlight: '#73d993', frameHue: '88deg' },
    human: { accent: '#c2a365', accentSoft: '#302817', essenceColor: '#b38734', essenceDark: '#47340f', essenceHighlight: '#e0bd68', frameHue: '42deg' },
  };
  const previewRemaining = Math.max(0, Number(previewParams.get('remaining')) || 0);
  const previewEssence = previewParams.has('essence')
    ? Number(previewParams.get('essence'))
    : 68;
  window.postMessage({
    action: 'hydrate',
    visible: true,
    position: previewWithGrimoire
      ? { right: '4.6vw', bottom: '42vh', scale: 1.0 }
      : { right: '2.2vw', bottom: '1.8vh', scale: 1.0 },
    status: previewParams.has('blocked')
      ? { blocked: true, activeAbilityId: previewParams.get('active') || null }
      : { blocked: false, activeAbilityId: null },
    essence: {
      class: previewClasses[previewArchetype] || 'bruxa',
      key: previewArchetype === 'vampire' ? 'sangue' : 'mana',
      label: previewArchetype === 'vampire' ? 'Sangue' : 'Mana',
      value: Math.max(0, Math.min(100, Number.isFinite(previewEssence) ? previewEssence : 68)),
      max: 100,
    },
    overload: {
      success: true,
      class: previewClasses[previewArchetype] || 'bruxa',
      value: Math.max(0, Math.min(100, Number(previewParams.get('overload')) || 0)),
      max: 100,
      tier: previewParams.get('tier') || 'stable',
      tierLabel: 'Estavel',
    },
    provider: {
      id: 'browser_preview',
      label: 'Bruxa',
      archetype: previewArchetype,
      theme: previewThemes[previewArchetype] || previewThemes.witch,
      abilities: [
        { id: 'familiar', slot: 1, key: '1', defaultKey: '1', label: 'Familiar', icon: '../../ob_bruxas/web/icons/familiar.png', enabled: true },
        { id: 'nevoa_bruxas', slot: 2, key: '4', defaultKey: '4', label: 'Nevoa das Bruxas', icon: '../../ob_bruxas/web/icons/nevoa-das-bruxas.png', enabled: true },
        { id: 'elo_arcano', slot: 3, key: '3', defaultKey: '3', label: 'Elo Arcano', icon: '../../ob_bruxas/web/icons/elo-arcano.png', enabled: true },
        {
          id: 'sentido_arcano',
          slot: 4,
          key: '2',
          defaultKey: '2',
          label: 'Sentido Arcano',
          icon: '../../ob_bruxas/web/icons/sentido-arcano.png',
          enabled: true,
          selected: true,
          cooldownRemaining: previewRemaining,
          cooldownDuration: previewRemaining > 0 ? 8000 : 0,
        },
      ],
    },
  });

  if (previewParams.has('keys')) {
    window.setTimeout(() => {
      openKeybindPanel(state.provider, [
        '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'Q', 'E', 'R', 'F', 'G', 'H', 'K', 'L', 'Z', 'X', 'C', 'V', 'B',
      ]);
    }, 80);
  }

  if (previewParams.has('cooldown')) {
    window.setTimeout(() => {
      window.postMessage({ action: 'cooldown', abilityId: 'sentido_arcano', duration: 8000 });
    }, 100);
  }

  if (previewParams.has('error')) {
    window.setInterval(() => {
      window.postMessage({ action: 'pulse', abilityId: 'familiar', variant: 'error' });
    }, 1400);
  }

  if (previewParams.has('drain')) {
    window.setTimeout(() => {
      window.postMessage({
        action: 'essence',
        essence: { class: 'bruxa', key: 'mana', label: 'Mana', value: 24, max: 100 },
      });
    }, 900);
  }

  if (previewParams.has('animate')) {
    const previewValues = [24, 82, 46, 100, 58];
    let previewIndex = 0;

    window.setInterval(() => {
      window.postMessage({
        action: 'essence',
        essence: {
          class: 'bruxa',
          key: 'mana',
          label: 'Mana',
          value: previewValues[previewIndex],
          max: 100,
        },
      });
      previewIndex = (previewIndex + 1) % previewValues.length;
    }, 2200);
  }
}
