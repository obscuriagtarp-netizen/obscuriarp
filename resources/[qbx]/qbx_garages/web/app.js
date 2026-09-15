const state = {
  open: false,
  garage: {},
  vehicles: [],
  selectedId: null,
  view: 'condition',
  filter: 'all',
  query: '',
  favorites: new Set(),
  lastPreviewId: null,
};

const $ = (selector) => document.querySelector(selector);
const FAVORITES_KEY = 'obscuria.garage.favorites';

document.documentElement.style.background = 'transparent';
document.body.style.background = 'transparent';
$('#app').hidden = true;

function resourceName() {
  return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_garages';
}

function post(name, payload = {}) {
  if (typeof GetParentResourceName !== 'function') return Promise.resolve({ ok: true });
  return fetch(`https://${resourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).then((response) => response.json()).catch(() => ({ ok: false, error: 'network' }));
}

function idOf(item) {
  return String(item?.id ?? `${item?.model || 'vehicle'}:${item?.plate || ''}`);
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[char]));
}

function loadFavorites() {
  try {
    const stored = JSON.parse(localStorage.getItem(FAVORITES_KEY) || '[]');
    state.favorites = new Set(Array.isArray(stored) ? stored.map(String) : []);
  } catch (_) {
    state.favorites = new Set();
  }
}

function saveFavorites() {
  try { localStorage.setItem(FAVORITES_KEY, JSON.stringify([...state.favorites])); } catch (_) {}
}

function visibleVehicles() {
  const query = state.query.trim().toLocaleLowerCase('pt-BR');
  return state.vehicles.filter((item) => {
    if (state.filter === 'favorites' && !state.favorites.has(idOf(item))) return false;
    if (state.filter === 'available' && (item.state === 2 || item.vipRental?.expired)) return false;
    if (!query) return true;
    return [item.name, item.brand, item.plate, item.model, item.displayClass]
      .filter(Boolean)
      .some((value) => String(value).toLocaleLowerCase('pt-BR').includes(query));
  });
}

function selectedVehicle() {
  return state.vehicles.find((item) => idOf(item) === state.selectedId) || null;
}

function starIcon() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.8 5.6 6.2.9-4.5 4.4 1.1 6.2L12 17.2l-5.6 2.9 1.1-6.2L3 9.5l6.2-.9L12 3Z"></path></svg>';
}

const classLabels = {
  car: 'Automóvel', motorcycle: 'Motocicleta', truck: 'Caminhão', armored: 'Blindado',
  police: 'Serviço', vip: 'Exclusivo', air: 'Aeronave', sea: 'Embarcação',
};

function level(value) {
  const numeric = Number(value) || 0;
  return numeric <= 0 ? 'Original' : `Nível ${numeric + 1}`;
}

function rentalDate(timestamp) {
  if (!timestamp) return 'Sem validade';
  return new Date(Number(timestamp) * 1000).toLocaleDateString('pt-BR');
}

function renderDetails(item) {
  if (!item) {
    $('#detail-content').innerHTML = '';
    return;
  }

  if (state.view === 'tunings') {
    const rows = [
      ['Motor', level(item.tunings?.engine)],
      ['Freios', level(item.tunings?.brakes)],
      ['Transmissão', level(item.tunings?.transmission)],
      ['Blindagem', level(item.tunings?.armor)],
      ['Turbo', item.tunings?.turbo ? 'Instalado' : 'Original'],
    ];
    $('#detail-content').innerHTML = rows.map(([label, value]) => `
      <div class="detail-line"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>
    `).join('');
    return;
  }

  const rows = [
    ['Motor', item.metrics?.engine ?? 0],
    ['Lataria', item.metrics?.body ?? 0],
    ['Combustível', item.metrics?.fuel ?? 0],
    ['Pneus', item.metrics?.tyres ?? 0],
  ];
  $('#detail-content').innerHTML = rows.map(([label, value]) => `
    <div class="metric">
      <span class="metric-label">${escapeHtml(label)}</span>
      <span class="metric-track"><span style="width:${Math.max(0, Math.min(100, Number(value) || 0))}%"></span></span>
      <strong class="metric-value">${Math.round(Number(value) || 0)}%</strong>
    </div>
  `).join('') + `<div class="detail-line"><span>Cor registrada</span><strong>${escapeHtml(item.metrics?.color || 'Original')}</strong></div>`
    + (item.vipRental?.managed ? `<div class="detail-line rental-line"><span>Mensalidade VIP</span><strong>${item.vipRental.active ? `Ativa até ${rentalDate(item.vipRental.expiresAt)}` : `${Number(item.vipRental.renewalRunes) || 0} Runas / ${Number(item.vipRental.durationDays) || 30} dias`}</strong></div>` : '');
}

function renderSelected() {
  const item = selectedVehicle();
  const visible = visibleVehicles();
  if (!item) {
    $('#vehicle-class').textContent = 'Veículo';
    $('#vehicle-name').textContent = 'Nenhum veículo';
    $('#vehicle-brand').textContent = 'Aguardando seleção';
    $('#vehicle-model').textContent = 'MODELO';
    $('#vehicle-plate').textContent = '--------';
    $('#vehicle-state').innerHTML = '<i></i> Indisponível';
    $('#spawn-button').disabled = true;
    $('#favorite-button').disabled = true;
    $('#selection-index').textContent = '00 / 00';
    renderDetails(null);
    return;
  }

  const index = Math.max(0, visible.findIndex((vehicle) => idOf(vehicle) === state.selectedId));
  const depot = item.state === 2;
  const rentalExpired = item.vipRental?.managed === true && item.vipRental?.active !== true;
  $('#vehicle-class').textContent = classLabels[item.displayClass] || 'Veículo';
  $('#vehicle-name').textContent = item.name || item.model || 'Veículo';
  $('#vehicle-brand').textContent = item.fixed ? 'Veículo de serviço' : (item.brand || 'Obscuria');
  $('#vehicle-model').textContent = String(item.model || 'modelo').toUpperCase();
  $('#vehicle-plate').textContent = item.plate || '--------';
  $('#vehicle-state').innerHTML = `<i></i> ${escapeHtml(item.stateLabel || 'Disponível')}`;
  $('#vehicle-state').classList.toggle('is-depot', depot);
  $('#vehicle-state').classList.toggle('is-expired', rentalExpired);
  $('#spawn-label').textContent = rentalExpired
    ? `Renovar · ${Number(item.vipRental.renewalRunes) || 0} Runas`
    : depot
    ? (item.depotPrice !== '0' ? `Retirar · $${item.depotPrice}` : 'Retirar do pátio')
    : 'Retirar veículo';
  $('#spawn-button').disabled = false;
  $('#favorite-button').disabled = false;
  $('#favorite-button').classList.toggle('is-active', state.favorites.has(idOf(item)));
  $('#selection-index').textContent = `${String(index + 1).padStart(2, '0')} / ${String(visible.length).padStart(2, '0')}`;
  renderDetails(item);
}

function selectVehicle(id, notify = true) {
  const item = state.vehicles.find((vehicle) => idOf(vehicle) === String(id));
  if (!item) return;
  state.selectedId = idOf(item);
  renderFleet();
  renderSelected();
  if (notify && state.lastPreviewId !== state.selectedId) {
    state.lastPreviewId = state.selectedId;
    post('previewVehicle', { id: item.id });
  }
}

function renderFleet() {
  const vehicles = visibleVehicles();
  const list = $('#vehicle-list');
  const empty = $('#vehicle-list-empty');
  list.querySelectorAll('.vehicle-row').forEach((row) => row.remove());
  empty.hidden = vehicles.length > 0;
  $('#fleet-count').textContent = String(vehicles.length).padStart(2, '0');

  vehicles.forEach((item, index) => {
    const id = idOf(item);
    const row = document.createElement('div');
    row.className = `vehicle-row${id === state.selectedId ? ' is-selected' : ''}${item.vipRental?.expired ? ' is-expired' : ''}`;
    row.dataset.id = id;
    row.setAttribute('role', 'button');
    row.setAttribute('tabindex', '0');
    row.innerHTML = `
      <span class="row-index">${String(index + 1).padStart(2, '0')}</span>
      <span class="row-copy"><strong>${escapeHtml(item.name)}</strong><span>${escapeHtml(item.brand || item.model)}</span></span>
      <span class="row-plate">${escapeHtml(item.plate)}</span>
      <button class="row-favorite${state.favorites.has(id) ? ' is-active' : ''}" type="button" title="Favoritar" aria-label="Favoritar">${starIcon()}</button>
    `;
    const choose = () => selectVehicle(id);
    row.addEventListener('click', choose);
    row.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); choose(); }
    });
    row.querySelector('.row-favorite').addEventListener('click', (event) => {
      event.stopPropagation();
      toggleFavorite(item);
    });
    list.appendChild(row);
  });
}

function ensureVisibleSelection() {
  const visible = visibleVehicles();
  if (!visible.some((item) => idOf(item) === state.selectedId)) {
    if (visible[0]) selectVehicle(idOf(visible[0]));
    else {
      state.selectedId = null;
      renderFleet();
      renderSelected();
    }
  } else {
    renderFleet();
    renderSelected();
  }
}

function moveSelection(delta) {
  const visible = visibleVehicles();
  if (!visible.length) return;
  const current = visible.findIndex((item) => idOf(item) === state.selectedId);
  const next = visible[(Math.max(0, current) + delta + visible.length) % visible.length];
  selectVehicle(idOf(next));
  document.querySelector(`.vehicle-row[data-id="${CSS.escape(idOf(next))}"]`)?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function toggleFavorite(item = selectedVehicle()) {
  if (!item) return;
  const id = idOf(item);
  if (state.favorites.has(id)) state.favorites.delete(id);
  else state.favorites.add(id);
  saveFavorites();
  ensureVisibleSelection();
}

function openGarage(payload) {
  state.open = true;
  state.garage = payload.garage || {};
  state.vehicles = Array.isArray(payload.vehicles) ? payload.vehicles : [];
  state.selectedId = state.vehicles[0] ? idOf(state.vehicles[0]) : null;
  state.lastPreviewId = state.selectedId;
  state.view = 'condition';
  state.filter = 'all';
  state.query = '';
  loadFavorites();
  $('#garage-title').textContent = state.garage.label || 'Garagem';
  $('#vehicle-search').value = '';
  document.querySelectorAll('.filter-button').forEach((button) => button.classList.toggle('is-active', button.dataset.filter === 'all'));
  document.querySelectorAll('.detail-tab').forEach((button) => button.classList.toggle('is-active', button.dataset.view === 'condition'));
  document.body.classList.add('nui-open');
  $('#app').classList.remove('is-hidden');
  $('#app').hidden = false;
  renderFleet();
  renderSelected();
}

function hideGarage() {
  state.open = false;
  document.body.classList.remove('nui-open');
  $('#app').classList.add('is-hidden');
  $('#app').hidden = true;
}

function closeGarage() {
  if (!state.open) return;
  hideGarage();
  post('close');
}

window.addEventListener('message', (event) => {
  if (event.data?.action === 'open') openGarage(event.data);
  if (event.data?.action === 'close') hideGarage();
});

$('#close-button').addEventListener('click', closeGarage);
$('#favorite-button').addEventListener('click', () => toggleFavorite());
$('#previous-button').addEventListener('click', () => moveSelection(-1));
$('#next-button').addEventListener('click', () => moveSelection(1));
$('#spawn-button').addEventListener('click', async () => {
  const item = selectedVehicle();
  if (!item) return;
  if (item.vipRental?.managed && !item.vipRental.active) {
    $('#spawn-button').disabled = true;
    const result = await post('renewVipVehicle', { id: item.id });
    if (result?.ok && result.rental) {
      item.vipRental = result.rental;
      item.stateLabel = 'Pronto para retirar';
      renderFleet();
    }
    renderSelected();
    return;
  }
  post('spawn', { id: item.id });
});
$('#vehicle-search').addEventListener('input', (event) => {
  state.query = event.target.value;
  ensureVisibleSelection();
});
document.querySelectorAll('.filter-button').forEach((button) => button.addEventListener('click', () => {
  state.filter = button.dataset.filter;
  document.querySelectorAll('.filter-button').forEach((item) => item.classList.toggle('is-active', item === button));
  ensureVisibleSelection();
}));
document.querySelectorAll('.detail-tab').forEach((button) => button.addEventListener('click', () => {
  state.view = button.dataset.view;
  document.querySelectorAll('.detail-tab').forEach((item) => item.classList.toggle('is-active', item === button));
  renderSelected();
}));
$('#vehicle-list').addEventListener('wheel', (event) => {
  if (Math.abs(event.deltaY) < 5) return;
  event.preventDefault();
  moveSelection(event.deltaY > 0 ? 1 : -1);
}, { passive: false });
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeGarage();
  if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') moveSelection(-1);
  if (event.key === 'ArrowRight' || event.key === 'ArrowDown') moveSelection(1);
});

const preview = new URLSearchParams(location.search);
if (preview.has('preview')) {
  document.body.classList.add('is-preview');
  openGarage({
    garage: { label: 'Garagem Eclipse', uiClass: 'car' },
    vehicles: [
      { id: 1, model: 'schafter3', name: 'Schafter V12', brand: 'Benefactor', plate: 'OB 011', displayClass: 'car', state: 1, stateLabel: 'Disponível', depotPrice: '0', metrics: { engine: 94, body: 87, fuel: 71, tyres: 100, color: 'Preto metálico' }, tunings: { engine: 3, armor: 2, turbo: true, brakes: 2, transmission: 3 } },
      { id: 2, model: 'sultanrs', name: 'Sultan RS', brand: 'Karin', plate: 'NOCTIS', displayClass: 'car', state: 1, stateLabel: 'Disponível', depotPrice: '0', metrics: { engine: 81, body: 76, fuel: 46, tyres: 92, color: 'Cinza aço' }, tunings: { engine: 4, armor: 1, turbo: true, brakes: 3, transmission: 3 } },
      { id: 3, model: 'bati', name: 'Bati 801', brand: 'Pegassi', plate: 'LUA 013', displayClass: 'motorcycle', state: 1, stateLabel: 'Disponível', depotPrice: '0', metrics: { engine: 100, body: 91, fuel: 63, tyres: 88, color: 'Vinho' }, tunings: { engine: 2, armor: 0, turbo: false, brakes: 2, transmission: 2 } },
      { id: 4, model: 'police', name: 'Interceptor', brand: 'Serviço', plate: 'OBPD 07', displayClass: 'police', fixed: true, state: 1, stateLabel: 'Serviço disponível', depotPrice: '0', metrics: { engine: 100, body: 100, fuel: 100, tyres: 100, color: 'Institucional' }, tunings: { engine: 3, armor: 3, turbo: true, brakes: 3, transmission: 3 } },
      { id: 5, model: 'dubsta2', name: 'Dubsta', brand: 'Benefactor', plate: 'RAVEN', displayClass: 'vip', state: 1, stateLabel: 'Mensalidade VIP vencida', depotPrice: '0', vipRental: { managed: true, active: false, expired: true, expiresAt: 1789000000, durationDays: 30, renewalRunes: 150 }, metrics: { engine: 68, body: 59, fuel: 30, tyres: 74, color: 'Verde floresta' }, tunings: { engine: 1, armor: 2, turbo: false, brakes: 1, transmission: 1 } },
    ],
  });
} else {
  post('ready');
}
