<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from "vue";
import { BellRing, ChefHat, Flame, LayoutDashboard, RefreshCw, ShoppingCart, X } from "lucide-vue-next";
import emblem from "./assets/obscuria-emblem.png";
import AdminView from "./components/AdminView.vue";
import KitchenView from "./components/KitchenView.vue";
import MenuView from "./components/MenuView.vue";
import PosView from "./components/PosView.vue";
import ProductionView from "./components/ProductionView.vue";
import PublicDisplay from "./components/PublicDisplay.vue";
import TerminalView from "./components/TerminalView.vue";
import { closeNui, nuiRequest, previewContext, previewMode, previewPayload } from "./nui";
import { queueAnnouncement } from "./tts";

const previewDisplay = previewMode && new URLSearchParams(window.location.search).get("display") === "1";
const visible = ref(previewMode && !previewDisplay);
const loading = ref(false);
const mode = ref(previewPayload.mode || "pos");
const payload = ref(previewMode ? previewPayload : null);
const context = ref(previewMode ? previewContext : { restaurantId: previewPayload.restaurant.id, pointId: null });
const displayPayload = ref(previewMode ? { restaurant: previewPayload.restaurant, orders: previewPayload.orders } : null);
const displayVisible = ref(previewDisplay);
const displayRequestedVisible = ref(previewDisplay);
const announcementSpeaking = ref(false);
const toast = ref(null);
const announcement = ref(null);
let toastTimer;
let refreshTimer;

const views = { pos: PosView, kitchen: KitchenView, production: ProductionView, menu: MenuView, terminal: TerminalView, admin: AdminView };
const currentView = computed(() => views[mode.value] || PosView);
const isCustomerTerminal = computed(() => mode.value === "terminal");
const isPublicMenu = computed(() => mode.value === "menu");
const isPointInterface = computed(() => context.value?.pointId != null && !isCustomerTerminal.value && !isPublicMenu.value);
const focusedMeta = computed(() => ({
  pos: { eyebrow: "Atendimento", title: "Caixa de pedidos" },
  kitchen: { eyebrow: "Produção", title: "Painel da cozinha" },
  production: { eyebrow: "Preparo", title: "Estação de receitas" },
  admin: { eyebrow: "Gerência", title: "Administração" },
}[mode.value] || { eyebrow: "Restaurante", title: "Operação" }));
const navigation = computed(() => {
  const items = [];
  if (payload.value?.permissions?.work) {
    items.push(
      { id: "pos", label: "Caixa", hint: "Pedidos e catálogo", icon: ShoppingCart },
      { id: "kitchen", label: "Cozinha", hint: "Fila de produção", icon: ChefHat },
      { id: "production", label: "Receitas", hint: "Bancada e inventário", icon: Flame },
    );
  }
  if (payload.value?.permissions?.manage) items.push({ id: "admin", label: "Gestão", hint: "Financeiro e ajustes", icon: LayoutDashboard });
  return items;
});

const errorMessages = {
  not_employee: "Você não está em serviço neste restaurante.",
  not_manager: "Apenas a gerência pode acessar esta área.",
  invalid_items: "Os itens do pedido não são válidos.",
  invalid_total: "O valor informado não é válido.",
  invalid_payment: "Esta cobrança não é válida.",
  invalid_payment_method: "Escolha Dinheiro ou Banco antes de emitir a cobrança.",
  customer_required: "Selecione um cliente próximo.",
  customer_not_nearby: "O cliente precisa permanecer próximo.",
  payment_unavailable: "Esta cobrança expirou ou já foi paga.",
  payment_processing_failed: "O pagamento não foi concluído. O valor foi devolvido; tente novamente.",
  wrong_customer: "Esta cobrança pertence a outro cliente.",
  terminal_too_far: "Aproxime-se da maquininha para concluir.",
  insufficient_money: "Saldo insuficiente nesta forma de pagamento.",
  missing_ingredient: "Faltam ingredientes para esta receita.",
  inventory_full: "Não há espaço suficiente no inventário.",
  not_ready: "O preparo ainda não terminou.",
  invalid_transition: "Este pedido já mudou de etapa.",
  ingredients_required: "Cadastre ao menos um ingrediente.",
  invalid_recipe: "Preencha os dados obrigatórios da receita.",
  invalid_recipe_effect: "Defina cada efeito entre 1% e o limite permitido.",
  too_many_recipe_effects: "Cada receita pode alterar no máximo dois status.",
  recipe_effect_item_not_supported: "Este item de saída não está configurado como consumível do restaurante.",
  invalid_category: "Preencha os dados obrigatórios da categoria.",
  category_not_found: "Escolha uma categoria ativa para esta receita.",
  nui_unavailable: "Não foi possível comunicar com a resource.",
  server_error: "O servidor recusou a operação. Consulte o console.",
};

function feedback(message, type = "info") {
  window.clearTimeout(toastTimer);
  toast.value = { message: errorMessages[message] || message || "Operação não concluída.", type };
  toastTimer = window.setTimeout(() => { toast.value = null; }, 3800);
}

async function load(nextMode = mode.value) {
  if (!payload.value?.restaurant?.id && !context.value.restaurantId) return;
  loading.value = true;
  const result = await nuiRequest("bootstrap", { mode: nextMode, restaurantId: payload.value?.restaurant?.id || context.value.restaurantId });
  loading.value = false;
  if (!result.ok) return feedback(result.error, "error");
  mode.value = nextMode;
  payload.value = result;
}

async function switchMode(nextMode) {
  if (nextMode === mode.value) return;
  await load(nextMode);
}

function scheduleRefresh() {
  window.clearTimeout(refreshTimer);
  refreshTimer = window.setTimeout(() => load(mode.value), 180);
}

async function close() {
  visible.value = false;
  payload.value = null;
  await closeNui();
}

function onMessage(event) {
  const data = event.data || {};
  if (data.action === "open") {
    context.value = data.context || {};
    payload.value = data.payload;
    mode.value = data.payload?.mode || data.context?.mode || "pos";
    visible.value = true;
    nextTick(() => document.querySelector(".restaurant-shell, .point-shell, .public-menu-shell, .customer-payment-shell")?.focus());
  } else if (data.action === "close") {
    visible.value = false;
    payload.value = null;
  } else if (data.action === "serverUpdate") {
    scheduleRefresh();
  } else if (data.action === "display") {
    displayRequestedVisible.value = data.visible === true && (data.payload?.orders?.length || 0) > 0;
    if (displayRequestedVisible.value) {
      displayPayload.value = data.payload;
      displayVisible.value = true;
    } else if (!announcementSpeaking.value) {
      displayVisible.value = false;
      displayPayload.value = null;
    }
  } else if (data.action === "announcement") {
    queueAnnouncement(data.payload, {
      onStart(item) {
        announcement.value = item;
        announcementSpeaking.value = true;
        if (displayPayload.value?.orders?.length) displayVisible.value = true;
      },
      onEnd(item, state) {
        if (announcement.value?.id === item.id) announcement.value = null;
        announcementSpeaking.value = state.hasNext;
        if (!state.hasNext && !displayRequestedVisible.value) {
          displayVisible.value = false;
          displayPayload.value = null;
        }
      },
    });
  } else if (data.action === "feedback") {
    feedback(data.code || data.message, data.type || "info");
  }
}

function onKey(event) {
  if (event.key === "Escape" && visible.value) close();
}

onMounted(() => {
  window.addEventListener("message", onMessage);
  window.addEventListener("keydown", onKey);
});
onBeforeUnmount(() => {
  window.removeEventListener("message", onMessage);
  window.removeEventListener("keydown", onKey);
  window.clearTimeout(toastTimer);
  window.clearTimeout(refreshTimer);
});
</script>

<template>
  <div v-if="displayVisible || announcement" class="public-display-stack">
    <PublicDisplay v-if="displayVisible" :payload="displayPayload" />
    <Transition name="announcement">
      <div v-if="announcement" class="announcement-banner"><BellRing :size="20" /><span>{{ announcement.message }}</span></div>
    </Transition>
  </div>

  <Transition name="interface">
    <section v-if="visible && payload && isCustomerTerminal" class="customer-payment-shell" tabindex="-1">
      <button class="receipt-close" title="Fechar" @click="close"><X :size="18" /></button>
      <TerminalView :payload="payload" @feedback="feedback" @refresh="scheduleRefresh" />
    </section>

    <main v-else-if="visible && payload && isPublicMenu" class="public-menu-shell" tabindex="-1">
      <header class="public-menu-brand">
        <img :src="emblem" alt="" />
        <div><small>{{ payload.restaurant.label }}</small><strong>Cardápio público</strong></div>
        <button class="close-command" title="Fechar" @click="close"><X :size="20" /></button>
      </header>
      <MenuView :payload="payload" />
    </main>

    <main v-else-if="visible && payload && isPointInterface" class="point-shell" tabindex="-1">
      <header class="point-shell-header">
        <div class="point-shell-brand"><img :src="emblem" alt="" /><span><small>{{ payload.restaurant.label }}</small><strong>{{ focusedMeta.title }}</strong></span></div>
        <div class="point-shell-status"><span><i />{{ focusedMeta.eyebrow }}</span><button class="icon-command" title="Atualizar" @click="load(mode)"><RefreshCw :size="18" /></button><button class="close-command" title="Fechar" @click="close"><X :size="20" /></button></div>
      </header>
      <section class="point-shell-content"><component :is="currentView" :payload="payload" @feedback="feedback" @refresh="scheduleRefresh" /></section>
    </main>

    <main v-else-if="visible && payload" class="restaurant-shell" tabindex="-1">
      <aside class="restaurant-sidebar">
        <header class="restaurant-brand">
          <img :src="emblem" alt="" />
          <div><small>Obscuria</small><strong>{{ payload.restaurant.label }}</strong></div>
        </header>
        <div class="operator-card"><span>{{ payload.player.name.slice(0, 1).toUpperCase() }}</span><div><small>Atendente</small><b>{{ payload.player.name }}</b><em>{{ payload.player.job.label }}</em></div></div>
        <nav class="restaurant-navigation">
          <small>Operação</small>
          <button v-for="item in navigation" :key="item.id" :class="{ active: mode === item.id }" @click="switchMode(item.id)">
            <component :is="item.icon" :size="19" />
            <span><b>{{ item.label }}</b><small>{{ item.hint }}</small></span>
          </button>
        </nav>
        <footer><span>Comissão por venda</span><strong>{{ Math.round((payload.commissionRate || 0.3) * 100) }}%</strong><small>Creditada somente após o pagamento.</small></footer>
      </aside>

      <section class="restaurant-content">
        <header class="content-header">
          <div><small>{{ payload.restaurant.label }}</small><h1>{{ navigation.find((item) => item.id === mode)?.label || "Restaurante" }}</h1></div>
          <div class="content-actions"><span class="connection-state"><i />Operação online</span><button class="icon-command" title="Atualizar" :disabled="loading" @click="load(mode)"><RefreshCw :size="18" /></button><button class="close-command" title="Fechar" @click="close"><X :size="20" /></button></div>
        </header>
        <component :is="currentView" :payload="payload" @feedback="feedback" @refresh="scheduleRefresh" />
      </section>
      <div class="ornament-corner top-left" /><div class="ornament-corner bottom-right" />
    </main>
  </Transition>

  <Transition name="toast"><div v-if="toast" :class="['restaurant-toast', toast.type]">{{ toast.message }}</div></Transition>
</template>
