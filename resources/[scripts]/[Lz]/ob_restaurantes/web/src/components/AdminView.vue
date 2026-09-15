<script setup>
import { computed, reactive, ref, watch } from "vue";
import { ArrowDown, ArrowUp, BadgeDollarSign, BanknoteArrowDown, BarChart3, Droplets, HeartPulse, MapPin, PackagePlus, Pencil, Plus, Sandwich, Save, Trash2, Utensils } from "lucide-vue-next";
import DynamicIcon from "./DynamicIcon.vue";
import { nuiRequest } from "../nui";

const props = defineProps({ payload: { type: Object, required: true } });
const emit = defineEmits(["feedback", "refresh"]);
const tab = ref("overview");
const saving = ref(false);
const deletingRecipeId = ref(null);
const withdrawAmount = ref("");
const restaurantForm = reactive({ label: "", commissionRate: 0.3, managerGrade: 4, theme: "obscuria" });
const categoryForm = reactive({ key: "", label: "", icon: "utensils", sortOrder: 10 });
const pointForm = reactive({ id: null, type: "pos", label: "", useCurrent: true, enabled: true });
const recipeForm = reactive({ id: null, name: "", key: "", categoryKey: "meals", description: "", image: "", price: 0, oldPrice: 0, menuBadge: "", featured: false, prepTime: 5, outputAmount: 1, productType: "food", itemWeight: 250, presentationKey: "", isCombo: false, enabled: true, ingredients: [{ item: "", label: "", amount: 1 }], contents: [], craftSteps: ["chop", "grill", "assemble"], effects: { hunger: 0, thirst: 0, stress: 0 } });

const metrics = computed(() => props.payload.dashboard || { totals: {}, products: [], team: [], accountBalance: 0 });
const activeCategories = computed(() => (props.payload.categories || []).filter((category) => category.enabled !== false));
const inventoryItems = computed(() => props.payload.inventoryItems || []);
const inventoryItemMap = computed(() => new Map(inventoryItems.value.map((item) => [item.name, item])));
const presentationOptions = computed(() => (props.payload.presentations || []).filter((entry) => entry.type === recipeForm.productType));
const categoryIcons = [
  { value: "utensils", label: "Pratos" },
  { value: "cup-soda", label: "Bebidas" },
  { value: "package-open", label: "Combos" },
  { value: "sandwich", label: "Lanches" },
  { value: "salad", label: "Saladas" },
  { value: "soup", label: "Sopas" },
  { value: "basket", label: "Porções" },
  { value: "store", label: "Especiais" },
  { value: "chef-hat", label: "Chef" },
  { value: "flame", label: "Quentes" },
];
const craftActionOptions = [
  { value: "prep", label: "Organizar", detail: "Animação de separação dos ingredientes" },
  { value: "chop", label: "Cortar ingredientes", detail: "Animação de corte na bancada" },
  { value: "portion", label: "Porcionar", detail: "Porções de tamanho uniforme" },
  { value: "knead", label: "Trabalhar a massa", detail: "Pressão e elasticidade" },
  { value: "shape", label: "Modelar", detail: "Formato e pressão uniformes" },
  { value: "grill", label: "Grelhar", detail: "Animação de preparo na chapa" },
  { value: "fry", label: "Fritar", detail: "Animação de preparo no fogão" },
  { value: "bake", label: "Assar", detail: "Animação de preparo no forno" },
  { value: "boil", label: "Cozinhar", detail: "Animação de cozimento" },
  { value: "melt", label: "Derreter", detail: "Calor gradual" },
  { value: "measure", label: "Medir componentes", detail: "Quantidade exata da receita" },
  { value: "pour", label: "Dosar líquidos", detail: "Quantidade exata" },
  { value: "mix", label: "Misturar", detail: "Movimento circular" },
  { value: "whisk", label: "Bater", detail: "Incorporar ar à mistura" },
  { value: "sauce", label: "Adicionar molho", detail: "Dosagem de molho" },
  { value: "season", label: "Temperar", detail: "Ponto de finalização" },
  { value: "assemble", label: "Montar", detail: "Ordem dos componentes" },
  { value: "plate", label: "Empratar", detail: "Montagem no prato" },
  { value: "decorate", label: "Decorar", detail: "Acabamento de confeitaria" },
  { value: "chill", label: "Resfriar", detail: "Ponto de resfriamento" },
  { value: "package", label: "Embalar", detail: "Finalização do pedido" },
];
const recipeEffectOptions = [
  { key: "hunger", label: "Fome", detail: "Recupera alimentação", icon: Sandwich },
  { key: "thirst", label: "Água", detail: "Recupera hidratação", icon: Droplets },
  { key: "stress", label: "Estresse", detail: "Reduz o estresse", icon: HeartPulse },
];
const effectLimits = computed(() => ({
  maxSelected: Math.max(1, Number(props.payload.recipeEffects?.maxSelected) || 2),
  maxAmount: Math.max(1, Number(props.payload.recipeEffects?.maxAmount) || 50),
  defaultAmount: Math.max(1, Number(props.payload.recipeEffects?.defaultAmount) || 20),
}));
const selectedEffectCount = computed(() => recipeEffectOptions.filter(({ key }) => Number(recipeForm.effects?.[key]) > 0).length);
const companyShare = computed(() => {
  const rate = Math.max(0, Math.min(0.9, Number(restaurantForm.commissionRate) || 0));
  return Math.round((1 - rate) * 100);
});
function money(value) { return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`; }
function syncRestaurant() {
  Object.assign(restaurantForm, {
    label: props.payload.restaurant.label,
    commissionRate: Number(props.payload.restaurant.commission_rate || 0.3),
    managerGrade: Number(props.payload.restaurant.manager_grade || 4),
    theme: props.payload.restaurant.theme || "obscuria",
  });
}
watch(() => props.payload.restaurant, syncRestaurant, { immediate: true, deep: true });

function copyItemRows(items, emptyRow = false) {
  const rows = (items || []).map((item) => ({
    item: String(item.item || ""),
    label: String(item.label || ""),
    amount: Math.max(1, Number(item.amount) || 1),
  }));
  return rows.length || !emptyRow ? rows : [{ item: "", label: "", amount: 1 }];
}
function compactItemRows(items) {
  return (items || []).map((entry) => {
    const item = String(entry.item || "").trim();
    const registered = inventoryItemMap.value.get(item);
    return item ? {
      item,
      label: String(entry.label || registered?.label || item).trim(),
      amount: Math.max(1, Math.floor(Number(entry.amount) || 1)),
    } : null;
  }).filter(Boolean);
}
function addItemRow(target) { target.push({ item: "", label: "", amount: 1 }); }
function removeItemRow(target, index) { target.splice(index, 1); }
function syncItemLabel(entry) {
  const registered = inventoryItemMap.value.get(String(entry.item || "").trim());
  if (registered) entry.label = registered.label;
}
function registeredItemLabel(name) { return inventoryItemMap.value.get(String(name || "").trim())?.label || "Item não selecionado"; }
function stepKeys(steps) { return (steps || []).map((step) => typeof step === "string" ? step : step.type).filter((step) => craftActionOptions.some((option) => option.value === step)); }
function addCraftStep(type) { if (type && recipeForm.craftSteps.length < 8) recipeForm.craftSteps.push(type); }
function removeCraftStep(index) { recipeForm.craftSteps.splice(index, 1); }
function moveCraftStep(index, direction) {
  const target = index + direction;
  if (target < 0 || target >= recipeForm.craftSteps.length) return;
  [recipeForm.craftSteps[index], recipeForm.craftSteps[target]] = [recipeForm.craftSteps[target], recipeForm.craftSteps[index]];
}
function craftAction(type) { return craftActionOptions.find((option) => option.value === type) || { label: type, detail: "Etapa personalizada" }; }
function normalizedEffects(effects) {
  return Object.fromEntries(recipeEffectOptions.map(({ key }) => [key, Math.max(0, Math.floor(Number(effects?.[key]) || 0))]));
}
function effectEnabled(key) { return Number(recipeForm.effects?.[key]) > 0; }
function toggleEffect(key) {
  if (effectEnabled(key)) {
    recipeForm.effects[key] = 0;
    return;
  }
  if (selectedEffectCount.value >= effectLimits.value.maxSelected) {
    emit("feedback", `Escolha no máximo ${effectLimits.value.maxSelected} efeitos por receita.`, "error");
    return;
  }
  recipeForm.effects[key] = Math.min(effectLimits.value.maxAmount, effectLimits.value.defaultAmount);
}
function clampEffect(key) {
  recipeForm.effects[key] = Math.min(effectLimits.value.maxAmount, Math.max(1, Math.floor(Number(recipeForm.effects[key]) || effectLimits.value.defaultAmount)));
}

async function saveRestaurant() {
  saving.value = true;
  const result = await nuiRequest("saveRestaurant", { restaurantId: props.payload.restaurant.id, settings: restaurantForm });
  saving.value = false;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", "Configurações do restaurante salvas.", "success"); emit("refresh");
}
async function withdraw() {
  const result = await nuiRequest("withdrawCompany", { restaurantId: props.payload.restaurant.id, amount: Number(withdrawAmount.value) });
  if (!result.ok) return emit("feedback", result.error, "error");
  withdrawAmount.value = ""; emit("feedback", "Valor retirado para sua conta bancária.", "success"); emit("refresh");
}
function editRecipe(recipe) {
  Object.assign(recipeForm, {
    id: recipe.id, name: recipe.name, key: recipe.recipe_key, categoryKey: recipe.category_key,
    description: recipe.description, image: recipe.image, price: Number(recipe.price),
    oldPrice: Number(recipe.old_price || 0), menuBadge: recipe.menu_badge || "", featured: recipe.featured === true,
    prepTime: Number(recipe.prep_time), outputAmount: Number(recipe.output_amount),
    productType: recipe.product_type === "drink" ? "drink" : "food", itemWeight: Number(recipe.item_weight || 250),
    presentationKey: recipe.presentation_key || "",
    isCombo: recipe.is_combo, enabled: recipe.enabled !== false,
    ingredients: copyItemRows(recipe.ingredients, true), contents: copyItemRows(recipe.contents),
    craftSteps: stepKeys(recipe.craft_steps),
    effects: normalizedEffects(recipe.effects),
  });
  tab.value = "recipes";
}
function resetRecipe() {
  Object.assign(recipeForm, { id: null, name: "", key: "", categoryKey: activeCategories.value[0]?.category_key || "meals", description: "", image: "", price: 0, oldPrice: 0, menuBadge: "", featured: false, prepTime: 5, outputAmount: 1, productType: "food", itemWeight: 250, presentationKey: "", isCombo: false, enabled: true, ingredients: [{ item: "", label: "", amount: 1 }], contents: [], craftSteps: ["chop", "grill", "assemble"], effects: { hunger: 0, thirst: 0, stress: 0 } });
}
async function saveRecipe() {
  if (selectedEffectCount.value > effectLimits.value.maxSelected) return emit("feedback", `Escolha no máximo ${effectLimits.value.maxSelected} efeitos por receita.`, "error");
  const ingredients = compactItemRows(recipeForm.ingredients);
  if (!String(recipeForm.name || "").trim() || !recipeForm.categoryKey) return emit("feedback", "Preencha o nome e a categoria da receita.", "error");
  if (!ingredients.length) return emit("feedback", "Adicione ao menos um ingrediente.", "error");
  saving.value = true;
  const result = await nuiRequest("saveRecipe", { restaurantId: props.payload.restaurant.id, recipe: { ...recipeForm, effects: normalizedEffects(recipeForm.effects), ingredients, contents: compactItemRows(recipeForm.contents) } });
  saving.value = false;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", "Receita salva no catálogo.", "success"); resetRecipe(); emit("refresh");
}
async function deleteRecipe(recipe) {
  if (deletingRecipeId.value) return;
  deletingRecipeId.value = recipe.id;
  const result = await nuiRequest("deleteRecipe", { restaurantId: props.payload.restaurant.id, recipeId: recipe.id });
  deletingRecipeId.value = null;
  if (!result.ok) return emit("feedback", result.error, "error");
  if (Number(recipeForm.id) === Number(recipe.id)) resetRecipe();
  emit("feedback", "Receita removida do catálogo.", "success"); emit("refresh");
}
async function saveCategory() {
  const categoryName = categoryForm.label.trim();
  const categoryKey = categoryForm.key.trim();
  if (!categoryName) return emit("feedback", "Informe o nome da categoria.", "error");
  if (!categoryKey) return emit("feedback", "Informe o identificador da categoria.", "error");

  categoryForm.label = categoryName;
  categoryForm.key = categoryKey;
  const result = await nuiRequest("saveCategory", { restaurantId: props.payload.restaurant.id, category: categoryForm });
  if (!result.ok) return emit("feedback", result.error, "error");
  Object.assign(categoryForm, { key: "", label: "", icon: "utensils", sortOrder: 10 });
  emit("feedback", "Categoria salva.", "success"); emit("refresh");
}
async function deleteCategory(category) {
  const result = await nuiRequest("deleteCategory", { restaurantId: props.payload.restaurant.id, categoryKey: category.category_key });
  if (!result.ok) return emit("feedback", result.error, "error");
  const affected = Number(result.affectedRecipes) || 0;
  emit("feedback", affected > 0 ? `Categoria removida e ${affected} receita(s) desativada(s).` : "Categoria removida.", "success");
  emit("refresh");
}
function editPoint(point) { Object.assign(pointForm, { id: point.id, type: point.type, label: point.label, useCurrent: true, enabled: point.enabled !== false }); }
function resetPoint() { Object.assign(pointForm, { id: null, type: "pos", label: "", useCurrent: true, enabled: true }); }
async function savePoint() {
  const result = await nuiRequest("savePoint", { restaurantId: props.payload.restaurant.id, point: { ...pointForm, useCurrent: true } });
  if (!result.ok) return emit("feedback", result.error, "error");
  resetPoint(); emit("feedback", "Ponto salvo na sua posição atual.", "success"); emit("refresh");
}
async function deletePoint(point) {
  const result = await nuiRequest("deletePoint", { restaurantId: props.payload.restaurant.id, pointId: point.id });
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", "Ponto removido.", "success"); emit("refresh");
}
</script>

<template>
  <section class="admin-view">
    <nav class="admin-tabs">
      <button :class="{ active: tab === 'overview' }" @click="tab = 'overview'"><BarChart3 :size="17" /> Visão geral</button>
      <button :class="{ active: tab === 'recipes' }" @click="tab = 'recipes'"><Utensils :size="17" /> Receitas</button>
      <button :class="{ active: tab === 'points' }" @click="tab = 'points'"><MapPin :size="17" /> Pontos no mapa</button>
    </nav>

    <div v-if="tab === 'overview'" class="admin-scroll">
      <div class="metric-row">
        <article><small>Vendas hoje</small><strong>{{ money(metrics.totals?.today_gross) }}</strong><span>{{ metrics.totals?.today_sales || 0 }} pedidos pagos</span></article>
        <article><small>Últimos 7 dias</small><strong>{{ money(metrics.totals?.week_gross) }}</strong><span>Receita bruta</span></article>
        <article><small>Caixa empresarial</small><strong>{{ money(metrics.accountBalance) }}</strong><span>Saldo persistente</span></article>
        <article><small>Comissões hoje</small><strong>{{ money(metrics.totals?.today_commission) }}</strong><span>Pagas à equipe</span></article>
      </div>
      <div class="admin-columns">
        <section class="admin-section">
          <header><BadgeDollarSign :size="19" /><div><small>Financeiro</small><h3>Retirada do caixa</h3></div></header>
          <div class="inline-form"><input v-model="withdrawAmount" type="number" min="1" placeholder="Valor" /><button :disabled="Number(withdrawAmount) < 1" @click="withdraw"><BanknoteArrowDown :size="16" /> Retirar</button></div>
          <p>O saldo representa os {{ companyShare }}% destinados à empresa após cada venda.</p>
        </section>
        <section class="admin-section settings-form">
          <header><Save :size="19" /><div><small>Operação</small><h3>Configurações gerais</h3></div></header>
          <label><span>Nome do restaurante</span><input v-model="restaurantForm.label" /></label>
          <div class="form-row"><label><span>Comissão (0 a 0,9)</span><input v-model="restaurantForm.commissionRate" type="number" min="0" max="0.9" step="0.01" /></label><label><span>Grau de gerente</span><input v-model="restaurantForm.managerGrade" type="number" min="0" /></label></div>
          <button class="primary-command" :disabled="saving" @click="saveRestaurant">Salvar restaurante</button>
        </section>
      </div>
      <div class="admin-columns analytics-lists">
        <section class="admin-section"><header><Utensils :size="19" /><div><small>Últimos 30 dias</small><h3>Produtos mais pedidos</h3></div></header><ol><li v-for="product in metrics.products" :key="product.name"><span><b>{{ product.name }}</b><small>{{ product.amount }} unidades</small></span><strong>{{ money(product.revenue) }}</strong></li></ol></section>
        <section class="admin-section"><header><BarChart3 :size="19" /><div><small>Desempenho</small><h3>Equipe de atendimento</h3></div></header><ol><li v-for="member in metrics.team" :key="member.employee_identifier"><span><b>{{ member.employee_name }}</b><small>{{ member.sales }} vendas</small></span><strong>{{ money(member.commission) }}</strong></li></ol></section>
      </div>
    </div>

    <div v-else-if="tab === 'recipes'" class="admin-scroll recipes-admin">
      <section class="admin-section recipe-editor">
        <header><PackagePlus :size="19" /><div><small>{{ recipeForm.id ? 'Edição' : 'Nova receita' }}</small><h3>{{ recipeForm.id ? recipeForm.name : 'Criar item do cardápio' }}</h3></div><button v-if="recipeForm.id" class="text-command" @click="resetRecipe">Nova receita</button></header>
        <datalist id="restaurant-inventory-items"><option v-for="item in inventoryItems" :key="item.name" :value="item.name" :label="item.label" /></datalist>
        <div class="form-row"><label><span>Nome</span><input v-model="recipeForm.name" /></label><label><span>Categoria</span><select v-model="recipeForm.categoryKey"><option v-for="category in activeCategories" :key="category.category_key" :value="category.category_key">{{ category.label }}</option></select></label></div>
        <label><span>Descrição</span><input v-model="recipeForm.description" /></label>
        <div class="form-row triple"><label><span>Preço atual</span><input v-model="recipeForm.price" type="number" min="0" /></label><label><span>Preço anterior</span><input v-model="recipeForm.oldPrice" type="number" min="0" placeholder="Use para promoções" /></label><label><span>Preparo em segundos</span><input v-model="recipeForm.prepTime" type="number" min="1" /></label></div>
        <label><span>Selo do cardápio</span><input v-model="recipeForm.menuBadge" maxlength="32" placeholder="Novidade, edição limitada..." /></label>
        <section class="product-settings-editor">
          <div class="product-type-field">
            <span>Tipo do produto</span>
            <div class="product-type-options">
              <button type="button" :class="{ active: recipeForm.productType === 'food' }" @click="recipeForm.productType = 'food'"><Sandwich :size="15" /> Comida</button>
              <button type="button" :class="{ active: recipeForm.productType === 'drink' }" @click="recipeForm.productType = 'drink'"><Droplets :size="15" /> Bebida</button>
            </div>
          </div>
          <label><span>Quantidade produzida</span><input v-model="recipeForm.outputAmount" type="number" min="1" /></label>
          <label><span>Peso por unidade (g)</span><input v-model="recipeForm.itemWeight" type="number" min="10" max="5000" /></label>
        </section>
        <section v-if="presentationOptions.length" class="presentation-editor">
          <header><div><small>Apresentação ao consumir</small><strong>Escolha a prop desta refeição</strong></div></header>
          <div class="presentation-options">
            <button type="button" :class="{ active: !recipeForm.presentationKey }" @click="recipeForm.presentationKey = ''">
              <span class="presentation-image"><Utensils :size="20" /></span>
              <span><b>Automático</b><small>Padrão de {{ recipeForm.productType === 'drink' ? 'bebida' : 'comida' }}</small></span>
            </button>
            <button v-for="presentation in presentationOptions" :key="presentation.key" type="button" :class="{ active: recipeForm.presentationKey === presentation.key }" @click="recipeForm.presentationKey = presentation.key">
              <span class="presentation-image"><img v-if="presentation.image" :src="presentation.image" alt="" /><Utensils v-else :size="20" /></span>
              <span><b>{{ presentation.label }}</b><small>{{ presentation.animationLabel || (presentation.type === 'drink' ? 'Beber' : 'Comer') }}</small></span>
            </button>
          </div>
        </section>
        <section class="recipe-effects-editor">
          <header><div><small>Efeitos ao consumir</small><strong>Status da receita</strong></div><span>{{ selectedEffectCount }}/{{ effectLimits.maxSelected }}</span></header>
          <div class="recipe-effects-grid">
            <article v-for="effect in recipeEffectOptions" :key="effect.key" :class="{ active: effectEnabled(effect.key), locked: !effectEnabled(effect.key) && selectedEffectCount >= effectLimits.maxSelected }">
              <label class="recipe-effect-switch">
                <input type="checkbox" :checked="effectEnabled(effect.key)" :disabled="!effectEnabled(effect.key) && selectedEffectCount >= effectLimits.maxSelected" @change="toggleEffect(effect.key)" />
                <component :is="effect.icon" :size="17" />
                <span><strong>{{ effect.label }}</strong><small>{{ effect.detail }}</small></span>
              </label>
              <label v-if="effectEnabled(effect.key)" class="recipe-effect-amount"><input v-model.number="recipeForm.effects[effect.key]" type="number" min="1" :max="effectLimits.maxAmount" @change="clampEffect(effect.key)" /><span>%</span></label>
            </article>
          </div>
        </section>
        <label><span>Imagem opcional</span><input v-model="recipeForm.image" placeholder="https://... ou caminho NUI" /></label>
        <section class="item-rows-editor">
          <header><div><small>Ingredientes necessários</small><strong>Selecione os itens e informe as quantidades</strong></div><button type="button" @click="addItemRow(recipeForm.ingredients)"><Plus :size="14" /> Ingrediente</button></header>
          <div class="item-rows-list">
            <article v-for="(ingredient, index) in recipeForm.ingredients" :key="`ingredient-${index}`">
              <label class="item-code-field"><span>Item do inventário</span><input v-model.trim="ingredient.item" list="restaurant-inventory-items" placeholder="Digite para pesquisar" @input="syncItemLabel(ingredient)" /><small>{{ registeredItemLabel(ingredient.item) }}</small></label>
              <label><span>Nome na receita</span><input v-model.trim="ingredient.label" placeholder="Preenchido automaticamente" /></label>
              <label class="item-amount-field"><span>Quantidade</span><input v-model.number="ingredient.amount" type="number" min="1" /></label>
              <button type="button" title="Remover ingrediente" @click="removeItemRow(recipeForm.ingredients, index)"><Trash2 :size="15" /></button>
            </article>
            <p v-if="!recipeForm.ingredients.length">Nenhum ingrediente adicionado.</p>
          </div>
        </section>
        <section class="craft-flow-editor">
          <header><div><small>Roteiro de animações</small><strong>O que o funcionário fará durante o preparo</strong></div><span>{{ recipeForm.craftSteps.length }}/8 etapas</span></header>
          <div class="craft-action-picker">
            <button v-for="action in craftActionOptions" :key="action.value" type="button" :disabled="recipeForm.craftSteps.length >= 8" @click="addCraftStep(action.value)"><Plus :size="13" /> {{ action.label }}</button>
          </div>
          <div v-if="recipeForm.craftSteps.length" class="craft-step-list">
            <article v-for="(step, index) in recipeForm.craftSteps" :key="`${step}-${index}`">
              <b>{{ String(index + 1).padStart(2, '0') }}</b><div><strong>{{ craftAction(step).label }}</strong><small>{{ craftAction(step).detail }}</small></div>
              <button type="button" title="Subir etapa" :disabled="index === 0" @click="moveCraftStep(index, -1)"><ArrowUp :size="13" /></button>
              <button type="button" title="Descer etapa" :disabled="index === recipeForm.craftSteps.length - 1" @click="moveCraftStep(index, 1)"><ArrowDown :size="13" /></button>
              <button type="button" title="Remover etapa" @click="removeCraftStep(index)"><Trash2 :size="13" /></button>
            </article>
          </div>
          <p v-else>Sem etapas: o craft usará o fluxo automático da categoria.</p>
        </section>
        <section v-if="recipeForm.isCombo" class="item-rows-editor combo-contents-editor">
          <header><div><small>Conteúdo da box</small><strong>Itens informados na descrição do combo</strong></div><button type="button" @click="addItemRow(recipeForm.contents)"><Plus :size="14" /> Item</button></header>
          <div class="item-rows-list">
            <article v-for="(content, index) in recipeForm.contents" :key="`content-${index}`">
              <label class="item-code-field"><span>Item do inventário</span><input v-model.trim="content.item" list="restaurant-inventory-items" placeholder="Digite para pesquisar" @input="syncItemLabel(content)" /><small>{{ registeredItemLabel(content.item) }}</small></label>
              <label><span>Nome exibido</span><input v-model.trim="content.label" placeholder="Preenchido automaticamente" /></label>
              <label class="item-amount-field"><span>Quantidade</span><input v-model.number="content.amount" type="number" min="1" /></label>
              <button type="button" title="Remover item" @click="removeItemRow(recipeForm.contents, index)"><Trash2 :size="15" /></button>
            </article>
            <p v-if="!recipeForm.contents.length">Nenhum conteúdo adicional informado.</p>
          </div>
        </section>
        <div class="toggle-row"><label><input v-model="recipeForm.isCombo" type="checkbox" /> É uma box ou combo</label><label><input v-model="recipeForm.featured" type="checkbox" /> Destaque da casa</label><label><input v-model="recipeForm.enabled" type="checkbox" /> Disponível no cardápio</label></div>
        <button class="primary-command" :disabled="saving" @click="saveRecipe"><Save :size="17" /> Salvar receita</button>
      </section>
      <section class="admin-section recipe-library">
        <header><Utensils :size="19" /><div><small>Catálogo atual</small><h3>{{ payload.recipes.length }} receitas</h3></div></header>
        <div class="recipe-library-list">
          <article v-for="recipe in payload.recipes" :key="recipe.id"><div><b>{{ recipe.name }}</b><small>{{ recipe.product_type === 'drink' ? 'Bebida' : 'Comida' }} · {{ money(recipe.price) }} · {{ stepKeys(recipe.craft_steps).length || 'auto' }} etapas</small></div><button title="Editar" @click="editRecipe(recipe)"><Pencil :size="16" /></button><button title="Excluir" :disabled="deletingRecipeId === recipe.id" @click="deleteRecipe(recipe)"><Trash2 :size="16" /></button></article>
        </div>
      </section>
      <section class="admin-section category-editor">
        <header><Plus :size="19" /><div><small>Organização</small><h3>Adicionar categoria</h3></div></header>
        <div class="form-row category-identity-row">
          <label><span>Identificador</span><input v-model="categoryForm.key" placeholder="sobremesas" /></label>
          <label><span>Nome</span><input v-model="categoryForm.label" placeholder="Sobremesas" required /></label>
          <label class="category-order-field" title="Categorias com números menores aparecem primeiro"><span>Posição no cardápio</span><input v-model="categoryForm.sortOrder" type="number" min="0" step="1" /></label>
        </div>
        <label class="category-icon-field"><span>Ícone da categoria</span>
          <div class="category-icon-picker" role="listbox" aria-label="Escolher ícone da categoria">
            <button v-for="option in categoryIcons" :key="option.value" type="button" :class="{ active: categoryForm.icon === option.value }" :title="option.label" :aria-label="option.label" :aria-selected="categoryForm.icon === option.value" @click="categoryForm.icon = option.value">
              <DynamicIcon :name="option.value" :size="19" /><small>{{ option.label }}</small>
            </button>
          </div>
        </label>
        <button class="secondary-command" :disabled="!categoryForm.label.trim() || !categoryForm.key.trim()" @click="saveCategory">Salvar categoria</button>
        <div class="category-list">
          <article v-for="category in activeCategories" :key="category.category_key">
            <span><DynamicIcon :name="category.icon" :size="17" /></span>
            <div><b>{{ category.label }}</b><small>{{ payload.recipes.filter((recipe) => recipe.enabled !== false && recipe.category_key === category.category_key).length }} receita(s)</small></div>
            <button :title="`Remover ${category.label}`" @click="deleteCategory(category)"><Trash2 :size="15" /></button>
          </article>
        </div>
      </section>
    </div>

    <div v-else class="admin-scroll points-admin">
      <section class="admin-section point-editor">
        <header><MapPin :size="19" /><div><small>{{ pointForm.id ? 'Reposicionar ponto' : 'Novo ponto' }}</small><h3>Usar minha posição atual</h3></div><button v-if="pointForm.id" class="text-command" @click="resetPoint">Novo</button></header>
        <label><span>Tipo de interação</span><select v-model="pointForm.type"><option value="pos">Caixa de pedidos</option><option value="kitchen">Painel da cozinha</option><option value="production">Estação de receitas clássica</option><option value="cutting">Bancada de preparo e corte</option><option value="stove">Fogão e chapa</option><option value="drinks">Estação de bebidas</option><option value="assembly">Montagem de pedidos</option><option value="menu">Cardápio para clientes</option><option value="terminal">Maquininha</option><option value="display">Telão de chamadas</option><option value="admin">Administração</option></select></label>
        <label><span>Nome do ponto</span><input v-model="pointForm.label" placeholder="Caixa principal" /></label>
        <button class="primary-command" @click="savePoint"><MapPin :size="17" /> {{ pointForm.id ? 'Atualizar nesta posição' : 'Criar nesta posição' }}</button>
      </section>
      <section class="admin-section point-list">
        <header><MapPin :size="19" /><div><small>Interações cadastradas</small><h3>{{ payload.points?.length || 0 }} pontos</h3></div></header>
        <article v-for="point in payload.points" :key="point.id"><span><MapPin :size="18" /></span><div><b>{{ point.label }}</b><small>{{ point.type }} · {{ Number(point.coords?.x || 0).toFixed(1) }}, {{ Number(point.coords?.y || 0).toFixed(1) }}</small></div><button title="Reposicionar" @click="editPoint(point)"><Pencil :size="16" /></button><button title="Remover" @click="deletePoint(point)"><Trash2 :size="16" /></button></article>
      </section>
    </div>
  </section>
</template>
