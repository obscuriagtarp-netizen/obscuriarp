const app = document.getElementById('app');
const previewMode = new URLSearchParams(window.location.search).get('preview') === '1';

document.documentElement.style.setProperty('background', 'transparent', 'important');
document.body.style.setProperty('background', 'transparent', 'important');
app.hidden = true;
app.style.setProperty('display', 'none', 'important');
app.classList.remove('is-visible', 'is-transitioning');
app.setAttribute('aria-hidden', 'true');

const icons = {
    search: '<circle class="icon-tone" cx="10.5" cy="10.5" r="7.3"/><circle cx="10.5" cy="10.5" r="7.3"/><path d="m16 16 4.2 4.2"/>',
    star: '<path class="icon-tone" d="m12 2.8 2.8 5.7 6.3.9-4.6 4.5 1.1 6.3-5.6-3-5.6 3 1.1-6.3-4.6-4.5 6.3-.9L12 2.8Z"/><path d="m12 2.8 2.8 5.7 6.3.9-4.6 4.5 1.1 6.3-5.6-3-5.6 3 1.1-6.3-4.6-4.5 6.3-.9L12 2.8Z"/>',
    sparkles: '<path class="icon-tone" d="m12 2.5-1.6 4.2L6.2 8.3l4.2 1.6L12 14l1.6-4.1 4.2-1.6-4.2-1.6L12 2.5Z"/><path d="m12 2.5-1.6 4.2L6.2 8.3l4.2 1.6L12 14l1.6-4.1 4.2-1.6-4.2-1.6L12 2.5Z"/><path d="m5.1 14.2-.8 2.1-2.1.8 2.1.8.8 2.1.8-2.1 2.1-.8-2.1-.8-.8-2.1Zm13.2.5-.6 1.6-1.6.6 1.6.6.6 1.6.6-1.6 1.6-.6-1.6-.6-.6-1.6Z"/>',
    package: '<path class="icon-tone" d="m3.4 7.3 8.6 4.4 8.6-4.4V17L12 21.3 3.4 17V7.3Z"/><path d="m3.4 7.3 8.6-4.4 8.6 4.4-8.6 4.4-8.6-4.4Zm0 0V17l8.6 4.3 8.6-4.3V7.3M12 11.7v9.6M7.8 5.1l8.6 4.4"/>',
    coffee: '<path class="icon-tone" d="M4.3 8.2h12.2v6.7a4.8 4.8 0 0 1-4.8 4.8H9.1a4.8 4.8 0 0 1-4.8-4.8V8.2Z"/><path d="M4.3 8.2h12.2v6.7a4.8 4.8 0 0 1-4.8 4.8H9.1a4.8 4.8 0 0 1-4.8-4.8V8.2Zm12.2 2.1h1.6a3 3 0 0 1 0 6h-1.8M8 3.4c-.8.9-.8 1.8 0 2.7m4-3.5c-.8 1.1-.8 2.2 0 3.3"/>',
    music: '<path class="icon-tone" d="M9.2 6.2 20 3.7v11.5a3.6 3.6 0 1 1-2-3.2V7.7L9.2 9.8v7a3.6 3.6 0 1 1-2-3.2V6.7l2-.5Z"/><path d="M9.2 16.8V6.2L20 3.7v11.5M9.2 9.8 20 7.3M9.2 16.8a3.6 3.6 0 1 1-3.6-3.6 3.6 3.6 0 0 1 3.6 3.6ZM20 15.2a3.6 3.6 0 1 1-3.6-3.6 3.6 3.6 0 0 1 3.6 3.6Z"/>',
    users: '<path class="icon-tone" d="M3 20v-1.6c0-2.6 2.4-4.7 5.4-4.7h2.2c3 0 5.4 2.1 5.4 4.7V20H3Z"/><path d="M3 20v-1.6c0-2.6 2.4-4.7 5.4-4.7h2.2c3 0 5.4 2.1 5.4 4.7V20M9.5 11.2a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm7-5.9a3.3 3.3 0 0 1 0 6.3m1 2.6c2.1.8 3.5 2.4 3.5 4.2V20"/>',
    paw: '<path class="icon-tone" d="M7.4 21c-2.1 0-3.6-1.3-3.2-3.2.6-2.8 4.5-5.2 7.8-5.2s7.2 2.4 7.8 5.2c.4 1.9-1.1 3.2-3.2 3.2-1.8 0-2.8-.9-4.6-.9s-2.8.9-4.6.9Z"/><ellipse cx="6.2" cy="7.8" rx="2.2" ry="2.8"/><ellipse cx="17.8" cy="7.8" rx="2.2" ry="2.8"/><ellipse cx="2.9" cy="13" rx="1.9" ry="2.5"/><ellipse cx="21.1" cy="13" rx="1.9" ry="2.5"/><path d="M7.4 21c-2.1 0-3.6-1.3-3.2-3.2.6-2.8 4.5-5.2 7.8-5.2s7.2 2.4 7.8 5.2c.4 1.9-1.1 3.2-3.2 3.2-1.8 0-2.8-.9-4.6-.9s-2.8.9-4.6.9Z"/>',
    footprints: '<path class="icon-tone" d="M7.4 2.8c2.3 0 3.8 2.6 3.5 5.2-.3 2.7-2 4.3-4 4-2-.2-3.1-2.1-2.7-4.7.3-2.5 1.2-4.5 3.2-4.5Zm9.2 9.1c2.3 0 3.8 2.6 3.5 5.2-.3 2.7-2 4.3-4 4-2-.2-3.1-2.1-2.7-4.7.3-2.5 1.2-4.5 3.2-4.5Z"/><path d="M7.4 2.8c2.3 0 3.8 2.6 3.5 5.2-.3 2.7-2 4.3-4 4-2-.2-3.1-2.1-2.7-4.7.3-2.5 1.2-4.5 3.2-4.5Zm9.2 9.1c2.3 0 3.8 2.6 3.5 5.2-.3 2.7-2 4.3-4 4-2-.2-3.1-2.1-2.7-4.7.3-2.5 1.2-4.5 3.2-4.5Z"/>',
    clapperboard: '<path class="icon-tone" d="M3.5 9.3h17v11h-17z"/><path d="M3.5 9.3h17v11h-17zM4.4 3.7l15.1-1.2 1 4.4L4.3 8.2l.1-4.5Zm4.8-.4L6.8 7.9m7.3-5-2.4 4.6m7.2-5-2.4 4.6"/>',
    smile: '<circle class="icon-tone" cx="12" cy="12" r="9.2"/><circle cx="12" cy="12" r="9.2"/><path d="M8.1 14.2c.9 1.5 2.2 2.2 3.9 2.2s3-.7 3.9-2.2M8.7 9.2h.1m6.4 0h.1"/>',
    x: '<path d="m7.2 7.2 9.6 9.6m0-9.6-9.6 9.6"/>',
    back: '<path d="m14.8 18-6-6 6-6"/>',
    stop: '<rect class="icon-tone" x="6.5" y="6.5" width="11" height="11" rx="2"/><rect x="6.5" y="6.5" width="11" height="11" rx="2"/>',
    empty: '<rect class="icon-tone" x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M8 9.5 16 15m0-5.5L8 15M3.5 4.5h17v15h-17z"/>'
};

const icon = (name, className = '') => `<svg class="icon ${className}" viewBox="0 0 24 24" aria-hidden="true">${icons[name] || icons.sparkles}</svg>`;

const state = {
    categories: [],
    favorites: {},
    activeCategory: null,
    view: 'radial',
    query: '',
    searchOpen: false,
    visibleLimit: 80,
    transitioning: false
};

const previewCategories = [
    ['general_emotes', 'Animações', 'sparkles', 'Animações, poses e movimentos do cotidiano.'],
    ['prop_emotes', 'Objetos', 'package', 'Animações que utilizam objetos e adereços.'],
    ['consumable_emotes', 'Consumo', 'coffee', 'Comidas, bebidas e pequenos objetos.'],
    ['dance_emotes', 'Danças', 'music', 'Passos, ritmos e coreografias.'],
    ['synchronized_emotes', 'Em dupla', 'users', 'Animações sincronizadas com outra pessoa.'],
    ['synchronized_dance_emotes', 'Dança em dupla', 'users', 'Coreografias sincronizadas com outra pessoa.'],
    ['animal_emotes', 'Animais', 'paw', 'Movimentos exclusivos para formas animais.'],
    ['walks', 'Caminhadas', 'footprints', 'Escolha a postura e o ritmo dos seus passos.'],
    ['scenarios', 'Cenários', 'clapperboard', 'Ações completas integradas ao ambiente.'],
    ['expressions', 'Expressões', 'smile', 'Humor e expressões faciais persistentes.']
].map((category, categoryIndex) => ({
    id: category[0],
    label: category[1],
    icon: category[2],
    description: category[3],
    items: Array.from({ length: 18 }, (_, itemIndex) => ({
        id: `${category[0]}:demo${itemIndex + 1}`,
        kind: category[0] === 'walks' ? 'walk' : category[0] === 'expressions' ? 'expression' : 'emote',
        category: category[0],
        command: ['saudacao', 'encostar', 'celebrar', 'observar', 'sentar', 'reverencia'][itemIndex % 6] + (itemIndex + 1),
        label: ['Saudacao discreta', 'Encostar na parede', 'Celebracao', 'Observar o horizonte', 'Sentar com calma', 'Reverencia'][itemIndex % 6],
        group: itemIndex % 7 === 0
    }))
}));

function nuiPost(eventName, data = {}) {
    if (previewMode || typeof GetParentResourceName !== 'function') {
        return Promise.resolve({ ok: true, favorites: state.favorites });
    }

    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json());
}

function favoriteItems() {
    const items = [];
    for (const category of state.categories) {
        for (const item of category.items || []) {
            if (state.favorites[item.id]) items.push(item);
        }
    }
    return items;
}

function allCategories() {
    return [{
        id: 'favorites',
        label: 'Favoritos',
        description: 'Sua coleção pessoal de animações.',
        icon: 'star',
        items: favoriteItems()
    }, ...state.categories];
}

function allItems() {
    const items = [];
    for (const category of state.categories) {
        for (const item of category.items || []) items.push(item);
    }
    return items;
}

function normalizeSearch(value) {
    return String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLocaleLowerCase('pt-BR')
        .trim();
}

function editDistance(left, right) {
    const rows = Array.from({ length: right.length + 1 }, (_, index) => index);
    for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
        let diagonal = rows[0];
        rows[0] = leftIndex;
        for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
            const previous = rows[rightIndex];
            rows[rightIndex] = Math.min(
                rows[rightIndex] + 1,
                rows[rightIndex - 1] + 1,
                diagonal + (left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1)
            );
            diagonal = previous;
        }
    }
    return rows[right.length];
}

function matchesSearch(item, rawQuery) {
    const query = normalizeSearch(rawQuery);
    if (!query) return true;

    const target = normalizeSearch(`${item.label} ${item.command}`);
    if (target.includes(query)) return true;

    const words = target.split(/\s+/).filter(Boolean);
    return query.split(/\s+/).every((token) => words.some((word) => {
        if (word.startsWith(token) || token.startsWith(word)) return true;
        const tolerance = token.length >= 7 ? 2 : token.length >= 4 ? 1 : 0;
        return tolerance > 0 && editDistance(token, word) <= tolerance;
    }));
}

function radialPoint(radius, angle) {
    const radians = angle * (Math.PI / 180);
    return {
        x: 50 + Math.cos(radians) * radius,
        y: 50 + Math.sin(radians) * radius
    };
}

function radialSegment(startAngle, endAngle, innerRadius = 8, outerRadius = 47) {
    const outerStart = radialPoint(outerRadius, startAngle);
    const outerEnd = radialPoint(outerRadius, endAngle);
    const innerEnd = radialPoint(innerRadius, endAngle);
    const innerStart = radialPoint(innerRadius, startAngle);
    const largeArc = endAngle - startAngle > 180 ? 1 : 0;

    return [
        `M ${outerStart.x.toFixed(3)} ${outerStart.y.toFixed(3)}`,
        `A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${outerEnd.x.toFixed(3)} ${outerEnd.y.toFixed(3)}`,
        `L ${innerEnd.x.toFixed(3)} ${innerEnd.y.toFixed(3)}`,
        `A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${innerStart.x.toFixed(3)} ${innerStart.y.toFixed(3)}`,
        'Z'
    ].join(' ');
}

function radialMarkup() {
    const categories = allCategories();
    const step = 360 / categories.length;
    const gap = Math.min(1.5, step * 0.055);
    const labelRadius = categories.length > 9 ? 33.4 : 32.8;
    const sectors = categories.map((category, index) => {
        const start = -90 + (step * index) + gap;
        const end = -90 + (step * (index + 1)) - gap;
        return `<path class="sector-path" d="${radialSegment(start, end)}"
            data-category="${escapeAttribute(category.id)}" role="button" tabindex="0"
            style="--delay:${index * 32}ms" aria-label="Abrir ${escapeAttribute(category.label)}"></path>`;
    }).join('');
    const labels = categories.map((category, index) => {
        const point = radialPoint(labelRadius, -90 + (step * index) + (step / 2));
        return `
            <div class="category-node" style="--node-x:${point.x}%;--node-y:${point.y}%;--delay:${index * 32}ms">
                ${icon(category.icon)}
                <span>${escapeHtml(category.label)}</span>
                <em>${category.items.length} ${category.items.length === 1 ? 'opção' : 'opções'}</em>
            </div>`;
    }).join('');

    return `
        <section class="radial-view ${categories.length > 9 ? 'is-dense' : ''}" aria-label="Menu de animacoes">
            <svg class="radial-wheel" viewBox="0 0 100 100" aria-label="Categorias de animação">
                <circle class="wheel-frame" cx="50" cy="50" r="48.3"></circle>
                ${sectors}
                <circle class="wheel-core" cx="50" cy="50" r="7.1"></circle>
            </svg>
            ${labels}
            <form class="radial-search-shell ${state.searchOpen ? 'is-open' : ''}" data-radial-search>
                <button class="search-core" type="button" data-action="search-toggle" aria-label="Pesquisar animação" aria-expanded="${state.searchOpen}">
                    ${icon('search')}
                </button>
                <input id="radial-search-input" type="text" autocomplete="off" value="${escapeAttribute(state.query)}"
                    placeholder="Digite uma animação..." aria-label="Pesquisar animação">
                <span class="search-enter">Enter</span>
            </form>
        </section>`;
}

function currentCategory() {
    if (state.activeCategory === 'search') {
        return {
            id: 'search',
            label: 'Resultados',
            description: `Animações relacionadas a “${state.query}”.`,
            icon: 'search',
            items: allItems()
        };
    }
    return allCategories().find((category) => category.id === state.activeCategory) || allCategories()[0];
}

function filteredItems(category) {
    if (!state.query.trim()) return category.items;
    return category.items.filter((item) => matchesSearch(item, state.query));
}

function categoryForItem(item) {
    return state.categories.find((category) => category.id === item.category || (category.items || []).some((candidate) => candidate.id === item.id));
}

function catalogMarkup(animate = true) {
    const category = currentCategory();
    const items = filteredItems(category);
    const visibleItems = items.slice(0, state.visibleLimit);
    const cards = visibleItems.map((item, index) => {
        const sourceCategory = categoryForItem(item);
        const categoryTag = category.id === 'search' && sourceCategory
            ? `<em class="category-tag">${escapeHtml(sourceCategory.label)}</em>`
            : '';
        return `
        <div class="emote-card" role="button" tabindex="0" data-play="${escapeAttribute(item.id)}" style="--card-delay:${Math.min(index, 28) * 12}ms">
            <span class="emote-mark">${icon(sourceCategory?.icon || (category.icon === 'star' || category.icon === 'search' ? 'sparkles' : category.icon))}</span>
            <span class="emote-copy">
                <strong>${escapeHtml(item.label)}</strong>
                <span>/${escapeHtml(item.command)}</span>
                <span class="emote-tags">${categoryTag}${item.group ? '<em>Em dupla</em>' : ''}</span>
            </span>
            <button class="favorite-button ${state.favorites[item.id] ? 'is-active' : ''}" type="button" data-favorite="${escapeAttribute(item.id)}"
                aria-label="${state.favorites[item.id] ? 'Remover dos favoritos' : 'Favoritar'}" aria-pressed="${Boolean(state.favorites[item.id])}">
                ${icon('star')}
            </button>
        </div>`;
    }).join('');
    const hasMore = visibleItems.length < items.length;

    return `
        <section class="catalog-view ${animate ? '' : 'is-static-update'}" aria-label="${escapeAttribute(category.label)}">
            <header class="catalog-topbar">
                <button class="back-button" type="button" data-action="back" aria-label="Voltar">${icon('back')}</button>
                <div class="catalog-identity">
                    <span class="catalog-icon">${icon(category.icon)}</span>
                    <div>
                        <small>Coleção de animações</small>
                        <h1>${escapeHtml(category.label)}</h1>
                        <p>${escapeHtml(category.description)}</p>
                    </div>
                </div>
                <span class="catalog-count">
                    <strong>${items.length}</strong>
                    <small>${items.length === 1 ? 'animação' : 'animações'}</small>
                </span>
            </header>
            <div class="search-strip">
                <label class="search-field">
                    ${icon('search')}
                    <input id="emote-search" type="text" autocomplete="off" value="${escapeAttribute(state.query)}" placeholder="Pesquisar por nome ou comando">
                </label>
                <span class="collection-context">
                    <i></i>
                    ${category.id === 'search' ? 'Todas as coleções' : escapeHtml(category.label)}
                </span>
            </div>
            <div class="emote-scroll">
                ${cards ? `<div class="emote-grid">${cards}</div>${hasMore ? `<button class="load-more" type="button" data-action="more">Exibir mais ${Math.min(80, items.length - visibleItems.length)} animações</button>` : ''}` : emptyMarkup(category)}
            </div>
        </section>`;
}

function emptyMarkup(category) {
    const isFavorites = category.id === 'favorites' && !state.query;
    return `
        <div class="empty-state">
            <div>
                ${icon(isFavorites ? 'star' : 'empty')}
                <h2>${isFavorites ? 'Sua coleção está vazia' : 'Nenhuma animação encontrada'}</h2>
                <p>${isFavorites ? 'Marque a estrela de qualquer animação para encontrá-la aqui.' : 'Tente outro nome ou pesquise pelo comando da animação.'}</p>
            </div>
        </div>`;
}

function render(animate = true) {
    app.innerHTML = state.view === 'radial' ? radialMarkup() : catalogMarkup(animate);
    app.classList.toggle('is-transitioning', state.transitioning);
    bindEvents();
}

function bindEvents() {
    app.querySelectorAll('[data-category]').forEach((sector) => {
        const open = () => openCategory(sector.dataset.category);
        sector.addEventListener('click', open);
        sector.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                open();
            }
        });
    });

    app.querySelector('[data-action="search-toggle"]')?.addEventListener('click', () => {
        state.searchOpen = true;
        const searchShell = app.querySelector('.radial-search-shell');
        const searchToggle = app.querySelector('[data-action="search-toggle"]');
        const searchInput = app.querySelector('#radial-search-input');

        searchShell?.classList.add('is-open');
        searchToggle?.setAttribute('aria-expanded', 'true');
        searchInput?.focus();
    });
    app.querySelector('[data-radial-search]')?.addEventListener('submit', (event) => {
        event.preventDefault();
        runRadialSearch();
    });
    const radialSearch = app.querySelector('#radial-search-input');
    radialSearch?.addEventListener('input', () => {
        state.query = radialSearch.value;
    });
    radialSearch?.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            state.query = radialSearch.value;
            runRadialSearch();
        }
    });
    app.querySelector('[data-action="back"]')?.addEventListener('click', backToRadial);
    app.querySelector('[data-action="more"]')?.addEventListener('click', () => {
        const scroll = app.querySelector('.emote-scroll');
        const scrollTop = scroll?.scrollTop || 0;
        state.visibleLimit += 80;
        render();
        const nextScroll = app.querySelector('.emote-scroll');
        if (nextScroll) nextScroll.scrollTop = scrollTop;
    });

    app.querySelectorAll('[data-play]').forEach((card) => {
        const play = (event) => {
            if (event.target.closest('[data-favorite]')) return;
            const item = allItems().find((candidate) => candidate.id === card.dataset.play);
            if (item) nuiPost('play', item);
        };
        card.addEventListener('click', play);
        card.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                play(event);
            }
        });
    });

    app.querySelectorAll('[data-favorite]').forEach((button) => {
        const toggle = (event) => {
            event.preventDefault();
            event.stopPropagation();
            toggleFavorite(button.dataset.favorite);
        };
        button.addEventListener('click', toggle);
        button.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') toggle(event);
        });
    });

    const search = app.querySelector('#emote-search');
    if (search) {
        search.addEventListener('input', () => {
            const { selectionStart, selectionEnd, selectionDirection } = search;
            state.query = search.value;
            state.visibleLimit = 80;
            render(false);
            const next = app.querySelector('#emote-search');
            next?.focus();
            next?.setSelectionRange(selectionStart, selectionEnd, selectionDirection);
        });
    }
}

function runRadialSearch() {
    const query = state.query.trim();
    if (!query) {
        app.querySelector('#radial-search-input')?.focus();
        return;
    }

    const matchingCategories = state.categories.filter((category) => (category.items || []).some((item) => matchesSearch(item, query)));
    const destination = matchingCategories.length === 1 ? matchingCategories[0].id : 'search';
    openCategory(destination, false, query);
}

function closeRadialSearch() {
    state.searchOpen = false;
    state.query = '';

    app.querySelector('.radial-search-shell')?.classList.remove('is-open');
    app.querySelector('[data-action="search-toggle"]')?.setAttribute('aria-expanded', 'false');

    const searchInput = app.querySelector('#radial-search-input');
    if (searchInput) {
        searchInput.value = '';
        searchInput.blur();
    }
}

function openCategory(categoryId, focusSearch = false, initialQuery = '') {
    if (state.transitioning) return;
    state.transitioning = true;
    render();

    window.setTimeout(() => {
        state.activeCategory = categoryId;
        state.view = 'catalog';
        state.query = initialQuery;
        state.searchOpen = false;
        state.visibleLimit = 80;
        state.transitioning = false;
        render();
        if (focusSearch) app.querySelector('#emote-search')?.focus();
    }, 680);
}

function backToRadial() {
    state.view = 'radial';
    state.activeCategory = null;
    state.query = '';
    state.searchOpen = false;
    state.visibleLimit = 80;
    state.transitioning = false;
    render();
}

function toggleFavorite(id) {
    state.favorites[id] = !state.favorites[id];
    if (!state.favorites[id]) delete state.favorites[id];
    updateFavoriteView(id);

    nuiPost('toggleFavorite', { id }).then((response) => {
        if (response?.favorites) {
            state.favorites = response.favorites;
            updateFavoriteView(id);
        }
    });
}

function updateFavoriteView(id) {
    if (state.view === 'catalog' && state.activeCategory === 'favorites') {
        const scrollTop = app.querySelector('.emote-scroll')?.scrollTop || 0;
        render(false);
        const scroll = app.querySelector('.emote-scroll');
        if (scroll) scroll.scrollTop = scrollTop;
        return;
    }

    app.querySelectorAll('[data-favorite]').forEach((button) => {
        if (button.dataset.favorite !== id) return;
        const active = Boolean(state.favorites[id]);
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-pressed', String(active));
        button.setAttribute('aria-label', active ? 'Remover dos favoritos' : 'Favoritar');
    });
}

function openMenu(payload) {
    state.categories = Array.isArray(payload.categories) ? payload.categories : [];
    state.favorites = payload.favorites || {};
    state.activeCategory = null;
    state.query = '';
    state.searchOpen = false;
    state.visibleLimit = 80;
    state.view = 'radial';
    state.transitioning = false;
    app.hidden = false;
    app.style.removeProperty('display');
    app.classList.add('is-visible');
    app.setAttribute('aria-hidden', 'false');
    render();
}

function hideMenu() {
    app.classList.remove('is-visible', 'is-transitioning');
    app.hidden = true;
    app.style.setProperty('display', 'none', 'important');
    app.setAttribute('aria-hidden', 'true');
    app.replaceChildren();
    state.transitioning = false;
    state.searchOpen = false;
}

function closeMenu() {
    hideMenu();
    nuiPost('close');
}

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[character]);
}

function escapeAttribute(value) {
    return escapeHtml(value);
}

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    if (payload.action === 'open') openMenu(payload);
    if (payload.action === 'update') {
        state.categories = Array.isArray(payload.categories) ? payload.categories : state.categories;
        state.favorites = payload.favorites || state.favorites;
        render();
    }
    if (payload.action === 'close') {
        hideMenu();
    }
});

window.addEventListener('keydown', (event) => {
    if (!app.classList.contains('is-visible')) return;
    if (event.key === 'Escape') {
        event.preventDefault();
        if (state.view === 'radial' && state.searchOpen) {
            closeRadialSearch();
        } else if (state.view === 'catalog') backToRadial();
        else closeMenu();
    }
    if (event.key === 'Backspace' && state.view === 'catalog' && document.activeElement?.tagName !== 'INPUT') {
        event.preventDefault();
        backToRadial();
    }
});

document.addEventListener('contextmenu', (event) => event.preventDefault());

if (previewMode) {
    document.body.classList.add('preview');
    openMenu({ categories: previewCategories, favorites: { 'general_emotes:demo1': true } });
} else {
    hideMenu();
    nuiPost('ready');
}
