<script setup>
import { computed, reactive, ref } from "vue";
import { Clock3, Flame, Sparkles } from "lucide-vue-next";
import DynamicIcon from "./DynamicIcon.vue";

const props = defineProps({ payload: { type: Object, required: true } });
const activeCategory = ref("all");
const imageErrors = reactive({});

const popularIds = computed(() => new Set(props.payload.menu?.popularRecipeIds || []));
const recipes = computed(() => (props.payload.recipes || [])
  .filter((recipe) => recipe.enabled !== false)
  .sort((left, right) => {
    const leftPriority = (left.featured ? 2 : 0) + (popularIds.value.has(left.id) ? 1 : 0);
    const rightPriority = (right.featured ? 2 : 0) + (popularIds.value.has(right.id) ? 1 : 0);
    return rightPriority - leftPriority || String(left.name).localeCompare(String(right.name), "pt-BR");
  }));
const categories = computed(() => (props.payload.categories || [])
  .filter((category) => category.enabled !== false)
  .map((category) => ({
    ...category,
    amount: recipes.value.filter((recipe) => recipe.category_key === category.category_key).length,
  }))
  .filter((category) => category.amount > 0));
const visibleRecipes = computed(() => activeCategory.value === "all"
  ? recipes.value
  : recipes.value.filter((recipe) => recipe.category_key === activeCategory.value));

function money(value) {
  return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`;
}

function categoryName(categoryKey) {
  return categories.value.find((category) => category.category_key === categoryKey)?.label || "Especial da casa";
}
</script>

<template>
  <section class="menu-catalog-view">
    <header class="menu-catalog-intro">
      <div>
        <small>Seleção da casa</small>
        <h2>Escolha o seu pedido</h2>
        <p>Receitas preparadas na hora, organizadas para uma consulta rápida.</p>
      </div>
      <span><Clock3 :size="15" /> Preparo sob demanda</span>
    </header>

    <nav class="menu-category-tabs" aria-label="Categorias do cardápio">
      <button type="button" :class="{ active: activeCategory === 'all' }" @click="activeCategory = 'all'">
        <Sparkles :size="17" /><span><b>Todos</b><small>{{ recipes.length }} opções</small></span>
      </button>
      <button v-for="category in categories" :key="category.category_key" type="button" :class="{ active: activeCategory === category.category_key }" @click="activeCategory = category.category_key">
        <DynamicIcon :name="category.icon" :size="17" /><span><b>{{ category.label }}</b><small>{{ category.amount }} {{ category.amount === 1 ? 'opção' : 'opções' }}</small></span>
      </button>
    </nav>

    <div class="menu-catalog-scroll">
      <div v-if="visibleRecipes.length" class="menu-product-grid">
        <article v-for="recipe in visibleRecipes" :key="recipe.id" :class="{ featured: recipe.featured, 'without-image': !recipe.image || imageErrors[recipe.id] }">
          <div class="menu-product-copy">
            <div class="menu-product-labels">
              <span v-if="recipe.menu_badge" class="custom-badge"><Sparkles :size="11" />{{ recipe.menu_badge }}</span>
              <span v-else-if="popularIds.has(recipe.id)" class="popular-badge"><Flame :size="11" />Mais pedido</span>
              <small>{{ categoryName(recipe.category_key) }}</small>
            </div>
            <h3>{{ recipe.name }}</h3>
            <p>{{ recipe.description || 'Preparado especialmente pela casa.' }}</p>
            <div class="menu-product-price">
              <span><small>Preço</small><strong>{{ money(recipe.price) }}</strong></span>
              <del v-if="Number(recipe.old_price) > Number(recipe.price)">{{ money(recipe.old_price) }}</del>
            </div>
          </div>
          <figure v-if="recipe.image && !imageErrors[recipe.id]" class="menu-product-media">
            <img :src="recipe.image" :alt="recipe.name" loading="lazy" @error="imageErrors[recipe.id] = true" />
          </figure>
        </article>
      </div>
      <div v-else class="menu-catalog-empty">
        <DynamicIcon name="utensils" :size="28" />
        <strong>Nenhum item disponível</strong>
        <p>Esta categoria está sendo atualizada.</p>
      </div>
    </div>

    <footer class="menu-catalog-footer">
      <span>Valores sujeitos à disponibilidade</span>
      <strong>{{ payload.restaurant.label }}</strong>
    </footer>
  </section>
</template>
