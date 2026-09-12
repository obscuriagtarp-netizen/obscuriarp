/* ── Debug NUI logging (controlled by Config.HudDebugNui) ── */
let _hudDebug = false;
const _origLog = console.log;
console.log = function(...args) {
  if (_hudDebug) _origLog.apply(console, args);
};

/* ── Locale system (strings received from Lua via NUI message) ── */
let currentStrings = {};
function t(key) {
  return currentStrings[key] !== undefined ? currentStrings[key] : key;
}
function setLabelText(inputId, text) {
  var el = document.getElementById(inputId);
  if (!el) return;
  var lbl = el.closest('label');
  if (!lbl) return;
  for (var i = 0; i < lbl.childNodes.length; i++) {
    var n = lbl.childNodes[i];
    if (n.nodeType === 3 && n.textContent.trim()) {
      n.textContent = n.textContent.replace(n.textContent.trim(), text);
      return;
    }
  }
}

const items = Array.from(document.querySelectorAll('#menuComAsa .radial-item'));
const scene = document.querySelector('.scene');
const root = document.documentElement;
const editToggle = document.getElementById('editToggle');
const editPanel = document.getElementById('editPanel');
const resetLayout = document.getElementById('resetLayout');
const resetPosition = document.getElementById('resetPosition');
const copyLayout = document.getElementById('copyLayout');
const coreIcon = document.querySelector('#coreComAsa .core-wing');

const controls = {
  menuScale: document.getElementById('ctrlScale'),
  menuOffsetX: document.getElementById('ctrlOffsetX'),
  menuOffsetY: document.getElementById('ctrlOffsetY'),
  radius: document.getElementById('ctrlRadius'),
  rotationOffset: document.getElementById('ctrlRotationOffset'),
  itemSize: document.getElementById('ctrlItemSize'),
  iconSize: document.getElementById('ctrlIconSize'),
  iconOffsetX: document.getElementById('ctrlIconOffsetX'),
  iconOffsetY: document.getElementById('ctrlIconOffsetY'),
  labelSize: document.getElementById('ctrlLabelSize'),
  itemLabelOffsetY: document.getElementById('ctrlItemLabelOffsetY'),
  showItemLabels: document.getElementById('ctrlShowItemLabels'),
  showBadges: document.getElementById('ctrlShowBadges'),
  coreIconSize: document.getElementById('ctrlCoreIconSize'),
  coreIconOffsetY: document.getElementById('ctrlCoreIconOffsetY'),
  coreIconPath: document.getElementById('ctrlCoreIconPath'),
  coreLabelSize: document.getElementById('ctrlCoreLabelSize'),
  coreLabelOffset: document.getElementById('ctrlCoreLabelOffset'),
  showCoreLabel: document.getElementById('ctrlShowCoreLabel'),
  clipItemIcons: document.getElementById('ctrlClipItemIcons'),
  colorRing: document.getElementById('ctrlColorRing'),
  colorItemBorder: document.getElementById('ctrlColorItemBorder'),
  colorActiveBorder: document.getElementById('ctrlColorActiveBorder'),
  colorText: document.getElementById('ctrlColorText'),
  iconRitual: document.getElementById('ctrlIconRitual'),
  iconAgachar: document.getElementById('ctrlIconAgachar'),
  iconBater: document.getElementById('ctrlIconBater'),
  iconRemoverasa: document.getElementById('ctrlIconRemoverasa'),
  iconAbrir: document.getElementById('ctrlIconAbrir'),
  iconFechar: document.getElementById('ctrlIconFechar'),
  iconIdles: document.getElementById('ctrlIconIdles'),
};

const iconTargets = {
  ritual: document.querySelector('.radial-item[data-action="ritual"] .icon-image'),
  agachar: document.querySelector('.radial-item[data-action="agachar"] .icon-image'),
  bater: document.querySelector('.radial-item[data-action="bater"] .icon-image'),
  removerasa: document.querySelector('.radial-item[data-action="removerasa"] .icon-image'),
  abrir: document.querySelector('.radial-item[data-action="abrir"] .icon-image'),
  fechar: document.querySelector('.radial-item[data-action="fechar"] .icon-image'),
  meditar: document.querySelector('.radial-item[data-action="meditar"] .icon-image'),
  idles: document.querySelector('.radial-item[data-action="idles"] .icon-image'),
};

const checkboxKeys = new Set(['showItemLabels', 'showBadges', 'showCoreLabel', 'clipItemIcons']);

const STORAGE_KEY = 'asasHudLayoutV12';

// Limpar chaves antigas para garantir defaults novos
['asasHudLayoutV1','asasHudLayoutV2','asasHudLayoutV3','asasHudLayoutV4','asasHudLayoutV5','asasHudLayoutV6','asasHudLayoutV7','asasHudLayoutV8','asasHudLayoutV9','asasHudLayoutV10','asasHudLayoutV11'].forEach((k) => localStorage.removeItem(k));
let hudClosed = true;
let editMode = false;
let inVariantView = false;
let hasWing = false;
let inWingIdPanel = false;
let isMeditating = false;
let isInRitual = false;
let ritualVariant = 0; // 0=none, 1=ritualasa1 (no stages), 2=ritualasa2/3 (has stages)
let isInAgachar = false;
let canEquipWings = true;

// FiveM NUI helper
function postToLua(name, data) {
  return fetch('https://' + GetParentResourceName() + '/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  }).catch(function() {});
}

const defaults = {
  menuScale: '1.47',
  menuOffsetX: '0',
  menuOffsetY: '0',
  radius: '188',
  rotationOffset: '0',
  itemSize: '114',
  iconSize: '112',
  iconOffsetX: '-1',
  iconOffsetY: '-28',
  labelSize: '0.63',
  itemLabelOffsetY: '-10',
  showItemLabels: '1',
  showBadges: '0',
  coreIconSize: '150',
  coreIconOffsetY: '6',
  coreIconPath: 'assets/img/asamenu.png',
  coreLabelSize: '0.79',
  coreLabelOffset: '-24',
  showCoreLabel: '0',
  clipItemIcons: '0',
  colorRing: '#ffffff',
  colorItemBorder: '#ffffff',
  colorActiveBorder: '#fab8ff',
  colorText: '#e7edf7',
  iconRitual: 'assets/img/iconrt.png',
  iconAgachar: 'assets/img/iconag.png',
  iconBater: 'assets/img/asabater.png',
  iconRemoverasa: 'assets/img/iconrv.png',
  iconAbrir: 'assets/img/pegar-asa-512.png',
  iconFechar: 'assets/img/iconeasafechada.png',
  iconMeditar: 'assets/img/meditar.png',
  iconIdles: 'assets/img/asaidle.png',
};

function normalizeLayout(layout) {
  const normalized = { ...layout };
  const raw = Number(normalized.coreLabelOffset);
  if (!Number.isNaN(raw) && raw >= -5 && raw <= 5) {
    normalized.coreLabelOffset = String(Math.round(raw * 16));
  }
  return normalized;
}

function toggleEditMode(forceValue) {
  editMode = typeof forceValue === 'boolean' ? forceValue : !editMode;
  editPanel.hidden = !editMode;
  editToggle.setAttribute('aria-expanded', String(editMode));
}

function readLayoutFromControls() {
  const data = {};
  Object.keys(controls).forEach((key) => {
    const control = controls[key];
    if (!control) return;
    if (checkboxKeys.has(key)) {
      data[key] = control.checked ? '1' : '0';
    } else {
      data[key] = control.value;
    }
  });
  return data;
}

function applyLayout(layout) {
  root.style.setProperty('--menu-scale', layout.menuScale);
  root.style.setProperty('--menu-offset-x', `${layout.menuOffsetX}px`);
  root.style.setProperty('--menu-offset-y', `${layout.menuOffsetY}px`);
  root.style.setProperty('--radius', `${layout.radius}px`);
  root.style.setProperty('--rotation-offset', `${layout.rotationOffset || 0}deg`);
  root.style.setProperty('--item-size', `${layout.itemSize}px`);

  const rotValEl = document.getElementById('rotationValue');
  if (rotValEl) rotValEl.textContent = `${layout.rotationOffset || 0}°`;
  root.style.setProperty('--icon-size', `${layout.iconSize}px`);
  root.style.setProperty('--icon-offset-x', `${layout.iconOffsetX}px`);
  root.style.setProperty('--icon-offset-y', `${layout.iconOffsetY}px`);
  root.style.setProperty('--label-size', `${layout.labelSize}rem`);
  root.style.setProperty('--item-label-offset-y', `${layout.itemLabelOffsetY}px`);
  root.style.setProperty('--core-icon-size', `${layout.coreIconSize}px`);
  root.style.setProperty('--core-icon-offset-y', `${layout.coreIconOffsetY}px`);
  root.style.setProperty('--core-label-size', `${layout.coreLabelSize}rem`);
  root.style.setProperty('--core-label-offset', `${layout.coreLabelOffset}px`);
  root.style.setProperty('--ring-color', layout.colorRing);
  root.style.setProperty('--item-border-color', layout.colorItemBorder);
  root.style.setProperty('--active-border-color', layout.colorActiveBorder);
  root.style.setProperty('--text', layout.colorText);

  if (coreIcon) {
    coreIcon.src = layout.coreIconPath;
  }

  if (iconTargets.ritual) iconTargets.ritual.src = layout.iconRitual;
  if (iconTargets.agachar) iconTargets.agachar.src = layout.iconAgachar;
  if (iconTargets.bater) iconTargets.bater.src = layout.iconBater;
  if (iconTargets.removerasa) iconTargets.removerasa.src = layout.iconRemoverasa;
  if (iconTargets.abrir) iconTargets.abrir.src = layout.iconAbrir;
  if (iconTargets.fechar) iconTargets.fechar.src = layout.iconFechar;
  if (iconTargets.meditar) iconTargets.meditar.src = layout.iconMeditar;
  if (iconTargets.idles) iconTargets.idles.src = layout.iconIdles;

  document.body.classList.toggle('hide-item-labels', layout.showItemLabels !== '1');
  document.body.classList.toggle('hide-core-label', layout.showCoreLabel !== '1');
  document.body.classList.toggle('hide-badges', layout.showBadges !== '1');
  document.body.classList.toggle('clip-item-icons', layout.clipItemIcons === '1');
}

function saveLayout(layout) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(layout));
}

function loadLayout() {
  let saved = null;
  try {
    saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
  } catch (_err) {
    saved = null;
  }

  const layout = normalizeLayout({ ...defaults, ...(saved || {}) });

  Object.keys(controls).forEach((key) => {
    const control = controls[key];
    if (!control) return;
    if (checkboxKeys.has(key)) {
      control.checked = layout[key] === '1';
    } else {
      control.value = layout[key];
    }
  });

  applyLayout(layout);
  return layout;
}

function bindEditorControls() {
  Object.keys(controls).forEach((key) => {
    const control = controls[key];
    if (!control) return;
    const handler = () => {
      const layout = readLayoutFromControls();
      applyLayout(layout);
      saveLayout(layout);
    };
    control.addEventListener('input', handler);
    control.addEventListener('change', handler);
  });

  editToggle.addEventListener('click', () => toggleEditMode());

  if (resetPosition) {
    resetPosition.addEventListener('click', () => {
      controls.menuOffsetX.value = '0';
      controls.menuOffsetY.value = '0';
      const layout = readLayoutFromControls();
      applyLayout(layout);
      saveLayout(layout);
    });
  }

  resetLayout.addEventListener('click', () => {
    Object.keys(controls).forEach((key) => {
      const control = controls[key];
      if (!control) return;
      if (checkboxKeys.has(key)) {
        control.checked = defaults[key] === '1';
      } else {
        control.value = defaults[key];
      }
    });
    applyLayout(defaults);
    saveLayout(defaults);
  });

  copyLayout.addEventListener('click', async () => {
    const payload = JSON.stringify(readLayoutFromControls(), null, 2);
    try {
      await navigator.clipboard.writeText(payload);
      copyLayout.textContent = t('copiado');
      setTimeout(() => {
        copyLayout.textContent = t('copiarJson');
      }, 1200);
    } catch (_err) {
      copyLayout.textContent = t('falhou');
      setTimeout(() => {
        copyLayout.textContent = t('copiarJson');
      }, 1200);
    }
  });
}

function openHud() {
  if (!scene || !hudClosed) return;
  // Limpa estado residual de variant view
  radialMenu.classList.remove('view-out');
  variantMenu.classList.remove('view-in');
  variantMenu.hidden = true;
  inVariantView = false;
  // Limpa estado residual de noAsa variant view
  menuNoAsa.classList.remove('view-out');
  variantMenuNoAsa.classList.remove('view-in');
  variantMenuNoAsa.hidden = true;
  inNoAsaVariantView = false;
  scene.style.display = '';
  scene.classList.add('hud-entering');
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      scene.classList.remove('hud-entering');
      scene.classList.remove('hud-hidden');
    });
  });
  hudClosed = false;
  updateMeditarSatellites();
  updateAgacharSatellites();
  updateNoAsaButtonLabels();
  updateNoAsaAgacharSatellites();
}

function closeHud() {
  if (!scene || hudClosed) return;
  scene.classList.add('hud-hidden');
  hudClosed = true;
  postToLua('closeHud');
  scene.addEventListener('transitionend', function handler() {
    scene.removeEventListener('transitionend', handler);
    if (hudClosed) scene.style.display = 'none';
  });
}

function setActiveItem(nextItem) {
  items.forEach((item) => item.classList.remove('is-active'));
  nextItem.classList.add('is-active');
}

/* ── Variantes sub-menu ── */

const variantMenu = document.getElementById('variantMenu');
const variantBack = document.getElementById('variantBack');
const variantTitle = document.getElementById('variantTitle');
const variantCards = document.getElementById('variantCards');
const radialMenu = document.getElementById('menuComAsa');

const variantsData = {
  agachar: [
    { id: 'agachar1', name: 'agachar1', desc: 'var1', icon: 'assets/img/iconag.png' },
    { id: 'agachar2', name: 'agachar2', desc: 'var2', icon: 'assets/img/iconag.png' },
    { id: 'agachar3', name: 'agachar3', desc: 'var3', icon: 'assets/img/iconag.png' },
    { id: 'agachar4', name: 'agachar4', desc: 'var4', icon: 'assets/img/iconag.png' },
  ],
  ritual: [
    { id: 'ritual1', name: 'ritual1Name', desc: 'var1', icon: 'assets/img/iconrt.png' },
    { id: 'ritual2', name: 'ritual2Name', desc: 'var2', icon: 'assets/img/iconrt.png' },
    { id: 'ritual3', name: 'ritual3Name', desc: 'var3', icon: 'assets/img/iconrt.png' },
  ],
  idles: [
    { id: 'idle1', name: 'idle1', desc: 'var1', icon: 'assets/img/asaidle.png' },
    { id: 'idle2', name: 'idle2', desc: 'var2', icon: 'assets/img/asaidle.png' },
    { id: 'idle3', name: 'idle3', desc: 'var3', icon: 'assets/img/asaidle.png' },
    { id: 'idle4', name: 'idle4', desc: 'var4', icon: 'assets/img/asaidle.png' },
    { id: 'idle5', name: 'idle5', desc: 'var5', icon: 'assets/img/asaidle.png' },
    { id: 'idle6', name: 'idle6', desc: 'var6', icon: 'assets/img/asaidle.png' },
  ],
  meditar: [
    { id: 'meditar1', name: 'meditar1', desc: 'chao', icon: 'assets/img/meditar.png' },
    { id: 'meditar2', name: 'meditar2', desc: 'ar', icon: 'assets/img/meditar.png' },
  ],
};

function openVariantView(action) {
  const variants = variantsData[action];
  if (!variants || variants.length === 0) return;

  const label = items.find((i) => i.dataset.action === action);
  variantTitle.textContent = label ? label.querySelector('.label').textContent : action.toUpperCase();

  variantCards.innerHTML = '';
  variants.forEach((v) => {
    const card = document.createElement('button');
    card.className = 'variant-card';
    card.type = 'button';
    card.dataset.variant = v.id;
    card.innerHTML = `
      <img class="variant-icon" src="${v.icon}" alt="${t(v.name)}">
      <span class="variant-name">${t(v.name)}</span>
      <span class="variant-desc">${t(v.desc)}</span>
    `;
    card.addEventListener('click', () => {
      console.log('Variante selecionada:', v.id);
      postToLua('hudAction', { action: v.id });
      if (action === 'meditar') {
        isMeditating = true;
      }
      if (action === 'ritual') {
        isInRitual = true;
        // ritual1 = variação 1 (sem estágios), ritual2/3 = variação 2/3 (com estágios)
        ritualVariant = (v.id === 'ritual1') ? 1 : 2;
      }
      if (action === 'agachar') {
        isInAgachar = true;
      }
      // Fecha direto sem voltar ao radial
      variantMenu.classList.remove('view-in');
      variantMenu.hidden = true;
      inVariantView = false;
      updateMeditarSatellites();
      updateRitualButton();
      updateRitualSatellites();
      updateAgacharSatellites();
      closeHud();
    });
    variantCards.appendChild(card);
  });

  radialMenu.classList.add('view-out');
  variantMenu.hidden = false;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      variantMenu.classList.add('view-in');
    });
  });
  inVariantView = true;
  updateMeditarSatellites();
}

function closeVariantView() {
  if (!inVariantView) return;
  variantMenu.classList.remove('view-in');
  radialMenu.classList.remove('view-out');
  variantMenu.addEventListener('transitionend', function handler() {
    variantMenu.removeEventListener('transitionend', handler);
    variantMenu.hidden = true;
  });
  inVariantView = false;
  updateMeditarSatellites();
}

variantBack.addEventListener('click', closeVariantView);

items.forEach((item) => {
  item.addEventListener('click', () => {
    const action = item.dataset.action;
    // Se está meditando e clicou no botão meditar → sair da meditação
    if (action === 'meditar' && isMeditating) {
      isMeditating = false;
      updateMeditarButton();
      updateMeditarSatellites();
      postToLua('hudAction', { action: 'meditarsair' });
      closeHud();
      return;
    }
    // Se está em ritual e clicou no botão ritual → sair do ritual
    if (action === 'ritual' && isInRitual) {
      isInRitual = false;
      ritualVariant = 0;
      updateRitualButton();
      updateRitualSatellites();
      postToLua('hudAction', { action: 'ritualsair' });
      closeHud();
      return;
    }
    if (variantsData[action]) {
      openVariantView(action);
    } else {
      postToLua('hudAction', { action: action });
      closeHud();
    }
  });
});

/* ── MEDITAR button state management ── */
const meditarBtn = Array.from(items).find((i) => i.dataset.action === 'meditar');
const meditarLabelEl = meditarBtn ? meditarBtn.querySelector('.label') : null;

function updateMeditarButton() {
  if (!meditarBtn || !meditarLabelEl) return;
  meditarLabelEl.textContent = isMeditating ? t('meditarSair') : t('meditar');
}

/* ── AGACHAR button state management (com asa) ── */
const agacharBtn = Array.from(items).find((i) => i.dataset.action === 'agachar');
const agacharLabelEl = agacharBtn ? agacharBtn.querySelector('.label') : null;

function updateAgacharButton() {
  if (!agacharBtn || !agacharLabelEl) return;
  agacharLabelEl.textContent = isInAgachar ? t('agacharSair') : t('agachar');
}

/* ── AGACHAR satellite state management ── */
const agacharSatellites = document.getElementById('agacharSatellites');

function updateAgacharSatellites() {
  if (agacharSatellites) {
    agacharSatellites.hidden = !(isInAgachar && hasWing && !inVariantView);
  }
}

// Cliques no satelite do agachar
if (agacharSatellites) {
  agacharSatellites.querySelectorAll('.satellite-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const action = btn.dataset.action;
      console.log('Agachar satelite acao:', action);
      postToLua('hudAction', { action: action });
      isInAgachar = false;
      updateAgacharSatellites();
      closeHud();
    });
  });
}

/* ── RITUAL button state management ── */
const ritualBtn = Array.from(items).find((i) => i.dataset.action === 'ritual');
const ritualLabelEl = ritualBtn ? ritualBtn.querySelector('.label') : null;

function updateRitualButton() {
  if (!ritualBtn || !ritualLabelEl) return;
  ritualLabelEl.textContent = isInRitual ? t('ritualSair') : t('ritual');
}

/* ── Satelites RITUAL 1/RITUAL 2 do RITUAL ── */
const ritualSatellites = document.getElementById('ritualSatellites');

function updateRitualSatellites() {
  if (ritualSatellites) {
    // Só mostra satélites para variação 2 ou 3 (ritualVariant === 2)
    ritualSatellites.hidden = !(isInRitual && ritualVariant === 2 && hasWing && !inVariantView);
  }
}

// Cliques nos satelites do ritual
if (ritualSatellites) {
  ritualSatellites.querySelectorAll('.satellite-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const action = btn.dataset.action;
      console.log('Ritual satelite acao:', action);
      postToLua('hudAction', { action: action });
      closeHud();
    });
  });
}

/* ── Satelites SUBIR/DESCER do MEDITAR ── */
const meditarSatellites = document.getElementById('meditarSatellites');

function updateMeditarSatellites() {
  if (meditarSatellites) {
    meditarSatellites.hidden = !(isMeditating && hasWing && !inVariantView);
  }
}

// Cliques nos satelites
if (meditarSatellites) {
  meditarSatellites.querySelectorAll('.satellite-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation(); // nao propagar pro botao MEDITAR
      const action = btn.dataset.action;
      console.log('Satelite acao:', action);
      postToLua('hudAction', { action: action });
      closeHud();
    });
  });
}

/* ── Estado da asa (sem asa / com asa) ── */

const menuNoAsa = document.getElementById('menuNoAsa');
const menuComAsa = document.getElementById('menuComAsa');
const coreNoAsa = document.getElementById('coreNoAsa');
const wingIdPanel = document.getElementById('wingIdPanel');
const wingIdInput = document.getElementById('wingIdInput');
const wingIdConfirm = document.getElementById('wingIdConfirm');
const wingIdCancel = document.getElementById('wingIdCancel');
const noAsaItems = Array.from(menuNoAsa.querySelectorAll('.radial-item'));

function applyWingState() {
  if (hasWing) {
    menuNoAsa.hidden = true;
    menuNoAsa.classList.remove('view-out');
    menuComAsa.hidden = false;
    menuComAsa.classList.remove('view-out');
  } else {
    menuComAsa.hidden = true;
    menuComAsa.classList.remove('view-out');
    menuNoAsa.hidden = false;
    menuNoAsa.classList.remove('view-out');
  }
  wingIdPanel.hidden = true;
  wingIdPanel.classList.remove('view-in');
  inWingIdPanel = false;
}

function applyCanEquip() {
  var title = coreNoAsa.querySelector('.core-title');
  if (canEquipWings) {
    coreNoAsa.classList.remove('core-locked');
    if (title) title.textContent = t('pegarAsa');
  } else {
    coreNoAsa.classList.add('core-locked');
    if (title) title.textContent = t('wingsLocked');
  }
}

function openWingIdPanel() {
  if (!canEquipWings) return;
  menuNoAsa.classList.add('view-out');
  wingIdPanel.hidden = false;
  wingIdInput.value = '';
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      wingIdPanel.classList.add('view-in');
      wingIdInput.focus();
    });
  });
  inWingIdPanel = true;
}

function closeWingIdPanel() {
  if (!inWingIdPanel) return;
  wingIdPanel.classList.remove('view-in');
  menuNoAsa.classList.remove('view-out');
  wingIdPanel.addEventListener('transitionend', function handler() {
    wingIdPanel.removeEventListener('transitionend', handler);
    wingIdPanel.hidden = true;
  });
  inWingIdPanel = false;
}

function confirmWingId() {
  const id = wingIdInput.value.trim();
  if (!id) {
    wingIdInput.focus();
    return;
  }
  console.log('Asa selecionada, ID:', id);
  postToLua('hudAction', { action: 'pegarasa', wingId: id });
  hasWing = true;
  inWingIdPanel = false;
  wingIdPanel.classList.remove('view-in');
  wingIdPanel.hidden = true;
  closeHud();
  setTimeout(() => {
    applyWingState();
  }, 300);
}

coreNoAsa.addEventListener('click', openWingIdPanel);
wingIdCancel.addEventListener('click', closeWingIdPanel);
wingIdConfirm.addEventListener('click', confirmWingId);
wingIdInput.addEventListener('keydown', (e) => {
  e.stopPropagation();
  if (e.key === 'Enter') confirmWingId();
  if (e.key === 'Escape') closeWingIdPanel();
});

/* ── NoAsa variant sub-menu (agachar + meditar sem asa) ── */

const variantMenuNoAsa = document.getElementById('variantMenuNoAsa');
const variantBackNoAsa = document.getElementById('variantBackNoAsa');
const variantTitleNoAsa = document.getElementById('variantTitleNoAsa');
const variantCardsNoAsa = document.getElementById('variantCardsNoAsa');
let inNoAsaVariantView = false;

const noAsaVariantsData = {
  agachar_noasa: [
    { id: 'agachar1', name: 'agachar1', desc: 'var1', icon: 'assets/img/iconag.png' },
    { id: 'agachar2', name: 'agachar2', desc: 'var2', icon: 'assets/img/iconag.png' },
    { id: 'agachar3', name: 'agachar3', desc: 'var3', icon: 'assets/img/iconag.png' },
    { id: 'agachar4', name: 'agachar4', desc: 'var4', icon: 'assets/img/iconag.png' },
  ],
  meditar_noasa: [
    { id: 'meditar1', name: 'meditar1', desc: 'chao', icon: 'assets/img/meditar.png' },
  ],
};

// NoAsa button state elements
const noAsaAgacharBtn = Array.from(noAsaItems).find((i) => i.dataset.action === 'agachar_noasa');
const noAsaAgacharLabel = noAsaAgacharBtn ? noAsaAgacharBtn.querySelector('.label') : null;
const noAsaMeditarBtn = Array.from(noAsaItems).find((i) => i.dataset.action === 'meditar_noasa');
const noAsaMeditarLabel = noAsaMeditarBtn ? noAsaMeditarBtn.querySelector('.label') : null;

// NoAsa agachar satellite
const agacharSatellitesNoAsa = document.getElementById('agacharSatellitesNoAsa');

function updateNoAsaAgacharSatellites() {
  if (agacharSatellitesNoAsa) {
    agacharSatellitesNoAsa.hidden = !(isInAgachar && !hasWing && !inNoAsaVariantView);
  }
}

function updateNoAsaButtonLabels() {
  if (noAsaAgacharLabel) {
    noAsaAgacharLabel.textContent = isInAgachar ? t('agacharSair') : t('agachar');
  }
  if (noAsaMeditarLabel) {
    noAsaMeditarLabel.textContent = isMeditating ? t('meditarSair') : t('meditar');
  }
}

if (agacharSatellitesNoAsa) {
  agacharSatellitesNoAsa.querySelectorAll('.satellite-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const action = btn.dataset.action;
      postToLua('hudAction', { action: action });
      isInAgachar = false;
      updateNoAsaAgacharSatellites();
      updateNoAsaButtonLabels();
      closeHud();
    });
  });
}

function openNoAsaVariantView(action) {
  const variants = noAsaVariantsData[action];
  if (!variants || variants.length === 0) return;

  const label = noAsaItems.find((i) => i.dataset.action === action);
  variantTitleNoAsa.textContent = label ? label.querySelector('.label').textContent : action.toUpperCase();

  variantCardsNoAsa.innerHTML = '';
  variants.forEach((v) => {
    const card = document.createElement('button');
    card.className = 'variant-card';
    card.type = 'button';
    card.dataset.variant = v.id;
    card.innerHTML = `
      <img class="variant-icon" src="${v.icon}" alt="${t(v.name)}">
      <span class="variant-name">${t(v.name)}</span>
      <span class="variant-desc">${t(v.desc)}</span>
    `;
    card.addEventListener('click', () => {
      console.log('NoAsa variante selecionada:', v.id);
      postToLua('hudAction', { action: v.id });
      if (action === 'meditar_noasa') {
        isMeditating = true;
      }
      if (action === 'agachar_noasa') {
        isInAgachar = true;
      }
      variantMenuNoAsa.classList.remove('view-in');
      variantMenuNoAsa.hidden = true;
      inNoAsaVariantView = false;
      updateNoAsaButtonLabels();
      updateNoAsaAgacharSatellites();
      closeHud();
    });
    variantCardsNoAsa.appendChild(card);
  });

  menuNoAsa.classList.add('view-out');
  variantMenuNoAsa.hidden = false;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      variantMenuNoAsa.classList.add('view-in');
    });
  });
  inNoAsaVariantView = true;
  updateNoAsaAgacharSatellites();
}

function closeNoAsaVariantView() {
  if (!inNoAsaVariantView) return;
  variantMenuNoAsa.classList.remove('view-in');
  menuNoAsa.classList.remove('view-out');
  variantMenuNoAsa.addEventListener('transitionend', function handler() {
    variantMenuNoAsa.removeEventListener('transitionend', handler);
    variantMenuNoAsa.hidden = true;
  });
  inNoAsaVariantView = false;
  updateNoAsaAgacharSatellites();
}

variantBackNoAsa.addEventListener('click', closeNoAsaVariantView);

noAsaItems.forEach((item) => {
  item.addEventListener('click', () => {
    const action = item.dataset.action;

    // Toggle MEDITAR SAIR
    if (action === 'meditar_noasa' && isMeditating) {
      isMeditating = false;
      updateNoAsaButtonLabels();
      postToLua('hudAction', { action: 'meditarsair' });
      closeHud();
      return;
    }

    // Toggle AGACHAR SAIR
    if (action === 'agachar_noasa' && isInAgachar) {
      isInAgachar = false;
      updateNoAsaButtonLabels();
      updateNoAsaAgacharSatellites();
      postToLua('hudAction', { action: 'agacharsair' });
      closeHud();
      return;
    }

    // Abrir cards de variantes se tiver
    if (noAsaVariantsData[action]) {
      openNoAsaVariantView(action);
    } else {
      postToLua('hudAction', { action: action });
      closeHud();
    }
  });
});

/* ── Apply locale to all HUD elements ── */
function applyLocale() {
  // Core titles
  var el;
  el = document.querySelector('#menuNoAsa .core-title');
  if (el) el.textContent = t('pegarAsa');
  el = document.querySelector('#menuComAsa .core-title');
  if (el) el.textContent = t('asasMenu');

  // Static button labels (com asa)
  var lbl;
  lbl = document.querySelector('[data-action="removerasa"] .label');
  if (lbl) lbl.textContent = t('removerAsa');
  lbl = document.querySelector('[data-action="bater"] .label');
  if (lbl) lbl.textContent = t('asaBater');
  lbl = document.querySelector('[data-action="abrir"] .label');
  if (lbl) lbl.textContent = t('abrir');
  lbl = document.querySelector('[data-action="fechar"] .label');
  if (lbl) lbl.textContent = t('fechar');
  lbl = document.querySelector('[data-action="idles"] .label');
  if (lbl) lbl.textContent = t('idles');

  // Dynamic buttons (use their update functions which now call t())
  updateMeditarButton();
  updateRitualButton();
  updateAgacharButton();
  updateNoAsaButtonLabels();

  // Satellite buttons
  document.querySelectorAll('.satellite-btn--agacharsair').forEach(function(b) { b.textContent = t('sair'); });
  el = document.querySelector('.satellite-btn--ritual1');
  if (el) el.textContent = t('ritual1Sat');
  el = document.querySelector('.satellite-btn--ritual2');
  if (el) el.textContent = t('ritual2Sat');
  el = document.querySelector('.satellite-btn--subir');
  if (el) el.textContent = t('subir');
  el = document.querySelector('.satellite-btn--descer');
  if (el) el.textContent = t('descer');

  // Rune bars (both menus have one)
  document.querySelectorAll('.rune-bar-title').forEach(function(e) { e.textContent = t('runas'); });
  var runeMap = { '1': 'runa1', '2': 'runa2', '3': 'runa3', '4': 'runa4', '5': 'runa5', '6': 'runa6', '7': 'runa7', 'delete': 'runaDelete' };
  document.querySelectorAll('.rune-btn').forEach(function(btn) {
    var key = runeMap[btn.dataset.rune];
    if (key) btn.title = t(key);
  });

  // Variant back buttons
  el = document.getElementById('variantBack');
  if (el) el.innerHTML = t('voltar');
  el = document.getElementById('variantBackNoAsa');
  if (el) el.innerHTML = t('voltar');

  // Wing ID panel
  el = document.querySelector('.wing-id-title');
  if (el) el.textContent = t('escolhaAsa');
  el = document.querySelector('.wing-id-desc');
  if (el) el.textContent = t('digiteId');
  el = document.getElementById('wingIdInput');
  if (el) el.placeholder = t('idPlaceholder');
  el = document.getElementById('wingIdCancel');
  if (el) el.textContent = t('cancelar');
  el = document.getElementById('wingIdConfirm');
  if (el) el.textContent = t('confirmar');

  // Editor toggle
  el = document.getElementById('editToggle');
  if (el) el.textContent = t('modoEdit');

  // Editor panel heading
  el = document.querySelector('#editPanel > h2');
  if (el) el.textContent = t('editorHud');

  // Editor summaries
  var summaries = document.querySelectorAll('#editPanel summary');
  var sumKeys = ['catGeral', 'catIcone', 'catNome', 'catCor'];
  summaries.forEach(function(s, i) { if (sumKeys[i]) s.textContent = t(sumKeys[i]); });

  // Editor labels (input ID → locale key)
  var labelMap = {
    ctrlScale: 'escalaGeral', ctrlOffsetX: 'posX', ctrlOffsetY: 'posY',
    ctrlRadius: 'distRadial', ctrlRotationOffset: 'rotMenu', ctrlItemSize: 'tamBotoes',
    ctrlIconSize: 'tamIconesBotoes', ctrlIconOffsetX: 'iconesEsqDir', ctrlIconOffsetY: 'iconesSubDesc',
    ctrlClipItemIcons: 'recortarIcones', ctrlCoreIconSize: 'tamIconeCentral',
    ctrlCoreIconOffsetY: 'iconeCentralSubDesc', ctrlCoreIconPath: 'iconeCentralCaminho',
    ctrlIconRitual: 'iconeRitual', ctrlIconAgachar: 'iconeAgachar', ctrlIconBater: 'iconeAsaBater',
    ctrlIconRemoverasa: 'iconeRemoverAsa', ctrlIconAbrir: 'iconeAbrir', ctrlIconFechar: 'iconeFechar',
    ctrlIconIdles: 'iconeIdles',
    ctrlLabelSize: 'tamTextoBotoes', ctrlItemLabelOffsetY: 'textoBotoesSubDesc',
    ctrlShowItemLabels: 'mostrarNomes', ctrlShowBadges: 'mostrarNumeros',
    ctrlCoreLabelSize: 'tamTextoCentral', ctrlCoreLabelOffset: 'textoCentralSubDesc',
    ctrlShowCoreLabel: 'mostrarTextoAsasMenu',
    ctrlColorRing: 'corAnelRadial', ctrlColorItemBorder: 'corBordaBotoes',
    ctrlColorActiveBorder: 'corDestaqueAtivo', ctrlColorText: 'corTextoGeral',
  };
  Object.keys(labelMap).forEach(function(id) { setLabelText(id, t(labelMap[id])); });

  // Editor buttons
  el = document.getElementById('resetPosition');
  if (el) el.textContent = t('resetXY');
  el = document.getElementById('resetLayout');
  if (el) el.textContent = t('resetar');
  el = document.getElementById('copyLayout');
  if (el) el.textContent = t('copiarJson');

  // Editor small text
  el = document.querySelector('#editPanel > small');
  if (el) el.textContent = t('atalhoEditor');
}

/* ── Rune bar click handlers ── */
document.querySelectorAll('.rune-btn').forEach((btn) => {
  btn.addEventListener('click', (e) => {
    e.stopPropagation();
    const rune = btn.dataset.rune;
    if (rune === 'delete') {
      console.log('Remover todas as runas');
      postToLua('hudAction', { action: 'runadeletar' });
    } else {
      const runeId = parseInt(rune, 10);
      console.log('Runa selecionada:', runeId);
      postToLua('hudAction', { action: 'runafada', runeId: runeId });
    }
    closeHud();
  });
});

applyWingState();

// Start hidden (NUI opens via Lua message)
if (scene) {
  scene.classList.add('hud-hidden');
  scene.style.display = 'none';
}

bindEditorControls();
loadLayout();
toggleEditMode(false);

document.addEventListener('keydown', (event) => {
  const targetInsideEditor = event.target && event.target.closest && event.target.closest('.edit-panel');

  if (event.key === 'Escape' || event.code === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    if (editMode) {
      toggleEditMode(false);
      return;
    }
    if (inWingIdPanel) {
      closeWingIdPanel();
      return;
    }
    if (inVariantView) {
      closeVariantView();
      return;
    }
    if (inNoAsaVariantView) {
      closeNoAsaVariantView();
      return;
    }
    closeHud();
    return;
  }

  if (targetInsideEditor) return;

  const currentIndex = items.findIndex((item) => item.classList.contains('is-active'));
  if (currentIndex === -1) return;

  let nextIndex = currentIndex;

  if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
    nextIndex = (currentIndex + 1) % items.length;
  }

  if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
    nextIndex = (currentIndex - 1 + items.length) % items.length;
  }

  if (nextIndex !== currentIndex) {
    event.preventDefault();
    setActiveItem(items[nextIndex]);
  }
});

// FiveM NUI message listener
window.addEventListener('message', function(event) {
  const data = event.data;
  if (data.action === 'openHud') {
    if (data.hudStrings && typeof data.hudStrings === 'object') {
      currentStrings = data.hudStrings;
    }
    document.body.classList.toggle('black-bg', !!data.hudBlackBg);
    _hudDebug = !!data.hudDebugNui;
    hasWing = !!data.hasWing;
    isMeditating = !!data.isMeditating;
    isInRitual = !!data.isInRitual;
    ritualVariant = data.ritualVariant || 0;
    isInAgachar = !!data.isInAgachar;
    canEquipWings = data.canEquip !== false;
    applyLocale();
    applyWingState();
    applyCanEquip();
    updateMeditarSatellites();
    updateRitualSatellites();
    updateAgacharSatellites();
    updateNoAsaAgacharSatellites();
    openHud();
  } else if (data.action === 'closeHud') {
    closeHud();
    document.body.classList.remove('black-bg');
  }
});
