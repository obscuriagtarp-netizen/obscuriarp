<script setup>
import { computed, reactive, ref, watch } from "vue";
import {
  ArrowLeft,
  ArrowDown,
  ArrowUp,
  BarChart3,
  BanknoteArrowDown,
  CircleDollarSign,
  MapPin,
  Pencil,
  Plus,
  Save,
  Store,
  Trash2,
  Utensils,
  Users,
  X,
} from "lucide-vue-next";
import "../styles/restaurant-management.css";

const props = defineProps({
  payload: { type: Object, required: true },
  request: { type: Function, required: true },
  available: { type: Boolean, default: true },
});

const emit = defineEmits(["close", "reload", "feedback", "availability"]);
const tab = ref("overview");
const busy = ref(false);
const withdrawAmount = ref("");
const pendingDelete = ref(null);
const restaurantForm = reactive({ label: "", commissionRate: 0.3, managerGrade: 4, theme: "obscuria" });
const categoryForm = reactive({ key: "", label: "", icon: "utensils", sortOrder: 10 });
const pointForm = reactive({ id: null, type: "pos", label: "", enabled: true });
const recipeForm = reactive({
  id: null,
  name: "",
  key: "",
  categoryKey: "meals",
  description: "",
  image: "",
  price: 0,
  oldPrice: 0,
  menuBadge: "",
  featured: false,
  prepTime: 5,
  outputItem: "",
  outputAmount: 1,
  isCombo: false,
  enabled: true,
  ingredientsText: "",
  contentsText: "",
  craftSteps: ["chop", "grill", "assemble"],
});

const dashboard = computed(() => props.payload.dashboard || { totals: {}, products: [], team: [], accountBalance: 0 });
const categories = computed(() => (props.payload.categories || []).filter((entry) => entry.enabled !== false));
const recipes = computed(() => props.payload.recipes || []);
const points = computed(() => props.payload.points || []);
const companyShare = computed(() => Math.round((1 - Math.max(0, Math.min(0.9, Number(restaurantForm.commissionRate) || 0))) * 100));

const categoryIcons = [
  { value: "utensils", label: "Pratos" },
  { value: "cup-soda", label: "Bebidas" },
  { value: "package-open", label: "Combos" },
  { value: "sandwich", label: "Lanches" },
  { value: "salad", label: "Saladas" },
  { value: "soup", label: "Sopas" },
];

const pointTypes = [
  { value: "pos", label: "Caixa de pedidos" },
  { value: "kitchen", label: "Painel da cozinha" },
  { value: "production", label: "Estação de receitas" },
  { value: "cutting", label: "Bancada de preparo" },
  { value: "stove", label: "Fogão ou chapa" },
  { value: "drinks", label: "Estação de bebidas" },
  { value: "assembly", label: "Montagem de pedidos" },
  { value: "menu", label: "Cardápio para clientes" },
  { value: "terminal", label: "Maquininha" },
  { value: "display", label: "Telão de chamadas" },
  { value: "admin", label: "Administração" },
];

const craftActionOptions = [
  { value: "prep", label: "Organizar", detail: "Separar ingredientes" },
  { value: "chop", label: "Cortar", detail: "Cortes guiados" },
  { value: "portion", label: "Porcionar", detail: "Porções uniformes" },
  { value: "knead", label: "Trabalhar massa", detail: "Elasticidade da massa" },
  { value: "shape", label: "Modelar", detail: "Modelagem do preparo" },
  { value: "grill", label: "Grelhar", detail: "Ponto da chapa" },
  { value: "fry", label: "Fritar", detail: "Temperatura do óleo" },
  { value: "bake", label: "Assar", detail: "Controle do forno" },
  { value: "boil", label: "Cozinhar", detail: "Cozimento constante" },
  { value: "melt", label: "Derreter", detail: "Calor gradual" },
  { value: "measure", label: "Medir", detail: "Medida exata" },
  { value: "pour", label: "Dosar", detail: "Quantidade exata" },
  { value: "mix", label: "Misturar", detail: "Movimento contínuo" },
  { value: "whisk", label: "Bater", detail: "Incorporar ar" },
  { value: "sauce", label: "Adicionar molho", detail: "Dosagem do molho" },
  { value: "season", label: "Temperar", detail: "Distribuir tempero" },
  { value: "assemble", label: "Montar", detail: "Ordem dos itens" },
  { value: "plate", label: "Empratar", detail: "Montagem do prato" },
  { value: "decorate", label: "Decorar", detail: "Finalização visual" },
  { value: "chill", label: "Resfriar", detail: "Controle de resfriamento" },
  { value: "package", label: "Embalar", detail: "Lacre final" },
];

function money(value) {
  return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`;
}

function syncRestaurant() {
  const restaurant = props.payload.restaurant || {};
  Object.assign(restaurantForm, {
    label: restaurant.label || "Restaurante",
    commissionRate: Number(restaurant.commission_rate ?? 0.3),
    managerGrade: Number(restaurant.manager_grade ?? 4),
    theme: restaurant.theme || "obscuria",
  });
  if (!categories.value.some((category) => category.category_key === recipeForm.categoryKey) && categories.value[0]) {
    recipeForm.categoryKey = categories.value[0].category_key;
  }
}

watch(() => props.payload.restaurant, syncRestaurant, { immediate: true, deep: true });

function errorText(result) {
  const code = result?.error;
  const messages = {
    not_manager: "Somente o gerente desta empresa pode realizar esta ação.",
    not_owner: "Somente o proprietário ou a staff pode realizar esta ação.",
    restaurant_not_found: "A empresa não está registrada como restaurante.",
    restaurant_unavailable: "O sistema do restaurante está indisponível.",
    invalid_recipe: "Preencha nome, categoria e item de saída da receita.",
    ingredients_required: "Informe pelo menos um ingrediente.",
    category_not_found: "Escolha uma categoria válida.",
    invalid_category: "Informe o nome e o identificador da categoria.",
    invalid_point: "Informe um tipo e um nome válidos para o ponto.",
    point_not_found: "Este ponto não existe mais.",
    player_position_unavailable: "Não foi possível ler sua posição na cidade.",
    recipe_not_found: "Esta receita não existe mais.",
    invalid_restaurant: "Informe um nome válido para o estabelecimento.",
    invalid_image: "Use uma imagem HTTPS ou um caminho NUI válido.",
    unknown_inventory_item: `O item ${result?.item || "informado"} não existe no ox_inventory.`,
    invalid_total: "Informe um valor válido.",
    insufficient_company_balance: "O caixa empresarial não possui esse valor.",
    withdraw_failed: "A retirada não pôde ser creditada no banco.",
    rate_limited: "Aguarde um instante antes de repetir a ação.",
  };
  return messages[code] || "Não foi possível concluir esta ação.";
}

async function run(action, data, success, reload = true) {
  if (busy.value) return { ok: false };
  busy.value = true;
  let result;
  try {
    result = await props.request(action, data || {});
  } catch {
    result = { ok: false, error: "nui_unavailable" };
  } finally {
    busy.value = false;
  }
  if (!result?.ok) {
    emit("feedback", errorText(result), "error");
    return result || { ok: false };
  }
  if (success) emit("feedback", success, "success");
  if (reload) emit("reload");
  return result;
}

function linesToItems(text) {
  return String(text || "")
    .split("\n")
    .map((line) => {
      const [item, label, amount] = line.split("|").map((part) => part?.trim());
      return item ? { item, label: label || item, amount: Math.max(1, Number(amount) || 1) } : null;
    })
    .filter(Boolean);
}

function itemsToLines(items) {
  return (items || []).map((item) => `${item.item}|${item.label || item.item}|${item.amount || 1}`).join("\n");
}

function stepKeys(steps) {
  return (steps || []).map((step) => typeof step === "string" ? step : step.type).filter((step) => craftActionOptions.some((option) => option.value === step));
}
function craftAction(type) { return craftActionOptions.find((option) => option.value === type) || { label: type, detail: "Etapa personalizada" }; }
function addCraftStep(type) { if (type && recipeForm.craftSteps.length < 8) recipeForm.craftSteps.push(type); }
function removeCraftStep(index) { recipeForm.craftSteps.splice(index, 1); }
function moveCraftStep(index, direction) {
  const target = index + direction;
  if (target < 0 || target >= recipeForm.craftSteps.length) return;
  [recipeForm.craftSteps[index], recipeForm.craftSteps[target]] = [recipeForm.craftSteps[target], recipeForm.craftSteps[index]];
}

function resetRecipe() {
  Object.assign(recipeForm, {
    id: null,
    name: "",
    key: "",
    categoryKey: categories.value[0]?.category_key || "meals",
    description: "",
    image: "",
    price: 0,
    oldPrice: 0,
    menuBadge: "",
    featured: false,
    prepTime: 5,
    outputItem: "",
    outputAmount: 1,
    isCombo: false,
    enabled: true,
    ingredientsText: "",
    contentsText: "",
    craftSteps: ["chop", "grill", "assemble"],
  });
}

function editRecipe(recipe) {
  Object.assign(recipeForm, {
    id: recipe.id,
    name: recipe.name,
    key: recipe.recipe_key,
    categoryKey: recipe.category_key,
    description: recipe.description || "",
    image: recipe.image || "",
    price: Number(recipe.price) || 0,
    oldPrice: Number(recipe.old_price) || 0,
    menuBadge: recipe.menu_badge || "",
    featured: recipe.featured === true,
    prepTime: Number(recipe.prep_time) || 5,
    outputItem: recipe.output_item || "",
    outputAmount: Number(recipe.output_amount) || 1,
    isCombo: recipe.is_combo === true,
    enabled: recipe.enabled !== false,
    ingredientsText: itemsToLines(recipe.ingredients),
    contentsText: itemsToLines(recipe.contents),
    craftSteps: stepKeys(recipe.craft_steps),
  });
  tab.value = "recipes";
}

async function saveRestaurant() {
  if (!restaurantForm.label.trim()) {
    emit("feedback", "Informe o nome do estabelecimento.", "error");
    return;
  }
  await run("saveRestaurant", { settings: { ...restaurantForm } }, "Configurações salvas.");
}

async function withdraw() {
  const result = await run("withdrawCompany", { amount: Number(withdrawAmount.value) }, "Valor enviado para sua conta bancária.");
  if (result?.ok) withdrawAmount.value = "";
}

async function saveRecipe() {
  if (!recipeForm.name.trim() || !recipeForm.categoryKey || !recipeForm.outputItem.trim()) {
    emit("feedback", "Preencha nome, categoria e item de saída.", "error");
    return;
  }
  if (!/^[a-z0-9_-]+$/.test(recipeForm.outputItem.trim())) {
    emit("feedback", "O item de saída deve usar apenas letras minúsculas, números, _ ou -.", "error");
    return;
  }
  const recipe = {
    ...recipeForm,
    ingredients: linesToItems(recipeForm.ingredientsText),
    contents: linesToItems(recipeForm.contentsText),
  };
  const result = await run("saveRecipe", { recipe }, "Receita salva no catálogo.");
  if (result?.ok) resetRecipe();
}

async function deleteRecipe(recipe) {
  pendingDelete.value = { type: "recipe", id: recipe.id, label: recipe.name };
}

async function saveCategory() {
  if (!categoryForm.label.trim() || !categoryForm.key.trim()) {
    emit("feedback", "Informe o nome e o identificador da categoria.", "error");
    return;
  }
  categoryForm.key = categoryForm.key.trim().toLowerCase().replace(/\s+/g, "_");
  if (!/^[a-z0-9_-]+$/.test(categoryForm.key)) {
    emit("feedback", "O identificador deve usar apenas letras minúsculas, números, _ ou -.", "error");
    return;
  }
  const result = await run("saveCategory", { category: { ...categoryForm } }, "Categoria salva.");
  if (result?.ok) Object.assign(categoryForm, { key: "", label: "", icon: "utensils", sortOrder: 10 });
}

async function deleteCategory(category) {
  pendingDelete.value = { type: "category", id: category.category_key, label: category.label };
}

function editPoint(point) {
  Object.assign(pointForm, { id: point.id, type: point.type, label: point.label, enabled: point.enabled !== false });
}

function resetPoint() {
  Object.assign(pointForm, { id: null, type: "pos", label: "", enabled: true });
}

async function savePoint() {
  if (!pointForm.label.trim()) {
    emit("feedback", "Informe um nome para o ponto.", "error");
    return;
  }
  const result = await run("savePoint", { point: { ...pointForm } }, "Ponto salvo na sua posição atual.");
  if (result?.ok) resetPoint();
}

async function deletePoint(point) {
  pendingDelete.value = { type: "point", id: point.id, label: point.label };
}

async function confirmDelete() {
  const target = pendingDelete.value;
  if (!target) return;
  pendingDelete.value = null;
  if (target.type === "recipe") await run("deleteRecipe", { recipeId: target.id }, "Receita removida do catálogo.");
  if (target.type === "category") await run("deleteCategory", { categoryKey: target.id }, "Categoria e receitas vinculadas foram desativadas.");
  if (target.type === "point") await run("deletePoint", { pointId: target.id }, "Ponto removido.");
}
</script>

<template>
  <section class="restaurant-manager">
    <header class="restaurant-manager__header">
      <button class="restaurant-manager__back" type="button" title="Voltar aos estabelecimentos" @click="emit('close')">
        <ArrowLeft :size="18" />
      </button>
      <div class="restaurant-manager__identity">
        <span><Store :size="16" /> Empresa registrada</span>
        <h2>{{ payload.restaurant.label }}</h2>
        <small>{{ payload.restaurant.job }} · Painel administrativo</small>
      </div>
      <button class="restaurant-manager__availability" :class="{ closed: !available }" type="button" @click="emit('availability', !available)">
        <i></i>{{ available ? "Aberto" : "Fechado" }}
      </button>
    </header>

    <nav class="restaurant-manager__tabs" aria-label="Áreas da gestão">
      <button :class="{ active: tab === 'overview' }" @click="tab = 'overview'"><BarChart3 :size="16" /> Visão geral</button>
      <button :class="{ active: tab === 'recipes' }" @click="tab = 'recipes'"><Utensils :size="16" /> Receitas e categorias</button>
      <button :class="{ active: tab === 'points' }" @click="tab = 'points'"><MapPin :size="16" /> Pontos de interação</button>
    </nav>

    <div v-if="tab === 'overview'" class="restaurant-manager__scroll">
      <div class="restaurant-metrics">
        <article><small>Vendas hoje</small><strong>{{ money(dashboard.totals?.today_gross) }}</strong><span>{{ dashboard.totals?.today_sales || 0 }} pedidos pagos</span></article>
        <article><small>Últimos 7 dias</small><strong>{{ money(dashboard.totals?.week_gross) }}</strong><span>Receita bruta</span></article>
        <article><small>Caixa empresarial</small><strong>{{ money(dashboard.accountBalance) }}</strong><span>Saldo disponível</span></article>
        <article><small>Comissões hoje</small><strong>{{ money(dashboard.totals?.today_commission) }}</strong><span>Pagas à equipe</span></article>
      </div>

      <div class="restaurant-manager__columns">
        <section class="restaurant-manager__section">
          <header><CircleDollarSign :size="18" /><div><small>Financeiro</small><h3>Retirada do caixa</h3></div></header>
          <div class="restaurant-inline-form">
            <input v-model="withdrawAmount" type="number" min="1" placeholder="Valor da retirada" />
            <button :disabled="busy || Number(withdrawAmount) < 1" @click="withdraw"><BanknoteArrowDown :size="15" /> Retirar</button>
          </div>
          <p>O saldo representa os {{ companyShare }}% destinados à empresa após cada venda.</p>
        </section>

        <section class="restaurant-manager__section restaurant-settings">
          <header><Save :size="18" /><div><small>Operação</small><h3>Configurações gerais</h3></div></header>
          <label><span>Nome do restaurante</span><input v-model="restaurantForm.label" /></label>
          <div class="restaurant-form-row">
            <label><span>Comissão do atendente</span><input v-model="restaurantForm.commissionRate" type="number" min="0" max="0.9" step="0.01" /></label>
            <label><span>Grau de gerente</span><input v-model="restaurantForm.managerGrade" type="number" min="0" /></label>
          </div>
          <button class="restaurant-primary" :disabled="busy" @click="saveRestaurant"><Save :size="15" /> Salvar configurações</button>
        </section>
      </div>

      <div class="restaurant-manager__columns">
        <section class="restaurant-manager__section restaurant-ranking">
          <header><Utensils :size="18" /><div><small>Últimos 30 dias</small><h3>Produtos mais pedidos</h3></div></header>
          <ol><li v-for="product in dashboard.products || []" :key="product.name"><span><b>{{ product.name }}</b><small>{{ product.amount }} unidades</small></span><strong>{{ money(product.revenue) }}</strong></li></ol>
          <p v-if="!(dashboard.products || []).length">Ainda não há vendas suficientes para este ranking.</p>
        </section>
        <section class="restaurant-manager__section restaurant-ranking">
          <header><Users :size="18" /><div><small>Desempenho</small><h3>Equipe de atendimento</h3></div></header>
          <ol><li v-for="member in dashboard.team || []" :key="member.employee_identifier"><span><b>{{ member.employee_name }}</b><small>{{ member.sales }} vendas</small></span><strong>{{ money(member.commission) }}</strong></li></ol>
          <p v-if="!(dashboard.team || []).length">Nenhum atendimento foi registrado neste período.</p>
        </section>
      </div>
    </div>

    <div v-else-if="tab === 'recipes'" class="restaurant-manager__scroll restaurant-catalog-management">
      <section class="restaurant-manager__section restaurant-recipe-editor">
        <header><Plus :size="18" /><div><small>{{ recipeForm.id ? "Edição" : "Nova receita" }}</small><h3>{{ recipeForm.id ? recipeForm.name : "Criar item do cardápio" }}</h3></div><button v-if="recipeForm.id" class="restaurant-text-button" @click="resetRecipe">Nova</button></header>
        <div class="restaurant-form-row"><label><span>Nome</span><input v-model="recipeForm.name" /></label><label><span>Categoria</span><select v-model="recipeForm.categoryKey"><option v-for="category in categories" :key="category.category_key" :value="category.category_key">{{ category.label }}</option></select></label></div>
        <label><span>Descrição</span><input v-model="recipeForm.description" /></label>
        <div class="restaurant-form-row restaurant-form-row--triple"><label><span>Preço</span><input v-model="recipeForm.price" type="number" min="0" /></label><label><span>Preço anterior</span><input v-model="recipeForm.oldPrice" type="number" min="0" /></label><label><span>Preparo (seg.)</span><input v-model="recipeForm.prepTime" type="number" min="1" /></label></div>
        <div class="restaurant-form-row"><label><span>Item de saída</span><input v-model="recipeForm.outputItem" /></label><label><span>Quantidade</span><input v-model="recipeForm.outputAmount" type="number" min="1" /></label></div>
        <label><span>Imagem do produto</span><input v-model="recipeForm.image" placeholder="URL ou caminho NUI" /></label>
        <label><span>Ingredientes: item|nome|quantidade</span><textarea v-model="recipeForm.ingredientsText"></textarea></label>
        <section class="restaurant-craft-flow">
          <header><div><small>Roteiro de preparo</small><strong>Interações da receita</strong></div><span>{{ recipeForm.craftSteps.length }}/8</span></header>
          <div class="restaurant-craft-picker"><button v-for="action in craftActionOptions" :key="action.value" type="button" :disabled="recipeForm.craftSteps.length >= 8" @click="addCraftStep(action.value)"><Plus :size="12" />{{ action.label }}</button></div>
          <div v-if="recipeForm.craftSteps.length" class="restaurant-craft-list">
            <article v-for="(step, index) in recipeForm.craftSteps" :key="`${step}-${index}`"><b>{{ index + 1 }}</b><div><strong>{{ craftAction(step).label }}</strong><small>{{ craftAction(step).detail }}</small></div><button :disabled="index === 0" title="Subir" @click="moveCraftStep(index, -1)"><ArrowUp :size="12" /></button><button :disabled="index === recipeForm.craftSteps.length - 1" title="Descer" @click="moveCraftStep(index, 1)"><ArrowDown :size="12" /></button><button title="Remover" @click="removeCraftStep(index)"><Trash2 :size="12" /></button></article>
          </div>
          <p v-else>O fluxo será definido automaticamente pela categoria.</p>
        </section>
        <label v-if="recipeForm.isCombo"><span>Conteúdo da box: item|nome|quantidade</span><textarea v-model="recipeForm.contentsText"></textarea></label>
        <div class="restaurant-checks"><label><input v-model="recipeForm.isCombo" type="checkbox" /> Box ou combo</label><label><input v-model="recipeForm.featured" type="checkbox" /> Destaque</label><label><input v-model="recipeForm.enabled" type="checkbox" /> Disponível</label></div>
        <button class="restaurant-primary" :disabled="busy" @click="saveRecipe"><Save :size="15" /> Salvar receita</button>
      </section>

      <div class="restaurant-catalog-side">
        <section class="restaurant-manager__section restaurant-library">
          <header><Utensils :size="18" /><div><small>Catálogo atual</small><h3>{{ recipes.length }} receitas</h3></div></header>
          <div class="restaurant-library__list">
            <article v-for="recipe in recipes" :key="recipe.id">
              <img v-if="recipe.image" :src="recipe.image" alt="" />
              <span v-else><Utensils :size="17" /></span>
              <div><b>{{ recipe.name }}</b><small>{{ recipe.output_item }} · {{ money(recipe.price) }}</small></div>
              <button title="Editar" @click="editRecipe(recipe)"><Pencil :size="15" /></button>
              <button title="Remover" @click="deleteRecipe(recipe)"><Trash2 :size="15" /></button>
            </article>
          </div>
        </section>

        <section class="restaurant-manager__section restaurant-category-editor">
          <header><Plus :size="18" /><div><small>Organização</small><h3>Categorias</h3></div></header>
          <div class="restaurant-form-row"><label><span>Identificador</span><input v-model="categoryForm.key" placeholder="sobremesas" /></label><label><span>Nome</span><input v-model="categoryForm.label" placeholder="Sobremesas" /></label></div>
          <div class="restaurant-category-icons">
            <button v-for="icon in categoryIcons" :key="icon.value" type="button" :class="{ active: categoryForm.icon === icon.value }" @click="categoryForm.icon = icon.value">{{ icon.label }}</button>
          </div>
          <button class="restaurant-secondary" :disabled="busy || !categoryForm.key.trim() || !categoryForm.label.trim()" @click="saveCategory">Salvar categoria</button>
          <div class="restaurant-category-list"><article v-for="category in categories" :key="category.category_key"><div><b>{{ category.label }}</b><small>{{ category.category_key }}</small></div><button title="Remover" @click="deleteCategory(category)"><Trash2 :size="14" /></button></article></div>
        </section>
      </div>
    </div>

    <div v-else class="restaurant-manager__scroll restaurant-points-management">
      <section class="restaurant-manager__section restaurant-point-editor">
        <header><MapPin :size="18" /><div><small>{{ pointForm.id ? "Reposicionar" : "Novo ponto" }}</small><h3>Usar posição atual</h3></div><button v-if="pointForm.id" class="restaurant-text-button" @click="resetPoint">Novo</button></header>
        <label><span>Tipo de interação</span><select v-model="pointForm.type"><option v-for="type in pointTypes" :key="type.value" :value="type.value">{{ type.label }}</option></select></label>
        <label><span>Nome do ponto</span><input v-model="pointForm.label" placeholder="Caixa principal" /></label>
        <button class="restaurant-primary" :disabled="busy" @click="savePoint"><MapPin :size="15" /> {{ pointForm.id ? "Atualizar nesta posição" : "Criar nesta posição" }}</button>
      </section>

      <section class="restaurant-manager__section restaurant-point-list">
        <header><MapPin :size="18" /><div><small>Interações cadastradas</small><h3>{{ points.length }} pontos</h3></div></header>
        <article v-for="point in points" :key="point.id"><span><MapPin :size="16" /></span><div><b>{{ point.label }}</b><small>{{ pointTypes.find((type) => type.value === point.type)?.label || point.type }} · {{ Number(point.coords?.x || 0).toFixed(1) }}, {{ Number(point.coords?.y || 0).toFixed(1) }}</small></div><button title="Reposicionar" @click="editPoint(point)"><Pencil :size="15" /></button><button title="Remover" @click="deletePoint(point)"><Trash2 :size="15" /></button></article>
      </section>
    </div>

    <div v-if="pendingDelete" class="restaurant-confirm" role="dialog" aria-modal="true" aria-labelledby="restaurant-confirm-title">
      <section>
        <header>
          <div><small>Confirmação necessária</small><h3 id="restaurant-confirm-title">Remover {{ pendingDelete.label }}?</h3></div>
          <button type="button" title="Cancelar" @click="pendingDelete = null"><X :size="17" /></button>
        </header>
        <p v-if="pendingDelete.type === 'category'">As receitas vinculadas a esta categoria também serão retiradas do cardápio.</p>
        <p v-else>Esta ação altera imediatamente a operação do estabelecimento.</p>
        <footer>
          <button type="button" @click="pendingDelete = null">Cancelar</button>
          <button type="button" class="danger" :disabled="busy" @click="confirmDelete"><Trash2 :size="14" /> Confirmar remoção</button>
        </footer>
      </section>
    </div>
  </section>
</template>
