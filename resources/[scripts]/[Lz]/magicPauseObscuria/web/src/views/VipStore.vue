<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import "../styles/vipstore.css";
import runeIcon from "../assets/imgs/runa-icon.png";

const props = defineProps({
  payload: {
    type: Object,
    default: null
  }
});
const emit = defineEmits(["refresh"]);
const previewParams = new URLSearchParams(window.location.search);
const previewMode = previewParams.get("preview") === "1";
const previewPanel = previewParams.get("vip") || "";

const view = ref("catalog");
const selectedCategory = ref("all");
const selectedProductId = ref("");
const confirmMode = ref("");
const detailProduct = ref(null);
const historyOpen = ref(false);
const dashboardOpen = ref(false);
const dashboardLoading = ref(false);
const dashboard = ref(null);
const dashboardTab = ref("overview");
const dashboardSearch = ref("");
const dashboardStatusFilter = ref("all");
const dashboardCouponDetails = ref("");
const vehicleRewardsOpen = ref(false);
const vehicleRedeemBusy = ref(0);
const failedVehicleImages = ref({});
const busy = ref(false);
const checkingPix = ref(false);
const feedback = ref(null);
const pixOrder = ref(null);
const pixPoll = ref(null);

const depositRunes = ref(250);
const depositInput = ref(250);
const couponCode = ref("");
const couponApplied = ref(false);
const couponInfo = ref(null);
const couponError = ref("");
const validatingCoupon = ref(false);
const couponRefreshTimer = ref(null);
const dashboardCoupon = ref({
  code: "",
  discountType: "percent",
  percent: 10,
  amount: 0,
  minRunes: 100,
  maxDiscount: 0,
  description: "",
  enabled: true
});

const store = computed(() => props.payload || {});
const products = computed(() => store.value.products || []);
const runeDeposit = computed(() => store.value.runeDeposit || { runesPerReal: 10, minimum: 10, maximum: 50000, step: 10, presets: [100, 250, 500, 1000, 2500, 5000] });
const categories = computed(() => [
  { id: "all", label: "Todos", icon: "fa-solid fa-layer-group" },
  ...(store.value.categories || [])
]);
const activeProducts = computed(() => {
  if (selectedCategory.value === "all") return products.value;
  return products.value.filter((product) => product.category === selectedCategory.value);
});
const selectedProduct = computed(() => {
  return products.value.find((product) => product.id === selectedProductId.value) || activeProducts.value[0] || products.value[0] || null;
});
const canUsePix = computed(() => store.value.pix?.enabled === true);
const depositEnabled = computed(() => runeDeposit.value.enabled !== false);
const originalPrice = computed(() => Number(depositRunes.value || 0) / Number(runeDeposit.value.runesPerReal || 10));
const finalPrice = computed(() => Math.max(0, couponApplied.value && couponInfo.value ? Number(couponInfo.value.final) : originalPrice.value));
const discountValue = computed(() => couponApplied.value && couponInfo.value ? Number(couponInfo.value.discount) || 0 : 0);
const dashboardStats = computed(() => dashboard.value?.stats || {});
const dashboardPayments = computed(() => dashboard.value?.payments || []);
const dashboardCoupons = computed(() => dashboard.value?.coupons || []);
const dashboardSearchTerm = computed(() => dashboardSearch.value.trim().toLowerCase());
const dashboardFilteredPayments = computed(() => {
  const term = dashboardSearchTerm.value;
  const status = dashboardStatusFilter.value;
  return dashboardPayments.value.filter((payment) => {
    const matchesStatus = status === "all" || String(payment.status || "").toLowerCase() === status;
    if (!matchesStatus) return false;
    if (!term) return true;
    return [
      payment.playerName,
      payment.passport,
      payment.id,
      payment.title,
      payment.coupon,
      payment.status
    ].some((value) => String(value || "").toLowerCase().includes(term));
  });
});
const dashboardRecentPayments = computed(() => dashboardFilteredPayments.value.slice(0, 8));
const dashboardTopCoupons = computed(() => {
  return [...dashboardCoupons.value]
    .sort((a, b) => (Number(b.usage?.count) || 0) - (Number(a.usage?.count) || 0))
    .slice(0, 5);
});
const dashboardSelectedCoupon = computed(() => {
  if (!dashboardCouponDetails.value) return null;
  return dashboardCoupons.value.find((coupon) => coupon.code === dashboardCouponDetails.value) || null;
});
const vehicleChoices = computed(() => store.value.vip?.vehicleChoices || []);

function vehicleImageKey(vehicle) {
  return `${vehicle.model || ""}:${vehicleImagePath(vehicle)}`;
}

function vehicleImagePath(vehicle) {
  const configured = String(vehicle.image || "").trim();
  if (configured && !/\/carro\.png$/i.test(configured)) return configured;

  const model = String(vehicle.model || "").trim();
  return model ? `web/imgs/vipstore/${model}.png` : "";
}

function vehicleHasImage(vehicle) {
  return Boolean(vehicleImagePath(vehicle)) && failedVehicleImages.value[vehicleImageKey(vehicle)] !== true;
}

function hideMissingVehicleImage(vehicle) {
  failedVehicleImages.value = {
    ...failedVehicleImages.value,
    [vehicleImageKey(vehicle)]: true
  };
}

function openVehicleRewards() {
  failedVehicleImages.value = {};
  vehicleRewardsOpen.value = true;
}

watch(
  [products, activeProducts],
  () => {
    if (!products.value.length) {
      selectedProductId.value = "";
      return;
    }
    if (!selectedProductId.value || !products.value.some((product) => product.id === selectedProductId.value)) {
      selectedProductId.value = activeProducts.value[0]?.id || products.value[0]?.id || "";
    }
  },
  { immediate: true }
);

watch(
  () => store.value.runeDeposit,
  () => {
    const presets = runeDeposit.value.presets || [];
    const value = presets[1] || runeDeposit.value.minimum || 10;
    depositRunes.value = value;
    depositInput.value = value;
  },
  { immediate: true }
);

watch(depositRunes, (value) => {
  depositInput.value = value;
  if (!couponApplied.value || !couponCode.value.trim()) return;
  if (couponRefreshTimer.value) window.clearTimeout(couponRefreshTimer.value);
  couponRefreshTimer.value = window.setTimeout(() => validateCoupon(true), 250);
});

watch(depositEnabled, (enabled) => {
  if (!enabled && view.value === "donate") view.value = "catalog";
});

watch(pixOrder, (order) => {
  if (order?.id) {
    startPixPolling();
  } else {
    stopPixPolling();
  }
});

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "MagicPause";
}

async function nui(eventName, data = {}) {
  if (previewMode) {
    const timestamp = Math.floor(Date.now() / 1000);
    if (eventName === "createRuneDepositOrder") {
      return {
        ok: true,
        message: "Pix de demonstração gerado.",
        status: "pending",
        order: {
          id: "preview-pix",
          copyPaste: "00020126580014BR.GOV.BCB.PIX0136preview-obscuria-runas-5204000053039865802BR5920OBSCURIA ROLEPLAY6009SAO PAULO62070503***6304ABCD"
        }
      };
    }
    if (eventName === "checkVipPixOrder") {
      return { ok: true, status: "pending", message: "Aguardando pagamento de demonstração." };
    }
    if (eventName === "getVipDashboard") {
      return {
        ok: true,
        message: "Dashboard carregado.",
        dashboard: {
          stats: {
            today: { total: 485, count: 4 },
            month: { total: 8240, count: 61 },
            total: { total: 28790, count: 214 },
            pending: 3,
            couponsUsed: 18
          },
          payments: [
            { id: 184, playerName: "Morgana Vale", passport: "1842", title: "Depósito de 2.500 Runas", amount: 250, currency: "BRL", coupon: "OBSCURIA10", status: "paid", createdAt: timestamp - 900, paidAt: timestamp - 840 },
            { id: 183, playerName: "Victor Salvatore", passport: "904", title: "Depósito de 1.000 Runas", amount: 100, currency: "BRL", coupon: "", status: "pending", createdAt: timestamp - 2400, paidAt: 0 },
            { id: 181, playerName: "Helena Blackwood", passport: "628", title: "Passe VIP", amount: 1000, currency: "runes", coupon: "", status: "paid", createdAt: timestamp - 5200, paidAt: timestamp - 5160 }
          ],
          coupons: [
            { code: "OBSCURIA10", description: "10% de desconto na contribuição", percent: 10, amount: 0, minRunes: 500, maxDiscount: 100, enabled: true, usage: { count: 18, runes: 24500, discount: 245, total: 2205 } },
            { code: "BOASVINDAS", description: "Bônus de entrada da cidade", percent: 5, amount: 0, minRunes: 100, maxDiscount: 30, enabled: false, usage: { count: 7, runes: 4200, discount: 21, total: 399 } }
          ]
        }
      };
    }
    if (["saveVipCoupon", "setVipCouponEnabled"].includes(eventName)) return { ok: true, message: "Prévia atualizada." };
    if (eventName === "redeemVipVehicle") {
      return { ok: true, message: `Prévia: ${data.model || "veículo"} enviado para a garagem.` };
    }
    return { ok: false, message: "Ação indisponível na prévia." };
  }

  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data)
  });
  return response.json().catch(() => ({}));
}

function money(value) {
  return Math.floor(Number(value) || 0).toLocaleString("pt-BR");
}

function brl(value) {
  return Number(value || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

function currency(value, currencyName = "BRL") {
  if (currencyName === "runes") return `${money(value)} Runas`;
  return brl(value);
}

function statusLabel(status) {
  return {
    paid: "Aprovado",
    pending: "Pendente",
    failed: "Falhou",
    cancelled: "Cancelado"
  }[String(status || "").toLowerCase()] || "Processando";
}

function assetUrl(value) {
  const path = String(value || "").trim();
  if (!path) return "";
  if (/^(https?:|data:|nui:)/i.test(path)) return path;
  if (previewMode && path.startsWith("web/")) return `/${path.slice(4)}`;
  return `nui://${resourceName()}/${path.replace(/^\/+/, "")}`;
}

function productTemplate(product = null) {
  return product?.template || store.value.productTemplate || "";
}

function productLayout(product = null) {
  return product?.layout === "landscape" ? "landscape" : "portrait";
}

function formatDate(timestamp) {
  const value = Number(timestamp) || 0;
  if (!value) return "-";
  return new Date(value * 1000).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
}

function showFeedback(message, kind = "info") {
  feedback.value = { message, kind };
  window.setTimeout(() => {
    if (feedback.value?.message === message) feedback.value = null;
  }, 5000);
}

function selectProduct(product) {
  selectedProductId.value = product.id;
  pixOrder.value = null;
}

function openConfirm(product = null) {
  if (product) selectProduct(product);
  if (!selectedProduct.value) return;
  confirmMode.value = "runes";
}

function openDetails(product) {
  detailProduct.value = product;
  selectProduct(product);
}

function closeConfirm() {
  if (busy.value || checkingPix.value) return;
  confirmMode.value = "";
  pixOrder.value = null;
}

function openDeposit() {
  if (!depositEnabled.value) {
    view.value = "catalog";
    return;
  }
  view.value = "donate";
  pixOrder.value = null;
}

async function openDashboard() {
  if (!store.value.isAdmin || dashboardLoading.value) return;
  dashboardOpen.value = true;
  dashboardTab.value = "overview";
  dashboardSearch.value = "";
  dashboardStatusFilter.value = "all";
  dashboardCouponDetails.value = "";
  dashboardLoading.value = true;
  const result = await nui("getVipDashboard");
  dashboardLoading.value = false;
  showFeedback(result.message || (result.ok ? "Dashboard carregado." : "Não foi possível abrir o dashboard."), result.ok ? "success" : "error");
  if (result.ok) dashboard.value = result.dashboard || null;
}

function clampDepositInput() {
  const cfg = runeDeposit.value;
  const step = Number(cfg.step) || 10;
  let value = Math.round((Number(depositInput.value) || 0) / step) * step;
  value = Math.max(Number(cfg.minimum) || step, Math.min(Number(cfg.maximum) || 50000, value));
  depositInput.value = value;
  depositRunes.value = value;
}

function increaseDeposit() {
  const cfg = runeDeposit.value;
  depositInput.value = Number(depositRunes.value) + (Number(cfg.step) || 10);
  clampDepositInput();
}

function decreaseDeposit() {
  const cfg = runeDeposit.value;
  depositInput.value = Number(depositRunes.value) - (Number(cfg.step) || 10);
  clampDepositInput();
}

async function validateCoupon(silent = false) {
  if (!couponCode.value.trim() || validatingCoupon.value) return;
  couponError.value = "";
  validatingCoupon.value = true;
  const result = await nui("validateRuneCoupon", { runes: depositRunes.value, coupon: couponCode.value });
  validatingCoupon.value = false;
  if (!result.ok) {
    couponApplied.value = false;
    couponInfo.value = null;
    couponError.value = result.message || "Cupom inválido.";
    return;
  }
  couponApplied.value = true;
  couponInfo.value = result;
  if (!silent) showFeedback(result.coupon?.description || "Cupom aplicado.", "success");
}

function removeCoupon() {
  couponApplied.value = false;
  couponInfo.value = null;
  couponError.value = "";
}

function editDashboardCoupon(coupon) {
  dashboardCouponDetails.value = coupon.code || "";
  dashboardCoupon.value = {
    code: coupon.code || "",
    discountType: Number(coupon.amount) > 0 ? "amount" : "percent",
    percent: Number(coupon.percent) || 10,
    amount: Number(coupon.amount) || 0,
    minRunes: Number(coupon.minRunes) || 0,
    maxDiscount: Number(coupon.maxDiscount) || 0,
    description: coupon.description || "",
    enabled: coupon.enabled !== false
  };
}

function viewDashboardCoupon(coupon) {
  dashboardCouponDetails.value = coupon.code || "";
  dashboardTab.value = "coupons";
}

function resetDashboardCoupon() {
  dashboardCoupon.value = {
    code: "",
    discountType: "percent",
    percent: 10,
    amount: 0,
    minRunes: 100,
    maxDiscount: 0,
    description: "",
    enabled: true
  };
}

async function saveDashboardCoupon() {
  if (dashboardLoading.value) return;
  dashboardLoading.value = true;
  const result = await nui("saveVipCoupon", dashboardCoupon.value);
  dashboardLoading.value = false;
  showFeedback(result.message || (result.ok ? "Cupom salvo." : "Não foi possível salvar o cupom."), result.ok ? "success" : "error");
  if (result.ok) {
    dashboard.value = result.dashboard || dashboard.value;
    resetDashboardCoupon();
  }
}

async function toggleDashboardCoupon(coupon) {
  if (dashboardLoading.value) return;
  dashboardLoading.value = true;
  const result = await nui("setVipCouponEnabled", { code: coupon.code, enabled: !coupon.enabled });
  dashboardLoading.value = false;
  showFeedback(result.message || (result.ok ? "Cupom atualizado." : "Não foi possível atualizar o cupom."), result.ok ? "success" : "error");
  if (result.ok) dashboard.value = result.dashboard || dashboard.value;
}

async function buyWithRunes() {
  if (!selectedProduct.value || busy.value) return;
  busy.value = true;
  const result = await nui("buyVipProductRunes", { productId: selectedProduct.value.id });
  busy.value = false;
  showFeedback(result.message || (result.ok ? "Compra concluída." : "Não foi possível comprar."), result.ok ? "success" : "error");
  if (result.ok) {
    closeConfirm();
    emit("refresh");
  }
}

async function redeemVipVehicle(entitlement, vehicle) {
  if (!entitlement?.entitlementId || !vehicle?.model || vehicleRedeemBusy.value) return;
  vehicleRedeemBusy.value = Number(entitlement.entitlementId);
  try {
    const result = await nui("redeemVipVehicle", {
      entitlementId: entitlement.entitlementId,
      model: vehicle.model
    });
    showFeedback(result.message || (result.ok ? "Veículo enviado para a garagem." : "Não foi possível resgatar."), result.ok ? "success" : "error");
    if (result.ok) {
      vehicleRewardsOpen.value = false;
      emit("refresh");
    }
  } catch (error) {
    showFeedback("Não foi possível comunicar com o servidor.", "error");
  } finally {
    vehicleRedeemBusy.value = 0;
  }
}

async function createRuneDepositOrder() {
  if (busy.value) return;
  busy.value = true;
  const result = await nui("createRuneDepositOrder", {
    runes: depositRunes.value,
    coupon: couponApplied.value ? couponCode.value : ""
  });
  busy.value = false;
  showFeedback(result.message || (result.ok ? "Pix gerado." : "Não foi possível gerar o Pix."), result.ok ? "success" : "error");
  if (result.ok) {
    pixOrder.value = result.order || null;
    if (result.quote) {
      couponInfo.value = result.quote;
      couponApplied.value = Boolean(result.quote.coupon);
    }
    if (result.status === "paid") emit("refresh");
  }
}

function stopPixPolling() {
  if (!pixPoll.value) return;
  window.clearInterval(pixPoll.value);
  pixPoll.value = null;
}

function startPixPolling() {
  stopPixPolling();
  pixPoll.value = window.setInterval(() => {
    checkPixOrder(true);
  }, 4500);
}

async function checkPixOrder(silent = false) {
  if (!pixOrder.value?.id || checkingPix.value) return;
  checkingPix.value = true;
  const result = await nui("checkVipPixOrder", { orderId: pixOrder.value.id });
  checkingPix.value = false;
  if (result.status === "paid") {
    showFeedback(result.message || "Pagamento confirmado. Runas entregues.", "success");
    closeConfirm();
    pixOrder.value = null;
    emit("refresh");
    return;
  }
  if (!silent) {
    showFeedback(result.message || "Aguardando confirmação do pagamento.", result.ok ? "info" : "error");
  }
}

async function copyPix() {
  const code = pixOrder.value?.copyPaste || "";
  if (!code) return;
  let copied = false;
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(code);
      copied = true;
    }
  } catch {
    copied = false;
  }

  if (!copied) {
    const textarea = document.createElement("textarea");
    textarea.value = code;
    textarea.setAttribute("readonly", "readonly");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, textarea.value.length);
    try {
      copied = document.execCommand("copy");
    } catch {
      copied = false;
    }
    document.body.removeChild(textarea);
  }

  if (copied) {
    showFeedback("Código Pix copiado.", "success");
  } else {
    showFeedback("Copie o código manualmente.", "info");
  }
}

function onOpenDeposit() {
  openDeposit();
}

onMounted(() => {
  window.addEventListener("magicpause:open-rune-deposit", onOpenDeposit);
  if (previewPanel === "donate") openDeposit();
  if (previewPanel === "history") historyOpen.value = true;
  if (previewPanel === "vehicles") vehicleRewardsOpen.value = true;
  if (previewPanel === "dashboard") window.setTimeout(openDashboard, 50);
  if (previewPanel === "details") {
    const productId = previewParams.get("product") || "trocar_raca";
    window.setTimeout(() => openDetails(products.value.find((product) => product.id === productId) || products.value[0]), 50);
  }
});
onBeforeUnmount(() => {
  stopPixPolling();
  if (couponRefreshTimer.value) window.clearTimeout(couponRefreshTimer.value);
  window.removeEventListener("magicpause:open-rune-deposit", onOpenDeposit);
});
</script>

<template>
  <section class="vip-store-screen">
    <header class="vip-store-header">
      <div>
        <small>Obscuria</small>
        <h1>{{ view === "catalog" ? "Loja VIP" : "Doação" }}</h1>
        <p v-if="view === 'catalog'">Produtos selecionados para quem busca praticidade, estilo e benefícios exclusivos.</p>
        <p v-else>Contribua com Runas e use na loja in-game. A cada 10 Runas, R$ 1,00.</p>
      </div>
      <div class="vip-header-actions">
        <button v-if="vehicleChoices.length" class="vip-history-trigger vip-rewards-trigger" type="button" title="Resgatar veículos" @click="openVehicleRewards">
          <i class="fa-solid fa-car-side"></i>
          <b>{{ vehicleChoices.length }}</b>
        </button>
        <button v-if="store.isAdmin" class="vip-history-trigger" type="button" title="Dashboard" @click="openDashboard">
          <i class="fa-solid fa-chart-line"></i>
        </button>
        <button class="vip-history-trigger" type="button" title="Histórico" @click="historyOpen = true">
          <i class="fa-solid fa-receipt"></i>
        </button>
      </div>
    </header>

    <div v-if="feedback" class="vip-feedback" :class="feedback.kind">
      <i :class="feedback.kind === 'success' ? 'fa-solid fa-check' : feedback.kind === 'error' ? 'fa-solid fa-xmark' : 'fa-solid fa-circle-info'"></i>
      <span>{{ feedback.message }}</span>
    </div>

    <div class="vip-mode-tabs">
      <button :class="{ active: view === 'catalog' }" type="button" @click="view = 'catalog'"><i class="fa-solid fa-store"></i> Catálogo</button>
      <button v-if="depositEnabled" :class="{ active: view === 'donate' }" type="button" @click="openDeposit"><img class="rune-icon" :src="runeIcon" alt="" /> Doação</button>
    </div>

    <template v-if="view === 'catalog'">
      <div class="vip-tabs">
        <button
          v-for="category in categories"
          :key="category.id"
          type="button"
          :class="{ active: selectedCategory === category.id }"
          @click="selectedCategory = category.id"
        >
          <i :class="category.icon || 'fa-solid fa-tag'"></i>
          <span>{{ category.label }}</span>
        </button>
      </div>

      <div class="vip-layout">
        <section class="vip-products">
          <article
            v-for="product in activeProducts"
            :key="product.id"
            class="vip-product-card"
            :class="[`layout-${productLayout(product)}`, { active: selectedProduct?.id === product.id }]"
          >
            <span class="vip-card-badge">{{ product.badge || "VIP" }}</span>
            <button class="vip-card-detail-button" type="button" title="Detalhes" @click="openDetails(product)">
              <i class="fa-solid fa-circle-info"></i>
            </button>
            <span class="vip-card-art" :class="`layout-${productLayout(product)}`">
              <img v-if="productTemplate(product)" class="vip-art-template" :src="assetUrl(productTemplate(product))" alt="" />
              <img v-if="product.image" class="vip-art-item" :src="assetUrl(product.image)" :alt="product.title" />
              <i v-else :class="product.icon || 'fa-solid fa-gem'"></i>
            </span>
            <span class="vip-card-copy">
              <b>{{ product.title }}</b>
              <small>{{ product.subtitle }}</small>
            </span>
            <span class="vip-card-price">
              <span><b>{{ money(product.priceRunes) }}</b><small>Runas</small></span>
              <button type="button" class="vip-card-buy" :disabled="product.payment?.runes === false" @click="openConfirm(product)">
                <img class="rune-icon" :src="runeIcon" alt="" />
                Comprar
              </button>
            </span>
          </article>
        </section>

        <aside class="vip-detail" v-if="false">
          <div class="vip-detail-hero">
            <span class="vip-detail-art">
              <img v-if="productTemplate(selectedProduct)" class="vip-art-template" :src="assetUrl(productTemplate(selectedProduct))" alt="" />
              <img v-if="selectedProduct.image" class="vip-art-item" :src="assetUrl(selectedProduct.image)" :alt="selectedProduct.title" />
              <i v-else :class="selectedProduct.icon || 'fa-solid fa-gem'"></i>
            </span>
            <div>
              <small>{{ selectedProduct.badge || "Produto VIP" }}</small>
              <h2>{{ selectedProduct.title }}</h2>
              <p>{{ selectedProduct.description }}</p>
            </div>
          </div>

          <div class="vip-price-grid">
            <div><span>Runas</span><b>{{ money(selectedProduct.priceRunes) }}</b></div>
          </div>

          <div class="vip-actions">
            <button type="button" class="vip-primary" :disabled="selectedProduct.payment?.runes === false" @click="openConfirm">
              <i class="fa-solid fa-gem"></i> Comprar com Runas
            </button>
          </div>

          <section class="vip-history">
            <div class="vip-section-title"><span>Histórico recente</span><small>{{ (store.history || []).length }} pedidos</small></div>
            <div v-if="!(store.history || []).length" class="vip-empty">Nenhuma compra recente.</div>
            <div v-for="order in store.history || []" :key="order.id" class="vip-history-row">
              <i :class="order.status === 'paid' ? 'fa-solid fa-check' : order.status === 'pending' ? 'fa-regular fa-clock' : 'fa-solid fa-xmark'"></i>
              <span><b>{{ order.title }}</b><small>{{ formatDate(order.paidAt || order.createdAt) }} · {{ order.method }}</small></span>
              <em>{{ statusLabel(order.status) }}</em>
            </div>
          </section>
        </aside>
      </div>
    </template>

    <template v-else-if="depositEnabled">
      <div class="donation-layout">
        <section class="donation-showcase">
          <div class="donation-glow"></div>
          <div class="donation-icon"><img :src="runeIcon" alt="Runa de Obscuria" /></div>
          <h2>Runas</h2>
          <p>Moeda premium oficial da cidade.</p>
          <div class="donation-stats">
            <span><b>10</b><small>Runas</small></span>
            <i class="fa-solid fa-arrow-right"></i>
            <span><b>R$ 1</b><small>Conversão</small></span>
            <span><b>Imediato</b><small>Entrega</small></span>
          </div>
          <div class="donation-tags">
            <span>Veículos</span>
            <span>Serviços</span>
            <span>Clãs</span>
            <span>Itens especiais</span>
          </div>
        </section>

        <aside class="donation-selector">
          <p class="selector-label">Selecione a quantidade</p>
          <div class="preset-grid">
            <button
              v-for="preset in runeDeposit.presets || []"
              :key="preset"
              :class="{ active: depositRunes === preset }"
              type="button"
              @click="depositRunes = preset"
            >
              <b>{{ money(preset) }}</b>
              <small>{{ brl(preset / runeDeposit.runesPerReal) }}</small>
            </button>
          </div>

          <div class="custom-label">Ou digite a quantidade</div>
          <div class="qty-wrap">
            <button class="qty-ctrl" type="button" @click="decreaseDeposit">-</button>
            <div class="qty-field">
              <input class="qty-input" type="number" v-model.number="depositInput" :min="runeDeposit.minimum" :max="runeDeposit.maximum" :step="runeDeposit.step" @change="clampDepositInput" />
              <span>Runas</span>
            </div>
            <button class="qty-ctrl" type="button" @click="increaseDeposit">+</button>
          </div>
          <input class="qty-slider" type="range" v-model.number="depositRunes" :min="runeDeposit.minimum" :max="runeDeposit.maximum" :step="runeDeposit.step" />

          <div class="coupon-box">
            <div class="coupon-row">
              <div class="coupon-field">
                <i class="fa-solid fa-tag"></i>
                <input v-model="couponCode" :disabled="couponApplied || validatingCoupon" placeholder="Cupom de desconto" @keyup.enter="validateCoupon" />
              </div>
              <button v-if="!couponApplied" type="button" :disabled="!couponCode.trim() || validatingCoupon" @click="validateCoupon">
                {{ validatingCoupon ? "..." : "Aplicar" }}
              </button>
              <button v-else type="button" class="remove" @click="removeCoupon">x</button>
            </div>
            <div v-if="couponApplied" class="coupon-ok">
              <i class="fa-solid fa-check"></i>
              {{ couponInfo?.coupon?.description || "Cupom aplicado" }} · economia de {{ brl(discountValue) }}
            </div>
            <div v-if="couponError" class="coupon-error">{{ couponError }}</div>
          </div>

          <div class="summary-card">
            <div><span>{{ money(depositRunes) }} Runas</span><b>{{ brl(originalPrice) }}</b></div>
            <footer>
              <span>
                Total
                <small v-if="couponApplied">Desconto {{ couponCode.toUpperCase() }} · -{{ brl(discountValue) }}</small>
              </span>
              <b>{{ brl(finalPrice) }}</b>
              <button type="button" :disabled="!canUsePix || busy" @click="createRuneDepositOrder">
                <i class="fa-brands fa-pix"></i>
                {{ busy ? "Gerando..." : "Contribuir" }}
              </button>
            </footer>
          </div>

          <p class="payment-note"><i class="fa-solid fa-lock"></i> Pagamento seguro via Pix · Runas entregues após confirmação</p>

          <div v-if="pixOrder" class="vip-pix-box embedded">
            <div class="vip-pix-head">
              <span><i class="fa-brands fa-pix"></i> Pix gerado</span>
              <em>{{ checkingPix ? "Verificando..." : "Aguardando pagamento" }}</em>
            </div>
            <div class="vip-pix-content">
              <img v-if="pixOrder.qrCode && (pixOrder.qrCode.startsWith('data:') || pixOrder.qrCode.startsWith('http'))" :src="pixOrder.qrCode" alt="QR Code Pix" />
              <div v-else class="vip-pix-placeholder"><i class="fa-brands fa-pix"></i><span>Pix copia e cola</span></div>
              <div class="vip-pix-copy">
                <textarea readonly :value="pixOrder.copyPaste || pixOrder.qrCode || 'A API não retornou código Pix.'" />
                <button type="button" class="vip-secondary" @click="copyPix">Copiar código</button>
              </div>
            </div>
          </div>
        </aside>
      </div>
    </template>

    <Transition name="confirm">
      <div v-if="vehicleRewardsOpen" class="vip-modal vip-workspace-modal">
        <div class="vip-confirm vip-vehicle-modal">
          <header class="vip-workspace-header">
            <span class="vip-workspace-icon"><i class="fa-solid fa-car-side"></i></span>
            <div><small>Benefícios disponíveis</small><h3>Escolha seu veículo</h3><p>Cada escolha é definitiva, vale por 30 dias e será enviada para a garagem.</p></div>
            <button type="button" title="Fechar" @click="vehicleRewardsOpen = false"><i class="fa-solid fa-xmark"></i></button>
          </header>
          <div class="vip-vehicle-entitlements">
            <section v-for="entitlement in vehicleChoices" :key="entitlement.entitlementId" class="vip-vehicle-entitlement">
              <div class="vip-section-title">
                <span>{{ entitlement.label }} · escolha {{ entitlement.slot }}</span>
                <small>
                  Veículo por {{ entitlement.durationDays || 30 }} dias · renovação por {{ money(entitlement.renewalRunes || 0) }} Runas
                  <template v-if="entitlement.expiresAt"> · escolha disponível até {{ formatDate(entitlement.expiresAt) }}</template>
                </small>
              </div>
              <div class="vip-vehicle-grid">
                <article v-for="vehicle in entitlement.vehicles || []" :key="vehicle.model" class="vip-vehicle-choice">
                  <span class="vip-vehicle-art">
                    <img v-if="productTemplate()" class="vip-art-template" :src="assetUrl(productTemplate())" alt="" />
                    <img v-if="vehicleHasImage(vehicle)" class="vip-art-item" :src="assetUrl(vehicleImagePath(vehicle))" :alt="vehicle.label" @error="hideMissingVehicleImage(vehicle)" />
                    <i v-else class="fa-solid fa-car-side"></i>
                  </span>
                  <div><b>{{ vehicle.label }}</b><small>{{ vehicle.model }}</small></div>
                  <button type="button" class="vip-primary" :disabled="vehicleRedeemBusy !== 0" @click="redeemVipVehicle(entitlement, vehicle)">
                    {{ vehicleRedeemBusy === entitlement.entitlementId ? "Enviando..." : "Escolher" }}
                  </button>
                </article>
              </div>
            </section>
          </div>
        </div>
      </div>
    </Transition>

    <Transition name="confirm">
      <div v-if="historyOpen" class="vip-modal vip-workspace-modal">
        <div class="vip-confirm vip-history-modal">
          <header class="vip-workspace-header">
            <span class="vip-workspace-icon"><i class="fa-solid fa-receipt"></i></span>
            <div><small>Movimentações da conta</small><h3>Histórico da Loja</h3><p>Acompanhe suas compras e contribuições recentes.</p></div>
            <button type="button" title="Fechar histórico" @click="historyOpen = false"><i class="fa-solid fa-xmark"></i></button>
          </header>
          <section class="vip-history open">
            <div class="vip-section-title"><span>Pedidos recentes</span><small>{{ (store.history || []).length }} registros encontrados</small></div>
            <div v-if="!(store.history || []).length" class="vip-empty">Nenhuma compra recente.</div>
            <div v-for="order in store.history || []" :key="order.id" class="vip-history-row" :class="String(order.status || '').toLowerCase()">
              <span class="vip-history-status-icon"><i :class="order.status === 'paid' ? 'fa-solid fa-check' : order.status === 'pending' ? 'fa-regular fa-clock' : 'fa-solid fa-xmark'"></i></span>
              <span><b>{{ order.title }}</b><small>{{ formatDate(order.paidAt || order.createdAt) }} · {{ order.method }}</small></span>
              <strong>{{ currency(order.amount, order.currency) }}</strong>
              <em>{{ statusLabel(order.status) }}</em>
            </div>
          </section>
        </div>
      </div>
    </Transition>

    <Transition name="confirm">
      <div v-if="dashboardOpen" class="vip-modal vip-workspace-modal">
        <div class="vip-confirm vip-dashboard-modal">
          <header class="vip-workspace-header">
            <span class="vip-workspace-icon"><i class="fa-solid fa-chart-line"></i></span>
            <div><small>Central de pagamentos</small><h3>Dashboard de Doações</h3><p>Receita, pagamentos e cupons em uma visão administrativa.</p></div>
            <button type="button" title="Fechar dashboard" @click="dashboardOpen = false"><i class="fa-solid fa-xmark"></i></button>
          </header>

          <section v-if="dashboardLoading && !dashboard" class="vip-dashboard-loading">
            <i class="fa-solid fa-circle-notch fa-spin"></i>
            <span>Carregando pagamentos...</span>
          </section>

          <section v-else class="vip-dashboard-grid">
            <div class="vip-dashboard-toolbar">
              <nav class="vip-dashboard-tabs">
                <button type="button" :class="{ active: dashboardTab === 'overview' }" @click="dashboardTab = 'overview'">
                  <i class="fa-solid fa-chart-pie"></i>
                  Visão geral
                </button>
                <button type="button" :class="{ active: dashboardTab === 'payments' }" @click="dashboardTab = 'payments'">
                  <i class="fa-solid fa-receipt"></i>
                  Pagamentos
                </button>
                <button type="button" :class="{ active: dashboardTab === 'coupons' }" @click="dashboardTab = 'coupons'">
                  <i class="fa-solid fa-ticket"></i>
                  Cupons
                </button>
              </nav>

              <label class="vip-dashboard-search">
                <i class="fa-solid fa-magnifying-glass"></i>
                <input v-model="dashboardSearch" placeholder="Pesquisar pessoa, ID ou cupom" />
                <button v-if="dashboardSearch" type="button" @click="dashboardSearch = ''"><i class="fa-solid fa-xmark"></i></button>
              </label>

              <div class="vip-dashboard-status">
                <button type="button" :class="{ active: dashboardStatusFilter === 'all' }" @click="dashboardStatusFilter = 'all'">Todos</button>
                <button type="button" :class="{ active: dashboardStatusFilter === 'paid' }" @click="dashboardStatusFilter = 'paid'">Aprovados</button>
                <button type="button" :class="{ active: dashboardStatusFilter === 'pending' }" @click="dashboardStatusFilter = 'pending'">Pendentes</button>
                <button type="button" :class="{ active: dashboardStatusFilter === 'failed' }" @click="dashboardStatusFilter = 'failed'">Falharam</button>
              </div>
            </div>

            <section v-if="dashboardTab === 'overview'" class="vip-dashboard-page">
              <div class="vip-dashboard-metrics featured">
                <article><small>Receita hoje</small><b>{{ brl(dashboardStats.today?.total) }}</b><span>{{ dashboardStats.today?.count || 0 }} pagamentos aprovados</span></article>
                <article><small>Receita mensal</small><b>{{ brl(dashboardStats.month?.total) }}</b><span>{{ dashboardStats.month?.count || 0 }} pagamentos aprovados</span></article>
                <article><small>Receita geral</small><b>{{ brl(dashboardStats.total?.total) }}</b><span>{{ dashboardStats.total?.count || 0 }} pagamentos aprovados</span></article>
                <article><small>Pendentes</small><b>{{ dashboardStats.pending || 0 }}</b><span>{{ dashboardStats.couponsUsed || 0 }} compras com cupom</span></article>
              </div>

              <div class="vip-dashboard-split">
                <section class="vip-dashboard-panel">
                  <div class="vip-section-title"><span>Últimos pagamentos</span><small>{{ dashboardRecentPayments.length }} recentes</small></div>
                  <div class="vip-dashboard-table compact">
                    <div v-for="payment in dashboardRecentPayments" :key="payment.id" class="vip-payment-row">
                      <span>
                        <b>{{ payment.playerName || payment.passport }}</b>
                        <small>#{{ payment.id }} - {{ payment.title }} - {{ formatDate(payment.paidAt || payment.createdAt) }}</small>
                      </span>
                      <em v-if="payment.coupon">{{ payment.coupon }}</em>
                      <strong>{{ currency(payment.amount, payment.currency) }}</strong>
                      <mark :class="payment.status">{{ statusLabel(payment.status) }}</mark>
                    </div>
                    <div v-if="!dashboardRecentPayments.length" class="vip-empty">Nenhum pagamento registrado.</div>
                  </div>
                </section>

                <section class="vip-dashboard-panel">
                  <div class="vip-section-title"><span>Cupons em destaque</span><small>Uso e economia</small></div>
                  <div class="vip-coupon-list compact">
                    <article v-for="coupon in dashboardTopCoupons" :key="coupon.code" class="vip-coupon-card summary" :class="{ disabled: !coupon.enabled }" @click="viewDashboardCoupon(coupon)">
                      <div>
                        <b>{{ coupon.code }}</b>
                        <small>{{ coupon.usage?.count || 0 }} usos - {{ money(coupon.usage?.runes) }} Runas</small>
                      </div>
                      <span>{{ brl(coupon.usage?.discount) }}</span>
                    </article>
                    <div v-if="!dashboardTopCoupons.length" class="vip-empty">Nenhum cupom cadastrado.</div>
                  </div>
                </section>
              </div>
            </section>

            <section v-else-if="dashboardTab === 'payments'" class="vip-dashboard-page">
              <section class="vip-dashboard-panel full">
                <div class="vip-section-title"><span>Pagamentos</span><small>{{ dashboardFilteredPayments.length }} de {{ dashboardPayments.length }} registros</small></div>
                <div class="vip-dashboard-table large">
                  <div v-for="payment in dashboardFilteredPayments" :key="payment.id" class="vip-payment-row detailed">
                    <span>
                      <b>{{ payment.playerName || payment.passport }}</b>
                      <small>#{{ payment.id }} - {{ payment.title }} - {{ formatDate(payment.paidAt || payment.createdAt) }}</small>
                    </span>
                    <em v-if="payment.coupon">{{ payment.coupon }}</em>
                    <strong>{{ currency(payment.amount, payment.currency) }}</strong>
                    <mark :class="payment.status">{{ statusLabel(payment.status) }}</mark>
                  </div>
                  <div v-if="!dashboardFilteredPayments.length" class="vip-empty">Nenhum pagamento encontrado.</div>
                </div>
              </section>
            </section>

            <section v-else class="vip-dashboard-page">
              <div class="vip-dashboard-coupons">
                <section class="vip-dashboard-panel">
                  <div class="vip-section-title"><span>Cupons cadastrados</span><small>{{ dashboardCoupons.length }} ativos e inativos</small></div>
                  <div class="vip-coupon-list large">
                    <article v-for="coupon in dashboardCoupons" :key="coupon.code" class="vip-coupon-card detailed" :class="{ disabled: !coupon.enabled }">
                      <div>
                        <b>{{ coupon.code }}</b>
                        <small>{{ coupon.description }}</small>
                        <small>{{ coupon.usage?.count || 0 }} usos - {{ money(coupon.usage?.runes) }} Runas vendidas - {{ brl(coupon.usage?.discount) }} em descontos</small>
                      </div>
                      <span>{{ coupon.amount ? brl(coupon.amount) : `${coupon.percent || 0}%` }}</span>
                      <button type="button" @click="viewDashboardCoupon(coupon)"><i class="fa-solid fa-eye"></i></button>
                      <button type="button" @click="editDashboardCoupon(coupon)"><i class="fa-solid fa-pen"></i></button>
                      <button type="button" @click="toggleDashboardCoupon(coupon)">
                        <i :class="coupon.enabled ? 'fa-solid fa-toggle-on' : 'fa-solid fa-toggle-off'"></i>
                      </button>
                    </article>
                    <div v-if="!dashboardCoupons.length" class="vip-empty">Nenhum cupom cadastrado.</div>
                  </div>
                </section>

                <section class="vip-coupon-form">
                  <div v-if="dashboardSelectedCoupon" class="vip-coupon-insight">
                    <div class="vip-section-title">
                      <span>{{ dashboardSelectedCoupon.code }}</span>
                      <small>{{ dashboardSelectedCoupon.enabled ? "Ativo" : "Inativo" }}</small>
                    </div>
                    <div class="vip-coupon-insight-grid">
                      <article><small>Usos</small><b>{{ dashboardSelectedCoupon.usage?.count || 0 }}</b></article>
                      <article><small>Descontado</small><b>{{ brl(dashboardSelectedCoupon.usage?.discount) }}</b></article>
                      <article><small>Runas</small><b>{{ money(dashboardSelectedCoupon.usage?.runes) }}</b></article>
                      <article><small>Receita</small><b>{{ brl(dashboardSelectedCoupon.usage?.total) }}</b></article>
                    </div>
                  </div>

                  <div class="vip-section-title"><span>Criar cupom</span><small>Desconto para doacao de Runas</small></div>
                  <div class="vip-form-grid">
                    <label><span>Codigo</span><input v-model="dashboardCoupon.code" placeholder="BEMVINDO10" /></label>
                    <label><span>Tipo</span><select v-model="dashboardCoupon.discountType"><option value="percent">Porcentagem</option><option value="amount">Valor fixo</option></select></label>
                    <label v-if="dashboardCoupon.discountType === 'percent'"><span>Porcentagem</span><input type="number" v-model.number="dashboardCoupon.percent" min="1" max="100" /></label>
                    <label v-else><span>Valor fixo</span><input type="number" v-model.number="dashboardCoupon.amount" min="1" /></label>
                    <label><span>Min. Runas</span><input type="number" v-model.number="dashboardCoupon.minRunes" min="0" /></label>
                    <label><span>Desconto max.</span><input type="number" v-model.number="dashboardCoupon.maxDiscount" min="0" placeholder="Opcional" /></label>
                    <label class="wide"><span>Descricao</span><input v-model="dashboardCoupon.description" placeholder="10% de desconto na doacao" /></label>
                  </div>
                  <footer>
                    <button type="button" class="vip-secondary" @click="resetDashboardCoupon">Limpar</button>
                    <button type="button" class="vip-primary" :disabled="dashboardLoading" @click="saveDashboardCoupon">
                      {{ dashboardLoading ? "Salvando..." : "Salvar cupom" }}
                    </button>
                  </footer>
                </section>
              </div>
            </section>

            <template v-if="false">
            <div class="vip-dashboard-metrics">
              <article><small>Hoje</small><b>{{ brl(dashboardStats.today?.total) }}</b><span>{{ dashboardStats.today?.count || 0 }} pagos</span></article>
              <article><small>Mês</small><b>{{ brl(dashboardStats.month?.total) }}</b><span>{{ dashboardStats.month?.count || 0 }} pagos</span></article>
              <article><small>Geral</small><b>{{ brl(dashboardStats.total?.total) }}</b><span>{{ dashboardStats.total?.count || 0 }} pagos</span></article>
              <article><small>Pendentes</small><b>{{ dashboardStats.pending || 0 }}</b><span>{{ dashboardStats.couponsUsed || 0 }} com cupom</span></article>
            </div>

            <div class="vip-dashboard-columns">
              <section class="vip-dashboard-panel">
                <div class="vip-section-title"><span>Pagamentos</span><small>{{ dashboardPayments.length }} registros</small></div>
                <div class="vip-dashboard-table">
                  <div v-for="payment in dashboardPayments" :key="payment.id" class="vip-payment-row">
                    <span>
                      <b>{{ payment.playerName || payment.passport }}</b>
                      <small>#{{ payment.id }} · {{ payment.title }} · {{ formatDate(payment.paidAt || payment.createdAt) }}</small>
                    </span>
                    <em v-if="payment.coupon">{{ payment.coupon }}</em>
                    <strong>{{ currency(payment.amount, payment.currency) }}</strong>
                    <mark :class="payment.status">{{ statusLabel(payment.status) }}</mark>
                  </div>
                  <div v-if="!dashboardPayments.length" class="vip-empty">Nenhum pagamento registrado.</div>
                </div>
              </section>

              <section class="vip-dashboard-panel">
                <div class="vip-section-title"><span>Cupons</span><small>{{ dashboardCoupons.length }} cadastrados</small></div>
                <div class="vip-coupon-list">
                  <article v-for="coupon in dashboardCoupons" :key="coupon.code" class="vip-coupon-card" :class="{ disabled: !coupon.enabled }">
                    <div>
                      <b>{{ coupon.code }}</b>
                      <small>{{ coupon.description }}</small>
                    </div>
                    <span>{{ coupon.amount ? brl(coupon.amount) : `${coupon.percent || 0}%` }}</span>
                    <button type="button" @click="editDashboardCoupon(coupon)"><i class="fa-solid fa-pen"></i></button>
                    <button type="button" @click="toggleDashboardCoupon(coupon)">
                      <i :class="coupon.enabled ? 'fa-solid fa-toggle-on' : 'fa-solid fa-toggle-off'"></i>
                    </button>
                  </article>
                </div>
              </section>
            </div>

            <section class="vip-coupon-form">
              <div class="vip-section-title"><span>Criar cupom</span><small>Desconto para doação de Runas</small></div>
              <div class="vip-form-grid">
                <label><span>Código</span><input v-model="dashboardCoupon.code" placeholder="BEMVINDO10" /></label>
                <label><span>Tipo</span><select v-model="dashboardCoupon.discountType"><option value="percent">Porcentagem</option><option value="amount">Valor fixo</option></select></label>
                <label v-if="dashboardCoupon.discountType === 'percent'"><span>Porcentagem</span><input type="number" v-model.number="dashboardCoupon.percent" min="1" max="100" /></label>
                <label v-else><span>Valor fixo</span><input type="number" v-model.number="dashboardCoupon.amount" min="1" /></label>
                <label><span>Mín. Runas</span><input type="number" v-model.number="dashboardCoupon.minRunes" min="0" /></label>
                <label><span>Desconto máx.</span><input type="number" v-model.number="dashboardCoupon.maxDiscount" min="0" placeholder="Opcional" /></label>
                <label class="wide"><span>Descrição</span><input v-model="dashboardCoupon.description" placeholder="10% de desconto na doação" /></label>
              </div>
              <footer>
                <button type="button" class="vip-secondary" @click="resetDashboardCoupon">Limpar</button>
                <button type="button" class="vip-primary" :disabled="dashboardLoading" @click="saveDashboardCoupon">
                  {{ dashboardLoading ? "Salvando..." : "Salvar cupom" }}
                </button>
              </footer>
            </section>
            </template>
          </section>
        </div>
      </div>
    </Transition>

    <Transition name="confirm">
      <div v-if="detailProduct" class="vip-modal">
        <div class="vip-confirm vip-product-modal">
          <header>
            <div><small>{{ detailProduct.badge || "Produto VIP" }}</small><h3>{{ detailProduct.title }}</h3></div>
            <button type="button" @click="detailProduct = null"><i class="fa-solid fa-xmark"></i></button>
          </header>
          <div class="vip-product-modal-body">
            <span class="vip-product-modal-art layout-landscape">
              <img v-if="productTemplate(detailProduct)" class="vip-art-template" :src="assetUrl(productTemplate(detailProduct))" alt="" />
              <img v-if="detailProduct.image" class="vip-art-item" :src="assetUrl(detailProduct.image)" :alt="detailProduct.title" />
              <i v-else :class="detailProduct.icon || 'fa-solid fa-gem'"></i>
            </span>
            <p>{{ detailProduct.description || detailProduct.subtitle }}</p>
            <ul v-if="detailProduct.features?.length" class="vip-product-features">
              <li v-for="feature in detailProduct.features" :key="feature"><i class="fa-solid fa-check"></i><span>{{ feature }}</span></li>
            </ul>
            <div class="vip-confirm-price"><span>Total</span><b>{{ money(detailProduct.priceRunes) }} Runas</b></div>
          </div>
          <footer>
            <button type="button" class="vip-secondary" @click="detailProduct = null">Fechar</button>
            <button type="button" class="vip-primary" :disabled="detailProduct.payment?.runes === false" @click="openConfirm(detailProduct); detailProduct = null">
              Comprar
            </button>
          </footer>
        </div>
      </div>
    </Transition>

    <Transition name="confirm">
      <div v-if="confirmMode" class="vip-modal">
        <div class="vip-confirm">
          <header>
            <div><small>Compra com Runas</small><h3>{{ selectedProduct?.title }}</h3></div>
            <button type="button" @click="closeConfirm"><i class="fa-solid fa-xmark"></i></button>
          </header>

          <template v-if="confirmMode === 'runes'">
            <p>Confirme a compra. O produto será entregue automaticamente após descontar as Runas.</p>
            <div class="vip-confirm-price"><span>Total</span><b>{{ money(selectedProduct?.priceRunes) }} Runas</b></div>
            <footer>
              <button type="button" class="vip-secondary" @click="closeConfirm">Cancelar</button>
              <button type="button" class="vip-primary" :disabled="busy" @click="buyWithRunes">{{ busy ? "Processando..." : "Confirmar compra" }}</button>
            </footer>
          </template>
        </div>
      </div>
    </Transition>
  </section>
</template>
