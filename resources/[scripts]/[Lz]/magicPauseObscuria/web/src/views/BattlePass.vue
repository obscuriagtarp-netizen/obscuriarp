<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import "../styles/battlepass.css";
import battlePassIcon from "../assets/battlepass/icone-passe.png";

const props = defineProps({
  payload: { type: Object, default: null },
  i18n: { type: Object, default: () => ({}) }
});

const emit = defineEmits(["refresh"]);

const selectedIndex = ref(1);
const activeTab = ref("rewards");
const adminOpen = ref(false);
const levelPurchaseOpen = ref(false);
const levelAmount = ref(1);
const busy = ref(false);
const feedback = ref(null);
const trackRef = ref(null);
let wheelTarget = 0;
let wheelFrame = 0;
const slotCount = ref(10);
const seasonForm = ref({
  title: "",
  subtitle: "",
  startsAt: 0,
  endsAt: 0,
  premiumPrice: 1000,
  xpPerLevel: 1000,
  active: true
});
const slotForm = ref(null);
const rewardTypes = ["item", "coins", "money", "vehicle", "command", "none"];

const data = computed(() => props.payload || {});
const locale = computed(() => props.i18n?.messages || data.value.locale?.messages || {});
const season = computed(() => data.value.season || null);
const slots = computed(() => [...(data.value.slots || [])].sort((a, b) => Number(a.index) - Number(b.index)));
const progress = computed(() => data.value.progress || {});
const missions = computed(() => data.value.missions || {});
const isAdmin = computed(() => data.value.isAdmin === true);
const selectedSlot = computed(() => slots.value.find((slot) => Number(slot.index) === Number(selectedIndex.value)) || slots.value[0] || null);
const claimedFree = computed(() => new Set((progress.value.claimedFree || []).map((value) => String(value))));
const claimedPremium = computed(() => new Set((progress.value.claimedPremium || []).map((value) => String(value))));
const currentXp = computed(() => Number(progress.value.xp) || 0);
const xpPerLevel = computed(() => Math.max(1, Number(season.value?.xpPerLevel) || 1000));
const level = computed(() => Math.max(1, Number(progress.value.level) || 1));
const passCompleted = computed(() => progress.value.completed === true || missions.value.locked === true);
const maxPassXp = computed(() => Math.max(0, Number(missions.value.maxXp) || 0));
const nextLevelXp = computed(() => passCompleted.value ? maxPassXp.value : level.value * xpPerLevel.value);
const progressPercent = computed(() => Math.min(100, Math.max(0, (currentXp.value / Math.max(1, nextLevelXp.value)) * 100)));
const hasPremium = computed(() => progress.value.premium === true);
const levelPurchase = computed(() => data.value.config?.levelPurchase || {});
const pricePerLevel = computed(() => Math.max(0, Number(levelPurchase.value.pricePerLevel) || 100));
const maxBuyableLevels = computed(() => {
  if (passCompleted.value) return 0;
  const remaining = Math.max(0, maxPassXp.value - currentXp.value);
  const available = Math.max(1, Math.ceil(remaining / xpPerLevel.value));
  return Math.min(available, Math.max(1, Number(levelPurchase.value.maxPerPurchase) || 25));
});
const levelPurchaseTotal = computed(() => Math.max(1, Number(levelAmount.value) || 1) * pricePerLevel.value);
const levelPurchaseXp = computed(() => Math.min(
  Math.max(0, maxPassXp.value - currentXp.value),
  Math.max(1, Number(levelAmount.value) || 1) * xpPerLevel.value
));
const unlockedSlots = computed(() => slots.value.filter((slot) => currentXp.value >= Number(slot.xpRequired || 0)).length);
const nextSlot = computed(() => slots.value.find((slot) => currentXp.value < Number(slot.xpRequired || 0)) || null);
const xpRemaining = computed(() => Math.max(0, nextLevelXp.value - currentXp.value));
const totalRewards = computed(() => slots.value.reduce((total, slot) => {
  const free = slot.freeReward && slot.freeReward.type !== "none" ? 1 : 0;
  const premium = slot.premiumReward && slot.premiumReward.type !== "none" ? 1 : 0;
  return total + free + premium;
}, 0));
const claimableRewards = computed(() => slots.value.reduce((total, slot) => {
  return total
    + (rewardStatus(slot, "free") === "available" ? 1 : 0)
    + (rewardStatus(slot, "premium") === "available" ? 1 : 0);
}, 0));
const seasonDaysRemaining = computed(() => {
  const end = Number(season.value?.endsAt) || 0;
  if (!end) return null;
  return Math.max(0, Math.ceil(((end * 1000) - Date.now()) / 86400000));
});
const seasonEndLabel = computed(() => {
  const end = Number(season.value?.endsAt) || 0;
  if (!end) return "Sem data definida";
  return new Date(end * 1000).toLocaleDateString("pt-BR", { day: "2-digit", month: "short" }).replace(".", "");
});
const lastClaimedIndex = computed(() => {
  const values = [
    ...(progress.value.claimedFree || []),
    ...(progress.value.claimedPremium || [])
  ].map((value) => Number(value) || 0);
  return Math.max(0, ...values);
});

function t(path, fallback) {
  const parts = String(path || "").split(".");
  let value = locale.value;
  for (const part of parts) value = value?.[part];
  return typeof value === "string" ? value : (fallback || path);
}

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "magicPauseObscuria";
}

async function nui(eventName, payload = {}) {
  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(payload)
  });
  return response.json().catch(() => ({}));
}

function assetUrl(value) {
  const path = String(value || "").trim();
  if (!path) return "";
  if (/^(https?:|data:|nui:)/i.test(path)) return path;
  return `nui://${resourceName()}/${path.replace(/^\/+/, "")}`;
}

function money(value) {
  return Math.floor(Number(value) || 0).toLocaleString("pt-BR");
}

function showFeedback(message, kind = "info") {
  feedback.value = { message, kind };
  window.setTimeout(() => {
    if (feedback.value?.message === message) feedback.value = null;
  }, 4200);
}

async function run(eventName, payload = {}) {
  if (busy.value) return {};
  busy.value = true;
  const result = await nui(eventName, payload);
  busy.value = false;
  showFeedback(result.message || (result.ok ? t("common.success", "Ação concluída.") : t("common.error", "Não foi possível concluir.")), result.kind || (result.ok ? "success" : "error"));
  if (result.payload) emit("refresh");
  return result;
}

function rewardStatus(slot, track) {
  const reward = track === "premium" ? slot.premiumReward : slot.freeReward;
  if (!reward || reward.type === "none") return "empty";
  if (currentXp.value < Number(slot.xpRequired || 0)) return "locked";
  if (track === "premium" && !hasPremium.value) return "premiumRequired";
  const set = track === "premium" ? claimedPremium.value : claimedFree.value;
  if (set.has(String(slot.index))) return "claimed";
  return "available";
}

function statusLabel(status) {
  const fallback = {
    empty: "Sem recompensa",
    locked: "Bloqueado",
    premiumRequired: "Passe premium",
    claimed: "Resgatado",
    available: "Resgatar"
  };
  return t(`common.${status}`, fallback[status] || status);
}

function rewardIcon(reward) {
  if (!reward) return "fa-solid fa-plus";
  if (reward.type === "coins") return "fa-solid fa-gem";
  if (reward.type === "money") return "fa-solid fa-money-bill-wave";
  if (reward.type === "vehicle") return "fa-solid fa-car-side";
  if (reward.type === "command") return "fa-solid fa-terminal";
  if (reward.type === "none") return "fa-solid fa-ban";
  return "fa-solid fa-box";
}

function rewardAmount(reward) {
  if (!reward) return "";
  if (reward.type === "vehicle") return `${Number(reward.durationDays) || 30} dias`;
  const amount = Number(reward.amount) || 0;
  return amount > 1 ? `x${money(amount)}` : "";
}

function rewardTypeLabel(type) {
  const fallback = { item: "Item", coins: "Runas", money: "Dinheiro", vehicle: "Veículo", command: "Comando", none: "Nenhuma" };
  return t(`battlepass.type_${type}`, fallback[type] || type);
}

function scrollTrack(direction) {
  const el = trackRef.value;
  if (!el) return;
  el.scrollBy({ left: direction * 260, behavior: "smooth" });
}

function scrollToSlot(index) {
  const el = trackRef.value;
  if (!el || !index) return;

  const slot = slots.value.find((item) => Number(item.index) === Number(index));
  const slotIndex = slots.value.indexOf(slot);
  const child = slotIndex >= 0 ? el.children[slotIndex] : null;
  if (!child) return;

  wheelTarget = Math.max(0, Math.min(maxTrackScroll(), child.offsetLeft - el.offsetLeft - 8));
  el.scrollTo({ left: wheelTarget, behavior: "smooth" });
}

function maxTrackScroll() {
  const el = trackRef.value;
  if (!el) return 0;
  return Math.max(0, el.scrollWidth - el.clientWidth);
}

function selectSlot(slot) {
  selectedIndex.value = Number(slot.index) || 1;
  syncSlotForm(slot);
}

function handleRewardClick(slot, track) {
  selectSlot(slot);
  if (rewardStatus(slot, track) === "available") claim(slot, track);
}

function makeReward(reward = {}) {
  return {
    type: reward.type || "item",
    label: reward.label || "",
    item: reward.item || "",
    command: reward.command || "",
    model: reward.model || "",
    amount: Number(reward.amount) || 1,
    image: reward.image || "",
    description: reward.description || "",
    durationDays: Number(reward.durationDays) || 30,
    renewalRunes: Number.isFinite(Number(reward.renewalRunes)) ? Number(reward.renewalRunes) : 150,
    garage: reward.garage || ""
  };
}

function syncSlotForm(slot = selectedSlot.value) {
  if (!slot) {
    slotForm.value = null;
    return;
  }

  slotForm.value = {
    index: slot.index,
    title: slot.title || `Slot ${slot.index}`,
    subtitle: slot.subtitle || "",
    image: slot.image || "",
    xpRequired: Number(slot.xpRequired) || 0,
    enabled: slot.enabled !== false,
    freeReward: makeReward(slot.freeReward),
    premiumReward: makeReward(slot.premiumReward)
  };
}

function syncSeasonForm() {
  if (!season.value) return;
  seasonForm.value = {
    title: season.value.title || "",
    subtitle: season.value.subtitle || "",
    startsAt: Number(season.value.startsAt) || 0,
    endsAt: Number(season.value.endsAt) || 0,
    premiumPrice: Number(season.value.premiumPrice) || 0,
    xpPerLevel: Number(season.value.xpPerLevel) || 1000,
    active: season.value.active !== false
  };
}

async function claim(slot, track) {
  await run("claimBattlePassReward", { index: slot.index, track });
}

async function buyPremium() {
  await run("buyBattlePassPremium");
}

function openLevelPurchase() {
  levelAmount.value = Math.min(Math.max(1, Number(levelAmount.value) || 1), maxBuyableLevels.value || 1);
  levelPurchaseOpen.value = true;
}

function changeLevelAmount(delta) {
  levelAmount.value = Math.min(maxBuyableLevels.value || 1, Math.max(1, Number(levelAmount.value || 1) + delta));
}

async function buyLevels() {
  const result = await run("buyBattlePassLevels", { amount: levelAmount.value });
  if (result.ok) levelPurchaseOpen.value = false;
}

async function claimMission(mission) {
  await run("claimBattlePassMission", { mission });
}

function missionPercent(progressValue, targetValue) {
  return Math.min(100, Math.max(0, (Number(progressValue || 0) / Math.max(1, Number(targetValue || 1))) * 100));
}

function missionState(mission) {
  if (missions.value.locked) return "Bloqueada";
  if (mission?.claimed) return "Resgatada";
  if (mission?.canClaim) return "Pronta para resgatar";
  return "Em andamento";
}

async function saveSeason() {
  await run("saveBattlePassSeason", seasonForm.value);
}

async function applySlotCount() {
  await run("setBattlePassSlotCount", { count: slotCount.value });
}

async function saveSlot() {
  if (!slotForm.value) return;
  await run("saveBattlePassSlot", slotForm.value);
}

watch(season, syncSeasonForm, { immediate: true });
watch(slots, () => {
  slotCount.value = Math.max(1, slots.value.length || 10);
  if (!slots.value.some((slot) => Number(slot.index) === Number(selectedIndex.value))) selectedIndex.value = slots.value[0]?.index || 1;
  syncSlotForm();
}, { immediate: true });
watch(maxBuyableLevels, (maximum) => {
  levelAmount.value = Math.min(Math.max(1, Number(levelAmount.value) || 1), maximum || 1);
});
watch(activeTab, async (tab) => {
  if (tab !== "rewards") return;
  await nextTick();
  const el = trackRef.value;
  if (!el) return;
  el.addEventListener("wheel", onTrackWheel, { passive: false });
  el.addEventListener("mousewheel", onTrackWheel, { passive: false });
  el.addEventListener("DOMMouseScroll", onTrackWheel, { passive: false });
});

function onTrackWheel(event) {
  const el = trackRef.value;
  if (!el || maxTrackScroll() <= 0) return;

  event.preventDefault?.();
  event.stopPropagation?.();

  const rawX = Number(event.deltaX) || 0;
  const rawY = Number(event.deltaY) || 0;
  const wheelDelta = Number(event.wheelDelta) || 0;
  const detail = Number(event.detail) || 0;
  let delta = Math.abs(rawX) > Math.abs(rawY) ? rawX : rawY;

  if (delta === 0 && wheelDelta !== 0) delta = -wheelDelta;
  if (delta === 0 && detail !== 0) delta = detail * 40;
  if (delta === 0) return;

  const max = maxTrackScroll();
  const strength = Math.abs(delta) < 24 ? 4.2 : 1.85;
  wheelTarget = Math.max(0, Math.min(max, (wheelFrame ? wheelTarget : el.scrollLeft) + (delta * strength)));

  if (wheelFrame) return;

  const animate = () => {
    const diff = wheelTarget - el.scrollLeft;
    if (Math.abs(diff) < 0.8) {
      el.scrollLeft = wheelTarget;
      wheelFrame = 0;
      return;
    }

    el.scrollLeft += diff * 0.36;
    wheelFrame = window.requestAnimationFrame(animate);
  };

  wheelFrame = window.requestAnimationFrame(animate);
}

onMounted(() => {
  const el = trackRef.value;
  if (!el) return;

  el.addEventListener("wheel", onTrackWheel, { passive: false });
  el.addEventListener("mousewheel", onTrackWheel, { passive: false });
  el.addEventListener("DOMMouseScroll", onTrackWheel, { passive: false });
});

onBeforeUnmount(() => {
  const el = trackRef.value;
  if (wheelFrame) {
    window.cancelAnimationFrame(wheelFrame);
    wheelFrame = 0;
  }
  if (!el) return;

  el.removeEventListener("wheel", onTrackWheel);
  el.removeEventListener("mousewheel", onTrackWheel);
  el.removeEventListener("DOMMouseScroll", onTrackWheel);
});
</script>

<template>
  <div class="battlepass-screen">
    <Transition name="feedback">
      <div v-if="feedback" class="vip-feedback" :class="feedback.kind">
        <i :class="feedback.kind === 'success' ? 'fa-solid fa-check' : 'fa-solid fa-circle-info'"></i>
        {{ feedback.message }}
      </div>
    </Transition>

    <header class="bp-season-hero">
      <div class="bp-season-emblem" aria-hidden="true">
        <img :src="battlePassIcon" alt="" />
      </div>

      <div class="bp-title-block">
        <small><span></span>{{ t("battlepass.season", "Temporada ativa") }}</small>
        <h1>{{ season?.title || t("battlepass.title", "Passe de Batalha") }}</h1>
        <p>{{ season?.subtitle || t("battlepass.subtitle", "Avance pela temporada e conquiste recompensas.") }}</p>
      </div>

      <div class="bp-season-facts">
        <article>
          <i class="fa-regular fa-calendar"></i>
          <span>
            <small>Encerramento</small>
            <b>{{ seasonDaysRemaining === null ? "Sem prazo" : `${seasonDaysRemaining} dias` }}</b>
          </span>
          <em>{{ seasonEndLabel }}</em>
        </article>
        <article>
          <i class="fa-solid fa-gift"></i>
          <span>
            <small>Coleção</small>
            <b>{{ totalRewards }} recompensas</b>
          </span>
          <em>{{ unlockedSlots }}/{{ slots.length }} etapas</em>
        </article>
      </div>

      <div class="bp-hero-actions">
        <button v-if="!hasPremium" class="bp-premium-btn" type="button" :disabled="busy" @click="buyPremium">
          <i class="fa-solid fa-crown"></i>
          <span>
            <small>{{ t("battlepass.buyPremium", "Desbloquear Premium") }}</small>
            <b>{{ money(season?.premiumPrice || 0) }} Runas</b>
          </span>
        </button>
        <span v-else class="bp-premium-owned">
          <i class="fa-solid fa-crown"></i>
          <span><small>Passe</small><b>{{ t("battlepass.premiumOwned", "Premium ativo") }}</b></span>
        </span>

        <button
          v-if="hasPremium && levelPurchase.enabled !== false"
          class="bp-level-buy-btn"
          type="button"
          :disabled="busy || passCompleted"
          @click="openLevelPurchase"
        >
          <i class="fa-solid fa-arrow-up-right-dots"></i>
          <span><small>A partir de</small><b>{{ money(pricePerLevel) }} Runas</b></span>
        </button>

        <button v-if="isAdmin" class="bp-admin-gear" type="button" @click="adminOpen = true" :title="t('battlepass.admin', 'Administrar temporada')">
          <i class="fa-solid fa-sliders"></i>
        </button>
      </div>
    </header>

    <main class="bp-layout">
      <section class="bp-board">
        <nav class="bp-section-tabs" aria-label="Seções do Passe de Batalha">
          <button type="button" :class="{ active: activeTab === 'rewards' }" @click="activeTab = 'rewards'">
            <i class="fa-solid fa-gift"></i>
            {{ t("battlepass.rewardsTab", "Recompensas") }}
          </button>
          <button type="button" :class="{ active: activeTab === 'missions' }" @click="activeTab = 'missions'">
            <i class="fa-solid fa-list-check"></i>
            {{ t("battlepass.missionsTab", "Missões") }}
          </button>
        </nav>

        <div v-if="activeTab === 'rewards'" class="bp-rewards-view">
          <div class="bp-overview">
          <div class="bp-level-overview">
            <div class="bp-level-card">
              <small>{{ t("battlepass.level", "Nível") }}</small>
              <strong>{{ level }}</strong>
            </div>
            <div class="bp-xp-block">
              <div class="bp-xp-row">
                <span>{{ t("battlepass.progress", "Progresso atual") }}</span>
                <b>{{ money(currentXp) }} <small>/ {{ money(nextLevelXp) }} XP</small></b>
              </div>
              <div class="bp-progress"><i :style="{ width: progressPercent + '%' }"></i></div>
              <div class="bp-xp-caption">
                <span>{{ Math.round(progressPercent) }}% concluído</span>
                <span>{{ money(xpRemaining) }} XP para o próximo nível</span>
              </div>
            </div>
          </div>

          <div class="bp-overview-stats">
            <article>
              <i class="fa-solid fa-unlock-keyhole"></i>
              <span><small>Etapas liberadas</small><b>{{ unlockedSlots }} de {{ slots.length }}</b></span>
            </article>
            <article :class="{ highlight: claimableRewards > 0 }">
              <i class="fa-solid fa-box-open"></i>
              <span><small>Disponíveis agora</small><b>{{ claimableRewards }} para resgatar</b></span>
            </article>
            <article>
              <i class="fa-solid fa-flag-checkered"></i>
              <span><small>Próximo marco</small><b>{{ nextSlot ? `Etapa ${nextSlot.index}` : "Temporada concluída" }}</b></span>
            </article>
          </div>
        </div>

          <div class="bp-track-toolbar">
          <div>
            <small>Trilha da temporada</small>
            <strong>Recompensas e marcos</strong>
          </div>
          <span class="bp-scroll-hint"><i class="fa-solid fa-computer-mouse"></i> Role para navegar</span>
          <div class="bp-track-actions">
            <button v-if="lastClaimedIndex > 0" class="bp-last-claimed" type="button" @click="scrollToSlot(lastClaimedIndex)" :title="t('battlepass.goLastClaimed', 'Ir ao último resgatado')">
              <i class="fa-solid fa-clock-rotate-left"></i>
              <b>#{{ lastClaimedIndex }}</b>
            </button>
            <button type="button" @click="scrollTrack(-1)" aria-label="Previous rewards">
              <i class="fa-solid fa-chevron-left"></i>
            </button>
            <button type="button" @click="scrollTrack(1)" aria-label="Next rewards">
              <i class="fa-solid fa-chevron-right"></i>
            </button>
          </div>
        </div>

          <div class="bp-reward-stage">
          <aside class="bp-lane-labels" aria-hidden="true">
            <span class="bp-lane-step"><small>Marco</small><b>Nível</b></span>
            <span class="bp-lane-free"><i class="fa-solid fa-gift"></i><small>Trilha</small><b>Gratuita</b></span>
            <span class="bp-lane-premium"><i class="fa-solid fa-crown"></i><small>Trilha</small><b>Premium</b></span>
          </aside>

          <div ref="trackRef" class="bp-track-scroll">
            <article
              v-for="slot in slots"
              :key="slot.id || slot.index"
              class="bp-column"
              :class="{ active: selectedSlot?.index === slot.index, locked: currentXp < Number(slot.xpRequired || 0), disabled: slot.enabled === false }"
            >
              <button class="bp-level-pin" type="button" @click="selectSlot(slot)">
                <b>{{ slot.index }}</b>
                <span>{{ slot.subtitle || `Etapa ${slot.index}` }}</span>
                <small>{{ money(slot.xpRequired) }} XP</small>
              </button>

              <button class="bp-card free" :class="rewardStatus(slot, 'free')" type="button" :title="slot.freeReward?.label || ''" @click="handleRewardClick(slot, 'free')">
                <span class="bp-card-image">
                  <img v-if="slot.freeReward?.image" :src="assetUrl(slot.freeReward.image)" alt="" />
                  <i v-else :class="rewardIcon(slot.freeReward)"></i>
                </span>
                <span v-if="rewardAmount(slot.freeReward)" class="bp-amount-badge">{{ rewardAmount(slot.freeReward) }}</span>
                <span class="bp-card-copy">
                  <small>{{ slot.title || `Etapa ${slot.index}` }}</small>
                  <b>{{ slot.freeReward?.label || t("battlepass.emptyReward", "Recompensa não configurada") }}</b>
                </span>
                <em>
                  <i :class="rewardStatus(slot, 'free') === 'claimed' ? 'fa-solid fa-check' : rewardStatus(slot, 'free') === 'available' ? 'fa-solid fa-hand-pointer' : 'fa-solid fa-lock' "></i>
                  {{ rewardStatus(slot, "free") === "available" ? t("common.claim", "Resgatar") : statusLabel(rewardStatus(slot, "free")) }}
                </em>
              </button>

              <button class="bp-card premium" :class="rewardStatus(slot, 'premium')" type="button" :title="slot.premiumReward?.label || ''" @click="handleRewardClick(slot, 'premium')">
                <span class="bp-card-image">
                  <img v-if="slot.premiumReward?.image" :src="assetUrl(slot.premiumReward.image)" alt="" />
                  <i v-else :class="rewardIcon(slot.premiumReward)"></i>
                </span>
                <span v-if="rewardAmount(slot.premiumReward)" class="bp-amount-badge">{{ rewardAmount(slot.premiumReward) }}</span>
                <span class="bp-card-copy">
                  <small>{{ slot.title || `Etapa ${slot.index}` }}</small>
                  <b>{{ slot.premiumReward?.label || t("battlepass.emptyReward", "Recompensa não configurada") }}</b>
                </span>
                <em>
                  <i :class="rewardStatus(slot, 'premium') === 'claimed' ? 'fa-solid fa-check' : rewardStatus(slot, 'premium') === 'available' ? 'fa-solid fa-hand-pointer' : 'fa-solid fa-lock' "></i>
                  {{ rewardStatus(slot, "premium") === "available" ? t("common.claim", "Resgatar") : statusLabel(rewardStatus(slot, "premium")) }}
                </em>
              </button>
            </article>
          </div>
          </div>
        </div>

        <section v-else class="bp-missions-view" :class="{ locked: missions.locked }">
          <header class="bp-missions-head">
            <div>
              <small>JORNADAS DIÁRIAS</small>
              <h2>Missões da temporada</h2>
              <p>O progresso é renovado diariamente. Volte, trabalhe e movimente a economia da cidade.</p>
            </div>
            <span><i class="fa-regular fa-clock"></i> Reinicia diariamente</span>
          </header>

          <div v-if="missions.locked" class="bp-missions-locked">
            <i class="fa-solid fa-lock"></i>
            <div>
              <b>Passe concluído</b>
              <span>{{ t("battlepass.missionsLocked", "Missões bloqueadas até o próximo passe.") }}</span>
            </div>
          </div>

          <div class="bp-mission-grid">
            <article v-if="missions.login?.enabled !== false" class="bp-mission-card login">
              <header><i class="fa-solid fa-calendar-check"></i><span><small>DIÁRIA</small><b>Entrada na cidade</b></span></header>
              <p>Resgate a presença de hoje. No {{ Number(missions.login?.streakDays || 30) }}º dia consecutivo, receba mais {{ money(missions.login?.streakBonusXp) }} XP.</p>
              <div class="bp-streak" aria-label="Sequência de entradas">
                <i v-for="day in Number(missions.login?.streakDays || 30)" :key="day" :class="{ active: day <= Number(missions.login?.streak || 0) }">{{ day }}</i>
              </div>
              <footer>
                <span><small>RECOMPENSA</small><b>+{{ money(missions.login?.dailyXp) }} XP</b></span>
                <button v-if="missions.login?.canClaim" type="button" :disabled="busy" @click="claimMission('login')">Resgatar</button>
                <em v-else>{{ missionState(missions.login) }}</em>
              </footer>
            </article>

            <article v-if="missions.jobs?.enabled !== false" class="bp-mission-card jobs">
              <header><i class="fa-solid fa-briefcase"></i><span><small>EMPREGOS</small><b>Trabalhe na cidade</b></span></header>
              <p>O XP recebido nos empregos também avança o passe até o limite diário.</p>
              <div class="bp-mission-progress"><i :style="{ width: missionPercent(missions.jobs?.progress, missions.jobs?.cap) + '%' }"></i></div>
              <div class="bp-mission-numbers"><b>{{ money(missions.jobs?.progress) }} XP</b><span>de {{ money(missions.jobs?.cap) }} XP</span></div>
              <footer><span><small>ENTREGA</small><b>Automática</b></span><em>{{ Number(missions.jobs?.progress || 0) >= Number(missions.jobs?.cap || 1) ? "Limite atingido" : "Em andamento" }}</em></footer>
            </article>

            <article v-if="missions.money?.enabled !== false" class="bp-mission-card money">
              <header><i class="fa-solid fa-money-bill-wave"></i><span><small>ECONOMIA</small><b>Movimente seu dinheiro</b></span></header>
              <p>Gaste R$ {{ money(missions.money?.target) }} usando dinheiro ou banco durante o dia.</p>
              <div class="bp-mission-progress"><i :style="{ width: missionPercent(missions.money?.progress, missions.money?.target) + '%' }"></i></div>
              <div class="bp-mission-numbers"><b>R$ {{ money(missions.money?.progress) }}</b><span>de R$ {{ money(missions.money?.target) }}</span></div>
              <footer>
                <span><small>RECOMPENSA</small><b>+{{ money(missions.money?.rewardXp) }} XP</b></span>
                <button v-if="missions.money?.canClaim" type="button" :disabled="busy" @click="claimMission('money')">Resgatar</button>
                <em v-else>{{ missionState(missions.money) }}</em>
              </footer>
            </article>

            <article v-if="missions.runes?.enabled !== false" class="bp-mission-card runes">
              <header><i class="fa-solid fa-gem"></i><span><small>RUNAS</small><b>Fortaleça a temporada</b></span></header>
              <p>Use {{ money(missions.runes?.target) }} Runas na cidade para liberar a recompensa diária.</p>
              <div class="bp-mission-progress"><i :style="{ width: missionPercent(missions.runes?.progress, missions.runes?.target) + '%' }"></i></div>
              <div class="bp-mission-numbers"><b>{{ money(missions.runes?.progress) }} Runas</b><span>de {{ money(missions.runes?.target) }}</span></div>
              <footer>
                <span><small>RECOMPENSA</small><b>+{{ money(missions.runes?.rewardXp) }} XP</b></span>
                <button v-if="missions.runes?.canClaim" type="button" :disabled="busy" @click="claimMission('runes')">Resgatar</button>
                <em v-else>{{ missionState(missions.runes) }}</em>
              </footer>
            </article>
          </div>
        </section>
      </section>
    </main>

    <Transition name="bp-modal">
      <section v-if="levelPurchaseOpen" class="bp-admin-backdrop">
        <div class="bp-level-purchase-modal" role="dialog" aria-modal="true">
          <header>
            <i class="fa-solid fa-arrow-up-right-dots"></i>
            <div><small>PASSE PREMIUM</small><h2>{{ t("battlepass.buyLevels", "Comprar níveis") }}</h2></div>
            <button type="button" @click="levelPurchaseOpen = false" aria-label="Fechar"><i class="fa-solid fa-xmark"></i></button>
          </header>
          <p>Avance imediatamente na trilha. Cada nível adiciona {{ money(xpPerLevel) }} XP ao passe atual.</p>
          <div class="bp-level-stepper">
            <button type="button" :disabled="levelAmount <= 1" @click="changeLevelAmount(-1)"><i class="fa-solid fa-minus"></i></button>
            <span><b>{{ levelAmount }}</b><small>nível(is)</small></span>
            <button type="button" :disabled="levelAmount >= maxBuyableLevels" @click="changeLevelAmount(1)"><i class="fa-solid fa-plus"></i></button>
          </div>
          <div class="bp-level-summary">
            <span><small>XP RECEBIDO</small><b>+{{ money(levelPurchaseXp) }} XP</b></span>
            <span><small>VALOR TOTAL</small><b>{{ money(levelPurchaseTotal) }} Runas</b></span>
          </div>
          <button class="bp-level-confirm" type="button" :disabled="busy || maxBuyableLevels <= 0" @click="buyLevels">
            <i class="fa-solid fa-gem"></i> Confirmar compra
          </button>
        </div>
      </section>
    </Transition>

    <Transition name="bp-modal">
      <section v-if="isAdmin && adminOpen" class="bp-admin-backdrop">
        <div class="bp-admin-modal" role="dialog" aria-modal="true">
          <header class="bp-admin-modal-head">
            <div class="bp-admin-icon"><i class="fa-solid fa-gear"></i></div>
            <div>
              <small>{{ t("battlepass.admin", "Administração") }}</small>
              <h2>{{ t("battlepass.adminTitle", "Editor do Passe") }}</h2>
              <p>{{ t("battlepass.adminSubtitle", "Configure a temporada e suas recompensas.") }}</p>
            </div>
            <button class="bp-modal-close" type="button" @click="adminOpen = false" :aria-label="t('common.close', 'Fechar')">
              <i class="fa-solid fa-xmark"></i>
            </button>
          </header>

          <div class="bp-admin-panel">
            <div class="bp-admin-workspace">
              <aside class="bp-admin-sidebar">
                <section class="bp-admin-card">
                  <div class="bp-admin-card-title">
                    <i class="fa-solid fa-calendar-days"></i>
                    <div>
                      <small>{{ t("battlepass.stepSeason", "Etapa 1") }}</small>
                      <h3>{{ t("battlepass.season", "Temporada") }}</h3>
                    </div>
                  </div>

                  <form class="bp-compact-form" @submit.prevent="saveSeason">
                    <label><span>{{ t("battlepass.seasonTitle", "Título") }}</span><input v-model="seasonForm.title" /></label>
                    <label><span>{{ t("battlepass.seasonSubtitle", "Subtítulo") }}</span><input v-model="seasonForm.subtitle" /></label>
                    <div class="bp-two-fields">
                      <label><span>{{ t("battlepass.premiumPrice", "Valor Premium") }}</span><input v-model.number="seasonForm.premiumPrice" type="number" min="0" /></label>
                      <label><span>{{ t("battlepass.xpPerLevel", "XP por nível") }}</span><input v-model.number="seasonForm.xpPerLevel" type="number" min="1" /></label>
                    </div>
                    <button class="bp-primary-action" type="submit" :disabled="busy">
                      <i class="fa-solid fa-floppy-disk"></i>
                      {{ t("common.save", "Salvar") }}
                    </button>
                  </form>
                </section>

                <section class="bp-admin-card">
                  <div class="bp-admin-card-title">
                    <i class="fa-solid fa-layer-group"></i>
                    <div>
                      <small>{{ t("battlepass.stepSlots", "Etapa 2") }}</small>
                      <h3>{{ t("battlepass.slots", "Marcos") }}</h3>
                    </div>
                  </div>

                  <div class="bp-slot-count-row">
                    <input v-model.number="slotCount" type="number" min="1" max="200" />
                    <button type="button" :disabled="busy" @click="applySlotCount">{{ t("battlepass.applySlots", "Aplicar") }}</button>
                  </div>

                  <div class="bp-admin-slot-list">
                    <button
                      v-for="slot in slots"
                      :key="'admin-slot-' + slot.index"
                      type="button"
                      :class="{ active: Number(slot.index) === Number(selectedIndex) }"
                      @click="selectSlot(slot)"
                    >
                      <b>#{{ slot.index }}</b>
                      <span>{{ slot.freeReward?.label || slot.premiumReward?.label || t("battlepass.emptyReward", "Sem recompensa") }}</span>
                      <small>{{ money(slot.xpRequired) }} XP</small>
                    </button>
                  </div>
                </section>
              </aside>

              <form v-if="slotForm" class="bp-slot-editor" @submit.prevent="saveSlot">
                <header class="bp-slot-editor-head">
                  <div>
                    <small>{{ t("battlepass.stepReward", "Etapa 3") }}</small>
                    <h3>{{ t("battlepass.selectedSlot", "Marco selecionado") }} #{{ slotForm.index }}</h3>
                    <p>{{ t("battlepass.slotEditorHint", "Defina a experiência necessária e o conteúdo recebido pelo jogador.") }}</p>
                  </div>
                  <button class="bp-primary-action" type="submit" :disabled="busy">
                    <i class="fa-solid fa-check"></i>
                    {{ t("battlepass.saveSlot", "Salvar marco") }}
                  </button>
                </header>

                <section class="bp-admin-card bp-slot-basics">
                  <div class="bp-admin-card-title">
                    <i class="fa-solid fa-sliders"></i>
                    <div>
                      <small>{{ t("battlepass.basicInfo", "Informações básicas") }}</small>
                      <h3>{{ t("battlepass.slotSettings", "Configurações do marco") }}</h3>
                    </div>
                  </div>

                  <div class="bp-field-grid">
                    <label><span>{{ t("battlepass.seasonTitle", "Título") }}</span><input v-model="slotForm.title" /></label>
                    <label><span>{{ t("battlepass.seasonSubtitle", "Subtítulo") }}</span><input v-model="slotForm.subtitle" /></label>
                    <label><span>{{ t("battlepass.xpRequired", "XP necessário") }}</span><input v-model.number="slotForm.xpRequired" type="number" min="0" /></label>
                    <button class="bp-toggle-button" type="button" :class="{ active: slotForm.enabled }" @click="slotForm.enabled = !slotForm.enabled">
                      <i :class="slotForm.enabled ? 'fa-solid fa-eye' : 'fa-solid fa-eye-slash'"></i>
                      {{ slotForm.enabled ? t("common.enabled", "Ativado") : t("common.disabled", "Desativado") }}
                    </button>
                  </div>
                </section>

                <div class="bp-reward-editor">
                  <section class="bp-reward-card">
                    <div class="bp-reward-card-head">
                      <i class="fa-solid fa-gift"></i>
                      <div>
                        <small>{{ t("battlepass.freeTrack", "Trilha gratuita") }}</small>
                        <h4>{{ t("battlepass.freeReward", "Recompensa gratuita") }}</h4>
                      </div>
                    </div>

                    <label>
                      <span>{{ t("battlepass.rewardType", "Tipo") }}</span>
                      <div class="bp-type-picker">
                        <button v-for="type in rewardTypes" :key="'free-' + type" type="button" :class="{ active: slotForm.freeReward.type === type }" @click="slotForm.freeReward.type = type">
                          {{ rewardTypeLabel(type) }}
                        </button>
                      </div>
                    </label>
                    <div class="bp-field-grid" :class="{ two: slotForm.freeReward.type !== 'vehicle' && slotForm.freeReward.type !== 'none' }">
                      <label><span>{{ t("battlepass.rewardLabel", "Nome da recompensa") }}</span><input v-model="slotForm.freeReward.label" /></label>
                      <label v-if="slotForm.freeReward.type !== 'vehicle' && slotForm.freeReward.type !== 'none'"><span>{{ t("battlepass.rewardAmount", "Quantidade") }}</span><input v-model.number="slotForm.freeReward.amount" type="number" min="1" /></label>
                    </div>
                    <label v-if="slotForm.freeReward.type === 'item'"><span>{{ t("battlepass.rewardItem", "Item ou identificador") }}</span><input v-model="slotForm.freeReward.item" /></label>
                    <label v-if="slotForm.freeReward.type === 'command'"><span>{{ t("battlepass.rewardCommand", "Comando") }}</span><input v-model="slotForm.freeReward.command" /></label>
                    <template v-if="slotForm.freeReward.type === 'vehicle'">
                      <div class="bp-field-grid two">
                        <label><span>{{ t("battlepass.rewardVehicleModel", "Spawn do veículo") }}</span><input v-model="slotForm.freeReward.model" placeholder="ex.: sultanrs" /></label>
                        <label><span>{{ t("battlepass.rewardVehicleDays", "Validade em dias") }}</span><input v-model.number="slotForm.freeReward.durationDays" type="number" min="1" max="3650" /></label>
                      </div>
                      <div class="bp-field-grid two">
                        <label><span>{{ t("battlepass.rewardVehicleRenewal", "Renovação em Runas") }}</span><input v-model.number="slotForm.freeReward.renewalRunes" type="number" min="0" /></label>
                        <label><span>{{ t("battlepass.rewardVehicleGarage", "Garagem inicial") }}</span><input v-model="slotForm.freeReward.garage" :placeholder="t('battlepass.rewardVehicleGarageHint', 'Vazio usa a garagem padrão')" /></label>
                      </div>
                    </template>
                    <label><span>{{ t("battlepass.rewardImage", "Caminho da imagem") }}</span><input v-model="slotForm.freeReward.image" placeholder="web/imgs/item.png" /></label>
                    <label><span>{{ t("battlepass.rewardDescription", "Descrição") }}</span><input v-model="slotForm.freeReward.description" :placeholder="slotForm.freeReward.type === 'vehicle' ? 'Veículo disponível por 30 dias.' : ''" /></label>
                  </section>

                  <section class="bp-reward-card premium">
                    <div class="bp-reward-card-head">
                      <i class="fa-solid fa-crown"></i>
                      <div>
                        <small>{{ t("battlepass.premiumTrack", "Trilha premium") }}</small>
                        <h4>{{ t("battlepass.premiumReward", "Recompensa premium") }}</h4>
                      </div>
                    </div>

                    <label>
                      <span>{{ t("battlepass.rewardType", "Tipo") }}</span>
                      <div class="bp-type-picker">
                        <button v-for="type in rewardTypes" :key="'premium-' + type" type="button" :class="{ active: slotForm.premiumReward.type === type }" @click="slotForm.premiumReward.type = type">
                          {{ rewardTypeLabel(type) }}
                        </button>
                      </div>
                    </label>
                    <div class="bp-field-grid" :class="{ two: slotForm.premiumReward.type !== 'vehicle' && slotForm.premiumReward.type !== 'none' }">
                      <label><span>{{ t("battlepass.rewardLabel", "Nome da recompensa") }}</span><input v-model="slotForm.premiumReward.label" /></label>
                      <label v-if="slotForm.premiumReward.type !== 'vehicle' && slotForm.premiumReward.type !== 'none'"><span>{{ t("battlepass.rewardAmount", "Quantidade") }}</span><input v-model.number="slotForm.premiumReward.amount" type="number" min="1" /></label>
                    </div>
                    <label v-if="slotForm.premiumReward.type === 'item'"><span>{{ t("battlepass.rewardItem", "Item ou identificador") }}</span><input v-model="slotForm.premiumReward.item" /></label>
                    <label v-if="slotForm.premiumReward.type === 'command'"><span>{{ t("battlepass.rewardCommand", "Comando") }}</span><input v-model="slotForm.premiumReward.command" /></label>
                    <template v-if="slotForm.premiumReward.type === 'vehicle'">
                      <div class="bp-field-grid two">
                        <label><span>{{ t("battlepass.rewardVehicleModel", "Spawn do veículo") }}</span><input v-model="slotForm.premiumReward.model" placeholder="ex.: sultanrs" /></label>
                        <label><span>{{ t("battlepass.rewardVehicleDays", "Validade em dias") }}</span><input v-model.number="slotForm.premiumReward.durationDays" type="number" min="1" max="3650" /></label>
                      </div>
                      <div class="bp-field-grid two">
                        <label><span>{{ t("battlepass.rewardVehicleRenewal", "Renovação em Runas") }}</span><input v-model.number="slotForm.premiumReward.renewalRunes" type="number" min="0" /></label>
                        <label><span>{{ t("battlepass.rewardVehicleGarage", "Garagem inicial") }}</span><input v-model="slotForm.premiumReward.garage" :placeholder="t('battlepass.rewardVehicleGarageHint', 'Vazio usa a garagem padrão')" /></label>
                      </div>
                    </template>
                    <label><span>{{ t("battlepass.rewardImage", "Caminho da imagem") }}</span><input v-model="slotForm.premiumReward.image" placeholder="web/imgs/item.png" /></label>
                    <label><span>{{ t("battlepass.rewardDescription", "Descrição") }}</span><input v-model="slotForm.premiumReward.description" :placeholder="slotForm.premiumReward.type === 'vehicle' ? 'Veículo disponível por 30 dias.' : ''" /></label>
                  </section>
                </div>
              </form>
            </div>
          </div>
        </div>
      </section>
    </Transition>
  </div>
</template>
