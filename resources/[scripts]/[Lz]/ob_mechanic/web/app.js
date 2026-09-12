const actionMenu = document.getElementById('actionmenu');
const menu = document.getElementById('menu');
const screenEyebrow = document.getElementById('screenEyebrow');
const screenTitle = document.getElementById('screenTitle');
const screenSubtitle = document.getElementById('screenSubtitle');
const catalogTitle = document.getElementById('catalogTitle');
const catalogDescription = document.getElementById('catalogDescription');
const price = document.getElementById('preco');
const backButton = document.getElementById('voltar');
const exitButton = document.getElementById('sair');
const payButton = document.getElementById('pagar');
const modifyButton = document.getElementById('modificar');
const cameraHint = document.getElementById('cam');
const mechanicPrompt = document.getElementById('mechanicPrompt');
const promptIcon = document.getElementById('promptIcon');
const promptEyebrow = document.getElementById('promptEyebrow');
const promptTitle = document.getElementById('promptTitle');
const promptMessage = document.getElementById('promptMessage');
const promptCancel = document.getElementById('promptCancel');
const promptConfirm = document.getElementById('promptConfirm');
const isPreview = new URLSearchParams(window.location.search).get('preview') === '1';

const cameras = ['front', 'rear', 'left', 'wheels', 'top'];
const typeLabels = {
  mod: 'Peça',
  toggle: 'Ativar',
  wheelType: 'Tipo',
  color: 'Cor',
  rgbColor: 'RGB',
  paintColor: 'Cor',
  paintFinish: 'Pintura',
  range: 'Modelo',
  tireVariation: 'Pneu',
  tireBurst: 'Blindado',
  neonToggle: 'Neon',
  neonColor: 'Neon',
  smokeColor: 'Fumaça',
  xenonColor: 'Xenon',
  livery: 'Livery',
  extra: 'Extra'
};

const state = {
  open: false,
  title: 'Automotiva Akuma',
  subtitle: 'Personalização e manutenção veicular',
  ui: {},
  categories: [],
  activeCategoryId: null,
  activeOptionId: null,
  totalLabel: '$ 0',
  damaged: false,
  locked: false,
  busy: false,
  cameraIndex: 0,
  view: 'categories'
};

let activePrompt = null;
let busyTimer = null;

function resourceName() {
  if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  return 'ob_mechanic';
}

function post(name, data = {}) {
  if (isPreview) return Promise.resolve({ ok: true });
  return fetch(`https://${resourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).then((response) => response.json()).catch(() => ({ ok: false }));
}

function setBusy(busy, label = 'Processando') {
  window.clearTimeout(busyTimer);
  busyTimer = null;
  state.busy = busy === true;
  actionMenu.classList.toggle('busy', state.busy);
  actionMenu.setAttribute('aria-busy', String(state.busy));
  payButton.disabled = state.busy || state.locked;
  modifyButton.disabled = state.busy;
  backButton.disabled = state.busy;
  exitButton.disabled = state.busy;
  cameraHint.disabled = state.busy;
  payButton.textContent = state.busy ? label : 'Concluir';

  if (state.busy) {
    busyTimer = window.setTimeout(() => setBusy(false), 15000);
  }
}

function openPrompt(payload = {}) {
  activePrompt = {
    type: payload.type || 'default'
  };

  promptIcon.textContent = payload.icon || '?';
  promptEyebrow.textContent = payload.eyebrow || 'Mecânica';
  promptTitle.textContent = payload.title || 'Confirmar acao';
  promptMessage.textContent = payload.message || 'Deseja continuar?';
  promptCancel.textContent = payload.cancel || 'Cancelar';
  promptConfirm.textContent = payload.confirm || 'Confirmar';
  mechanicPrompt.classList.add('visible');
  mechanicPrompt.setAttribute('aria-hidden', 'false');
}

function closePrompt(accepted) {
  if (!activePrompt) return;
  const prompt = activePrompt;
  activePrompt = null;
  mechanicPrompt.classList.remove('visible');
  mechanicPrompt.setAttribute('aria-hidden', 'true');
  post('promptAction', {
    type: prompt.type,
    accepted: accepted === true
  });
}

function svgData(kind) {
  const paths = {
    performance: '<path d="M15 19a6 6 0 1 0-6-6"/><path d="M15 13l5-5"/><path d="M4 19h16"/>',
    body: '<path d="M5 15l2-5h10l2 5"/><path d="M3 15h18v4H3z"/><circle cx="7" cy="19" r="2"/><circle cx="17" cy="19" r="2"/>',
    wheels: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M12 4v4M12 16v4M4 12h4M16 12h4"/>',
    colors: '<path d="M12 4a8 8 0 0 0-8 8c0 3 2 5 5 5h1l1 3 2-3h2a5 5 0 0 0 5-5 8 8 0 0 0-8-8z"/><circle cx="9" cy="10" r="1"/><circle cx="13" cy="9" r="1"/><circle cx="15" cy="13" r="1"/>',
    lights: '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 13v2h8v-2a7 7 0 0 0-4-13z"/>',
    extras: '<circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1l2-1.5-2-3.5-2.4 1a7 7 0 0 0-1.7-1L14.5 3h-5l-.3 3a7 7 0 0 0-1.7 1l-2.4-1-2 3.5L5.1 11a7 7 0 0 0 0 2l-2 1.5 2 3.5 2.4-1a7 7 0 0 0 1.7 1l.3 3h5l.3-3a7 7 0 0 0 1.7-1l2.4 1 2-3.5-2-1.5a7 7 0 0 0 .1-1z"/>',
    option: '<path d="M6 18L18 6"/><path d="M8 6h10v10"/><path d="M5 20h14"/>'
  };

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24" fill="none" stroke="#d6c1ff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="2" width="20" height="20" rx="5" fill="rgba(142,92,255,.20)" stroke="rgba(214,193,255,.55)"/>
      ${paths[kind] || paths.option}
    </svg>`;

  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

function iconKind(category) {
  const map = {
    performance: 'performance',
    body: 'body',
    wheels: 'wheels',
    colors: 'colors',
    lights: 'lights',
    extras: 'extras'
  };
  return map[category?.id] || 'option';
}

function imageFor(kind, category, option) {
  const ui = state.ui || {};
  const categoryImages = ui.categoryImages || {};
  const optionImages = ui.optionImages || {};

  if (kind === 'category' && categoryImages[category?.id]) return categoryImages[category.id];
  if ((kind === 'option' || kind === 'value') && optionImages[option?.id]) return optionImages[option.id];
  if ((kind === 'option' || kind === 'value') && categoryImages[category?.id]) return categoryImages[category.id];
  return ui.fallbackImage || '';
}

function fallbackKind(category) {
  return iconKind(category || {});
}

function currentCategory() {
  return state.categories.find((category) => category.id === state.activeCategoryId) || state.categories[0] || null;
}

function currentOption() {
  const category = currentCategory();
  if (!category) return null;
  return category.options.find((option) => option.id === state.activeOptionId) || category.options[0] || null;
}

function setPayload(payload, keepView = false, preserveScroll = false) {
  state.title = payload.title || 'Automotiva Akuma';
  state.subtitle = payload.subtitle || 'Personalização e manutenção veicular';
  state.ui = payload.ui || {};
  state.categories = payload.categories || [];
  state.totalLabel = payload.totalLabel || '$ 0';
  state.damaged = payload.damaged === true;
  state.locked = payload.locked === true;
  actionMenu.style.setProperty('--mechanic-banner-image', state.ui.bannerImage ? `url("${state.ui.bannerImage}")` : 'none');

  if (!keepView) {
    state.activeCategoryId = payload.activeCategoryId || state.categories[0]?.id || null;
    state.activeOptionId = null;
    state.view = 'categories';
  } else if (!state.categories.some((category) => category.id === state.activeCategoryId)) {
    state.activeCategoryId = state.categories[0]?.id || null;
    state.activeOptionId = null;
    state.view = 'categories';
  }

  render(preserveScroll);
}

function setHeader(eyebrow, title, subtitle) {
  screenEyebrow.textContent = eyebrow || 'Oficina autorizada';
  screenTitle.textContent = title || 'Automotiva Akuma';
  screenSubtitle.textContent = subtitle || state.subtitle;
}

function setCatalog(title, description) {
  catalogTitle.textContent = title;
  catalogDescription.textContent = description;
}

function renderCardImage(src, fallback, label) {
  const safeLabel = label || '';
  const fallbackSrc = svgData(fallback || 'option');

  if (!src) {
    return `<img class="card-image fallback" src="${fallbackSrc}" alt="${safeLabel}">`;
  }

  return `
    <img class="card-image" src="${src}" alt="${safeLabel}" onerror="this.onerror=null;this.src='${fallbackSrc}';this.classList.add('fallback');">
  `;
}

function card(className, imageSrc, fallback, label, meta, onClick, active = false, changed = false) {
  const button = document.createElement('button');
  button.className = `${className}${active ? ' active' : ''}${changed ? ' changed' : ''}`;
  button.type = 'button';
  button.innerHTML = `
    <div class="media">${renderCardImage(imageSrc, fallback, label)}</div>
    <div class="textbox">
      <span>${label}</span>
      ${meta ? `<small>${meta}</small>` : ''}
    </div>
    <div class="card-arrow">&rsaquo;</div>
  `;
  button.addEventListener('click', onClick);
  return button;
}

function clampColor(value) {
  const number = Number.parseInt(value, 10);
  if (Number.isNaN(number)) return 0;
  return Math.max(0, Math.min(255, number));
}

function parseRgb(value) {
  const parts = String(value || '255,255,255').split(',').map(clampColor);
  return {
    r: parts[0] ?? 255,
    g: parts[1] ?? 255,
    b: parts[2] ?? 255
  };
}

function rgbToValue(rgb) {
  return `${clampColor(rgb.r)},${clampColor(rgb.g)},${clampColor(rgb.b)}`;
}

function rgbToHex(rgb) {
  const toHex = (value) => clampColor(value).toString(16).padStart(2, '0');
  return `#${toHex(rgb.r)}${toHex(rgb.g)}${toHex(rgb.b)}`;
}

function hexToRgb(value) {
  const hex = String(value || '#ffffff').replace('#', '');
  if (hex.length !== 6) return { r: 255, g: 255, b: 255 };
  return {
    r: Number.parseInt(hex.slice(0, 2), 16),
    g: Number.parseInt(hex.slice(2, 4), 16),
    b: Number.parseInt(hex.slice(4, 6), 16)
  };
}

function renderRgbEditor(category, option) {
  const rgb = parseRgb(option.current);
  const image = imageFor('category', category);
  const fallback = fallbackKind(category);
  const finishes = option.finishes || [];
  const activeFinish = option.finish || 'metallic';
  const finishButtons = finishes.map((finish) => `
    <button class="paint-finish ${String(activeFinish) === String(finish.value) ? 'active' : ''}" data-finish="${finish.value}" type="button">
      ${finish.label}
    </button>
  `).join('');

  menu.innerHTML = `
    <div class="rgb-editor">
      <div class="rgb-preview">
        <div class="rgb-card-image">${renderCardImage(image, fallback, option.label)}</div>
        <div class="rgb-swatch" style="background: rgb(${rgb.r}, ${rgb.g}, ${rgb.b})"></div>
      </div>

      <div class="rgb-fields">
        <label>
          <span>Cor</span>
          <input class="rgb-color-picker" type="color" value="${rgbToHex(rgb)}">
        </label>
        <label>
          <span>R</span>
          <input class="rgb-input" data-channel="r" type="number" min="0" max="255" value="${rgb.r}">
        </label>
        <label>
          <span>G</span>
          <input class="rgb-input" data-channel="g" type="number" min="0" max="255" value="${rgb.g}">
        </label>
        <label>
          <span>B</span>
          <input class="rgb-input" data-channel="b" type="number" min="0" max="255" value="${rgb.b}">
        </label>
      </div>

      ${finishButtons ? `
        <div class="paint-finish-panel">
          <span>Tipo de pintura</span>
          <div class="paint-finish-grid">${finishButtons}</div>
        </div>
      ` : ''}

      <div class="rgb-live-note">Aplicando em tempo real</div>
    </div>
  `;

  const colorPicker = menu.querySelector('.rgb-color-picker');
  const inputs = [...menu.querySelectorAll('.rgb-input')];
  const swatch = menu.querySelector('.rgb-swatch');
  let applyTimer = null;

  const readInputs = () => ({
    r: clampColor(inputs.find((input) => input.dataset.channel === 'r')?.value),
    g: clampColor(inputs.find((input) => input.dataset.channel === 'g')?.value),
    b: clampColor(inputs.find((input) => input.dataset.channel === 'b')?.value)
  });

  const updateSwatch = (nextRgb) => {
    swatch.style.background = `rgb(${nextRgb.r}, ${nextRgb.g}, ${nextRgb.b})`;
    colorPicker.value = rgbToHex(nextRgb);
  };

  const applyRgb = (nextRgb) => {
    const value = rgbToValue(nextRgb);
    option.current = value;

    window.clearTimeout(applyTimer);
    applyTimer = window.setTimeout(() => {
      post('apply', {
        categoryId: category.id,
        optionId: option.id,
        value,
        silent: true
      });
    }, 45);
  };

  colorPicker.addEventListener('input', () => {
    const nextRgb = hexToRgb(colorPicker.value);
    inputs.forEach((input) => {
      input.value = nextRgb[input.dataset.channel];
    });
    updateSwatch(nextRgb);
    applyRgb(nextRgb);
  });

  inputs.forEach((input) => {
    input.addEventListener('input', () => {
      const nextRgb = readInputs();
      updateSwatch(nextRgb);
      applyRgb(nextRgb);
    });
  });

  menu.querySelectorAll('.paint-finish').forEach((button) => {
    button.addEventListener('click', () => {
      const value = button.dataset.finish;
      option.finish = value;
      menu.querySelectorAll('.paint-finish').forEach((item) => item.classList.toggle('active', item === button));
      post('apply', {
        categoryId: category.id,
        optionId: 'paint_finish',
        value,
        silent: true
      });
    });
  });
}

function renderPaintEditor(category, option) {
  const image = imageFor('category', category);
  const fallback = fallbackKind(category);
  const paint = option.paint || {};
  const finishes = option.finishes || [];
  const target = option.selectedTarget || 'primary';
  const currentFinish = option.selectedFinish || paint[`${target}Finish`] || 'metallic';
  const rgb = parseRgb(paint[`${target}Rgb`] || '255,255,255');
  const isChrome = currentFinish === 'chrome';
  const swatchStyle = isChrome
    ? 'linear-gradient(135deg, #f7f7ff 0%, #8d8d98 34%, #ffffff 52%, #5c5c68 100%)'
    : `rgb(${rgb.r}, ${rgb.g}, ${rgb.b})`;

  const targetButtons = [
    { label: 'Primaria', value: 'primary' },
    { label: 'Secundaria', value: 'secondary' }
  ].map((item) => `
    <button class="paint-target ${target === item.value ? 'active' : ''}" data-target="${item.value}" type="button">${item.label}</button>
  `).join('');

  const finishButtons = finishes.map((finish) => `
    <button class="paint-finish ${currentFinish === finish.value ? 'active' : ''}" data-finish="${finish.value}" type="button">
      ${finish.label}
    </button>
  `).join('');

  menu.innerHTML = `
    <div class="paint-editor">
      <div class="paint-preview">
        <div class="rgb-card-image">${renderCardImage(image, fallback, option.label)}</div>
        <div class="paint-main-swatch" style="background:${swatchStyle}"></div>
      </div>

      <div class="paint-section">
        <span>Editar</span>
        <div class="paint-target-grid">${targetButtons}</div>
      </div>

      <div class="paint-section">
        <span>Tipo de pintura</span>
        <div class="paint-finish-grid">${finishButtons}</div>
      </div>

      <div class="paint-section">
        <span>Cor</span>
        <div class="paint-rgb-fields">
          <label>
            <span>Cor</span>
            <input class="rgb-color-picker" type="color" value="${rgbToHex(rgb)}">
          </label>
          <label>
            <span>R</span>
            <input class="rgb-input" data-channel="r" type="number" min="0" max="255" value="${rgb.r}">
          </label>
          <label>
            <span>G</span>
            <input class="rgb-input" data-channel="g" type="number" min="0" max="255" value="${rgb.g}">
          </label>
          <label>
            <span>B</span>
            <input class="rgb-input" data-channel="b" type="number" min="0" max="255" value="${rgb.b}">
          </label>
        </div>
      </div>

    </div>
  `;

  const colorPicker = menu.querySelector('.rgb-color-picker');
  const inputs = [...menu.querySelectorAll('.rgb-input')];
  const swatch = menu.querySelector('.paint-main-swatch');
  let applyTimer = null;

  const readInputs = () => ({
    r: clampColor(inputs.find((input) => input.dataset.channel === 'r')?.value),
    g: clampColor(inputs.find((input) => input.dataset.channel === 'g')?.value),
    b: clampColor(inputs.find((input) => input.dataset.channel === 'b')?.value)
  });

  const updateSwatch = (nextRgb, finish = currentFinish) => {
    if (finish === 'chrome') {
      swatch.style.background = 'linear-gradient(135deg, #f7f7ff 0%, #8d8d98 34%, #ffffff 52%, #5c5c68 100%)';
    } else {
      swatch.style.background = `rgb(${nextRgb.r}, ${nextRgb.g}, ${nextRgb.b})`;
    }
    colorPicker.value = rgbToHex(nextRgb);
  };

  const applyPaint = (nextRgb, finish = currentFinish, debounce = true) => {
    const rgbValue = rgbToValue(nextRgb);
    option.paint = {
      ...paint,
      [`${target}Rgb`]: rgbValue,
      [`${target}Finish`]: finish
    };
    option.selectedFinish = finish;

    const send = () => post('apply', {
      categoryId: category.id,
      optionId: option.id,
      value: {
        target,
        finish,
        rgb: rgbValue
      },
      silent: true
    });

    window.clearTimeout(applyTimer);
    if (debounce) {
      applyTimer = window.setTimeout(send, 45);
    } else {
      send();
    }
  };

  colorPicker.addEventListener('input', () => {
    const nextRgb = hexToRgb(colorPicker.value);
    inputs.forEach((input) => {
      input.value = nextRgb[input.dataset.channel];
    });
    updateSwatch(nextRgb, currentFinish);
    applyPaint(nextRgb, currentFinish);
  });

  inputs.forEach((input) => {
    input.addEventListener('input', () => {
      const nextRgb = readInputs();
      updateSwatch(nextRgb, currentFinish);
      applyPaint(nextRgb, currentFinish);
    });
  });

  menu.querySelectorAll('.paint-target').forEach((button) => {
    button.addEventListener('click', () => {
      option.selectedTarget = button.dataset.target || 'primary';
      option.selectedFinish = option.paint?.[`${option.selectedTarget}Finish`] || 'metallic';
      renderPaintEditor(category, option);
    });
  });

  menu.querySelectorAll('.paint-finish').forEach((button) => {
    button.addEventListener('click', () => {
      const finish = button.dataset.finish || 'metallic';
      const nextRgb = readInputs();
      updateSwatch(nextRgb, finish);
      applyPaint(nextRgb, finish, false);
      renderPaintEditor(category, option);
    });
  });
}

function restoreMenuScroll(scrollTop) {
  menu.scrollTop = scrollTop || 0;
  window.requestAnimationFrame(() => {
    menu.scrollTop = scrollTop || 0;
  });
}

function renderCategories(preserveScroll = false) {
  const previousScroll = preserveScroll ? menu.scrollTop : 0;
  actionMenu.classList.add('root-view');
  setHeader(state.ui.eyebrow || 'Oficina autorizada', state.title, state.subtitle);
  setCatalog('CATÁLOGO TÉCNICO', 'Selecione uma categoria para inspecionar o veículo.');
  backButton.style.display = 'none';
  menu.innerHTML = '';
  menu.className = 'menu menu-categories';
  state.view = 'categories';

  if (!state.categories.length) {
    menu.innerHTML = '<div class="empty">Nenhuma customizacao disponivel.</div>';
    return;
  }

  state.categories.forEach((category) => {
    menu.appendChild(card('option', imageFor('category', category), fallbackKind(category), category.label, category.priceLabel || '', () => {
      state.activeCategoryId = category.id;
      state.activeOptionId = null;
      renderOptions();
    }));
  });

  restoreMenuScroll(previousScroll);
}

function renderOptions(preserveScroll = false) {
  const category = currentCategory();
  if (!category) return renderCategories();
  const previousScroll = preserveScroll ? menu.scrollTop : 0;

  actionMenu.classList.remove('root-view');
  setHeader('Catálogo técnico', category.label, `${category.options.length} opções disponíveis`);
  setCatalog('PEÇAS E ACABAMENTOS', 'Escolha o componente que deseja configurar.');
  backButton.style.display = 'block';
  menu.innerHTML = '';
  menu.className = 'menu menu-options';
  state.view = 'options';

  if (!category.options.length) {
    menu.innerHTML = '<div class="empty">Nenhuma opcao encontrada.</div>';
    return;
  }

  category.options.forEach((option) => {
    const label = option.changed ? `${option.label}` : option.label;
    const meta = option.changed ? 'Alterado' : '';
    menu.appendChild(card('option2', imageFor('category', category), fallbackKind(category), label, meta, () => {
      state.activeOptionId = option.id;
      renderValues();
    }, false, option.changed));
  });

  restoreMenuScroll(previousScroll);
}

function renderValues(preserveScroll = false) {
  const category = currentCategory();
  const option = currentOption();
  if (!category || !option) return renderOptions();
  const previousScroll = preserveScroll ? menu.scrollTop : 0;

  actionMenu.classList.remove('root-view');
  setHeader(typeLabels[option.type] || 'Opção', option.label, category.label);
  setCatalog('CONFIGURAÇÃO', 'Compare as opções no veículo antes de concluir.');
  backButton.style.display = 'block';
  menu.innerHTML = '';
  menu.className = 'menu menu-values';
  state.view = 'values';

  if (option.type === 'paintColor') {
    renderPaintEditor(category, option);
    restoreMenuScroll(previousScroll);
    return;
  }

  if (option.type === 'rgbColor') {
    renderRgbEditor(category, option);
    restoreMenuScroll(previousScroll);
    return;
  }

  if (!option.values?.length) {
    menu.innerHTML = '<div class="empty">Nenhum valor disponivel.</div>';
    return;
  }

  option.values.forEach((entry) => {
    const isActive = String(option.current) === String(entry.value);
    const meta = isActive ? 'Selecionado' : 'Aplicar';
    menu.appendChild(card('option2 value-card', imageFor('category', category), fallbackKind(category), entry.label, meta, () => {
      option.current = entry.value;
      post('apply', {
        categoryId: category.id,
        optionId: option.id,
        value: entry.value
      });
      renderValues(true);
    }, isActive, option.changed));
  });

  restoreMenuScroll(previousScroll);
}

function render(preserveScroll = false) {
  price.textContent = state.totalLabel;
  actionMenu.classList.toggle('locked', state.locked);
  modifyButton.style.display = state.open && state.locked ? 'block' : 'none';
  setBusy(state.busy);

  if (state.view === 'values') return renderValues(preserveScroll);
  if (state.view === 'options') return renderOptions(preserveScroll);
  renderCategories(preserveScroll);
}

function goBack() {
  if (state.view === 'values') {
    state.activeOptionId = null;
    return renderOptions();
  }

  if (state.view === 'options') {
    state.activeOptionId = null;
    return renderCategories();
  }
}

function cycleCamera() {
  state.cameraIndex = (state.cameraIndex + 1) % cameras.length;
  post('camera', { view: cameras[state.cameraIndex] });
}

backButton.addEventListener('click', goBack);
exitButton.addEventListener('click', () => {
  if (!state.busy) post('close');
});
payButton.addEventListener('click', () => {
  if (state.busy || state.locked) return;
  setBusy(true);
  post('checkout');
});
modifyButton.addEventListener('click', () => {
  if (state.busy) return;
  setBusy(true, 'Reparando');
  post('repair');
});
cameraHint.addEventListener('click', () => {
  if (!state.busy) cycleCamera();
});
promptCancel.addEventListener('click', () => closePrompt(false));
promptConfirm.addEventListener('click', () => closePrompt(true));

document.addEventListener('keyup', (event) => {
  if (event.key === 'Escape') post('close');
  if (event.key.toLowerCase() === 'h' && state.open) cycleCamera();
});

window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.action === 'open') {
    state.open = true;
    actionMenu.style.display = 'block';
    setPayload(data.payload || {});
  }

  if (data.action === 'refresh') {
    setPayload(data.payload || {}, true, true);
  }

  if (data.action === 'total') {
    state.totalLabel = data.payload?.totalLabel || '$ 0';
    price.textContent = state.totalLabel;
  }

  if (data.action === 'busy') {
    setBusy(data.payload?.busy === true, data.payload?.label || 'Processando');
  }

  if (data.action === 'prompt') {
    openPrompt(data.payload || {});
  }

  if (data.action === 'close') {
    state.open = false;
    state.busy = false;
    actionMenu.style.display = 'none';
    modifyButton.style.display = 'none';
    mechanicPrompt.classList.remove('visible');
    mechanicPrompt.setAttribute('aria-hidden', 'true');
    activePrompt = null;
  }
});

if (isPreview) {
  const previewParams = new URLSearchParams(window.location.search);
  const previewOptions = (prefix) => [
    { id: `${prefix}_original`, label: 'Original', type: 'mod', current: -1, changed: false, values: [
      { label: 'Original', value: -1 }, { label: 'Nível 1', value: 0 }, { label: 'Nível 2', value: 1 }
    ] },
    { id: `${prefix}_upgrade`, label: 'Aprimoramento', type: 'mod', current: 1, changed: true, values: [
      { label: 'Original', value: -1 }, { label: 'Nível 1', value: 0 }, { label: 'Nível 2', value: 1 }
    ] }
  ];

  window.dispatchEvent(new MessageEvent('message', { data: {
    action: 'open',
    payload: {
      title: 'Automotiva Akuma',
      subtitle: 'Personalização, performance e acabamento do veículo.',
      totalLabel: '$ 24.500',
      damaged: previewParams.get('damaged') === '1',
      locked: previewParams.get('damaged') === '1',
      ui: {
        eyebrow: 'Oficina autorizada',
        categoryImages: {
          performance: 'images/categories/performance.png?v=2.1.0',
          body: 'images/categories/bodywork.png?v=2.1.0',
          wheels: 'images/categories/wheels.png?v=2.1.0',
          colors: 'images/categories/colors.png?v=2.1.0',
          lights: 'images/categories/lights.png?v=2.1.0',
          extras: 'images/categories/extras.png?v=2.1.0'
        }
      },
      categories: [
        { id: 'performance', label: 'Performance', priceLabel: '$ 18.000', options: previewOptions('performance') },
        { id: 'body', label: 'Lataria', priceLabel: '$ 7.500', options: previewOptions('body') },
        { id: 'wheels', label: 'Rodas', priceLabel: '$ 5.500', options: previewOptions('wheels') },
        { id: 'colors', label: 'Cores', priceLabel: '$ 3.500', options: [{
          id: 'paint_color',
          label: 'Pintura do veículo',
          type: 'paintColor',
          current: '120,48,146:22,24,29:metallic:matte',
          changed: true,
          finishes: [
            { label: 'Metálico', value: 'metallic' },
            { label: 'Fosco', value: 'matte' },
            { label: 'Cromado', value: 'chrome' }
          ],
          paint: {
            primaryRgb: '120,48,146',
            secondaryRgb: '22,24,29',
            primaryFinish: 'metallic',
            secondaryFinish: 'matte'
          },
          values: [{ label: 'Cor', value: 'paint' }]
        }] },
        { id: 'lights', label: 'Iluminação', priceLabel: '$ 4.500', options: previewOptions('lights') },
        { id: 'extras', label: 'Extras', priceLabel: '$ 3.000', options: previewOptions('extras') }
      ]
    }
  }}));

  if (previewParams.get('prompt') === '1') {
    window.dispatchEvent(new MessageEvent('message', { data: {
      action: 'prompt',
      payload: {
        type: 'savePending',
        icon: '?',
        eyebrow: 'Automotiva Akuma',
        title: 'Salvar configuração',
        message: 'Deseja guardar esta preparação para continuar quando retornar à oficina?',
        cancel: 'Agora não',
        confirm: 'Salvar'
      }
    }}));
  }
}
