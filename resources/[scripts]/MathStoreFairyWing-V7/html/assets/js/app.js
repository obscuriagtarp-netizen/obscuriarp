/* ── Debug NUI logging (controlled by Config.HudDebugNui) ── */
let _hudDebug = false;
const _origLog = console.log;
console.log = function(...args) {
  if (_hudDebug) _origLog.apply(console, args);
};

/* ── i18n / Locale system ── */
const I18N = {
  'pt-BR': {
    pegar_ambos: 'PEGAR AMBOS', pegar_asa: 'PEGAR ASA', pegar_cauda: 'PEGAR CAUDA',
    asa_fechar: 'ASA FECHAR', asa_abrir: 'ASA ABRIR', asa_bater: 'ASA BATER',
    cauda_a: 'CAUDA A', cauda_f: 'CAUDA F', cauda_b: 'CAUDA B',
    toggle_asa: 'PEGAR ASA', toggle_asa_rem: 'REMOVER ASA',
    toggle_cauda: 'PEGAR CAUDA', toggle_cauda_rem: 'REMOVER CAUDA',
    demon_menu: 'DEMON MENU', modo_edit: 'Modo Edit',
    escolha_asa: 'ESCOLHA SUA ASA', desc_asa: 'Digite o número da asa que deseja equipar',
    placeholder_asa: 'ID da asa', cancelar: 'Cancelar', confirmar: 'Confirmar',
    escolha_cauda: 'ESCOLHA SUA CAUDA', desc_cauda: 'Digite o número da cauda que deseja equipar',
    placeholder_cauda: 'ID da cauda',
    bloqueado: 'BLOQUEADO',
  },
  'en-US': {
    pegar_ambos: 'GET BOTH', pegar_asa: 'GET WINGS', pegar_cauda: 'GET TAIL',
    asa_fechar: 'CLOSE WINGS', asa_abrir: 'OPEN WINGS', asa_bater: 'FLAP WINGS',
    cauda_a: 'TAIL OPEN', cauda_f: 'TAIL WRAP', cauda_b: 'TAIL FLAP',
    toggle_asa: 'GET WINGS', toggle_asa_rem: 'REMOVE WINGS',
    toggle_cauda: 'GET TAIL', toggle_cauda_rem: 'REMOVE TAIL',
    demon_menu: 'DEMON MENU', modo_edit: 'Edit Mode',
    escolha_asa: 'CHOOSE YOUR WINGS', desc_asa: 'Enter the wing number you want to equip',
    placeholder_asa: 'Wing ID', cancelar: 'Cancel', confirmar: 'Confirm',
    escolha_cauda: 'CHOOSE YOUR TAIL', desc_cauda: 'Enter the tail number you want to equip',
    placeholder_cauda: 'Tail ID',
    bloqueado: 'LOCKED',
  },
  'es': {
    pegar_ambos: 'OBTENER AMBOS', pegar_asa: 'OBTENER ALAS', pegar_cauda: 'OBTENER COLA',
    asa_fechar: 'CERRAR ALAS', asa_abrir: 'ABRIR ALAS', asa_bater: 'BATIR ALAS',
    cauda_a: 'COLA ABIERTA', cauda_f: 'COLA ENROLL', cauda_b: 'COLA BATIR',
    toggle_asa: 'OBTENER ALAS', toggle_asa_rem: 'QUITAR ALAS',
    toggle_cauda: 'OBTENER COLA', toggle_cauda_rem: 'QUITAR COLA',
    demon_menu: 'MENÚ DEMON', modo_edit: 'Modo Edición',
    escolha_asa: 'ELIGE TUS ALAS', desc_asa: 'Ingresa el número del ala que deseas equipar',
    placeholder_asa: 'ID del ala', cancelar: 'Cancelar', confirmar: 'Confirmar',
    escolha_cauda: 'ELIGE TU COLA', desc_cauda: 'Ingresa el número de la cola que deseas equipar',
    placeholder_cauda: 'ID de la cola',
    bloqueado: 'BLOQUEADO',
  },
  'fr': {
    pegar_ambos: 'OBTENIR LES DEUX', pegar_asa: 'OBTENIR AILES', pegar_cauda: 'OBTENIR QUEUE',
    asa_fechar: 'FERMER AILES', asa_abrir: 'OUVRIR AILES', asa_bater: 'BATTRE AILES',
    cauda_a: 'QUEUE DROITE', cauda_f: 'QUEUE ENROULÉE', cauda_b: 'QUEUE BATTRE',
    toggle_asa: 'OBTENIR AILES', toggle_asa_rem: 'RETIRER AILES',
    toggle_cauda: 'OBTENIR QUEUE', toggle_cauda_rem: 'RETIRER QUEUE',
    demon_menu: 'MENU DÉMON', modo_edit: 'Mode Édition',
    escolha_asa: 'CHOISISSEZ VOS AILES', desc_asa: 'Entrez le numéro des ailes à équiper',
    placeholder_asa: 'ID des ailes', cancelar: 'Annuler', confirmar: 'Confirmer',
    escolha_cauda: 'CHOISISSEZ VOTRE QUEUE', desc_cauda: 'Entrez le numéro de la queue à équiper',
    placeholder_cauda: 'ID de la queue',
    bloqueado: 'VERROUILLÉ',
  },
  'pt-PT': {
    pegar_ambos: 'OBTER AMBOS', pegar_asa: 'OBTER ASAS', pegar_cauda: 'OBTER CAUDA',
    asa_fechar: 'FECHAR ASAS', asa_abrir: 'ABRIR ASAS', asa_bater: 'BATER ASAS',
    cauda_a: 'CAUDA A', cauda_f: 'CAUDA F', cauda_b: 'CAUDA B',
    toggle_asa: 'OBTER ASAS', toggle_asa_rem: 'REMOVER ASAS',
    toggle_cauda: 'OBTER CAUDA', toggle_cauda_rem: 'REMOVER CAUDA',
    demon_menu: 'MENU DEMON', modo_edit: 'Modo Edição',
    escolha_asa: 'ESCOLHA AS SUAS ASAS', desc_asa: 'Introduza o número da asa que deseja equipar',
    placeholder_asa: 'ID da asa', cancelar: 'Cancelar', confirmar: 'Confirmar',
    escolha_cauda: 'ESCOLHA A SUA CAUDA', desc_cauda: 'Introduza o número da cauda que deseja equipar',
    placeholder_cauda: 'ID da cauda',
    bloqueado: 'BLOQUEADO',
  },
  'th': {
    pegar_ambos: 'รับทั้งสอง', pegar_asa: 'รับปีก', pegar_cauda: 'รับหาง',
    asa_fechar: 'ปิดปีก', asa_abrir: 'เปิดปีก', asa_bater: 'กระพือปีก',
    cauda_a: 'หางตรง', cauda_f: 'หางม้วน', cauda_b: 'หางกระพือ',
    toggle_asa: 'รับปีก', toggle_asa_rem: 'ถอดปีก',
    toggle_cauda: 'รับหาง', toggle_cauda_rem: 'ถอดหาง',
    demon_menu: 'เมนู DEMON', modo_edit: 'โหมดแก้ไข',
    escolha_asa: 'เลือกปีกของคุณ', desc_asa: 'ป้อนหมายเลขปีกที่ต้องการสวม',
    placeholder_asa: 'ID ปีก', cancelar: 'ยกเลิก', confirmar: 'ยืนยัน',
    escolha_cauda: 'เลือกหางของคุณ', desc_cauda: 'ป้อนหมายเลขหางที่ต้องการสวม',
    placeholder_cauda: 'ID หาง',
    bloqueado: 'ล็อค',
  },
};

let currentLocale = 'pt-BR';

function t(key) {
  return (I18N[currentLocale] && I18N[currentLocale][key]) || (I18N['pt-BR'] && I18N['pt-BR'][key]) || key;
}

function applyLocale() {
  document.querySelectorAll('[data-i18n]').forEach(function(el) {
    el.textContent = t(el.dataset.i18n);
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach(function(el) {
    el.placeholder = t(el.dataset.i18nPlaceholder);
  });
  // Update toggle labels based on current state
  if (btn3Label) btn3Label.textContent = hasWing ? t('toggle_asa_rem') : t('toggle_asa');
  if (btn7Label) btn7Label.textContent = hasTail ? t('toggle_cauda_rem') : t('toggle_cauda');
}

/* ── DOM refs ── */
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
};

const checkboxKeys = new Set(['showItemLabels', 'showBadges', 'showCoreLabel', 'clipItemIcons']);

const STORAGE_KEY = 'demonHudLayoutV1';

let hudClosed = true;
let editMode = false;
let hasWing = false;
let hasTail = false;
let hasTailFeature = true; // controlled by Config.HasTail from Lua
let canEquipWings = true;
let inWingIdPanel = false;
let inTailIdPanel = false;

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
  coreIconPath: 'assets/img/central3.png',
  coreLabelSize: '0.79',
  coreLabelOffset: '-24',
  showCoreLabel: '0',
  clipItemIcons: '0',
  colorRing: '#1a3560',
  colorItemBorder: '#1a3560',
  colorActiveBorder: '#3a6aaa',
  colorText: '#00d4ff',
};

/* ── Layout system ── */

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
  if (rotValEl) rotValEl.textContent = `${layout.rotationOffset || 0}\u00b0`;
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

  if (coreIcon) coreIcon.src = layout.coreIconPath;

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

  const layout = { ...defaults, ...(saved || {}) };

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
      copyLayout.textContent = 'Copiado!';
      setTimeout(() => { copyLayout.textContent = 'Copiar JSON'; }, 1200);
    } catch (_err) {
      copyLayout.textContent = 'Falhou';
      setTimeout(() => { copyLayout.textContent = 'Copiar JSON'; }, 1200);
    }
  });
}

/* ── HUD open/close ── */

function openHud() {
  if (!scene || !hudClosed) return;
  scene.style.display = '';
  scene.classList.add('hud-entering');
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      scene.classList.remove('hud-entering');
      scene.classList.remove('hud-hidden');
    });
  });
  hudClosed = false;
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

/* ── Wing/Tail state ── */

const menuNoAsa = document.getElementById('menuNoAsa');
const menuComAsa = document.getElementById('menuComAsa');
const coreNoAsa = document.getElementById('coreNoAsa');

// NoAsa side buttons
const btnNoAsaAsa = document.getElementById('btnNoAsaAsa');
const btnNoAsaCauda = document.getElementById('btnNoAsaCauda');

// Toggle buttons in menuComAsa
const btn3Label = document.getElementById('btn3Label');
const btn7Label = document.getElementById('btn7Label');

// Wing ID panel
const wingIdPanel = document.getElementById('wingIdPanel');
const wingIdInput = document.getElementById('wingIdInput');
const wingIdConfirm = document.getElementById('wingIdConfirm');
const wingIdCancel = document.getElementById('wingIdCancel');

// Tail ID panel
const tailIdPanel = document.getElementById('tailIdPanel');
const tailIdInput = document.getElementById('tailIdInput');
const tailIdConfirm = document.getElementById('tailIdConfirm');
const tailIdCancel = document.getElementById('tailIdCancel');

// Track what we're opening the ID panel for
let idPanelTarget = 'both'; // 'both', 'wing', 'tail', 'wing-toggle', 'tail-toggle'

function updateDynamicButtons() {
  // Button 3: toggle wing
  if (btn3Label) {
    btn3Label.textContent = hasWing ? t('toggle_asa_rem') : t('toggle_asa');
  }
  // Button 7: toggle tail
  if (btn7Label) {
    btn7Label.textContent = hasTail ? t('toggle_cauda_rem') : t('toggle_cauda');
  }
}

/* ── Tail feature toggle ── */

function applyTailFeature() {
  // Hide/show all elements marked with data-tail
  document.querySelectorAll('[data-tail]').forEach(function(el) {
    el.style.display = hasTailFeature ? '' : 'none';
  });
  // When tail feature is off: hide side PEGAR ASA button (redundant with center)
  if (btnNoAsaAsa) btnNoAsaAsa.style.display = hasTailFeature ? '' : 'none';
  // When tail feature is off: center NoAsa on wing-only, hide PEGAR AMBOS label
  const coreTitle = coreNoAsa ? coreNoAsa.querySelector('.core-title') : null;
  if (!hasTailFeature) {
    if (coreTitle) coreTitle.dataset.i18n = 'pegar_asa';
  } else {
    if (coreTitle) coreTitle.dataset.i18n = 'pegar_ambos';
  }
  // Redistribute visible radial buttons evenly
  redistributeRadialButtons();
}

function redistributeRadialButtons() {
  // Save original angles on first call
  items.forEach(function(btn) {
    if (btn.dataset.originalAngle == null) {
      var match = btn.style.cssText.match(/--angle:\s*([\d.]+)deg/);
      btn.dataset.originalAngle = match ? match[1] : '0';
    }
  });

  if (hasTailFeature) {
    // Restore original angles
    items.forEach(function(btn) {
      btn.style.setProperty('--angle', btn.dataset.originalAngle + 'deg');
    });
  } else {
    // Get only non-tail buttons and redistribute evenly
    var visibleItems = items.filter(function(btn) {
      return !btn.hasAttribute('data-tail');
    });
    var count = visibleItems.length;
    if (count === 0) return;
    var step = 360 / count;
    visibleItems.forEach(function(btn, i) {
      btn.style.setProperty('--angle', (step * i) + 'deg');
    });
  }
}

function applyWingState() {
  // Clean up transition classes from ID panels
  menuNoAsa.classList.remove('view-out');
  menuComAsa.classList.remove('view-out');

  // menuNoAsa only shows when NEITHER wing NOR tail equipped
  // When tail feature is off, only wing matters
  const equipped = hasTailFeature ? (hasWing || hasTail) : hasWing;
  if (equipped) {
    menuNoAsa.hidden = true;
    menuComAsa.hidden = false;
  } else {
    menuComAsa.hidden = true;
    menuNoAsa.hidden = false;
  }
  wingIdPanel.hidden = true;
  wingIdPanel.classList.remove('view-in');
  inWingIdPanel = false;
  tailIdPanel.hidden = true;
  tailIdPanel.classList.remove('view-in');
  inTailIdPanel = false;

  updateDynamicButtons();
}

/* ── Wing ID Panel ── */

function applyCanEquip() {
  var title = coreNoAsa.querySelector('.core-title');
  if (canEquipWings) {
    coreNoAsa.classList.remove('core-locked');
    if (btnNoAsaAsa) btnNoAsaAsa.classList.remove('core-locked');
    if (btnNoAsaCauda) btnNoAsaCauda.classList.remove('core-locked');
    if (title) title.textContent = hasTailFeature ? t('pegar_ambos') : t('pegar_asa');
  } else {
    coreNoAsa.classList.add('core-locked');
    if (btnNoAsaAsa) btnNoAsaAsa.classList.add('core-locked');
    if (btnNoAsaCauda) btnNoAsaCauda.classList.add('core-locked');
    if (title) title.textContent = t('bloqueado');
  }
}

function openWingIdPanel(fromMenu) {
  if (!canEquipWings) return;
  const parentMenu = fromMenu === 'comAsa' ? menuComAsa : menuNoAsa;
  parentMenu.classList.add('view-out');
  wingIdPanel.hidden = false;
  wingIdInput.value = '';
  // Update max and placeholder based on available color slots
  var maxSlot = colorSlots.length > 0 ? colorSlots.length : 1;
  wingIdInput.max = maxSlot;
  wingIdInput.placeholder = '1 - ' + maxSlot;
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
  menuComAsa.classList.remove('view-out');
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

  var slot = parseInt(id);
  var maxSlot = colorSlots.length > 0 ? colorSlots.length : 1;
  if (isNaN(slot) || slot < 1 || slot > maxSlot) {
    wingIdInput.value = '';
    wingIdInput.focus();
    return;
  }

  if (idPanelTarget === 'both') {
    postToLua('hudAction', { action: 'pegarambos', wingId: slot, tailId: slot });
    hasWing = true;
    hasTail = true;
  } else {
    postToLua('hudAction', { action: 'pegarasa', wingId: slot });
    hasWing = true;
  }

  inWingIdPanel = false;
  wingIdPanel.classList.remove('view-in');
  wingIdPanel.hidden = true;
  closeHud();
  setTimeout(() => { applyWingState(); }, 300);
}

// Core center click: PEGAR AMBOS (or PEGAR ASA when tail feature is off)
coreNoAsa.addEventListener('click', () => {
  idPanelTarget = hasTailFeature ? 'both' : 'wing';
  openWingIdPanel('noAsa');
});

// Side button: PEGAR ASA only
btnNoAsaAsa.addEventListener('click', () => {
  idPanelTarget = 'wing';
  openWingIdPanel('noAsa');
});

// Side button: PEGAR CAUDA only
btnNoAsaCauda.addEventListener('click', () => {
  idPanelTarget = 'tail';
  openTailIdPanel('noAsa');
});

wingIdCancel.addEventListener('click', closeWingIdPanel);
wingIdConfirm.addEventListener('click', confirmWingId);
wingIdInput.addEventListener('keydown', (e) => {
  e.stopPropagation();
  if (e.key === 'Enter') confirmWingId();
  if (e.key === 'Escape') closeWingIdPanel();
});

/* ── Tail ID Panel ── */

function openTailIdPanel(fromMenu) {
  if (!canEquipWings) return;
  const parentMenu = fromMenu === 'noAsa' ? menuNoAsa : menuComAsa;
  parentMenu.classList.add('view-out');
  tailIdPanel.hidden = false;
  tailIdInput.value = '';
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      tailIdPanel.classList.add('view-in');
      tailIdInput.focus();
    });
  });
  inTailIdPanel = true;
}

function closeTailIdPanel() {
  if (!inTailIdPanel) return;
  tailIdPanel.classList.remove('view-in');
  menuComAsa.classList.remove('view-out');
  menuNoAsa.classList.remove('view-out');
  tailIdPanel.addEventListener('transitionend', function handler() {
    tailIdPanel.removeEventListener('transitionend', handler);
    tailIdPanel.hidden = true;
  });
  inTailIdPanel = false;
}

function confirmTailId() {
  const id = tailIdInput.value.trim();
  if (!id) {
    tailIdInput.focus();
    return;
  }
  postToLua('hudAction', { action: 'pegarcauda', tailId: id });
  hasTail = true;
  inTailIdPanel = false;
  tailIdPanel.classList.remove('view-in');
  tailIdPanel.hidden = true;
  closeHud();
  setTimeout(() => { applyWingState(); }, 300);
}

tailIdCancel.addEventListener('click', closeTailIdPanel);
tailIdConfirm.addEventListener('click', confirmTailId);
tailIdInput.addEventListener('keydown', (e) => {
  e.stopPropagation();
  if (e.key === 'Enter') confirmTailId();
  if (e.key === 'Escape') closeTailIdPanel();
});

/* ── Radial button clicks ── */

items.forEach((item) => {
  item.addEventListener('click', () => {
    const action = item.dataset.action;

    // Button 3: toggle wing (pegar/remover)
    if (action === 'toggleasa') {
      if (hasWing) {
        postToLua('hudAction', { action: 'removerasa' });
        hasWing = false;
        // If neither wing nor tail, go back to initial menu
        if (!hasTail) {
          closeHud();
          setTimeout(() => { applyWingState(); }, 300);
        } else {
          updateDynamicButtons();
          closeHud();
        }
      } else {
        idPanelTarget = 'wing-toggle';
        openWingIdPanel('comAsa');
      }
      return;
    }

    // Button 7: toggle tail (pegar/remover)
    if (action === 'togglecauda') {
      if (hasTail) {
        postToLua('hudAction', { action: 'removercauda' });
        hasTail = false;
        // If neither wing nor tail, go back to initial menu
        if (!hasWing) {
          closeHud();
          setTimeout(() => { applyWingState(); }, 300);
        } else {
          updateDynamicButtons();
          closeHud();
        }
      } else {
        idPanelTarget = 'tail-toggle';
        openTailIdPanel('comAsa');
      }
      return;
    }

    // All other buttons: send action directly
    postToLua('hudAction', { action: action });
    closeHud();
  });
});

/* ── Init ── */

applyWingState();

// Start hidden
if (scene) {
  scene.classList.add('hud-hidden');
  scene.style.display = 'none';
}

bindEditorControls();
loadLayout();
toggleEditMode(false);

/* ── Keyboard ── */

document.addEventListener('keydown', (event) => {
  const targetInsideEditor = event.target && event.target.closest && event.target.closest('.edit-panel');

  if (event.key === 'Escape' || event.code === 'Escape') {
    event.preventDefault();
    event.stopPropagation();
    if (catalogOpen) {
      if (catalogViewer && !catalogViewer.hidden) {
        closeViewer();
        return;
      }
      closeCatalog();
      return;
    }
    if (editMode) {
      toggleEditMode(false);
      return;
    }
    if (inWingIdPanel) {
      closeWingIdPanel();
      return;
    }
    if (inTailIdPanel) {
      closeTailIdPanel();
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

/* ── Catalog system ── */

const catalogOverlay = document.getElementById('catalogOverlay');
const catalogGrid = document.getElementById('catalogGrid');
const catalogClose = document.getElementById('catalogClose');
const catalogBtn = document.getElementById('catalogBtn');
const catalogLoading = document.getElementById('catalogLoading');
const catalogTokenInput = document.getElementById('catalogTokenInput');
const catalogRedeemBtn = document.getElementById('catalogRedeemBtn');
const catalogTokenStatus = document.getElementById('catalogTokenStatus');

let catalogOpen = false;
let catalogUrl = '';
let catalogProduct = '';
let catalogLoaded = false;
let catalogData = null;
let ownedColors = [];
let colorSlots = []; // ordered list of real color numbers [1, 7, 42, ...]
let selectedColors = {};
let tokenMode = false;

function openCatalog() {
  if (!catalogUrl || !catalogProduct) return;
  catalogOpen = true;
  catalogOverlay.hidden = false;

  // Hide radial menus
  if (menuNoAsa) menuNoAsa.style.display = 'none';
  if (menuComAsa) menuComAsa.style.display = 'none';
  if (catalogBtn) catalogBtn.hidden = true;

  if (!catalogLoaded) {
    loadCatalog();
  }
}

function closeCatalog() {
  if (!catalogOpen) return;
  catalogOpen = false;
  catalogOverlay.hidden = true;

  // Reset token input and selections
  if (catalogTokenInput) catalogTokenInput.value = '';
  selectedColors = {};
  if (catalogTokenStatus) {
    catalogTokenStatus.textContent = '';
    catalogTokenStatus.className = 'catalog-token-status';
  }
  updateRedeemButton();

  // Restore radial menus
  if (menuNoAsa) menuNoAsa.style.display = '';
  if (menuComAsa) menuComAsa.style.display = '';
  if (catalogBtn) catalogBtn.hidden = false;
}

async function loadCatalog() {
  catalogGrid.innerHTML = '<div class="catalog-loading">Carregando cores...</div>';

  try {
    const encodedProduct = encodeURIComponent(catalogProduct);
    const resp = await fetch(catalogUrl + '/api/catalog/' + encodedProduct);
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const json = await resp.json();
    catalogData = json;
    catalogLoaded = true;
    renderCatalog(json);
  } catch (err) {
    catalogGrid.innerHTML = '<div class="catalog-error">Erro ao carregar catálogo</div>';
    console.log('[Catalog] Error:', err);
  }
}

function renderCatalog(json) {
  if (!json.colors || json.colors.length === 0) {
    catalogGrid.innerHTML = '<div class="catalog-loading">Nenhuma cor disponível</div>';
    return;
  }

  catalogGrid.innerHTML = '';
  selectedColors = {};

  json.colors.forEach(function(color) {
    var colorNum = color.color_number;
    var isOwned = ownedColors.indexOf(colorNum) !== -1;

    const card = document.createElement('div');
    card.className = 'catalog-card';
    card.style.cursor = 'pointer';
    card.dataset.colorNumber = colorNum;

    // Selection checkbox (always visible for non-owned colors)
    var selectBox = document.createElement('div');
    selectBox.className = 'catalog-card-select visible';
    selectBox.dataset.colorNumber = colorNum;
    if (isOwned) {
      selectBox.style.display = 'none'; // Can't select owned colors
    }
    selectBox.addEventListener('click', function(e) {
      e.stopPropagation();
      if (isOwned) return;
      var cn = parseInt(this.dataset.colorNumber);
      if (selectedColors[cn]) {
        delete selectedColors[cn];
        this.classList.remove('checked');
        this.textContent = '';
      } else {
        selectedColors[cn] = true;
        this.classList.add('checked');
        this.textContent = '✓';
      }
      updateRedeemButton();
    });
    card.appendChild(selectBox);

    // Owned badge
    if (isOwned) {
      var badge = document.createElement('div');
      badge.className = 'catalog-card-badge owned';
      badge.textContent = 'ADQUIRIDO';
      card.appendChild(badge);
    }

    card.addEventListener('click', function() { openViewer(color); });

    const img = document.createElement('img');
    img.className = 'catalog-card-img';
    img.alt = color.name || 'Cor ' + colorNum;
    img.loading = 'lazy';
    img.src = color.preview_url + '/1';
    img.onerror = function() {
      this.style.display = 'none';
      const placeholder = document.createElement('div');
      placeholder.className = 'catalog-card-img loading';
      placeholder.textContent = 'Sem preview';
      card.insertBefore(placeholder, card.firstChild);
    };

    const info = document.createElement('div');
    info.className = 'catalog-card-info';

    const num = document.createElement('span');
    num.className = 'catalog-card-number';
    num.textContent = 'COR #' + colorNum;

    const name = document.createElement('p');
    name.className = 'catalog-card-name';
    name.textContent = color.name || 'Cor ' + colorNum;

    info.appendChild(num);
    info.appendChild(name);

    // Like button on card
    var likeRow = document.createElement('div');
    likeRow.className = 'catalog-card-like';
    likeRow.innerHTML = '<span class="like-icon">🤍</span> <span class="like-num">' + (color.likes || 0) + '</span>';
    (function(cn, row) {
      row.addEventListener('click', function(e) {
        e.stopPropagation();
        var icon = row.querySelector('.like-icon');
        var numEl = row.querySelector('.like-num');
        icon.textContent = '❤️';
        row.style.transform = 'scale(1.2)';
        setTimeout(function() { row.style.transform = 'scale(1)'; }, 200);
        var likeUrl = catalogUrl + '/api/like/' + encodeURIComponent(catalogProduct) + '/' + cn;
        fetch(likeUrl, { method: 'POST' })
          .then(function(r) { return r.json(); })
          .then(function(data) {
            numEl.textContent = data.likes;
            // Update catalogData too
            if (catalogData && catalogData.colors) {
              catalogData.colors.forEach(function(c) { if (c.color_number == cn) c.likes = data.likes; });
            }
          })
          .catch(function(err) { console.error('Like error:', err); });
      });
    })(colorNum, likeRow);
    info.appendChild(likeRow);

    card.appendChild(img);
    card.appendChild(info);
    catalogGrid.appendChild(card);
  });
}

function updateRedeemButton() {
  var count = Object.keys(selectedColors).length;
  var hasToken = catalogTokenInput && catalogTokenInput.value.trim().length > 0;
  if (catalogRedeemBtn) {
    catalogRedeemBtn.disabled = !(hasToken && count > 0);
    catalogRedeemBtn.textContent = count > 0 ? 'RESGATAR (' + count + ')' : 'RESGATAR';
  }
}

function setTokenMode(active) {
  // No-op: checkboxes are always visible now
}

if (catalogClose) {
  catalogClose.addEventListener('click', closeCatalog);
}

if (catalogBtn) {
  catalogBtn.addEventListener('click', openCatalog);
}

/* ── Token Input + Redeem Logic ── */

if (catalogTokenInput) {
  catalogTokenInput.addEventListener('input', function() {
    updateRedeemButton();
    if (catalogTokenStatus) {
      catalogTokenStatus.textContent = '';
      catalogTokenStatus.className = 'catalog-token-status';
    }
  });
}

if (catalogRedeemBtn) {
  catalogRedeemBtn.addEventListener('click', function() {
    var token = catalogTokenInput ? catalogTokenInput.value.trim() : '';
    var colors = Object.keys(selectedColors).map(Number);
    if (!token || colors.length === 0) return;

    catalogRedeemBtn.disabled = true;
    catalogRedeemBtn.textContent = 'RESGATANDO...';
    if (catalogTokenStatus) {
      catalogTokenStatus.textContent = 'Processando...';
      catalogTokenStatus.className = 'catalog-token-status';
    }

    // Send to FiveM Lua via NUI callback
    fetch('https://' + GetParentResourceName() + '/redeemToken', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: token, colors: colors })
    }).catch(function() {});
  });
}

/* ── Catalog 360° Viewer ── */

const catalogViewer = document.getElementById('catalogViewer');
const catalogViewerBack = document.getElementById('catalogViewerBack');
const catalogViewerTitle = document.getElementById('catalogViewerTitle');
const catalogViewerStage = document.getElementById('catalogViewerStage');
const catalogViewerCanvas = document.getElementById('catalogViewerCanvas');
const catalogViewerCtx = catalogViewerCanvas ? catalogViewerCanvas.getContext('2d') : null;
const catalogViewerLoader = document.getElementById('catalogViewerLoader');
const catalogViewerFill = document.getElementById('catalogViewerFill');
const catalogViewerHint = document.getElementById('catalogViewerHint');

let viewerPreloaded = []; // Image objects preloaded in memory
let viewerReady = false;  // all frames loaded
let viewerCurrentFrame = 0;
let viewerDragging = false;
let viewerStartX = 0;
let viewerZoom = 1.0; // zoom level (1.0 = fit, max 3.0, min 0.5)

function viewerDraw(frameIdx) {
  if (!catalogViewerCtx || !viewerPreloaded[frameIdx]) return;
  var img = viewerPreloaded[frameIdx];
  if (!img.complete || !img.naturalWidth) return;

  var canvas = catalogViewerCanvas;
  var cw = canvas.width;
  var ch = canvas.height;
  catalogViewerCtx.clearRect(0, 0, cw, ch);

  // Fit image inside canvas with padding, then apply zoom
  var iw = img.naturalWidth;
  var ih = img.naturalHeight;
  var baseScale = Math.min((cw * 0.9) / iw, (ch * 0.9) / ih);
  var scale = baseScale * viewerZoom;
  var dw = iw * scale;
  var dh = ih * scale;
  var dx = (cw - dw) / 2;
  var dy = (ch - dh) / 2;
  catalogViewerCtx.drawImage(img, dx, dy, dw, dh);
}

let viewerCurrentColor = null;

function openViewer(color) {
  if (!catalogUrl) return;
  viewerCurrentColor = color;
  viewerZoom = 1.0; // reset zoom when opening new color
  catalogViewer.hidden = false;
  catalogViewerTitle.textContent = (color.name || 'Cor ' + color.color_number) + '  —  COR #' + color.color_number;

  // Update viewer like count
  var vlc = document.getElementById('catalogViewerLikeCount');
  var vlb = document.getElementById('catalogViewerLike');
  if (vlc) vlc.textContent = color.likes || 0;
  if (vlb) vlb.innerHTML = '🤍 <span id="catalogViewerLikeCount">' + (color.likes || 0) + '</span>';

  // Setup viewer redeem panel
  var vrPanel = document.getElementById('viewerRedeemPanel');
  var vrBadge = document.getElementById('viewerRedeemBadge');
  var vrInput = document.getElementById('viewerTokenInput');
  var vrBtn = document.getElementById('viewerRedeemBtn');
  var vrStatus = document.getElementById('viewerRedeemStatus');
  var isOwned = ownedColors.indexOf(color.color_number) !== -1;

  if (vrBadge) {
    if (isOwned) {
      vrBadge.textContent = 'ADQUIRIDO';
      vrBadge.className = 'viewer-redeem-status viewer-redeem-owned';
    } else {
      vrBadge.textContent = 'NÃO ADQUIRIDO';
      vrBadge.className = 'viewer-redeem-status viewer-redeem-not-owned';
    }
  }
  if (vrInput) { vrInput.value = ''; vrInput.disabled = isOwned; }
  if (vrBtn) { vrBtn.disabled = true; vrBtn.textContent = isOwned ? 'JÁ ADQUIRIDO' : 'RESGATAR COR'; }
  if (vrStatus) { vrStatus.textContent = ''; vrStatus.className = 'viewer-redeem-status-text'; }
  viewerPreloaded = [];
  viewerReady = false;
  viewerCurrentFrame = 0;

  // Size canvas to stage
  if (catalogViewerStage && catalogViewerCanvas) {
    catalogViewerCanvas.width = catalogViewerStage.offsetWidth || 500;
    catalogViewerCanvas.height = catalogViewerStage.offsetHeight || 500;
  }

  // Show loader
  if (catalogViewerLoader) {
    catalogViewerLoader.hidden = false;
    catalogViewerLoader.querySelector('.catalog-viewer-loader-text').textContent = 'Carregando 3D Viewer...';
  }
  if (catalogViewerHint) catalogViewerHint.hidden = true;
  if (catalogViewerFill) catalogViewerFill.style.width = '0%';
  if (catalogViewerCtx) catalogViewerCtx.clearRect(0, 0, catalogViewerCanvas.width, catalogViewerCanvas.height);

  // Fetch frame URLs and preload everything
  var encodedProduct = encodeURIComponent(catalogProduct);
  fetch(catalogUrl + '/api/preview/' + encodedProduct + '/' + color.color_number)
    .then(function(r) { return r.json(); })
    .then(function(json) {
      if (!json.frames || json.frames.length === 0) {
        if (catalogViewerLoader) {
          catalogViewerLoader.querySelector('.catalog-viewer-loader-text').textContent = 'Modelo indisponível';
        }
        return;
      }

      var total = json.frames.length;
      var loaded = 0;
      viewerPreloaded = new Array(total);

      json.frames.forEach(function(f, i) {
        var img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = function() {
          loaded++;
          if (catalogViewerFill) catalogViewerFill.style.width = Math.round((loaded / total) * 100) + '%';
          // Draw first frame as soon as it loads
          if (i === 0 && loaded >= 1) viewerDraw(0);
          // All done?
          if (loaded >= total) {
            viewerReady = true;
            if (catalogViewerLoader) catalogViewerLoader.hidden = true;
            if (catalogViewerHint) catalogViewerHint.hidden = false;
            viewerDraw(viewerCurrentFrame);
          }
        };
        img.onerror = function() {
          loaded++;
          if (catalogViewerFill) catalogViewerFill.style.width = Math.round((loaded / total) * 100) + '%';
          if (loaded >= total) {
            viewerReady = true;
            if (catalogViewerLoader) catalogViewerLoader.hidden = true;
            if (catalogViewerHint) catalogViewerHint.hidden = false;
          }
        };
        img.src = f.url;
        viewerPreloaded[i] = img;
      });
    })
    .catch(function() {
      if (catalogViewerLoader) {
        catalogViewerLoader.querySelector('.catalog-viewer-loader-text').textContent = 'Erro ao carregar';
      }
    });
}

function closeViewer() {
  catalogViewer.hidden = true;
  viewerPreloaded = [];
  viewerReady = false;
  viewerCurrentColor = null;
  // Re-render catalog grid to reflect updated likes
  if (catalogLoaded && catalogData) renderCatalog(catalogData);
}

if (catalogViewerBack) {
  catalogViewerBack.addEventListener('click', closeViewer);
}

/* ── Viewer Like Button ── */
(function() {
  var viewerLikeBtn = document.getElementById('catalogViewerLike');
  var viewerLikeCount = document.getElementById('catalogViewerLikeCount');
  if (!viewerLikeBtn) return;

  viewerLikeBtn.addEventListener('click', function() {
    if (!viewerCurrentColor || !catalogUrl) return;
    var cn = viewerCurrentColor.color_number;
    viewerLikeBtn.style.transform = 'scale(1.3)';
    setTimeout(function() { viewerLikeBtn.style.transform = 'scale(1)'; }, 200);

    var likeUrl = catalogUrl + '/api/like/' + encodeURIComponent(catalogProduct) + '/' + cn;
    fetch(likeUrl, { method: 'POST' })
      .then(function(r) { return r.json(); })
      .then(function(data) {
        var countEl = document.getElementById('catalogViewerLikeCount');
        if (countEl) countEl.textContent = data.likes;
        viewerLikeBtn.innerHTML = '❤️ <span id="catalogViewerLikeCount">' + data.likes + '</span>';
        // Update catalogData too
        if (catalogData && catalogData.colors) {
          catalogData.colors.forEach(function(c) { if (c.color_number == cn) c.likes = data.likes; });
        }
      })
      .catch(function(err) { console.error('Like error:', err); });
  });
})();

/* ── Discord copy-to-clipboard ── */
(function() {
  function copyText(str) {
    var ta = document.createElement('textarea');
    ta.value = str;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch(e) {}
    document.body.removeChild(ta);
  }
  function setupDiscordCopy(el) {
    if (!el) return;
    el.addEventListener('click', function() {
      var name = el.querySelector('.catalog-discord-name, .viewer-discord-name');
      if (!name) return;
      var text = name.textContent.trim();
      copyText(text);
      var original = name.textContent;
      name.textContent = 'Copiado!';
      name.style.color = '#66ff88';
      setTimeout(function() { name.textContent = original; name.style.color = ''; }, 1500);
    });
  }
  setupDiscordCopy(document.getElementById('catalogDiscord'));
  setupDiscordCopy(document.getElementById('viewerDiscord'));
})();

/* ── Viewer Redeem Panel Logic ── */
(function() {
  var vrInput = document.getElementById('viewerTokenInput');
  var vrBtn = document.getElementById('viewerRedeemBtn');
  var vrStatus = document.getElementById('viewerRedeemStatus');

  if (vrInput) {
    vrInput.addEventListener('input', function() {
      var hasText = this.value.trim().length > 0;
      var isOwned = viewerCurrentColor && ownedColors.indexOf(viewerCurrentColor.color_number) !== -1;
      if (vrBtn) vrBtn.disabled = !hasText || isOwned;
    });
  }

  if (vrBtn) {
    vrBtn.addEventListener('click', function() {
      if (!viewerCurrentColor || !vrInput) return;
      var token = vrInput.value.trim();
      if (!token) return;
      var colorNum = viewerCurrentColor.color_number;
      var isOwned = ownedColors.indexOf(colorNum) !== -1;
      if (isOwned) return;

      vrBtn.disabled = true;
      vrBtn.textContent = 'RESGATANDO...';
      if (vrStatus) { vrStatus.textContent = 'Processando...'; vrStatus.className = 'viewer-redeem-status-text'; }

      fetch('https://' + GetParentResourceName() + '/redeemToken', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: token, colors: [colorNum] })
      }).catch(function() {});
    });
  }
})();

// Drag to rotate — canvas based, instant
if (catalogViewerStage) {
  catalogViewerStage.addEventListener('mousedown', function(e) {
    if (!viewerReady || viewerPreloaded.length === 0) return;
    viewerDragging = true;
    viewerStartX = e.clientX;
    e.preventDefault();
  });

  document.addEventListener('mousemove', function(e) {
    if (!viewerDragging || !viewerReady || viewerPreloaded.length === 0) return;
    var dx = e.clientX - viewerStartX;
    var total = viewerPreloaded.length;
    var sensitivity = Math.max(2, Math.floor(400 / total));
    if (Math.abs(dx) >= sensitivity) {
      var steps = Math.floor(Math.abs(dx) / sensitivity);
      if (dx > 0) {
        viewerCurrentFrame = (viewerCurrentFrame + steps) % total;
      } else {
        viewerCurrentFrame = (viewerCurrentFrame - steps + total) % total;
      }
      viewerDraw(viewerCurrentFrame);
      viewerStartX = e.clientX;
    }
  });

  document.addEventListener('mouseup', function() {
    viewerDragging = false;
  });

  // Fix alt-tab stuck drag
  window.addEventListener('blur', function() { viewerDragging = false; });
  document.addEventListener('visibilitychange', function() { if (document.hidden) viewerDragging = false; });

  // Zoom with mouse wheel
  catalogViewerStage.addEventListener('wheel', function(e) {
    if (!viewerReady || viewerPreloaded.length === 0) return;
    e.preventDefault();
    var delta = e.deltaY > 0 ? -0.15 : 0.15;
    viewerZoom = Math.min(3.0, Math.max(0.5, viewerZoom + delta));
    viewerDraw(viewerCurrentFrame);
  }, { passive: false });
}

/* ── FiveM NUI message listener ── */

window.addEventListener('message', function(event) {
  const data = event.data;
  if (data.action === 'openHud') {
    document.body.classList.toggle('black-bg', !!data.hudBlackBg);
    _hudDebug = !!data.hudDebugNui;
    hasWing = !!data.hasWing;
    hasTail = !!data.hasTail;
    hasTailFeature = data.hasTailFeature !== false;
    canEquipWings = data.canEquip !== false;
    currentLocale = data.locale || 'pt-BR';

    // Catalog config from Lua
    if (data.catalogUrl) catalogUrl = data.catalogUrl;
    if (data.catalogProduct) catalogProduct = data.catalogProduct;
    if (catalogBtn) catalogBtn.hidden = !(catalogUrl && catalogProduct);

    // Owned colors from server scan
    if (data.ownedColors) {
      ownedColors = data.ownedColors;
      // Re-render catalog if already loaded so badges update
      if (catalogLoaded && catalogData) renderCatalog(catalogData);
    }

    // Color slots (order-of-purchase mapping)
    if (data.colorSlots) {
      colorSlots = data.colorSlots;
    }

    applyTailFeature();
    applyLocale();
    applyWingState();
    applyCanEquip();
    openHud();
  } else if (data.action === 'closeHud') {
    if (catalogOpen) closeCatalog();
    closeHud();
    document.body.classList.remove('black-bg');
  } else if (data.action === 'redeemResult') {
    // Handle redeem result from server
    var redeemed = data.redeemed || [];
    var errors = data.errors || [];

    // Update color slots if provided
    if (data.colorSlots && data.colorSlots.length > 0) {
      colorSlots = data.colorSlots;
    }

    // Update owned colors
    if (data.success && redeemed.length > 0) {
      redeemed.forEach(function(cn) {
        if (ownedColors.indexOf(cn) === -1) ownedColors.push(cn);
      });
    }

    // Update main catalog token bar
    if (catalogTokenStatus) {
      if (data.success && redeemed.length > 0) {
        catalogTokenStatus.textContent = redeemed.length + ' cor(es) resgatada(s)!';
        catalogTokenStatus.className = 'catalog-token-status success';
        selectedColors = {};
        if (catalogTokenInput) catalogTokenInput.value = '';
        if (catalogData) renderCatalog(catalogData);
      } else {
        var errMsg = errors.length > 0 ? errors[0] : 'Erro ao resgatar';
        catalogTokenStatus.textContent = errMsg;
        catalogTokenStatus.className = 'catalog-token-status error';
      }
    }

    if (catalogRedeemBtn) {
      catalogRedeemBtn.disabled = false;
      catalogRedeemBtn.textContent = 'RESGATAR';
    }

    // Update viewer redeem panel if open
    var vrBadge = document.getElementById('viewerRedeemBadge');
    var vrBtn = document.getElementById('viewerRedeemBtn');
    var vrInput = document.getElementById('viewerTokenInput');
    var vrStatus = document.getElementById('viewerRedeemStatus');
    if (viewerCurrentColor) {
      var cn = viewerCurrentColor.color_number;
      var nowOwned = ownedColors.indexOf(cn) !== -1;
      if (vrBadge) {
        vrBadge.textContent = nowOwned ? 'ADQUIRIDO' : 'NÃO ADQUIRIDO';
        vrBadge.className = nowOwned ? 'viewer-redeem-status viewer-redeem-owned' : 'viewer-redeem-status viewer-redeem-not-owned';
      }
      if (vrBtn) {
        if (data.success && redeemed.indexOf(cn) !== -1) {
          vrBtn.textContent = 'RESGATADO ✓';
          vrBtn.disabled = true;
        } else if (errors.length > 0 && !data.success) {
          vrBtn.textContent = 'RESGATAR COR';
          vrBtn.disabled = !vrInput || !vrInput.value.trim();
        } else {
          vrBtn.textContent = nowOwned ? 'JÁ ADQUIRIDO' : 'RESGATAR COR';
          vrBtn.disabled = nowOwned;
        }
      }
      if (vrStatus) {
        if (data.success && redeemed.indexOf(cn) !== -1) {
          vrStatus.textContent = 'Cor resgatada com sucesso!';
          vrStatus.className = 'viewer-redeem-status-text success';
        } else if (errors.length > 0) {
          vrStatus.textContent = errors[0];
          vrStatus.className = 'viewer-redeem-status-text error';
        }
      }
    }
  }
});
