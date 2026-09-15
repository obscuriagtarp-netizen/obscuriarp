const app = document.getElementById('app');
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ob_housing';
const previewMode = new URLSearchParams(window.location.search).get('preview') === '1';

const state = {
    activeView: 'catalog',
    isAdmin: false,
    catalog: [],
    mine: [],
    admin: [],
    presets: [],
    imageLimit: 8,
    fallbackImage: '',
    filter: 'all',
    catalogSearch: '',
    adminSearch: '',
    editor: null,
    selectedDetails: null,
    grantProperty: null,
    accessProperty: null,
    ownersProperty: null,
    confirmAction: null,
    keyManuallyEdited: false
};

const errors = {
    database_initializing: 'O sistema ainda está iniciando.',
    forbidden: 'Você não possui permissão para esta ação.',
    property_not_found: 'Imóvel não encontrado.',
    property_unavailable: 'Este imóvel não está mais disponível.',
    already_owned: 'Você já possui este imóvel.',
    no_access: 'Você não possui acesso a este imóvel.',
    too_far: 'Aproxime-se do imóvel.',
    insufficient_funds: 'Saldo insuficiente.',
    not_for_sale: 'Este imóvel não está à venda.',
    purchases_disabled: 'As compras estão indisponíveis agora.',
    house_limit: 'Você atingiu o limite de casas.',
    invalid_key: 'A chave deve usar letras minúsculas, números, _ ou -.',
    invalid_label: 'Informe um nome válido.',
    invalid_entrance: 'Capture a entrada externa.',
    invalid_interior: 'Complete os pontos do interior.',
    duplicate_key: 'Essa chave já está em uso.',
    citizen_not_found: 'Citizen ID não encontrado.',
    invalid_expiry: 'Informe uma duração válida para a concessão.',
    already_owner: 'Este personagem já é o proprietário.',
    property_busy: 'O imóvel está sendo atualizado. Aguarde um instante.',
    slow_down: 'Aguarde um instante antes de repetir.',
    starter_cannot_archive: 'O apartamento inicial não pode ser arquivado.',
    purchase_failed: 'A compra falhou e o valor foi devolvido.',
    grant_failed: 'Não foi possível entregar o imóvel.',
    revoke_failed: 'Não foi possível remover o imóvel.',
    preview_disabled: 'A visualização de interiores está desativada.',
    internal_error: 'Não foi possível concluir a ação.'
};

const demoPayload = {
    ok: true,
    mode: new URLSearchParams(window.location.search).get('screen') || 'catalog',
    isAdmin: true,
    imageLimit: 8,
    fallbackImage: 'images/olho-branco.png',
    presets: [
        { key: 'bob_studio', label: 'Estúdio compacto', provider: 'bob74_ipl', interior: { entry: { x: 266.11, y: -1007.43, z: -101.01, h: 357 }, exit: { x: 266.11, y: -1007.43, z: -101.01, h: 357 }, stash: { x: 265.92, y: -999.38, z: -99.01 }, wardrobe: { x: 259.82, y: -1003.95, z: -99.01 } } },
        { key: 'bob_house_mid', label: 'Casa urbana', provider: 'bob74_ipl', interior: { entry: { x: 346.52, y: -1012.96, z: -99.2, h: 1 }, exit: { x: 346.52, y: -1012.96, z: -99.2, h: 1 }, stash: { x: 351.86, y: -998.73, z: -99.2 }, wardrobe: { x: 350.7, y: -993.6, z: -99.2 } } },
        { key: 'bob_apartment_high', label: 'Apartamento de luxo - Integrity Way', provider: 'bob74_ipl', interior: { entry: { x: -35.31, y: -580.42, z: 88.71, h: 70 }, exit: { x: -35.31, y: -580.42, z: 88.71, h: 70 }, stash: { x: -38.72, y: -583.78, z: 88.71 }, wardrobe: { x: -37.52, y: -571.62, z: 88.71 } } },
        { key: 'bob_apartment_del_perro', label: 'Apartamento de luxo - Del Perro', provider: 'bob74_ipl', interior: { entry: { x: -1477.14, y: -538.75, z: 55.53, h: 215 }, exit: { x: -1477.14, y: -538.75, z: 55.53, h: 215 }, stash: { x: -1468.74, y: -537.22, z: 50.73 }, wardrobe: { x: -1467.49, y: -529.57, z: 50.72 } } },
        { key: 'bob_mansion_wild_oats', label: 'Mansão - Wild Oats Drive', provider: 'bob74_ipl', interior: { entry: { x: -174.08, y: 497.15, z: 137.67, h: 192 }, exit: { x: -174.08, y: 497.15, z: 137.67, h: 192 }, stash: { x: -170.56, y: 482.26, z: 137.24 }, wardrobe: { x: -167.44, y: 487.76, z: 133.84 } } },
        { key: 'bob_mansion_conker_2044', label: 'Mansão - North Conker 2044', provider: 'bob74_ipl', interior: { entry: { x: 341.84, y: 437.70, z: 149.39, h: 118 }, exit: { x: 341.84, y: 437.70, z: 149.39, h: 118 }, stash: { x: 334.10, y: 428.50, z: 145.57 }, wardrobe: { x: 334.35, y: 436.92, z: 145.57 } } },
        { key: 'bob_mansion_conker_2045', label: 'Mansão - North Conker 2045', provider: 'bob74_ipl', interior: { entry: { x: 373.68, y: 423.83, z: 145.91, h: 167 }, exit: { x: 373.68, y: 423.83, z: 145.91, h: 167 }, stash: { x: 377.20, y: 407.55, z: 145.50 }, wardrobe: { x: 374.20, y: 411.62, z: 142.10 } } },
        { key: 'bob_mansion_hillcrest_2862', label: 'Mansão - Hillcrest 2862', provider: 'bob74_ipl', interior: { entry: { x: -682.45, y: 592.03, z: 145.39, h: 218 }, exit: { x: -682.45, y: 592.03, z: 145.39, h: 218 }, stash: { x: -671.80, y: 580.63, z: 145.17 }, wardrobe: { x: -671.55, y: 587.80, z: 141.57 } } },
        { key: 'bob_mansion_hillcrest_2868', label: 'Mansão - Hillcrest 2868', provider: 'bob74_ipl', interior: { entry: { x: -758.81, y: 619.08, z: 144.15, h: 111 }, exit: { x: -758.81, y: 619.08, z: 144.15, h: 111 }, stash: { x: -767.90, y: 610.85, z: 144.14 }, wardrobe: { x: -764.55, y: 618.97, z: 140.14 } } },
        { key: 'bob_mansion_hillcrest_2874', label: 'Mansão - Hillcrest 2874', provider: 'bob74_ipl', interior: { entry: { x: -859.89, y: 690.72, z: 152.86, h: 193 }, exit: { x: -859.89, y: 690.72, z: 152.86, h: 193 }, stash: { x: -855.42, y: 674.96, z: 152.65 }, wardrobe: { x: -852.73, y: 680.19, z: 148.65 } } },
        { key: 'bob_mansion_whispymound', label: 'Mansão - Whispymound Drive', provider: 'bob74_ipl', interior: { entry: { x: 117.26, y: 559.79, z: 184.30, h: 187 }, exit: { x: 117.26, y: 559.79, z: 184.30, h: 187 }, stash: { x: 123.18, y: 544.38, z: 183.90 }, wardrobe: { x: 121.14, y: 548.75, z: 180.50 } } },
        { key: 'bob_mansion_mad_wayne', label: 'Mansão - Mad Wayne Thunder', provider: 'bob74_ipl', interior: { entry: { x: -1289.78, y: 449.45, z: 97.90, h: 180 }, exit: { x: -1289.78, y: 449.45, z: 97.90, h: 180 }, stash: { x: -1286.86, y: 433.37, z: 97.69 }, wardrobe: { x: -1284.22, y: 438.18, z: 94.09 } } }
    ],
    catalog: [
        { id: 2, key: 'casa_mirror', type: 'house', ownershipMode: 'unique', label: 'Casa Mirror Park', description: 'Residência tranquila com acesso rápido ao centro da cidade.', price: 480000, purchasable: true, available: true, listed: true, status: 'available', gallery: [], stashSlots: 50, stashWeight: 100000, entrance: { x: 1, y: 1, z: 1 }, presetKey: 'bob_house_mid' },
        { id: 3, key: 'apt_del_perro', type: 'apartment', ownershipMode: 'instanced', label: 'Apartamento Del Perro', description: 'Apartamento de alto padrão próximo ao litoral.', price: 720000, purchasable: true, available: true, listed: true, status: 'available', gallery: [], stashSlots: 70, stashWeight: 150000, entrance: { x: 1, y: 1, z: 1 }, presetKey: 'bob_apartment_high' },
        { id: 4, key: 'mansao_eclipse', type: 'house', ownershipMode: 'instanced', label: 'Mansão Eclipse', description: 'Propriedade reservada para membros Eclipse e Arcano.', price: 0, purchasable: false, available: true, listed: true, status: 'available', vipTier: 'eclipse', gallery: [], stashSlots: 100, stashWeight: 300000, entrance: { x: 1, y: 1, z: 1 }, presetKey: 'bob_apartment_high' }
    ],
    mine: [
        { id: 1, key: 'apartamento_inicial', type: 'apartment', ownershipMode: 'instanced', label: 'Apartamento Inicial', description: 'Seu primeiro endereço em Obscuria.', price: 0, available: true, starter: true, gallery: [], stashSlots: 20, stashWeight: 30000, entrance: { x: 1, y: 1, z: 1 }, ownershipId: 18, accessRole: 'owner', acquisition: 'starter' }
    ]
};
demoPayload.admin = [demoPayload.mine[0], ...demoPayload.catalog];

function escapeHtml(value) {
    return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}

function deepClone(value) {
    return value == null ? value : JSON.parse(JSON.stringify(value));
}

async function post(endpoint, payload = {}) {
    if (previewMode) {
        if (endpoint === 'capturePoint') return { ok: true, coords: { x: -716.55, y: 261.22, z: 84.14, h: 90 } };
        return { ok: true };
    }
    try {
        const response = await fetch(`https://${resourceName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        });
        return await response.json();
    } catch (_) {
        return { ok: false, error: 'internal_error' };
    }
}

function request(action, data = {}) {
    return post('request', { action, data });
}

let toastTimer;
function toast(message, type = '') {
    const element = document.getElementById('toast');
    element.textContent = message;
    element.className = `toast ${type}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => element.classList.add('is-hidden'), 3400);
}

function resultOk(result, successMessage) {
    if (!result?.ok) {
        toast(errors[result?.error] || 'Não foi possível concluir a ação.', 'error');
        return false;
    }
    if (successMessage) toast(successMessage, 'success');
    return true;
}

function formatMoney(value) {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 }).format(Number(value) || 0);
}

function propertyPrice(property) {
    if (!property.purchasable) return property.vipTier ? `VIP ${String(property.vipTier).toUpperCase()}` : 'Indisponível';
    return Number(property.price) > 0 ? formatMoney(property.price) : 'Gratuito';
}

function propertyType(property) {
    return property.type === 'apartment' ? 'Apartamento' : 'Casa';
}

function coverImage(property) {
    return Array.isArray(property.gallery) && property.gallery[0] ? property.gallery[0] : state.fallbackImage;
}

function imageMarkup(property) {
    const source = coverImage(property);
    if (!source) return '';
    const fallback = !Array.isArray(property.gallery) || !property.gallery[0];
    return `<img class="${fallback ? 'fallback-logo' : ''}" src="${escapeHtml(source)}" alt="${escapeHtml(property.label)}" loading="lazy">`;
}

function cardMarkup(property, context) {
    const mine = context === 'mine';
    const available = property.available !== false;
    const statusLabel = available ? 'Disponível' : 'Ocupado';
    const actions = mine
        ? `<button class="secondary-button" data-action="waypoint" data-id="${property.id}" type="button">GPS</button>
           ${property.accessRole === 'owner' ? `<button class="primary-button" data-action="access" data-id="${property.id}" type="button">Chaves</button>` : ''}`
        : `<button class="secondary-button" data-action="details" data-context="catalog" data-id="${property.id}" type="button">Detalhes</button>`;

    return `<article class="property-card">
        <div class="property-image">
            ${imageMarkup(property)}
            <div class="card-badges">
                <span class="type-badge">${escapeHtml(propertyType(property))}</span>
                ${property.vipTier ? `<span class="vip-badge">VIP ${escapeHtml(String(property.vipTier).toUpperCase())}</span>` : `<span class="status-badge ${available ? 'available' : 'unavailable'}">${statusLabel}</span>`}
            </div>
        </div>
        <div class="property-card-body">
            <h3>${escapeHtml(property.label)}</h3>
            <p>${escapeHtml(property.description || 'Imóvel cadastrado na rede Obscuria.')}</p>
            <div class="property-card-footer">
                <div class="price-block"><span>${mine ? 'VÍNCULO' : 'VALOR'}</span><strong>${mine ? escapeHtml(String(property.acquisition || 'proprietário').toUpperCase()) : propertyPrice(property)}</strong></div>
                <div class="card-actions">${actions}</div>
            </div>
        </div>
    </article>`;
}

function renderCatalog() {
    const search = state.catalogSearch.trim().toLowerCase();
    const filtered = state.catalog.filter((property) => {
        const matchesType = state.filter === 'all' || property.type === state.filter;
        const haystack = `${property.label} ${property.description || ''} ${property.key}`.toLowerCase();
        return matchesType && (!search || haystack.includes(search));
    });
    document.getElementById('catalogGrid').innerHTML = filtered.map((property) => cardMarkup(property, 'catalog')).join('');
    document.getElementById('catalogEmpty').classList.toggle('is-hidden', filtered.length > 0);
}

function renderMine() {
    document.getElementById('mineGrid').innerHTML = state.mine.map((property) => cardMarkup(property, 'mine')).join('');
    document.getElementById('mineEmpty').classList.toggle('is-hidden', state.mine.length > 0);
    document.getElementById('mineSummary').textContent = `${state.mine.length} ${state.mine.length === 1 ? 'propriedade' : 'propriedades'}`;
}

function renderAdminList() {
    const search = state.adminSearch.trim().toLowerCase();
    const rows = state.admin.filter((property) => `${property.label} ${property.key}`.toLowerCase().includes(search));
    document.getElementById('adminList').innerHTML = rows.map((property) => `<button class="admin-row ${state.editor?.id === property.id ? 'is-active' : ''}" data-action="edit" data-id="${property.id}" type="button">
        <span class="admin-thumb">${imageMarkup(property)}</span>
        <span><strong>${escapeHtml(property.label)}</strong><span>${escapeHtml(property.key)}</span></span>
        <em>${property.ownerCount || 0} ${Number(property.ownerCount) === 1 ? 'dono' : 'donos'}</em>
    </button>`).join('');
}

function coordinateText(value) {
    if (!value || value.x == null) return 'Não definida';
    const base = `${Number(value.x).toFixed(2)}, ${Number(value.y).toFixed(2)}, ${Number(value.z).toFixed(2)}`;
    return value.h == null ? base : `${base}, ${Number(value.h).toFixed(2)}`;
}

function currentPreset() {
    return state.presets.find((preset) => preset.key === state.editor?.presetKey) || state.presets[0];
}

function ensureEditorInterior() {
    if (!state.editor) return;
    const preset = currentPreset();
    state.editor.interior ||= deepClone(preset?.interior || {});
}

function renderPointFields() {
    if (!state.editor) return;
    ensureEditorInterior();
    document.querySelectorAll('.point-row').forEach((row) => {
        const name = row.dataset.point;
        const value = name === 'entrance' ? state.editor.entrance : state.editor.interior?.[name];
        row.querySelector('span').textContent = coordinateText(value);
    });
}

function galleryRow(source, index) {
    return `<div class="gallery-row" data-index="${index}">
        <div class="gallery-preview">${source ? `<img src="${escapeHtml(source)}" alt="Prévia">` : ''}</div>
        <input type="text" maxlength="500" value="${escapeHtml(source)}" placeholder="images/foto.webp ou https://...">
        <button class="icon-button" data-action="remove-image" data-index="${index}" type="button" aria-label="Remover imagem">X</button>
    </div>`;
}

function renderGalleryEditor() {
    const editor = state.editor;
    if (!editor) return;
    editor.gallery = Array.isArray(editor.gallery) ? editor.gallery : [];
    document.getElementById('galleryEditor').innerHTML = editor.gallery.map(galleryRow).join('');
    document.getElementById('addImageButton').disabled = editor.gallery.length >= state.imageLimit;
}

function blankEditor() {
    const preset = state.presets[0];
    return {
        id: null,
        key: '',
        label: '',
        description: '',
        type: 'house',
        ownershipMode: 'unique',
        presetKey: preset?.key || '',
        entrance: null,
        interior: deepClone(preset?.interior || {}),
        price: 0,
        paymentAccount: 'bank',
        vipTier: '',
        purchasable: true,
        starter: false,
        listed: true,
        status: 'available',
        stashSlots: 30,
        stashWeight: 50000,
        gallery: []
    };
}

function fillEditor(property) {
    state.editor = property ? deepClone(property) : blankEditor();
    state.keyManuallyEdited = Boolean(property);
    const form = document.getElementById('propertyForm');
    const editor = state.editor;
    form.elements.label.value = editor.label || '';
    form.elements.key.value = editor.key || '';
    form.elements.description.value = editor.description || '';
    form.elements.type.value = editor.type || 'house';
    form.elements.ownershipMode.value = editor.ownershipMode || 'unique';
    form.elements.presetKey.value = editor.presetKey || state.presets[0]?.key || '';
    form.elements.price.value = Number(editor.price) || 0;
    form.elements.paymentAccount.value = editor.paymentAccount || 'bank';
    form.elements.vipTier.value = editor.vipTier || '';
    form.elements.listed.checked = editor.listed !== false;
    form.elements.purchasable.checked = !editor.vipTier && editor.purchasable !== false;
    form.elements.starter.checked = editor.starter === true;
    form.elements.enabled.checked = editor.status !== 'disabled';
    form.elements.stashSlots.value = Number(editor.stashSlots) || 30;
    form.elements.stashWeightKg.value = (Number(editor.stashWeight) || 50000) / 1000;
    document.getElementById('editorEyebrow').textContent = editor.id ? editor.key : 'NOVO CADASTRO';
    document.getElementById('editorTitle').textContent = editor.id ? editor.label : 'Criar imóvel';
    document.querySelectorAll('.edit-only').forEach((element) => element.classList.toggle('is-hidden', !editor.id));
    renderPointFields();
    renderGalleryEditor();
    renderAdminList();
}

function renderPresets() {
    const select = document.getElementById('presetSelect');
    select.innerHTML = state.presets.map((preset) => `<option value="${escapeHtml(preset.key)}">${escapeHtml(preset.label)}</option>`).join('');
}

function setView(view) {
    if (view === 'admin' && !state.isAdmin) view = 'catalog';
    state.activeView = view;
    document.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('is-active', tab.dataset.view === view));
    document.querySelectorAll('.view').forEach((element) => element.classList.remove('is-active'));
    document.getElementById(`${view}View`).classList.add('is-active');
    const subtitles = {
        catalog: 'Encontre um lugar para chamar de seu.',
        mine: 'Endereços, acessos e moradores em um só lugar.',
        admin: 'Cadastro e controle do patrimônio da cidade.'
    };
    document.getElementById('pageSubtitle').textContent = subtitles[view];
    if (view === 'admin' && !state.editor) fillEditor(null);
}

function hydrate(payload) {
    state.isAdmin = payload.isAdmin === true;
    state.catalog = Array.isArray(payload.catalog) ? payload.catalog : [];
    state.mine = Array.isArray(payload.mine) ? payload.mine : [];
    state.admin = Array.isArray(payload.admin) ? payload.admin : [];
    state.presets = Array.isArray(payload.presets) ? payload.presets : [];
    state.imageLimit = Number(payload.imageLimit) || 8;
    state.fallbackImage = payload.fallbackImage || '';
    document.getElementById('catalogCount').textContent = state.catalog.length;
    document.getElementById('mineCount').textContent = state.mine.length;
    document.querySelectorAll('.admin-only').forEach((element) => element.classList.toggle('is-hidden', !state.isAdmin));
    renderPresets();
    renderCatalog();
    renderMine();
    renderAdminList();
    if (state.isAdmin && !state.editor) fillEditor(null);
    setView(payload.mode || state.activeView);
}

async function refresh(preferredView = state.activeView) {
    if (previewMode) {
        hydrate({ ...demoPayload, mode: preferredView });
        return;
    }
    const result = await request('refresh', { mode: preferredView });
    if (resultOk(result)) hydrate(result);
}

function openModal(id) {
    document.getElementById(id).classList.remove('is-hidden');
}

function closeModal(id) {
    document.getElementById(id).classList.add('is-hidden');
    if (id === 'confirmModal') state.confirmAction = null;
}

function findProperty(id, context) {
    const list = context === 'mine' ? state.mine : context === 'admin' ? state.admin : state.catalog;
    return list.find((property) => Number(property.id) === Number(id));
}

function openDetails(property, context) {
    if (!property) return;
    state.selectedDetails = { property, context };
    document.getElementById('detailsType').textContent = `${propertyType(property)}${property.vipTier ? ` | VIP ${String(property.vipTier).toUpperCase()}` : ''}`;
    document.getElementById('detailsName').textContent = property.label;
    document.getElementById('detailsDescription').textContent = property.description || 'Imóvel cadastrado na rede Obscuria.';
    document.getElementById('detailsPrice').textContent = context === 'mine' ? String(property.acquisition || 'Proprietário') : propertyPrice(property);
    document.getElementById('detailsStash').textContent = `${property.stashSlots || 0} espaços | ${Math.round((property.stashWeight || 0) / 1000)} kg`;
    document.getElementById('detailsMode').textContent = property.ownershipMode === 'instanced' ? 'Individual' : 'Exclusivo';
    const status = document.getElementById('detailsStatus');
    status.textContent = property.available === false ? 'Ocupado' : 'Disponível';
    status.className = `status-badge ${property.available === false ? 'unavailable' : 'available'}`;

    const gallery = document.getElementById('detailsGallery');
    const images = Array.isArray(property.gallery) ? property.gallery : [];
    gallery.classList.toggle('single', images.length <= 1);
    gallery.innerHTML = images.length
        ? images.map((source) => `<img src="${escapeHtml(source)}" alt="${escapeHtml(property.label)}">`).join('')
        : '<div class="gallery-placeholder">IMOVEL SEM FOTOS</div>';

    const actions = [];
    actions.push(`<button class="secondary-button" data-action="waypoint" data-id="${property.id}" type="button">Marcar GPS</button>`);
    if (context === 'catalog') {
        if (property.purchasable && property.available !== false) actions.push(`<button class="primary-button" data-action="purchase" data-id="${property.id}" type="button">Comprar</button>`);
        else if (property.vipTier) actions.push('<button class="primary-button" type="button" disabled>Benefício VIP</button>');
    } else if (context === 'mine' && property.accessRole === 'owner') {
        actions.push(`<button class="primary-button" data-action="access" data-id="${property.id}" type="button">Gerenciar chaves</button>`);
    }
    document.getElementById('detailsActions').innerHTML = actions.join('');
    openModal('detailsModal');
}

function confirmDialog(title, copy, action) {
    document.getElementById('confirmTitle').textContent = title;
    document.getElementById('confirmCopy').textContent = copy;
    state.confirmAction = action;
    openModal('confirmModal');
}

async function purchase(property) {
    const result = await request('purchase', { propertyId: property.id });
    if (!resultOk(result, `${property.label} agora pertence a você.`)) return;
    closeModal('confirmModal');
    closeModal('detailsModal');
    await refresh('mine');
}

function editorPayload() {
    const form = document.getElementById('propertyForm');
    const editor = state.editor;
    return {
        id: editor.id,
        label: form.elements.label.value.trim(),
        key: form.elements.key.value.trim().toLowerCase(),
        description: form.elements.description.value.trim(),
        type: form.elements.type.value,
        ownershipMode: form.elements.ownershipMode.value,
        presetKey: form.elements.presetKey.value,
        price: Number(form.elements.price.value) || 0,
        paymentAccount: form.elements.paymentAccount.value,
        vipTier: form.elements.vipTier.value.trim(),
        listed: form.elements.listed.checked,
        purchasable: form.elements.purchasable.checked,
        starter: form.elements.starter.checked,
        status: form.elements.enabled.checked ? 'available' : 'disabled',
        stashSlots: Number(form.elements.stashSlots.value) || 30,
        stashWeight: Math.round((Number(form.elements.stashWeightKg.value) || 50) * 1000),
        entrance: editor.entrance,
        interior: editor.interior,
        gallery: editor.gallery.map((source) => source.trim()).filter(Boolean)
    };
}

async function saveEditor(event) {
    event.preventDefault();
    const result = await request('saveProperty', editorPayload());
    if (!resultOk(result, 'Imóvel salvo com sucesso.')) return;
    await refresh('admin');
    const saved = state.admin.find((property) => Number(property.id) === Number(result.property?.id));
    fillEditor(saved || result.property);
}

async function capturePoint(name) {
    const result = await post('capturePoint');
    if (result?.error === 'cancelled') return;
    if (!resultOk(result)) return;
    if (name === 'entrance') state.editor.entrance = result.coords;
    else {
        ensureEditorInterior();
        state.editor.interior[name] = result.coords;
        if (name === 'entry' && !state.editor.interior.exit) state.editor.interior.exit = deepClone(result.coords);
    }
    renderPointFields();
    toast('Posição capturada.', 'success');
}

function openGrant(property) {
    state.grantProperty = property;
    document.getElementById('grantPropertyName').textContent = property.label;
    document.getElementById('grantForm').reset();
    openModal('grantModal');
}

async function submitGrant(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const result = await request('grantProperty', {
        propertyId: state.grantProperty.id,
        citizenid: form.elements.citizenid.value.trim(),
        acquisition: form.elements.acquisition.value,
        durationDays: Number(form.elements.durationDays.value) || 0
    });
    if (!resultOk(result, 'Imóvel entregue com sucesso.')) return;
    closeModal('grantModal');
    await refresh('admin');
}

async function openAccess(property) {
    closeModal('detailsModal');
    state.accessProperty = property;
    document.getElementById('accessPropertyName').textContent = property.label;
    document.getElementById('accessList').innerHTML = '';
    openModal('accessModal');
    const result = await request('listAccess', { ownershipId: property.ownershipId });
    if (!resultOk(result)) return;
    renderAccess(result.access);
}

async function openOwners(property) {
    state.ownersProperty = property;
    document.getElementById('ownersPropertyName').textContent = property.label;
    document.getElementById('ownersList').innerHTML = '';
    openModal('ownersModal');
    const result = await request('listOwners', { propertyId: property.id });
    if (!resultOk(result)) return;
    renderOwners(result.owners || []);
}

function renderOwners(entries) {
    const list = document.getElementById('ownersList');
    list.innerHTML = entries.length ? entries.map((entry) => {
        const expiry = entry.expires_at
            ? new Date(Number(entry.expires_at) * 1000).toLocaleDateString('pt-BR')
            : 'Permanente';
        return `<div class="access-row">
            <div><strong>${escapeHtml(entry.name || entry.citizenid)}</strong><span>${escapeHtml(entry.citizenid)} | ${escapeHtml(entry.acquisition || 'admin')}</span></div>
            <span>${entry.active ? escapeHtml(expiry) : 'Expirado'}</span>
            ${entry.active ? `<button class="text-button" data-action="revoke-owner" data-citizenid="${escapeHtml(entry.citizenid)}" type="button">Revogar</button>` : '<span></span>'}
        </div>`;
    }).join('') : '<div class="empty-state"><strong>Sem proprietários</strong><span>Este imóvel está livre.</span></div>';
}

function renderAccess(entries) {
    const list = document.getElementById('accessList');
    list.innerHTML = entries.length ? entries.map((entry) => `<div class="access-row">
        <div><strong>${escapeHtml(entry.name || entry.citizenid)}</strong><span>${escapeHtml(entry.citizenid)}</span></div>
        <span>${entry.role === 'guest' ? 'Visitante' : 'Morador'}</span>
        <button class="text-button" data-action="revoke-access" data-access-id="${entry.id}" type="button">Remover</button>
    </div>`).join('') : '<div class="empty-state"><strong>Nenhuma chave adicional</strong><span>Somente o proprietário possui acesso.</span></div>';
}

async function submitAccess(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const result = await request('grantAccess', {
        ownershipId: state.accessProperty.ownershipId,
        citizenid: form.elements.citizenid.value.trim(),
        role: form.elements.role.value
    });
    if (!resultOk(result, 'Acesso atualizado.')) return;
    form.elements.citizenid.value = '';
    renderAccess(result.access || []);
}

async function revokeAccess(accessId) {
    const result = await request('revokeAccess', { accessId });
    if (!resultOk(result, 'Acesso removido.')) return;
    renderAccess(result.access || []);
}

async function closePanel() {
    document.querySelectorAll('.modal').forEach((modal) => modal.classList.add('is-hidden'));
    app.classList.add('is-hidden');
    if (!previewMode) await post('close');
}

document.getElementById('closeButton').addEventListener('click', closePanel);
document.getElementById('propertyForm').addEventListener('submit', saveEditor);
document.getElementById('grantForm').addEventListener('submit', submitGrant);
document.getElementById('accessForm').addEventListener('submit', submitAccess);

document.getElementById('catalogSearch').addEventListener('input', (event) => {
    state.catalogSearch = event.target.value;
    renderCatalog();
});

document.getElementById('adminSearch').addEventListener('input', (event) => {
    state.adminSearch = event.target.value;
    renderAdminList();
});

document.querySelectorAll('.tab').forEach((tab) => tab.addEventListener('click', () => setView(tab.dataset.view)));
document.querySelectorAll('.segmented button').forEach((button) => button.addEventListener('click', () => {
    document.querySelectorAll('.segmented button').forEach((item) => item.classList.remove('is-active'));
    button.classList.add('is-active');
    state.filter = button.dataset.filter;
    renderCatalog();
}));

document.getElementById('newPropertyButton').addEventListener('click', () => fillEditor(null));
document.getElementById('addImageButton').addEventListener('click', () => {
    if (state.editor.gallery.length >= state.imageLimit) return;
    state.editor.gallery.push('');
    renderGalleryEditor();
});

document.getElementById('presetSelect').addEventListener('change', (event) => {
    state.editor.presetKey = event.target.value;
    const preset = currentPreset();
    state.editor.interior = deepClone(preset?.interior || {});
    renderPointFields();
});

document.getElementById('propertyForm').elements.label.addEventListener('input', (event) => {
    if (state.keyManuallyEdited) return;
    const key = event.target.value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    document.getElementById('propertyForm').elements.key.value = key;
});
document.getElementById('propertyForm').elements.key.addEventListener('input', () => { state.keyManuallyEdited = true; });
document.getElementById('propertyForm').elements.vipTier.addEventListener('input', (event) => {
    if (event.target.value.trim()) document.getElementById('propertyForm').elements.purchasable.checked = false;
});

document.getElementById('galleryEditor').addEventListener('input', (event) => {
    const row = event.target.closest('.gallery-row');
    if (!row || event.target.tagName !== 'INPUT') return;
    const index = Number(row.dataset.index);
    state.editor.gallery[index] = event.target.value;
    const preview = row.querySelector('.gallery-preview');
    preview.innerHTML = event.target.value ? `<img src="${escapeHtml(event.target.value)}" alt="Prévia">` : '';
});

document.getElementById('pointFields').addEventListener('click', (event) => {
    const row = event.target.closest('.point-row');
    if (row && event.target.closest('button')) capturePoint(row.dataset.point);
});

document.getElementById('previewButton').addEventListener('click', () => {
    if (state.editor?.id) post('request', { action: 'preview', data: { propertyId: state.editor.id } });
});
document.getElementById('previewPresetButton').addEventListener('click', () => {
    const presetKey = document.getElementById('presetSelect').value;
    if (presetKey) post('request', { action: 'previewPreset', data: { presetKey } });
});
document.getElementById('ownersButton').addEventListener('click', () => { if (state.editor?.id) openOwners(state.editor); });
document.getElementById('grantButton').addEventListener('click', () => { if (state.editor?.id) openGrant(state.editor); });
document.getElementById('archiveButton').addEventListener('click', () => {
    if (!state.editor?.id) return;
    const property = state.editor;
    confirmDialog('Arquivar imóvel', `${property.label} deixará de aparecer e aceitar entradas.`, async () => {
        const result = await request('archiveProperty', { propertyId: property.id });
        if (!resultOk(result, 'Imóvel arquivado.')) return;
        closeModal('confirmModal');
        state.editor = null;
        await refresh('admin');
        fillEditor(null);
    });
});

document.getElementById('confirmButton').addEventListener('click', () => {
    const action = state.confirmAction;
    if (typeof action === 'function') action();
});

document.addEventListener('click', (event) => {
    const close = event.target.closest('[data-close-modal]');
    if (close) {
        closeModal(close.dataset.closeModal);
        return;
    }
    const button = event.target.closest('[data-action]');
    if (!button) return;
    const action = button.dataset.action;
    const id = Number(button.dataset.id);
    if (action === 'details') openDetails(findProperty(id, button.dataset.context), button.dataset.context);
    if (action === 'waypoint') {
        const property = findProperty(id, state.activeView === 'mine' ? 'mine' : 'catalog') || state.selectedDetails?.property;
        if (property?.entrance) request('waypoint', { entrance: property.entrance });
    }
    if (action === 'purchase') {
        const property = findProperty(id, 'catalog') || state.selectedDetails?.property;
        if (property) confirmDialog('Comprar imóvel', `Confirmar a compra de ${property.label} por ${propertyPrice(property)}?`, () => purchase(property));
    }
    if (action === 'access') {
        const property = findProperty(id, 'mine') || state.selectedDetails?.property;
        if (property) openAccess(property);
    }
    if (action === 'edit') fillEditor(findProperty(id, 'admin'));
    if (action === 'remove-image') {
        state.editor.gallery.splice(Number(button.dataset.index), 1);
        renderGalleryEditor();
    }
    if (action === 'revoke-access') revokeAccess(Number(button.dataset.accessId));
    if (action === 'revoke-owner') {
        const citizenid = button.dataset.citizenid;
        const property = state.ownersProperty;
        confirmDialog('Revogar propriedade', `Remover o acesso de ${citizenid} a ${property.label}?`, async () => {
            const result = await request('revokeProperty', { propertyId: property.id, citizenid, reason: 'admin_panel' });
            if (!resultOk(result, 'Propriedade revogada.')) return;
            closeModal('confirmModal');
            await refresh('admin');
            await openOwners(state.admin.find((item) => Number(item.id) === Number(property.id)) || property);
        });
    }
});

document.addEventListener('error', (event) => {
    if (event.target.tagName !== 'IMG') return;
    event.target.remove();
}, true);

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    const openModalElement = [...document.querySelectorAll('.modal:not(.is-hidden)')].pop();
    if (openModalElement) closeModal(openModalElement.id);
    else closePanel();
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'open') {
        hydrate(message.payload || {});
        app.classList.remove('is-hidden');
    }
    if (message.action === 'close') app.classList.add('is-hidden');
    if (message.action === 'capture') app.classList.toggle('is-capturing', message.active === true);
});

if (previewMode) {
    hydrate(demoPayload);
    app.classList.remove('is-hidden');
}
