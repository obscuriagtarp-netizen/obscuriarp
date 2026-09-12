<script setup>
import { computed, onBeforeUnmount, ref } from "vue";
import { Check, Clock3, PackageCheck, RefreshCw } from "lucide-vue-next";
import DynamicIcon from "./DynamicIcon.vue";
import { nuiRequest } from "../nui";

const props = defineProps({ payload: { type: Object, required: true } });
const emit = defineEmits(["feedback", "refresh"]);
const activeCategory = ref("all");
const busy = ref(null);
const tick = ref(Date.now());
const timer = window.setInterval(() => { tick.value = Date.now(); }, 500);
onBeforeUnmount(() => window.clearInterval(timer));

const categories = computed(() => (props.payload.categories || []).filter((category) => category.enabled !== false));
const activeCategoryKeys = computed(() => new Set(categories.value.map((category) => category.category_key)));
const recipes = computed(() => (props.payload.recipes || []).filter((recipe) => recipe.enabled !== false
  && activeCategoryKeys.value.has(recipe.category_key)
  && (activeCategory.value === "all" || recipe.category_key === activeCategory.value)));
function ready(production) { return new Date(production.ready_at).getTime() <= tick.value; }

async function start(recipe) {
  busy.value = recipe.id;
  const result = await nuiRequest("startProduction", { restaurantId: props.payload.restaurant.id, recipeId: recipe.id });
  busy.value = null;
  if (!result.ok) return emit("feedback", result.error === "missing_ingredient" ? `Ingrediente insuficiente: ${result.item}.` : result.error, "error");
  emit("feedback", `${recipe.name} entrou em preparo.`, "success");
  window.setTimeout(() => emit("refresh"), 250);
}

async function collect(production) {
  busy.value = `p-${production.id}`;
  const result = await nuiRequest("collectProduction", { productionId: production.id });
  busy.value = null;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", "Produto recolhido e enviado ao inventário.", "success");
  emit("refresh");
}
</script>

<template>
  <div class="production-layout">
    <section class="production-catalog">
      <header class="section-toolbar"><div><small>Estação de preparo</small><h2>Receitas disponíveis</h2></div></header>
      <nav class="category-tabs"><button :class="{ active: activeCategory === 'all' }" @click="activeCategory = 'all'">Todas</button><button v-for="category in categories" :key="category.category_key" :class="{ active: activeCategory === category.category_key }" @click="activeCategory = category.category_key">{{ category.label }}</button></nav>
      <div class="production-grid">
        <article v-for="recipe in recipes" :key="recipe.id" class="production-recipe">
          <header><span><DynamicIcon :name="recipe.icon" :size="26" /></span><div><b>{{ recipe.name }}</b><small>{{ recipe.prep_time }} segundos</small></div></header>
          <p>{{ recipe.description }}</p>
          <ul><li v-for="ingredient in recipe.ingredients" :key="ingredient.item"><Check :size="13" /> {{ ingredient.amount }}x {{ ingredient.label || ingredient.item }}</li></ul>
          <button :disabled="busy === recipe.id" @click="start(recipe)">{{ busy === recipe.id ? "Iniciando..." : "Preparar receita" }}</button>
        </article>
      </div>
    </section>
    <aside class="production-queue">
      <header><Clock3 :size="19" /><div><small>Minha bancada</small><h3>Preparos ativos</h3></div><button class="icon-command" title="Atualizar" @click="$emit('refresh')"><RefreshCw :size="16" /></button></header>
      <article v-for="production in payload.productions" :key="production.id">
        <DynamicIcon :name="production.icon" :size="22" />
        <div><b>{{ production.recipe_name }}</b><small>{{ ready(production) ? "Pronto para recolher" : "Em preparação" }}</small></div>
        <button :disabled="!ready(production) || busy === `p-${production.id}`" @click="collect(production)"><PackageCheck :size="16" /></button>
      </article>
      <div v-if="!payload.productions?.length" class="empty-compact">Nenhum preparo ativo.</div>
    </aside>
  </div>
</template>
