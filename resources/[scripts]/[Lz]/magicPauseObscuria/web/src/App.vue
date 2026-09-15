<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { state, closeMenu } from "./store/menu";

import Geral from "./views/Geral.vue";
import Rankings from "./views/Rankings.vue";
import Raspadinhas from "./views/Raspadinha.vue";
import Empregos from "./views/Empregos.vue";
import Estabelecimentos from "./views/Estabelecimentos.vue";
import Factions from "./views/Factions.vue";
import VipStore from "./views/VipStore.vue";
import Tickets from "./views/Tickets.vue";
import BattlePass from "./views/BattlePass.vue";
import olhoBranco from "./assets/imgs/olho-branco.png";
import runeIcon from "./assets/imgs/runa-icon.png";

const screens = {
  geral: Geral,
  ranking: Rankings,
  raspadinha: Raspadinhas,
  empregos: Empregos,
  estabelecimentos: Estabelecimentos,
  vip: VipStore,
  tickets: Tickets,
  battlepass: BattlePass,
  factions: Factions
};

const profile = ref({ id: "", name: "", avatar: "", runes: 0 });
const factionPayload = ref(null);
const vipPayload = ref(null);
const ticketsPayload = ref(null);
const battlePassPayload = ref(null);
const establishmentsPayload = ref(null);
const rankingsPayload = ref(null);
const loadingProfile = ref(false);
const openedAt = ref(0);
const previewParams = new URLSearchParams(window.location.search);
const previewMode = previewParams.get("preview") === "1";

const previewOptions = [
  { id: "geral", label: "Geral", description: "Informações do personagem.", icon: "fa-solid fa-user" },
  { id: "ranking", label: "Ranking", description: "Destaques da cidade.", icon: "fa-solid fa-ranking-star" },
  { id: "factions", label: "Clãs", description: "Catálogo, liderança e gestão.", icon: "fa-solid fa-building-shield" },
  { id: "vip", label: "Loja VIP", description: "Produtos, Pix, Runas e vantagens.", icon: "fa-solid fa-gem" },
  { id: "empregos", label: "Empregos", description: "Indisponível no momento.", icon: "fa-solid fa-briefcase", disabled: true },
  { id: "estabelecimentos", label: "Estabelecimentos", description: "Locais e utilidades.", icon: "fa-solid fa-store" },
  { id: "battlepass", label: "Passe de Batalha", description: "Temporada, progresso e recompensas.", icon: "fa-solid fa-shield-halved" },
  { id: "tickets", label: "Suporte", description: "Tickets e atendimento com a equipe.", icon: "fa-solid fa-headset" }
];

const options = computed(() => {
  const configured = factionPayload.value?.options?.length
    ? factionPayload.value.options
    : previewOptions;

  return configured.filter((option) => option.disabled !== true);
});

const activeScreen = computed(() => {
  const option = options.value.find((item) => item.id === state.screen);
  return option?.disabled ? Geral : (screens[state.screen] || Geral);
});
const initials = computed(() => {
  return String(profile.value.name || "VG")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
});

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "MagicPause";
}

async function nui(eventName, data = {}) {
  if (previewMode) return previewResponse(eventName, data);
  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data)
  });
  return response.json().catch(() => ({}));
}

function previewResponse(eventName) {
  const timestamp = Math.floor(Date.now() / 1000);
  if (eventName === "getPlayerInfo") return { passport: "1842", name: "Morgana Vale", runes: 2450 };
  if (eventName === "getRankings") return {
    ok: true,
    limit: 10,
    generatedAt: timestamp,
    rankings: {
      donations: [
        { position: 1, passport: "2041", name: "Helena Moura", value: 18500, contributions: 8 },
        { position: 2, passport: "3182", name: "Ninti Pre", value: 14200, contributions: 6 },
        { position: 3, passport: "3910", name: "Dante Moretti", value: 9800, contributions: 4 },
        { position: 4, passport: "1554", name: "Evelyn Black", value: 7200, contributions: 3 },
        { position: 5, passport: "4480", name: "Victor Salazar", value: 5100, contributions: 2 }
      ],
      vehicles: [
        { position: 1, passport: "3910", name: "Dante Moretti", value: 18 },
        { position: 2, passport: "1554", name: "Evelyn Black", value: 14 },
        { position: 3, passport: "1842", name: "Morgana Vale", value: 11, isCurrent: true },
        { position: 4, passport: "2041", name: "Helena Moura", value: 9 }
      ],
      money: [
        { position: 1, passport: "4480", name: "Victor Salazar", value: 845300, cash: 15300, bank: 830000 },
        { position: 2, passport: "1842", name: "Morgana Vale", value: 190810, cash: 4270, bank: 186540, isCurrent: true },
        { position: 3, passport: "2041", name: "Helena Moura", value: 162400, cash: 12400, bank: 150000 },
        { position: 4, passport: "3910", name: "Dante Moretti", value: 128050, cash: 8050, bank: 120000 }
      ]
    },
    current: {
      donations: { position: 27, passport: "1842", value: 1200, contributions: 1, inTop: false },
      vehicles: { position: 3, passport: "1842", value: 11, inTop: true },
      money: { position: 2, passport: "1842", value: 190810, cash: 4270, bank: 186540, inTop: true }
    }
  };
  if (eventName === "getFactions") return { profile: { id: "1842", name: "Morgana Vale", runes: 2450 }, runes: 2450, options: previewOptions };
  if (eventName === "getVipStore") return {
    enabled: true,
    title: "Loja VIP",
    subtitle: "Produtos especiais de Obscuria.",
    currencyLabel: "Runas",
    productTemplate: "web/imgs/vipstore/bg_template.png",
    balance: 2450,
    isAdmin: true,
    pix: { enabled: true },
    runeDeposit: { enabled: true, runesPerReal: 10, minimum: 10, maximum: 50000, step: 10, presets: [100, 250, 500, 1000, 2500] },
    categories: [
      { id: "featured", label: "Planos VIP", icon: "fa-solid fa-crown" },
      { id: "services", label: "Personagem", icon: "fa-solid fa-user-gear" }
    ],
    products: [
      { id: "vip_veu", category: "featured", title: "VIP VÉU", subtitle: "30 dias de benefícios", description: "Renda extra, veículo exclusivo e mais capacidade.", image: "web/imgs/vipstore/veu.png", icon: "fa-solid fa-moon", badge: "VÉU", priceRunes: 399, payment: { runes: true }, features: ["$ 50.000 iniciais", "$ 2.000 por hora", "1 veículo VÉU", "+10 kg enquanto estiver ativo", "5% em veículos", "Tag VÉU"] },
      { id: "vip_eclipse", category: "featured", title: "VIP ECLIPSE", subtitle: "30 dias de benefícios", description: "Dois veículos, mais capacidade e descontos em serviços.", image: "web/imgs/vipstore/eclipse.png", icon: "fa-solid fa-circle-half-stroke", badge: "ECLIPSE", priceRunes: 799, payment: { runes: true }, features: ["$ 120.000 iniciais", "$ 4.000 por hora", "2 veículos ECLIPSE", "+20 kg enquanto estiver ativo", "10% em veículos, combustível e hospital", "1 Troca de Nome", "Tag ECLIPSE"] },
      { id: "vip_arcano", category: "featured", title: "VIP ARCANO", subtitle: "30 dias de benefícios", description: "O nível máximo de benefícios da Obscuria.", image: "web/imgs/vipstore/arcano.png", icon: "fa-solid fa-wand-sparkles", badge: "ARCANO", priceRunes: 1499, payment: { runes: true }, features: ["$ 250.000 iniciais", "$ 7.500 por hora", "3 veículos ARCANO", "+30 kg enquanto estiver ativo", "15% em veículos, combustível e hospital", "2 Trocas de Nome", "Tag ARCANO"] },
      { id: "trocar_raca", category: "services", title: "Trocar a raça", subtitle: "Escolha uma nova classe", description: "Receba um selo para refazer a escolha de raça do personagem quando desejar.", image: "web/imgs/vipstore/troca_raca.png", icon: "fa-solid fa-arrows-rotate", badge: "RAÇA", priceRunes: 100, payment: { runes: true }, features: ["Item entregue no inventário", "Uso único", "Abre novamente o seletor de raça"] },
      { id: "trocar_nome", category: "services", title: "Trocar o nome", subtitle: "Novo nome e sobrenome", description: "Receba um documento para alterar o nome completo do personagem.", image: "web/imgs/vipstore/troca_nome.png", icon: "fa-solid fa-signature", badge: "NOME", priceRunes: 50, payment: { runes: true }, features: ["Item entregue no inventário", "Uso único", "Altera nome e sobrenome"] },
      { id: "personagem_extra", category: "services", title: "Mais um personagem", subtitle: "Uma vaga adicional no multichar", description: "Adiciona permanentemente uma vaga de personagem à sua conta.", image: "web/imgs/vipstore/personagem_a_mais.png", icon: "fa-solid fa-user-plus", badge: "VAGA", priceRunes: 200, payment: { runes: true }, features: ["Benefício vinculado à licença", "Liberação permanente", "Visível ao retornar ao multichar"] },
      { id: "refazer_personagem", category: "services", title: "Refazer personagem", subtitle: "Personalização completa", description: "Receba um selo para abrir novamente a criação completa de aparência.", image: "web/imgs/vipstore/refazer_personagem.png", icon: "fa-solid fa-wand-magic-sparkles", badge: "VISUAL", priceRunes: 50, payment: { runes: true }, features: ["Item entregue no inventário", "Uso único", "Rosto, corpo, cabelo, roupas e tatuagens"] }
    ],
    vip: {
      active: true,
      memberships: [{ id: 42, vip: "eclipse", label: "VIP ECLIPSE", expiresAt: timestamp + 2592000 }],
      benefits: { salaryTotal: 4000, vehicleDiscount: 10, fuelDiscount: 10, medicalDiscount: 10, inventoryWeight: 20000 },
      vehicleChoices: [{ entitlementId: 91, membershipId: 42, vip: "eclipse", label: "VIP ECLIPSE", slot: 1, expiresAt: timestamp + 2592000, vehicles: [
        { model: "16charger", label: "Lodge Charger", image: "web/imgs/vipstore/16charger.png" },
        { model: "2f2fgtr34", label: "R34", image: "web/imgs/vipstore/2f2fgtr34.png" },
        { model: "18performante", label: "Huracan Performante", image: "web/imgs/vipstore/18performante.png" },
        { model: "19gv80", label: "Tundra PRO", image: "web/imgs/vipstore/19gv80.png" },
        { model: "20xb7", label: "X7 SPORT", image: "web/imgs/vipstore/20xb7.png" },
        { model: "18velar", label: "Velar", image: "web/imgs/vipstore/18Velar.png" },
        { model: "21rsq8", label: "RS Q8", image: "web/imgs/vipstore/21rsq8.png" }
      ] }]
    },
    history: [
      { id: 184, title: "Depósito de 2.500 Runas", method: "Pix", status: "paid", amount: 250, currency: "BRL", createdAt: timestamp - 7200, paidAt: timestamp - 7140 },
      { id: 176, title: "Passe VIP", method: "Runas", status: "paid", amount: 1000, currency: "runes", createdAt: timestamp - 172800, paidAt: timestamp - 172780 },
      { id: 169, title: "Depósito de 500 Runas", method: "Pix", status: "pending", amount: 50, currency: "BRL", createdAt: timestamp - 259200, paidAt: 0 }
    ]
  };
  if (eventName === "getTickets") return {
    ok: true,
    isStaff: true,
    profile: { passport: "1842", name: "Morgana Vale", coins: 2450 },
    config: {
      maxOpenPerPlayer: 3,
      maxTitleLength: 80,
      maxMessageLength: 900,
      categories: [{ id: "support", label: "Suporte", icon: "fa-solid fa-headset" }, { id: "purchase", label: "Compras", icon: "fa-solid fa-bag-shopping" }, { id: "bug", label: "Problema técnico", icon: "fa-solid fa-bug" }, { id: "report", label: "Denúncia", icon: "fa-solid fa-triangle-exclamation" }],
      statuses: [{ id: "open", label: "Aberto", color: "#9b72cf" }, { id: "answered", label: "Respondido", color: "#4eaa88" }, { id: "waiting", label: "Aguardando", color: "#c99548" }, { id: "closed", label: "Fechado", color: "#85818f" }]
    },
    tickets: [{ id: 21, passport: "1842", playerName: "Morgana Vale", category: "support", title: "Preciso de ajuda com um item", status: "answered", assignedName: "Edward", createdAt: timestamp - 1800, updatedAt: timestamp - 240, unread: true }],
    selectedTicket: { id: 21, passport: "1842", playerName: "Morgana Vale", category: "support", title: "Preciso de ajuda com um item", status: "answered", assignedName: "Edward", createdAt: timestamp - 1800, updatedAt: timestamp - 240, unread: true },
    messages: [{ id: 1, ticketId: 21, passport: "1842", playerName: "Morgana Vale", staff: false, message: "O item não apareceu após a compra.", createdAt: timestamp - 1700 }, { id: 2, ticketId: 21, passport: "staff", playerName: "Edward", staff: true, message: "Vou verificar o pedido para você agora.", createdAt: timestamp - 240 }]
  };
  if (eventName === "getBattlePass") return {
    isAdmin: true,
    balance: 2450,
    season: { id: 1, title: "Crônicas de Obscuria", subtitle: "Complete jornadas e desvende os segredos da temporada.", startsAt: timestamp - 86400, endsAt: timestamp + 2592000, premiumPrice: 1000, xpPerLevel: 1000, active: true },
    progress: { xp: 2650, level: 3, premium: true, completed: false, claimedFree: [1, 2], claimedPremium: [1, 2] },
    missions: {
      locked: false,
      maxXp: 7000,
      resetsAt: timestamp + 21600,
      login: { enabled: true, claimed: false, canClaim: true, streak: 4, nextStreak: 5, streakDays: 30, dailyXp: 1000, streakBonusXp: 5000 },
      jobs: { enabled: true, progress: 2350, cap: 5000 },
      money: { enabled: true, progress: 14250, target: 20000, rewardXp: 3500, claimed: false, canClaim: false },
      runes: { enabled: true, progress: 200, target: 200, rewardXp: 5000, claimed: false, canClaim: true }
    },
    config: { maxSlots: 200, levelPurchase: { enabled: true, pricePerLevel: 100, maxPerPurchase: 25 } },
    slots: Array.from({ length: 8 }, (_, index) => ({ id: index + 1, index: index + 1, title: ["Primeiro Presságio", "Passos na Névoa", "Segredo Antigo", "Véu de Obscuria", "Marca do Destino", "Ecos da Cidade", "Pacto Noturno", "Crônica Completa"][index], subtitle: `Etapa ${index + 1}`, xpRequired: index * 1000, enabled: true, freeReward: { type: index % 2 ? "money" : "coins", label: index % 2 ? "$ 1.000" : "50 Runas", amount: index % 2 ? 1000 : 50 }, premiumReward: { type: "coins", label: `${100 + index * 50} Runas`, amount: 100 + index * 50 } }))
  };
  if (eventName === "getEstablishments") return {
    ok: true,
    available: true,
    isStaff: true,
    profile: { id: "1842", source: 12, name: "Morgana Vale" },
    restaurants: [
      {
        id: "vanilla",
        label: "Vanilla",
        job: "vanilla",
        theme: "vanilla",
        isOpen: true,
        canWork: false,
        canManage: false,
        isBoss: false,
        location: { x: 127.4, y: -1287.1, z: 29.3 },
        menu: {
          categories: [{ key: "drinks", label: "Bebidas", icon: "cup-soda", sortOrder: 1 }],
          recipes: [
            { id: 1, categoryKey: "drinks", name: "Refresco da casa", description: "Bebida preparada e servida gelada.", image: "", price: 90, oldPrice: null, badge: "", featured: true, isCombo: false },
            { id: 2, categoryKey: "drinks", name: "Combo noturno", description: "Seleção especial do estabelecimento.", image: "", price: 320, oldPrice: 380, badge: "Destaque", featured: true, isCombo: true }
          ]
        }
      },
      { id: "bahama_mamas", label: "Bahama Mamas", job: "bahama", theme: "bahama", isOpen: true, canWork: false, canManage: false, isBoss: false },
      { id: "club_77", label: "Club 77", job: "club77", theme: "club77", isOpen: false, canWork: false, canManage: false, isBoss: false },
      {
        id: "moomoo_cafe",
        label: "MooMoo Cafe",
        job: "moomoo",
        theme: "moomoo",
        isOpen: true,
        canWork: true,
        canManage: true,
        isBoss: true,
        isMember: true,
        description: "Cafeteria, refeições e atendimento ao público.",
        features: { menu: true, location: true, call: true },
        location: { x: -584.3, y: -1061.1, z: 22.3 },
        locationLabel: "MooMoo Cafe",
        callText: "Solicite atendimento da equipe em serviço.",
        notes: { text: "Cardápio atualizado e equipe disponível para atendimento.", updatedBy: "Morgana Vale", updatedAt: "2026-09-11 18:00:00" },
        dashboard: {
          accountBalance: 18240,
          totals: { today_gross: 4850, week_gross: 28110, month_gross: 98540, today_commission: 1455, today_sales: 17 },
          products: [{ name: "Combo da Casa", amount: 83, revenue: 38180 }, { name: "Hamburguer da Casa", amount: 61, revenue: 17080 }],
          team: [{ employee_identifier: "preview", employee_name: "Morgana Vale", sales: 23, gross: 7380, commission: 2214 }]
        },
        management: {
          ok: true,
          restaurant: { id: "moomoo_cafe", label: "MooMoo Cafe", job: "moomoo", manager_grade: 4, commission_rate: 0.3, theme: "moomoo" },
          categories: [{ id: 1, category_key: "drinks", label: "Bebidas", icon: "cup-soda", sort_order: 1, enabled: true }],
          recipes: [{ id: 3, recipe_key: "moomoo_combo", category_key: "drinks", name: "Combo da Casa", description: "Seleção preparada pela cafeteria.", image: "", price: 460, old_price: 520, menu_badge: "Destaque", featured: true, prep_time: 8, output_item: "produto_restaurante", output_amount: 1, product_type: "drink", item_weight: 300, presentation_key: "coffee", is_combo: true, ingredients: [{ item: "ob_leite", label: "Leite", amount: 1 }], contents: [], craft_steps: [{ type: "mix" }, { type: "package" }], enabled: true }],
          presentations: [
            { key: "coffee", label: "Copo de café", image: "", type: "drink", animationLabel: "Beber", default: true },
            { key: "soda_can", label: "Lata de refrigerante", image: "", type: "drink", animationLabel: "Beber", default: false },
            { key: "burger", label: "Hambúrguer", image: "", type: "food", animationLabel: "Comer", default: true }
          ],
          points: [{ id: 1, restaurant_id: "moomoo_cafe", type: "pos", label: "Caixa", coords: { x: -584.3, y: -1061.1, z: 22.3 }, enabled: true }],
          dashboard: { accountBalance: 18240, totals: { today_gross: 4850, week_gross: 28110, month_gross: 98540, today_commission: 1455, today_sales: 17 }, products: [{ name: "Combo da Casa", amount: 83, revenue: 38180 }], team: [{ employee_identifier: "preview", employee_name: "Morgana Vale", sales: 23, gross: 7380, commission: 2214 }] },
          members: [{ id: "MOO001", citizenId: "MOO001", source: 12, name: "Morgana Vale", role: "Gerente", grade: 4, isBoss: true, online: true }, { id: "MOO002", citizenId: "MOO002", name: "Caio Duarte", role: "Atendente", grade: 1, isBoss: false, online: false }],
          jobGrades: [{ grade: 0, label: "Aprendiz", isBoss: false }, { grade: 1, label: "Atendente", isBoss: false }, { grade: 4, label: "Gerente", isBoss: true }]
        }
      },
      {
        id: "dreamycoffee",
        label: "Dreamy Coffee",
        job: "cafebeans",
        theme: "cafebeans",
        isOpen: true,
        canWork: false,
        canManage: false,
        isBoss: false,
        description: "Cafeteria, bebidas e atendimento ao público.",
        features: { menu: true, location: true, call: true }
      },
      { id: "chinese_seoul", label: "Chinese Seoul", job: "chinese", theme: "chinese", isOpen: true, canWork: false, canManage: false, isBoss: false }
    ]
  };
  return { ok: true };
}

async function refreshProfile() {
  if (loadingProfile.value) return;
  loadingProfile.value = true;
  try {
    const info = await nui("getPlayerInfo");
    applyPlayerInfo(info);
  } finally {
    loadingProfile.value = false;
  }
}

function applyPlayerInfo(info) {
  if (!info || typeof info !== "object") return;
  profile.value = {
    id: info.passport || info.id || profile.value.id || "",
    name: info.name || profile.value.name || "",
    avatar: info.avatar || profile.value.avatar || "",
    runes: info.runes ?? info.vipMoney ?? profile.value.runes ?? 0
  };
}

async function refreshFactions() {
  const payload = await nui("getFactions");
  if (payload && payload.profile) {
    factionPayload.value = payload;
    profile.value = {
      ...profile.value,
      avatar: profile.value.avatar || payload.profile.avatar || "",
      runes: payload.runes ?? profile.value.runes ?? 0
    };
  }
}

async function refreshVipStore() {
  vipPayload.value = await nui("getVipStore");
  if (vipPayload.value) profile.value = { ...profile.value, runes: vipPayload.value.balance ?? profile.value.runes ?? 0 };
}

async function refreshTickets(next = null) {
  if (next && Array.isArray(next.tickets)) {
    ticketsPayload.value = next;
    return;
  }
  const ticketId = typeof next === "number" || typeof next === "string" ? next : next?.ticketId;
  ticketsPayload.value = await nui("getTickets", ticketId ? { ticketId } : {});
}

async function refreshBattlePass() {
  battlePassPayload.value = await nui("getBattlePass");
}

async function refreshEstablishments() {
  establishmentsPayload.value = await nui("getEstablishments");
}

async function refreshRankings() {
  rankingsPayload.value = await nui("getRankings");
}

async function chooseOption(option) {
  if (!option || option.disabled) return;
  state.screen = option.id;
  state.currentSection = option;
  if (option.id === "factions") await refreshFactions();
  if (option.id === "vip") await refreshVipStore();
  if (option.id === "tickets") await refreshTickets();
  if (option.id === "battlepass") await refreshBattlePass();
  if (option.id === "estabelecimentos") await refreshEstablishments();
  if (option.id === "ranking") await refreshRankings();
}

function ensureAvailableScreen() {
  const selected = options.value.find((item) => item.id === state.screen);
  if (selected && !selected.disabled) return;

  const first = options.value.find((item) => !item.disabled);
  state.screen = first?.id || "geral";
  state.currentSection = first || null;
}

async function openMap() {
  await nui("openMap");
}

async function openSettings() {
  await closeMenu();
  await nui("openGtaSettings");
}

async function openRuneDeposit() {
  state.screen = "vip";
  state.currentSection = { id: "vip", label: "Loja VIP" };
  await refreshVipStore();
  window.setTimeout(() => window.dispatchEvent(new CustomEvent("magicpause:open-rune-deposit")), 0);
}

function money(value) {
  return Math.floor(Number(value) || 0).toLocaleString("pt-BR");
}

function onKeyDown(event) {
  if (!state.visible) return;
  if (Date.now() - openedAt.value < 450) return;
  if (event.key === "Escape") closeMenu();
}

async function onRefreshFactions() {
  await refreshFactions();
}

watch(
  () => state.playerInfo,
  (info) => {
    if (info) applyPlayerInfo(info);
    else profile.value = { id: "", name: "", avatar: "", runes: 0 };
  },
  { immediate: true }
);

watch(
  () => state.visible,
  async (visible) => {
    if (!visible) return;
    openedAt.value = Date.now();
    if (!state.screen || state.screen === "main") state.screen = "geral";
    applyPlayerInfo(state.playerInfo);
    await Promise.allSettled([refreshProfile(), refreshFactions()]);
    ensureAvailableScreen();
    if (state.screen === "vip") await refreshVipStore();
    if (state.screen === "tickets") await refreshTickets();
    if (state.screen === "battlepass") await refreshBattlePass();
    if (state.screen === "estabelecimentos") await refreshEstablishments();
    if (state.screen === "ranking") await refreshRankings();
  }
);

onMounted(() => {
  if (previewMode) {
    state.screen = previewParams.get("screen") || "vip";
    state.visible = true;
  }
  window.addEventListener("keydown", onKeyDown);
  window.addEventListener("magicpause:refresh-factions", onRefreshFactions);
});
onBeforeUnmount(() => {
  window.removeEventListener("keydown", onKeyDown);
  window.removeEventListener("magicpause:refresh-factions", onRefreshFactions);
});
</script>

<template>
  <Transition name="menu">
    <div v-show="state.visible" class="esc-shell">
      <div class="esc-frame">
        <button class="esc-close" type="button" aria-label="Fechar menu" title="Fechar" @click="closeMenu">
          <i class="fa-solid fa-xmark"></i>
        </button>

        <aside class="side-panel">
          <header class="menu-brand">
            <img class="menu-brand-logo" :src="olhoBranco" alt="" />
            <span>
              <strong>Obscuria</strong>
            </span>
          </header>

          <section class="profile">
            <div class="profile-avatar">
              <img v-if="profile.avatar" :src="profile.avatar" alt="Avatar" />
              <span v-else>{{ initials }}</span>
            </div>
            <div class="profile-copy">
              <small>Personagem ativo</small>
              <strong>{{ profile.name || "Personagem" }}</strong>
              <span>Passaporte {{ profile.id || "-" }}</span>
            </div>
            <button class="profile-runes" type="button" title="Abrir Loja VIP" @click="openRuneDeposit">
              <img class="rune-icon" :src="runeIcon" alt="" />
              <b>{{ money(profile.runes) }}</b>
            </button>
          </section>

          <nav class="menu-navigation">
            <p class="section-label">Navegação</p>
            <button
              v-for="option in options"
              :key="option.id"
              class="nav-option"
              :class="{ active: state.screen === option.id, locked: option.disabled }"
              type="button"
              :disabled="option.disabled"
              @click="chooseOption(option)"
            >
              <span class="nav-visual">
                <img v-if="option.image" :src="option.image" :alt="option.label" />
                <i v-else :class="option.icon"></i>
              </span>
              <span class="nav-copy">
                <b>{{ option.label }}</b>
                <small>{{ option.description }}</small>
              </span>
              <i :class="option.disabled ? 'fa-solid fa-lock arrow' : 'fa-solid fa-chevron-right arrow'"></i>
            </button>
          </nav>

          <footer class="panel-footer">
            <button class="native-shortcut" type="button" @click="openMap">
              <i class="fa-solid fa-map-location-dot"></i>
              <span>Mapa</span>
            </button>
            <button class="native-shortcut" type="button" @click="openSettings">
              <i class="fa-solid fa-gear"></i>
              <span>Configurações</span>
            </button>
          </footer>
        </aside>

        <main class="content-panel">
          <component
            :is="activeScreen"
            v-bind="state.screen === 'geral' ? { payload: state.playerInfo } : state.screen === 'factions' ? { payload: factionPayload } : state.screen === 'vip' ? { payload: vipPayload } : state.screen === 'tickets' ? { payload: ticketsPayload, i18n: ticketsPayload?.locale } : state.screen === 'battlepass' ? { payload: battlePassPayload, i18n: battlePassPayload?.locale } : state.screen === 'estabelecimentos' ? { payload: establishmentsPayload } : state.screen === 'ranking' ? { payload: rankingsPayload } : {}"
            @refresh="state.screen === 'vip' ? refreshVipStore() : state.screen === 'tickets' ? refreshTickets($event) : state.screen === 'battlepass' ? refreshBattlePass() : state.screen === 'estabelecimentos' ? refreshEstablishments() : refreshFactions()"
          />
        </main>
      </div>
    </div>
  </Transition>
</template>
