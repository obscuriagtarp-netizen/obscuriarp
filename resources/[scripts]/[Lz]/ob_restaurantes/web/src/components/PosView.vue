<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { Banknote, CreditCard, Minus, Plus, Search, ShoppingCart, Trash2, UserRound } from "lucide-vue-next";
import DynamicIcon from "./DynamicIcon.vue";
import { nuiRequest } from "../nui";

const props = defineProps({ payload: { type: Object, required: true } });
const emit = defineEmits(["feedback", "refresh"]);
const activeCategory = ref("all");
const search = ref("");
const cart = ref([]);
const customers = ref([]);
const customerSource = ref("");
const customerName = ref("");
const notes = ref("");
const paymentAccount = ref("bank");
const busy = ref(false);
const recipeImageErrors = reactive({});

const categories = computed(() => (props.payload.categories || []).filter((category) => category.enabled !== false));
const recipes = computed(() => (props.payload.recipes || []).filter((recipe) => recipe.enabled !== false));
const filtered = computed(() => recipes.value.filter((recipe) => {
  const categoryMatches = activeCategory.value === "all" || recipe.category_key === activeCategory.value;
  const term = search.value.trim().toLowerCase();
  return categoryMatches && (!term || `${recipe.name} ${recipe.description}`.toLowerCase().includes(term));
}));
const total = computed(() => cart.value.reduce((sum, item) => sum + item.price * item.amount, 0));
const itemCount = computed(() => cart.value.reduce((sum, item) => sum + item.amount, 0));

function money(value) { return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`; }
function add(recipe) {
  const existing = cart.value.find((item) => item.recipeId === recipe.id);
  if (existing) existing.amount += 1;
  else cart.value.push({ recipeId: recipe.id, name: recipe.name, price: Number(recipe.price), amount: 1 });
}
function adjust(item, direction) {
  item.amount += direction;
  if (item.amount <= 0) cart.value = cart.value.filter((entry) => entry !== item);
}

async function loadCustomers() {
  const result = await nuiRequest("nearbyCustomers");
  customers.value = result.customers || [];
}

async function finishOrder() {
  if (!cart.value.length) return emit("feedback", "Adicione ao menos um item ao pedido.", "error");
  if (!customerSource.value && !customerName.value.trim()) return emit("feedback", "Selecione o cliente ou informe um nome.", "error");
  busy.value = true;
  const result = await nuiRequest("createOrder", {
    restaurantId: props.payload.restaurant.id,
    customerSource: customerSource.value ? Number(customerSource.value) : null,
    customerName: customerName.value,
    notes: notes.value,
    account: paymentAccount.value,
    items: cart.value.map((item) => ({ recipeId: item.recipeId, amount: item.amount })),
  });
  busy.value = false;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", `Pedido ${result.publicCode} criado. Cobrança enviada para a maquininha.`, "success");
  cart.value = [];
  notes.value = "";
  customerSource.value = "";
  customerName.value = "";
  emit("refresh");
}

onMounted(loadCustomers);
</script>

<template>
  <div class="pos-layout">
    <section class="catalog-pane">
      <header class="section-toolbar">
        <div>
          <small>Catálogo</small>
          <h2>Monte o pedido</h2>
        </div>
        <label class="search-box"><Search :size="17" /><input v-model="search" placeholder="Buscar item" /></label>
      </header>
      <nav class="category-tabs">
        <button :class="{ active: activeCategory === 'all' }" @click="activeCategory = 'all'"><DynamicIcon name="store" :size="17" /> Todos</button>
        <button v-for="category in categories" :key="category.category_key" :class="{ active: activeCategory === category.category_key }" @click="activeCategory = category.category_key">
          <DynamicIcon :name="category.icon" :size="17" /> {{ category.label }}
        </button>
      </nav>
      <div class="recipe-grid">
        <button v-for="recipe in filtered" :key="recipe.id" class="recipe-tile" :class="{ 'without-image': !recipe.image || recipeImageErrors[recipe.id] }" @click="add(recipe)">
          <span v-if="recipe.image && !recipeImageErrors[recipe.id]" class="recipe-visual">
            <img :src="recipe.image" :alt="recipe.name" @error="recipeImageErrors[recipe.id] = true" />
          </span>
          <span class="recipe-copy"><b>{{ recipe.name }}</b><small>{{ recipe.description }}</small></span>
          <strong>{{ money(recipe.price) }}</strong>
          <Plus class="recipe-add" :size="18" />
        </button>
      </div>
    </section>

    <aside class="order-pane">
      <header><ShoppingCart :size="20" /><div><small>Comanda atual</small><h2>{{ itemCount }} {{ itemCount === 1 ? "item" : "itens" }}</h2></div></header>
      <div class="customer-fields">
        <label><span><UserRound :size="14" /> Cliente próximo</span><select v-model="customerSource" @focus="loadCustomers"><option value="">Informar pelo nome</option><option v-for="customer in customers" :key="customer.source" :value="customer.source">{{ customer.name }}</option></select></label>
        <label v-if="!customerSource"><span>Nome para chamada</span><input v-model="customerName" maxlength="70" placeholder="Nome do cliente" /></label>
      </div>
      <div class="cart-lines">
        <article v-for="item in cart" :key="item.recipeId" class="cart-line">
          <div><b>{{ item.name }}</b><small>{{ money(item.price * item.amount) }}</small></div>
          <div class="stepper"><button @click="adjust(item, -1)"><Minus :size="14" /></button><span>{{ item.amount }}</span><button @click="adjust(item, 1)"><Plus :size="14" /></button></div>
        </article>
        <div v-if="!cart.length" class="empty-state"><Trash2 :size="28" /><b>Pedido vazio</b><span>Selecione os produtos no catálogo.</span></div>
      </div>
      <label class="notes-field"><span>Observações da cozinha</span><textarea v-model="notes" maxlength="500" placeholder="Ponto da carne, retirar ingrediente..." /></label>
      <div class="payment-choice">
        <span>Forma combinada com o cliente</span>
        <div>
          <button :class="{ active: paymentAccount === 'cash' }" @click="paymentAccount = 'cash'"><Banknote :size="15" /> Dinheiro</button>
          <button :class="{ active: paymentAccount === 'bank' }" @click="paymentAccount = 'bank'"><CreditCard :size="15" /> Banco</button>
        </div>
      </div>
      <footer class="order-total"><span>Total do pedido</span><strong>{{ money(total) }}</strong><small>{{ Math.round((payload.commissionRate || 0.3) * 100) }}% de comissão ao atendente após o pagamento</small><button class="primary-command" :disabled="busy || !cart.length" @click="finishOrder">{{ busy ? "Enviando..." : "Emitir comanda" }}</button></footer>
    </aside>
  </div>
</template>
