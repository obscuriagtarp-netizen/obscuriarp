const app = document.querySelector('#app');
const identityContent = document.querySelector('#identityContent');
const characterSlots = document.querySelector('#characterSlots');
const slotLabel = document.querySelector('#slotLabel');
const statusLabel = document.querySelector('#statusLabel');
const slotCount = document.querySelector('#slotCount');
const playButton = document.querySelector('#playButton');
const deleteButton = document.querySelector('#deleteButton');
const modalLayer = document.querySelector('#modalLayer');
const createModal = document.querySelector('#createModal');
const deleteModal = document.querySelector('#deleteModal');
const createForm = document.querySelector('#createForm');
const createSlot = document.querySelector('#createSlot');
const birthdate = document.querySelector('#birthdate');
const nationality = document.querySelector('#nationality');
const nationalitySelect = document.querySelector('#nationalitySelect');
const nationalityTrigger = document.querySelector('#nationalityTrigger');
const nationalityValue = document.querySelector('#nationalityValue');
const nationalityMenu = document.querySelector('#nationalityMenu');
const formError = document.querySelector('#formError');
const deleteConfirmName = document.querySelector('#deleteConfirmName');
const deleteConfirmInput = document.querySelector('#deleteConfirmInput');
const confirmDeleteButton = document.querySelector('#confirmDeleteButton');
const loading = document.querySelector('#loading');
const loadingLabel = document.querySelector('#loadingLabel');
const toast = document.querySelector('#toast');

const previewParams = new URLSearchParams(window.location.search);
const previewMode = previewParams.has('preview');
const previewLoading = previewParams.get('loading') === '1';
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ob_multichar';
const classFallback = { id: 'indefinida', label: 'Não definida', icon: 'assets/classes/indefinida.png', accent: '#9d96a7' };
const money = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });

const state = {
    visible: false,
    characters: [],
    amount: 0,
    selectedSlot: null,
    deleteEnabled: true,
    deleteTarget: null,
    bootstrapStartedAt: 0,
};

const minimumBootstrapDuration = 900;
let loadingHideTimer;

function showLoading(label, bootstrap = false) {
    window.clearTimeout(loadingHideTimer);
    if (bootstrap) {
        state.bootstrapStartedAt = performance.now();
        app.classList.add('is-booting');
    }
    loadingLabel.textContent = label || 'Aguarde...';
    loading.classList.remove('is-hidden');
}

function hideLoading() {
    window.clearTimeout(loadingHideTimer);
    const elapsed = performance.now() - state.bootstrapStartedAt;
    const delay = app.classList.contains('is-booting')
        ? Math.max(0, minimumBootstrapDuration - elapsed)
        : 0;

    loadingHideTimer = window.setTimeout(() => {
        loading.classList.add('is-hidden');
        app.classList.remove('is-booting');
        state.bootstrapStartedAt = 0;
    }, delay);
}

async function post(eventName, payload = {}) {
    if (previewMode) return { ok: true };
    try {
        const response = await fetch(`https://${resourceName}/${eventName}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload),
        });
        return await response.json();
    } catch (_) {
        return { ok: false };
    }
}

let focusClaimPending = false;

async function claimFocus() {
    if (!state.visible || previewMode || focusClaimPending) return;
    focusClaimPending = true;
    window.focus();
    await post('claimFocus');
    focusClaimPending = false;
}

function selectedCharacter() {
    return state.characters.find((character) => character.slot === state.selectedSlot) || null;
}

function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function appendDetail(grid, label, value) {
    const item = element('div', 'detail');
    item.append(element('span', '', label), element('strong', '', value));
    grid.append(item);
}

function setNationalityOptions(options, defaultValue = 'Brasileira') {
    const values = Array.isArray(options)
        ? options.map((value) => String(value).trim()).filter(Boolean)
        : [];

    if (!values.includes(defaultValue)) values.unshift(defaultValue);
    nationalityMenu.replaceChildren(...values.map((value) => {
        const option = element('button', 'nationality-select__option', value);
        option.type = 'button';
        option.setAttribute('role', 'option');
        option.dataset.value = value;
        option.addEventListener('click', () => {
            selectNationality(value);
            closeNationalityMenu();
            nationalityTrigger.focus();
        });
        return option;
    }));
    selectNationality(defaultValue);
}

function selectNationality(value) {
    nationality.value = value;
    nationalityValue.textContent = value;
    nationalityMenu.querySelectorAll('.nationality-select__option').forEach((option) => {
        const selected = option.dataset.value === value;
        option.classList.toggle('is-selected', selected);
        option.setAttribute('aria-selected', String(selected));
    });
}

function closeNationalityMenu() {
    nationalitySelect.classList.remove('is-open');
    nationalityMenu.classList.add('is-hidden');
    nationalityTrigger.setAttribute('aria-expanded', 'false');
}

function toggleNationalityMenu() {
    const willOpen = !nationalitySelect.classList.contains('is-open');
    nationalitySelect.classList.toggle('is-open', willOpen);
    nationalityMenu.classList.toggle('is-hidden', !willOpen);
    nationalityTrigger.setAttribute('aria-expanded', String(willOpen));
}

function calculateAge(birthdateValue) {
    const match = String(birthdateValue || '').match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!match) return 'Não informada';

    const [, yearValue, monthValue, dayValue] = match;
    const year = Number(yearValue);
    const month = Number(monthValue);
    const day = Number(dayValue);
    const today = new Date();

    let age = today.getFullYear() - year;
    const birthdayPassed = today.getMonth() + 1 > month
        || (today.getMonth() + 1 === month && today.getDate() >= day);

    if (!birthdayPassed) age -= 1;
    return age >= 0 ? `${age} ${age === 1 ? 'ano' : 'anos'}` : 'Não informada';
}

function maskBirthdate(value) {
    const digits = String(value || '').replace(/\D/g, '').slice(0, 8);
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) return `${digits.slice(0, 2)}/${digits.slice(2)}`;
    return `${digits.slice(0, 2)}/${digits.slice(2, 4)}/${digits.slice(4)}`;
}

function brazilianDateToIso(value) {
    const match = String(value || '').match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (!match) return null;

    const day = Number(match[1]);
    const month = Number(match[2]);
    const year = Number(match[3]);
    const date = new Date(year, month - 1, day);

    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
        return null;
    }

    return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function renderIdentity() {
    const character = selectedCharacter();
    const empty = !character || character.empty;
    slotLabel.textContent = `Registro ${String(state.selectedSlot || 1).padStart(2, '0')}`;
    statusLabel.textContent = empty ? 'Novo destino' : 'Disponível';
    identityContent.replaceChildren();

    if (empty) {
        const wrapper = element('div', 'empty-identity');
        const content = element('div');
        const mark = element('div', 'empty-identity__mark');
        mark.append(element('span', '', '+'));
        content.append(mark, element('h2', '', 'Registro vazio'), element('p', '', 'Crie um personagem para iniciar uma nova história em Obscuria.'));
        wrapper.append(content);
        identityContent.append(wrapper);
        playButton.textContent = 'Criar personagem';
        deleteButton.classList.add('is-hidden');
        return;
    }

    const title = element('h2', 'identity-name', `${character.firstname} ${character.lastname}`);
    const citizen = element('div', 'identity-citizen', `Cidadão ${character.citizenid}`);
    const classInfo = character.class || classFallback;
    const classRow = element('div', 'class-inline');
    const classImage = element('img');
    classImage.src = classInfo.icon;
    classImage.alt = '';
    const classCopy = element('div');
    classCopy.append(element('small', '', 'Classe vinculada'), element('strong', '', classInfo.label));
    classRow.append(classImage, classCopy);

    const grid = element('div', 'detail-grid');
    appendDetail(grid, 'Idade', calculateAge(character.birthdate));
    appendDetail(grid, 'Nacionalidade', character.nationality);
    appendDetail(grid, 'Profissão', character.job);
    appendDetail(grid, 'Cargo', character.grade);
    appendDetail(grid, 'Banco', money.format(character.bank));
    appendDetail(grid, 'Dinheiro', money.format(character.cash));
    appendDetail(grid, 'Telefone', character.phone);
    appendDetail(grid, 'Vínculo', character.gang === 'Nenhum' ? 'Sem vínculo' : character.gang);

    identityContent.append(title, citizen, classRow, grid);
    playButton.textContent = 'Entrar na cidade';
    deleteButton.classList.toggle('is-hidden', !state.deleteEnabled);
}

function chooseSlot(character) {
    state.selectedSlot = character.slot;
    renderAll();
    if (character.empty) {
        post('previewNew', { slot: character.slot, gender: 0 });
    } else {
        post('selectCharacter', { slot: character.slot, citizenid: character.citizenid, gender: character.gender });
    }
}

function renderSlots() {
    characterSlots.replaceChildren();
    const filled = state.characters.filter((character) => !character.empty).length;
    slotCount.textContent = `${filled} ${filled === 1 ? 'personagem' : 'personagens'}`;

    state.characters.forEach((character) => {
        const card = element('button', `character-card${character.empty ? ' character-card--empty' : ''}${character.slot === state.selectedSlot ? ' is-selected' : ''}`);
        card.type = 'button';
        card.style.setProperty('--card-accent', character.class?.accent || classFallback.accent);
        card.addEventListener('click', () => chooseSlot(character));

        if (character.empty) {
            card.append(element('span', 'character-card__plus', '+'));
            const copy = element('span', 'character-card__copy');
            copy.append(element('small', '', `Registro ${String(character.slot).padStart(2, '0')}`), element('strong', '', 'Novo personagem'), element('span', '', 'Iniciar uma história'));
            card.append(copy);
        } else {
            const icon = element('img');
            icon.src = character.class?.icon || classFallback.icon;
            icon.alt = '';
            const copy = element('span', 'character-card__copy');
            copy.append(
                element('small', '', character.class?.label || classFallback.label),
                element('strong', '', `${character.firstname} ${character.lastname}`),
                element('span', '', `${character.job} · ${character.grade}`),
            );
            card.append(icon, copy);
        }
        characterSlots.append(card);
    });
}

function renderAll() {
    renderIdentity();
    renderSlots();
}

function openModal(modal) {
    modalLayer.classList.remove('is-hidden');
    modalLayer.setAttribute('aria-hidden', 'false');
    [createModal, deleteModal].forEach((item) => item.classList.toggle('is-hidden', item !== modal));
}

function closeModals() {
    closeNationalityMenu();
    modalLayer.classList.add('is-hidden');
    modalLayer.setAttribute('aria-hidden', 'true');
    createModal.classList.add('is-hidden');
    deleteModal.classList.add('is-hidden');
    formError.textContent = '';
    deleteConfirmInput.value = '';
    confirmDeleteButton.disabled = true;
}

function openCreate() {
    const character = selectedCharacter();
    if (!character?.empty) return;
    createForm.reset();
    selectNationality(createForm.dataset.defaultNationality || 'Brasileira');
    createSlot.value = character.slot;
    formError.textContent = '';
    openModal(createModal);
    window.setTimeout(() => createForm.elements.firstname.focus(), 80);
}

function openDelete() {
    const character = selectedCharacter();
    if (!character || character.empty) return;
    state.deleteTarget = character;
    const fullName = `${character.firstname} ${character.lastname}`;
    deleteConfirmName.textContent = fullName;
    deleteConfirmInput.value = '';
    confirmDeleteButton.disabled = true;
    openModal(deleteModal);
    window.setTimeout(() => deleteConfirmInput.focus(), 80);
}

function showToast(message) {
    toast.textContent = message;
    toast.classList.remove('is-hidden');
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => toast.classList.add('is-hidden'), 3400);
}

playButton.addEventListener('click', () => {
    const character = selectedCharacter();
    if (!character || character.empty) return openCreate();
    post('playCharacter', { citizenid: character.citizenid });
});

deleteButton.addEventListener('click', openDelete);
document.querySelectorAll('[data-close-modal]').forEach((button) => button.addEventListener('click', closeModals));
nationalityTrigger.addEventListener('click', toggleNationalityMenu);
document.addEventListener('click', (event) => {
    if (!nationalitySelect.contains(event.target)) closeNationalityMenu();
});
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeNationalityMenu();
});

Array.from(createForm.elements.gender).forEach((radio) => {
    radio.addEventListener('change', () => post('previewNew', { slot: Number(createSlot.value), gender: Number(radio.value) }));
});

birthdate.addEventListener('input', () => {
    birthdate.value = maskBirthdate(birthdate.value);
});

createForm.addEventListener('submit', (event) => {
    event.preventDefault();
    formError.textContent = '';
    const data = Object.fromEntries(new FormData(createForm));
    const isoBirthdate = brazilianDateToIso(data.birthdate);

    if (!isoBirthdate || (birthdate.dataset.min && isoBirthdate < birthdate.dataset.min) || (birthdate.dataset.max && isoBirthdate > birthdate.dataset.max)) {
        formError.textContent = 'Informe uma data válida no formato DD/MM/AAAA.';
        birthdate.focus();
        return;
    }

    data.slot = Number(data.slot);
    data.gender = Number(data.gender);
    data.birthdate = isoBirthdate;
    post('createCharacter', data);
});

deleteConfirmInput.addEventListener('input', () => {
    const expected = deleteConfirmName.textContent.trim().toLocaleLowerCase('pt-BR');
    confirmDeleteButton.disabled = deleteConfirmInput.value.trim().toLocaleLowerCase('pt-BR') !== expected;
});

confirmDeleteButton.addEventListener('click', () => {
    if (confirmDeleteButton.disabled || !state.deleteTarget) return;
    const citizenid = state.deleteTarget.citizenid;
    closeModals();
    post('deleteCharacter', { citizenid });
});

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data.action !== 'string') return;
    const payload = data.data || {};

    if (data.action === 'bootstrap') {
        state.visible = true;
        app.classList.remove('is-hidden');
        app.setAttribute('aria-hidden', 'false');
        showLoading(payload.label || 'Preparando seus registros...', true);
        window.requestAnimationFrame(claimFocus);
    }

    if (data.action === 'visible') {
        state.visible = payload.visible === true;
        app.classList.toggle('is-hidden', !state.visible);
        app.setAttribute('aria-hidden', String(!state.visible));
        if (!state.visible) {
            app.classList.remove('is-booting');
            closeModals();
        } else {
            window.requestAnimationFrame(claimFocus);
        }
    }

    if (data.action === 'open') {
        state.characters = Array.isArray(payload.characters) ? payload.characters : [];
        state.amount = Number(payload.amount) || state.characters.length;
        state.selectedSlot = Number(payload.selectedSlot) || state.characters[0]?.slot || 1;
        state.deleteEnabled = payload.deleteEnabled !== false;
        birthdate.dataset.min = payload.dateMin || '';
        birthdate.dataset.max = payload.dateMax || '';
        createForm.dataset.defaultNationality = payload.defaultNationality || 'Brasileira';
        setNationalityOptions(payload.nationalities, createForm.dataset.defaultNationality);
        renderAll();
        post('uiAck');
    }

    if (data.action === 'busy') {
        if (payload.active === true) {
            showLoading(payload.label || 'Aguarde...');
        } else {
            hideLoading();
        }
    }

    if (data.action === 'formError') {
        formError.textContent = payload.message || 'Revise os dados informados.';
        if (createModal.classList.contains('is-hidden')) openModal(createModal);
    }

    if (data.action === 'error') showToast(payload.message || 'Não foi possível concluir a ação.');
});

if (previewMode) {
    setNationalityOptions([
        'Brasileira', 'Argentina', 'Chilena', 'Colombiana', 'Mexicana',
        'Norte-americana', 'Canadense', 'Portuguesa', 'Espanhola', 'Francesa',
        'Italiana', 'Alemã', 'Britânica', 'Irlandesa', 'Angolana', 'Moçambicana',
        'Japonesa', 'Chinesa', 'Sul-coreana', 'Russa', 'Ucraniana',
    ]);
    state.characters = [
        { slot: 1, empty: false, citizenid: 'OBS10482', firstname: 'Morgana', lastname: 'Vale', gender: 1, birthdate: '1997-10-31', nationality: 'Brasileira', phone: '555-0148', bank: 147830, cash: 820, job: 'Ravenwood Café', grade: 'Gerente', gang: 'Nenhum', class: { id: 'bruxa', label: 'Bruxa', icon: 'assets/classes/bruxa.png', accent: '#9f79d7' } },
        { slot: 2, empty: false, citizenid: 'OBS20911', firstname: 'Lucien', lastname: 'Ravenwood', gender: 0, birthdate: '1894-02-17', nationality: 'Britânica', phone: '555-0217', bank: 88200, cash: 320, job: 'Empresário', grade: 'Sócio', gang: 'Nenhum', class: { id: 'vampiro', label: 'Vampiro', icon: 'assets/classes/vampiro.png', accent: '#b85d68' } },
        { slot: 3, empty: true },
        { slot: 4, empty: true },
    ];
    state.amount = state.characters.length;
    state.selectedSlot = 1;
    state.visible = true;
    app.classList.remove('is-hidden');
    if (previewLoading) {
        showLoading('Preparando seus registros...', true);
    } else {
        renderAll();
    }
} else {
    post('ready');
}

window.addEventListener('pageshow', claimFocus);
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) claimFocus();
});
