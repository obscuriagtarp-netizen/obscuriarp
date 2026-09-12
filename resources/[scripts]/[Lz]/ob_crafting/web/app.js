const elements = {
    app: document.querySelector('#app'),
    shell: document.querySelector('#craftShell'),
    close: document.querySelector('#closeButton'),
    catalog: document.querySelector('#catalogView'),
    compact: document.querySelector('#compactView'),
    stationName: document.querySelector('#stationName'),
    kindEyebrow: document.querySelector('#kindEyebrow'),
    kindDescription: document.querySelector('#kindDescription'),
    search: document.querySelector('#searchInput'),
    recipeList: document.querySelector('#recipeList'),
    recipeCount: document.querySelector('#recipeCount'),
    recipeCategory: document.querySelector('#recipeCategory'),
    recipeName: document.querySelector('#recipeName'),
    recipeTime: document.querySelector('#recipeTime'),
    quantityDecrease: document.querySelector('#quantityDecrease'),
    quantityIncrease: document.querySelector('#quantityIncrease'),
    quantityValue: document.querySelector('#quantityValue'),
    recipeDescription: document.querySelector('#recipeDescription'),
    outputImage: document.querySelector('#outputImage'),
    outputFallback: document.querySelector('#outputFallback'),
    outputAmount: document.querySelector('#outputAmount'),
    outputLabel: document.querySelector('#outputLabel'),
    processTrack: document.querySelector('#processTrack'),
    processCount: document.querySelector('#processCount'),
    ingredientList: document.querySelector('#ingredientList'),
    summaryTime: document.querySelector('#summaryTime'),
    summaryYield: document.querySelector('#summaryYield'),
    prepare: document.querySelector('#prepareButton'),
    availability: document.querySelector('#availabilityMessage'),
    compactImage: document.querySelector('#compactImage'),
    compactFallback: document.querySelector('#compactFallback'),
    compactName: document.querySelector('#compactName'),
    compactStep: document.querySelector('#compactStep'),
    compactBar: document.querySelector('#compactBar'),
    compactTimer: document.querySelector('#compactTimer'),
    toast: document.querySelector('#toast')
};

const state = {
    visible: false,
    payload: null,
    selectedId: null,
    quantity: 1,
    search: '',
    crafting: false,
    progressTimer: null,
    toastTimer: null
};

const imageAliases = {
    hamburguer: 'burger.png',
    carne: 'burger.png',
    pao: 'sandwich.png',
    salad: 'sandwich.png',
    batata: 'fries.png',
    batata_frita: 'fries.png',
    refrigerante: 'cola.png',
    xarope: 'cola.png',
    combo_box: 'pizza_ham_box.png',
    WEAPON_PISTOL: 'weapon_pistol.png',
    pistol_ammo: 'pistol_ammo.png',
    steel: 'steel.png',
    aluminum: 'aluminum.png',
    rubber: 'rubber.png',
    acetone: 'acetone.png',
    meth_baggy: 'meth_baggy.png',
    water: 'water.png'
};

const errors = {
    station_not_found: 'Esta bancada não está disponível.',
    access_denied: 'Você não possui acesso a esta bancada.',
    too_far: 'Você se afastou da bancada.',
    missing_ingredient: 'Faltam ingredientes para esta receita.',
    inventory_full: 'Não há espaço suficiente no inventário.',
    inventory_changed: 'Os ingredientes mudaram durante o preparo.',
    already_crafting: 'Já existe uma produção em andamento.',
    craft_not_found: 'A produção não pôde ser confirmada.',
    interrupted: 'O preparo foi interrompido.',
    provider_unavailable: 'O cadastro de receitas está indisponível.',
    server_error: 'Não foi possível concluir a produção.'
};

const browserPreview = typeof window.GetParentResourceName !== 'function';

const operationDefinitions = {
    prep: { label: 'Organizar ingredientes', description: 'Separe os ingredientes na ordem do preparo.', animation: 'assembly' },
    chop: { label: 'Cortar ingredientes', description: 'Fatie os ingredientes na sequência indicada.', animation: 'cutting' },
    portion: { label: 'Porcionar', description: 'Divida o preparo em porções uniformes.', animation: 'assembly' },
    knead: { label: 'Trabalhar a massa', description: 'Pressione e dobre a massa até atingir elasticidade.', animation: 'assembly' },
    shape: { label: 'Modelar', description: 'Modele cada porção aplicando pressão uniforme.', animation: 'assembly' },
    grill: { label: 'Grelhar', description: 'Controle a chapa e retire no ponto certo.', animation: 'stove' },
    fry: { label: 'Fritar', description: 'Mantenha o óleo dentro da temperatura ideal.', animation: 'stove' },
    bake: { label: 'Assar', description: 'Controle o calor até finalizar o cozimento.', animation: 'stove' },
    boil: { label: 'Cozinhar', description: 'Mantenha o preparo em temperatura constante.', animation: 'stove' },
    melt: { label: 'Derreter', description: 'Aplique calor gradualmente sem queimar o preparo.', animation: 'stove' },
    pour: { label: 'Dosar líquidos', description: 'Sirva a quantidade exata da receita.', animation: 'drinks' },
    mix: { label: 'Misturar', description: 'Misture continuamente até atingir o ponto.', animation: 'drinks' },
    whisk: { label: 'Bater', description: 'Incorpore ar com movimentos circulares constantes.', animation: 'drinks' },
    sauce: { label: 'Adicionar molho', description: 'Dose o molho sem ultrapassar a medida da receita.', animation: 'drinks' },
    season: { label: 'Temperar', description: 'Acerte o ponto para distribuir o tempero por igual.', animation: 'assembly' },
    assemble: { label: 'Montar', description: 'Organize os componentes na ordem correta.', animation: 'assembly' },
    plate: { label: 'Empratar', description: 'Disponha os componentes do prato na ordem correta.', animation: 'assembly' },
    decorate: { label: 'Decorar', description: 'Finalize a apresentação no momento de precisão.', animation: 'assembly' },
    chill: { label: 'Resfriar', description: 'Interrompa o resfriamento quando atingir o ponto.', animation: 'assembly' },
    package: { label: 'Embalar', description: 'Finalize e lacre o produto para entrega.', animation: 'assembly' },
    measure: { label: 'Medir componentes', description: 'Separe a quantidade exata indicada na receita.', animation: 'drinks' },
    dose: { label: 'Dosar reagentes', description: 'Dose cada reagente sem exceder o limite.', animation: 'narcotics' },
    synthesize: { label: 'Sintetizar', description: 'Misture os reagentes até estabilizar a reação.', animation: 'narcotics' },
    heat: { label: 'Aquecer composto', description: 'Aqueça o composto dentro da faixa segura.', animation: 'narcotics' },
    stabilize: { label: 'Estabilizar', description: 'Confirme a reação no instante correto.', animation: 'narcotics' },
    calibrate: { label: 'Calibrar', description: 'Ajuste o mecanismo dentro da zona de precisão.', animation: 'weapons' },
    weld: { label: 'Soldar', description: 'Controle o calor da união sem danificar a peça.', animation: 'weapons' },
    seal: { label: 'Selar', description: 'Finalize o conjunto no ponto indicado.', animation: 'weapons' },
    refine: { label: 'Refinar', description: 'Processe o material até alcançar consistência.', animation: 'utility' }
};

const kitchenProfiles = {
    meal: ['prep', 'chop', 'grill', 'season', 'plate'],
    fried: ['prep', 'chop', 'fry', 'season', 'package'],
    pasta: ['prep', 'measure', 'knead', 'portion', 'boil', 'sauce', 'plate'],
    sweets: ['prep', 'measure', 'mix', 'shape', 'bake', 'decorate'],
    bakery: ['prep', 'measure', 'knead', 'shape', 'bake', 'chill'],
    drinks: ['measure', 'pour', 'mix', 'decorate'],
    cold: ['prep', 'chop', 'mix', 'plate'],
    combo: ['prep', 'assemble', 'package'],
    default: ['prep', 'chop', 'grill', 'assemble']
};

const kitchenCategoryProfiles = {
    meals: 'meal', pratos: 'meal', lanches: 'meal', sandwiches: 'meal',
    fried: 'fried', frituras: 'fried', porções: 'fried', porcoes: 'fried',
    pasta: 'pasta', massas: 'pasta', macarrão: 'pasta', macarrao: 'pasta',
    sweets: 'sweets', desserts: 'sweets', sobremesas: 'sweets', doces: 'sweets',
    bakery: 'bakery', padaria: 'bakery', pães: 'bakery', paes: 'bakery',
    drinks: 'drinks', bebidas: 'drinks',
    salads: 'cold', saladas: 'cold', frios: 'cold',
    combos: 'combo', kits: 'combo'
};

function resourceName() {
    return window.GetParentResourceName?.() || 'ob_crafting';
}

async function post(action, data = {}) {
    if (browserPreview) {
        if (action === 'beginCraft') {
            const recipe = selectedRecipe();
            const quantity = Math.max(1, Math.floor(Number(data.quantity) || 1));
            const response = { ok: true, token: 'browser-preview', duration: adjustedDuration(recipe, quantity), quantity, recipe, animation: {} };
            window.setTimeout(() => handleMessage({ action: 'craftStarted', payload: response }), 50);
            return response;
        }
        return { ok: true };
    }
    try {
        const response = await fetch(`https://${resourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch {
        return { ok: false, error: 'server_error' };
    }
}

function itemImage(item, image) {
    if (image && /^(https?:|data:|nui:|\.\/|\.\.\/)/i.test(image)) return image;
    const filename = image || imageAliases[item] || `${String(item || '').toLowerCase()}.png`;
    return `assets/items/${filename}`;
}

function setImage(imageElement, fallbackElement, item, image, label) {
    imageElement.hidden = false;
    fallbackElement.hidden = true;
    imageElement.alt = label || '';
    imageElement.src = itemImage(item, image);
    imageElement.onerror = () => {
        imageElement.hidden = true;
        fallbackElement.hidden = false;
        fallbackElement.textContent = String(label || item || 'OB').slice(0, 2).toUpperCase();
    };
}

function selectedRecipe() {
    return state.payload?.recipes?.find((recipe) => String(recipe.id) === String(state.selectedId)) || null;
}

function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
}

function filteredRecipes() {
    const query = state.search.trim().toLocaleLowerCase('pt-BR');
    if (!query) return state.payload?.recipes || [];
    return (state.payload?.recipes || []).filter((recipe) => `${recipe.name} ${recipe.description}`.toLocaleLowerCase('pt-BR').includes(query));
}

function renderRecipeList() {
    const recipes = filteredRecipes();
    elements.recipeList.replaceChildren();
    elements.recipeCount.textContent = `${recipes.length} ${recipes.length === 1 ? 'receita' : 'receitas'}`;

    recipes.forEach((recipe) => {
        const button = node('button', `recipe-card${String(recipe.id) === String(state.selectedId) ? ' active' : ''}${recipe.available === false ? ' unavailable' : ''}`);
        button.type = 'button';
        button.dataset.recipeId = recipe.id;
        const visual = node('span', 'recipe-card__image');
        const image = node('img');
        const fallback = node('span', 'recipe-card__fallback', 'OB');
        fallback.hidden = true;
        visual.append(image, fallback);
        setImage(image, fallback, recipe.output?.item, recipe.image, recipe.name);
        const copy = node('span', 'recipe-card__copy');
        copy.append(node('strong', '', recipe.name), node('span', '', `${recipeDuration(recipe)}s · ${recipe.output?.amount || 1}×`));
        button.append(visual, copy, node('b', '', '›'));
        button.addEventListener('click', () => selectRecipe(recipe.id));
        elements.recipeList.append(button);
    });

    if (!recipes.length) elements.recipeList.append(node('p', 'empty-copy', 'Nenhuma receita encontrada.'));
}

function recipeSteps(recipe) {
    const configured = Array.isArray(recipe?.steps) && recipe.steps.length
        ? recipe.steps
        : Array.isArray(recipe?.craftSteps) && recipe.craftSteps.length
            ? recipe.craftSteps
            : Array.isArray(recipe?.craft_steps) && recipe.craft_steps.length
                ? recipe.craft_steps
                : null;

    let source = configured;
    if (!source) {
        const category = String(recipe?.category || '').toLowerCase();
        const requestedProfile = String(recipe?.craftProfile || recipe?.craft_profile || '').toLowerCase();
        const profile = requestedProfile || kitchenCategoryProfiles[category] || 'default';
        source = kitchenProfiles[profile] || kitchenProfiles.default;
    }

    return source.slice(0, 8).map((entry) => {
        if (typeof entry === 'object' && entry) {
            const base = operationDefinitions[entry.key] || operationDefinitions.package;
            return { ...base, ...entry, key: entry.key || 'package' };
        }
        const key = String(entry);
        return { ...(operationDefinitions[key] || operationDefinitions.package), key };
    });
}

function recipeDuration(recipe) {
    const steps = recipe ? recipeSteps(recipe) : [];
    return Math.max(1, Number(recipe?.duration) || 1, steps.length * 2);
}

function quantityLimit(recipe) {
    const configured = Math.max(1, Math.floor(Number(state.payload?.quantity?.max) || 20));
    const ingredientLimit = recipe?.ingredients?.length
        ? Math.min(...recipe.ingredients.map((ingredient) => Math.floor(Number(ingredient.count || 0) / Math.max(1, Number(ingredient.amount || 1)))))
        : configured;
    const available = Number.isFinite(Number(recipe?.maxQuantity))
        ? Math.max(0, Math.floor(Number(recipe.maxQuantity)))
        : Math.max(0, ingredientLimit);
    return Math.min(configured, available);
}

function adjustedDuration(recipe, quantity = state.quantity) {
    const base = recipeDuration(recipe);
    const increase = Math.max(0, Number(state.payload?.quantity?.timeIncreasePercent) || 0.12);
    const maximum = Math.max(base, Number(state.payload?.quantity?.maxDuration) || 120);
    return Math.min(maximum, Math.ceil(base * (1 + Math.max(0, quantity - 1) * increase)));
}

function renderProcess(recipe) {
    const steps = recipe ? recipeSteps(recipe) : [];
    elements.processTrack.replaceChildren();
    elements.processCount.textContent = `${steps.length} ${steps.length === 1 ? 'etapa' : 'etapas'}`;
    steps.forEach((operation, index) => {
        const step = node('div', 'process-step');
        step.append(node('b', '', String(index + 1).padStart(2, '0')), node('span', '', operation.label));
        elements.processTrack.append(step);
    });
    if (!steps.length) elements.processTrack.append(node('p', 'empty-copy', 'Selecione uma receita.'));
}

function renderIngredients(recipe, quantity = state.quantity) {
    elements.ingredientList.replaceChildren();
    (recipe?.ingredients || []).forEach((ingredient) => {
        const required = Number(ingredient.amount || 0) * quantity;
        const enough = Number(ingredient.count || 0) >= required;
        const row = node('div', `ingredient-row${enough ? '' : ' missing'}`);
        const image = node('img', 'ingredient-row__image');
        const fallback = node('span', 'ingredient-row__fallback', '·');
        fallback.hidden = true;
        setImage(image, fallback, ingredient.item, ingredient.image, ingredient.label);
        const copy = node('div');
        copy.append(node('strong', '', ingredient.label), node('span', '', `Necessário: ${required}`));
        row.append(image, copy, node('b', '', `${ingredient.count || 0} / ${required}`));
        elements.ingredientList.append(row);
    });
    if (!recipe?.ingredients?.length) elements.ingredientList.append(node('p', 'empty-copy', 'Esta receita não exige ingredientes.'));
}

function renderSelected() {
    const recipe = selectedRecipe();
    const kind = state.payload?.kind || {};
    renderProcess(recipe);
    if (!recipe) {
        elements.recipeName.textContent = 'Selecione uma receita';
        elements.recipeDescription.textContent = 'Escolha uma receita para consultar os ingredientes e iniciar o preparo.';
        elements.prepare.disabled = true;
        elements.availability.textContent = 'Selecione uma receita.';
        state.quantity = 1;
        elements.quantityValue.textContent = '1';
        elements.quantityDecrease.disabled = true;
        elements.quantityIncrease.disabled = true;
        renderIngredients(null);
        return;
    }

    const maxQuantity = quantityLimit(recipe);
    state.quantity = Math.max(1, Math.min(state.quantity, Math.max(1, maxQuantity)));
    const quantity = state.quantity;
    const outputAmount = Number(recipe.output?.amount || 1) * quantity;
    const duration = adjustedDuration(recipe, quantity);
    elements.recipeCategory.textContent = recipe.category || kind.label || 'Receita selecionada';
    elements.recipeName.textContent = recipe.name;
    elements.recipeTime.textContent = `${duration}s`;
    elements.quantityValue.textContent = String(quantity);
    elements.quantityDecrease.disabled = quantity <= 1 || state.crafting;
    elements.quantityIncrease.disabled = quantity >= maxQuantity || state.crafting;
    elements.recipeDescription.textContent = recipe.description || 'Produção artesanal.';
    elements.outputAmount.textContent = `${outputAmount}×`;
    elements.outputLabel.textContent = recipe.output?.label || recipe.name;
    elements.summaryTime.textContent = `${duration} segundos`;
    elements.summaryYield.textContent = `${outputAmount} ${outputAmount === 1 ? 'unidade' : 'unidades'}`;
    setImage(elements.outputImage, elements.outputFallback, recipe.output?.item, recipe.image, recipe.name);
    renderIngredients(recipe, quantity);
    const available = recipe.available !== false && maxQuantity >= quantity;
    elements.prepare.disabled = !available || state.crafting;
    elements.availability.textContent = available
        ? `${quantity} ${quantity === 1 ? 'lote selecionado' : 'lotes selecionados'}. Bancada pronta.`
        : 'Confira os ingredientes e o espaço no inventário.';
}

function selectRecipe(recipeId) {
    state.selectedId = recipeId;
    state.quantity = 1;
    renderRecipeList();
    renderSelected();
    sound('select');
}

function renderPayload(payload, keepSelection = false) {
    state.payload = payload;
    const kind = payload.kind || {};
    elements.shell.dataset.kind = payload.station?.kind || 'utility';
    document.documentElement.style.setProperty('--accent', kind.accent || '#a77ad4');
    elements.stationName.textContent = payload.restaurant?.label ? `${payload.restaurant.label} · ${payload.station?.label || 'Bancada'}` : payload.station?.label || 'Bancada de produção';
    elements.kindEyebrow.textContent = kind.eyebrow || kind.label || 'Produção';
    elements.kindDescription.textContent = kind.description || 'Produção especializada.';
    if (!keepSelection || !(payload.recipes || []).some((recipe) => String(recipe.id) === String(state.selectedId))) state.selectedId = payload.recipes?.[0]?.id ?? null;
    renderRecipeList();
    renderSelected();
}

function open(payload) {
    state.visible = true;
    state.crafting = false;
    state.quantity = 1;
    elements.app.classList.remove('is-hidden');
    elements.shell.classList.remove('is-compact');
    elements.catalog.classList.remove('is-hidden');
    elements.compact.classList.add('is-hidden');
    renderPayload(payload);
}

function close() {
    state.visible = false;
    elements.app.classList.add('is-hidden');
    post('close');
}

let audioContext;
function sound(type) {
    try {
        audioContext ||= new AudioContext();
        const oscillator = audioContext.createOscillator();
        const gain = audioContext.createGain();
        const now = audioContext.currentTime;
        oscillator.type = type === 'miss' ? 'sawtooth' : 'sine';
        oscillator.frequency.setValueAtTime(type === 'success' ? 620 : type === 'miss' ? 150 : 320, now);
        if (type === 'success') oscillator.frequency.exponentialRampToValueAtTime(940, now + .1);
        gain.gain.setValueAtTime(type === 'miss' ? .055 : .035, now);
        gain.gain.exponentialRampToValueAtTime(.001, now + .13);
        oscillator.connect(gain).connect(audioContext.destination);
        oscillator.start(now);
        oscillator.stop(now + .14);
    } catch {}
}

function showToast(message, type = 'success') {
    window.clearTimeout(state.toastTimer);
    elements.toast.textContent = message;
    elements.toast.className = `toast visible${type === 'error' ? ' error' : ''}`;
    state.toastTimer = window.setTimeout(() => { elements.toast.className = 'toast'; }, 2600);
}

async function startCraft() {
    const recipe = selectedRecipe();
    if (!recipe || recipe.available === false || state.crafting) return;
    state.crafting = true;
    elements.prepare.disabled = true;
    sound('select');
    const response = await post('beginCraft', { recipeId: recipe.id, quantity: state.quantity });
    if (!response?.ok) {
        state.crafting = false;
        renderSelected();
        showToast(errors[response?.error] || 'Não foi possível iniciar o preparo.', 'error');
    }
}

function startCompact(payload) {
    state.crafting = true;
    const recipe = payload.recipe || selectedRecipe();
    const quantity = Math.max(1, Number(payload.quantity) || state.quantity || 1);
    const steps = recipeSteps(recipe);
    elements.shell.classList.add('is-compact');
    elements.compact.classList.remove('is-hidden');
    elements.compactName.textContent = recipe?.name || 'Produção';
    elements.compactStep.textContent = steps[0]?.label || 'Preparando produção';
    setImage(elements.compactImage, elements.compactFallback, recipe?.output?.item, recipe?.image, recipe?.name);
    const duration = Math.max(adjustedDuration(recipe, quantity), Number(payload.duration) || 1);
    const startedAt = performance.now();
    window.clearInterval(state.progressTimer);
    const update = () => {
        const elapsed = (performance.now() - startedAt) / 1000;
        const percent = Math.min(100, elapsed / duration * 100);
        const stepIndex = steps.length ? Math.min(steps.length - 1, Math.floor(elapsed / (duration / steps.length))) : 0;
        elements.compactBar.style.width = `${percent}%`;
        elements.compactStep.textContent = steps[stepIndex]?.label || 'Preparando produção';
        elements.compactTimer.textContent = `${Math.max(0, Math.ceil(duration - elapsed))}s restantes`;
        if (percent >= 100) window.clearInterval(state.progressTimer);
    };
    update();
    state.progressTimer = window.setInterval(update, 100);
    if (browserPreview) window.setTimeout(() => handleMessage({ action: 'craftComplete', payload: { ok: true, label: recipe?.output?.label || recipe?.name, amount: (recipe?.output?.amount || 1) * quantity } }), duration * 1000 + 150);
}

function completeCraft(payload) {
    state.crafting = false;
    window.clearInterval(state.progressTimer);
    elements.shell.classList.remove('is-compact');
    elements.compact.classList.add('is-hidden');
    elements.catalog.classList.remove('is-hidden');
    renderSelected();
    if (payload?.ok) showToast(`${payload.amount || 1}× ${payload.label || 'Produção concluída'}`);
    else showToast(errors[payload?.error] || 'A produção foi interrompida.', 'error');
}

function handleMessage(message) {
    const action = message?.action;
    if (action === 'open') open(message.payload);
    if (action === 'close') elements.app.classList.add('is-hidden');
    if (action === 'refresh') renderPayload(message.payload, true);
    if (action === 'feedback') showToast(errors[message.payload?.error] || 'Não foi possível atualizar a bancada.', 'error');
    if (action === 'craftStarted') startCompact(message.payload);
    if (action === 'craftComplete') completeCraft(message.payload);
}

elements.close.addEventListener('click', () => { if (!state.crafting) close(); });
elements.search.addEventListener('input', (event) => { state.search = event.target.value; renderRecipeList(); });
elements.quantityDecrease.addEventListener('click', () => { state.quantity = Math.max(1, state.quantity - 1); renderSelected(); sound('select'); });
elements.quantityIncrease.addEventListener('click', () => { state.quantity = Math.min(quantityLimit(selectedRecipe()), state.quantity + 1); renderSelected(); sound('select'); });
elements.prepare.addEventListener('click', startCraft);
window.addEventListener('message', (event) => handleMessage(event.data));
window.addEventListener('keydown', (event) => {
    if (!state.visible) return;
    if (event.key === 'Escape' && !state.crafting) close();
});

const previewPayloads = {
    kitchen: {
        ok: true,
        preview: true,
        station: { id: 'preview_kitchen', label: 'Bancada Ravenwood', kind: 'kitchen' },
        kind: { label: 'Cozinha', eyebrow: 'Mise en place', description: 'Prepare cada receita com calma e organização.', accent: '#d49a62' },
        recipes: [
            { id: 'burger', name: 'Hambúrguer Ravenwood', category: 'Pratos', description: 'Pão tostado, carne selada e salada fresca.', image: 'burger.png', duration: 8, difficulty: .58, available: true, craftSteps: ['chop', 'grill', 'assemble'], output: { item: 'hamburguer', label: 'Hambúrguer Ravenwood', amount: 1 }, ingredients: [{ item: 'pao', label: 'Pão artesanal', amount: 1, count: 4 }, { item: 'carne', label: 'Carne preparada', amount: 1, count: 3 }, { item: 'salad', label: 'Salada fresca', amount: 1, count: 5 }] },
            { id: 'fries', name: 'Batatas da Casa', category: 'Pratos', description: 'Porção cortada e finalizada na temperatura certa.', image: 'fries.png', duration: 6, difficulty: .62, available: true, craftSteps: ['chop', 'fry', 'package'], output: { item: 'batata_frita', label: 'Batatas da Casa', amount: 1 }, ingredients: [{ item: 'batata', label: 'Batata', amount: 2, count: 8 }] },
            { id: 'fresh_pasta', name: 'Massa Fresca', category: 'Massas', description: 'Massa trabalhada, porcionada e servida com molho.', duration: 14, difficulty: .5, available: true, craftSteps: ['prep', 'measure', 'knead', 'portion', 'boil', 'sauce', 'plate'], output: { item: 'ob_massa_fresca', label: 'Massa Fresca', amount: 1 }, ingredients: [{ item: 'ob_farinha', label: 'Farinha', amount: 2, count: 6 }, { item: 'ob_ovo', label: 'Ovos', amount: 2, count: 5 }, { item: 'water', label: 'Água', amount: 1, count: 4 }] },
            { id: 'pastry_box', name: 'Doce de Forno', category: 'Sobremesas', description: 'Massa aerada, modelada e decorada após assar.', image: 'pizza_ham_box.png', duration: 13, difficulty: .47, available: true, craftSteps: ['prep', 'measure', 'whisk', 'shape', 'bake', 'decorate'], output: { item: 'ob_doce_forno', label: 'Doce de Forno', amount: 2 }, ingredients: [{ item: 'ob_farinha', label: 'Farinha', amount: 1, count: 6 }, { item: 'ob_acucar', label: 'Açúcar', amount: 1, count: 4 }, { item: 'ob_ovo', label: 'Ovos', amount: 2, count: 5 }] },
            { id: 'house_drink', name: 'Refresco da Casa', category: 'Bebidas', description: 'Bebida dosada, misturada e finalizada na hora.', image: 'cola.png', duration: 5, difficulty: .6, available: true, craftSteps: ['measure', 'pour', 'mix', 'decorate'], output: { item: 'refrigerante', label: 'Refresco da Casa', amount: 1 }, ingredients: [{ item: 'water', label: 'Água', amount: 1, count: 4 }, { item: 'xarope', label: 'Xarope', amount: 1, count: 3 }] },
            { id: 'combo', name: 'Box Ravenwood', category: 'Combos', description: 'Pedido completo organizado para entrega.', image: 'pizza_ham_box.png', duration: 12, difficulty: .5, available: false, craftSteps: ['assemble', 'package'], output: { item: 'combo_box', label: 'Box Ravenwood', amount: 1 }, ingredients: [{ item: 'hamburguer', label: 'Hambúrguer', amount: 1, count: 0 }, { item: 'batata_frita', label: 'Batatas', amount: 1, count: 3 }, { item: 'refrigerante', label: 'Refrigerante', amount: 1, count: 3 }] }
        ]
    },
    weapons: {
        ok: true, preview: true,
        station: { id: 'preview_weapons', label: 'Bancada de armamentos', kind: 'weapons' },
        kind: { label: 'Armeiro', eyebrow: 'Bancada técnica', description: 'Monte componentes e calibre o mecanismo com precisão.', accent: '#9ca8b8' },
        recipes: [
            { id: 'pistol', name: 'Pistola compacta', description: 'Armação montada e mecanismo calibrado sobre a bancada.', duration: 24, difficulty: .38, available: true, craftSteps: ['refine', 'assemble', 'calibrate', 'weld', 'seal'], output: { item: 'WEAPON_PISTOL', label: 'Pistola compacta', amount: 1 }, ingredients: [{ item: 'steel', label: 'Aço', amount: 5, count: 14 }, { item: 'aluminum', label: 'Alumínio', amount: 3, count: 10 }, { item: 'rubber', label: 'Borracha', amount: 2, count: 8 }] },
            { id: 'ammo', name: 'Kit de munição', description: 'Componentes prensados, separados e conferidos.', image: 'pistol_ammo.png', duration: 12, difficulty: .42, available: true, craftSteps: ['assemble', 'calibrate', 'seal'], output: { item: 'pistol_ammo', label: 'Munição de pistola', amount: 2 }, ingredients: [{ item: 'steel', label: 'Aço', amount: 3, count: 12 }, { item: 'aluminum', label: 'Alumínio', amount: 2, count: 10 }, { item: 'rubber', label: 'Borracha', amount: 1, count: 8 }] }
        ]
    },
    narcotics: {
        ok: true, preview: true,
        station: { id: 'preview_narcotics', label: 'Mesa de síntese', kind: 'narcotics' },
        kind: { label: 'Laboratório', eyebrow: 'Síntese controlada', description: 'Dose reagentes e estabilize a mistura sem desperdício.', accent: '#7fc0a0' },
        recipes: [{ id: 'compound', name: 'Composto sintético', description: 'Reagentes dosados, aquecidos e estabilizados na bancada.', image: 'meth_baggy.png', duration: 18, difficulty: .34, available: true, craftSteps: ['dose', 'synthesize', 'heat', 'stabilize', 'package'], output: { item: 'meth_baggy', label: 'Composto embalado', amount: 2 }, ingredients: [{ item: 'acetone', label: 'Acetona', amount: 1, count: 4 }, { item: 'aluminum', label: 'Alumínio', amount: 2, count: 8 }, { item: 'water', label: 'Água', amount: 1, count: 6 }] }]
    }
};

if (browserPreview) {
    const previewParams = new URLSearchParams(location.search);
    const requested = previewParams.get('preview');
    const key = requested && requested !== '1' ? requested : 'kitchen';
    open(previewPayloads[key] || previewPayloads.kitchen);
    const requestedRecipe = previewParams.get('recipe');
    if (requestedRecipe && state.payload.recipes.some((recipe) => recipe.id === requestedRecipe)) selectRecipe(requestedRecipe);
}
