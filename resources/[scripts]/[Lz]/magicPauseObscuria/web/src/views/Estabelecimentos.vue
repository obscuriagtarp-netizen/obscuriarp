<script setup>
import { computed, reactive, ref, watch } from "vue";
import {
  Building2,
  Users,
  Shield,
  Search,
  UtensilsCrossed,
  MapPin,
  Megaphone,
  Image as ImageIcon,
  NotebookPen,
  UserPlus,
  UserMinus,
  ArrowUpWideNarrow,
  ArrowDownWideNarrow,
  X,
  Eye,
  Save,
  Trash2,
} from "lucide-vue-next";
import RestaurantManagement from "../components/RestaurantManagement.vue";

const props = defineProps({
  payload: { type: Object, default: null },
});
const emit = defineEmits(["refresh"]);
const previewMode = new URLSearchParams(window.location.search).get("preview") === "1";

const player = reactive({
  id: "",
  name: "Cidadão",
  isStaff: false,
  groups: [],
  leaderOf: [],
});
const establishments = ref([]);

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "MagicPause";
}

async function nui(eventName, data = {}) {
  if (previewMode) return previewAction(eventName, data);
  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  });
  return response.json().catch(() => ({}));
}

function previewAction(eventName, data) {
  if (eventName === "getRestaurantManagement") {
    return Promise.resolve(establishments.value.find((entry) => entry.id === data.restaurantId)?.management || { ok: false });
  }
  if (eventName === "restaurantManagementAction") return Promise.resolve({ ok: true });
  if (eventName === "setRestaurantAvailability") return Promise.resolve({ ok: true, isOpen: data.open === true });
  if (eventName === "setEstablishmentWaypoint") return Promise.resolve({ ok: true });
  if (eventName === "callEstablishment") return Promise.resolve({ ok: true, recipients: 2 });
  return Promise.resolve({ ok: true });
}

function tagFor(entry) {
  const source = String(entry.theme || entry.label || entry.id || "EST").replace(/[^a-z0-9 ]/gi, " ");
  const words = source.split(/\s+/).filter(Boolean);
  return (words.length > 1 ? words.map((word) => word[0]).join("") : words[0] || "EST").slice(0, 6).toUpperCase();
}

function mapEstablishment(entry) {
  const management = entry.management?.ok === false ? null : entry.management;
  const menu = entry.menu || {};
  const recipes = menu.recipes || [];
  const features = entry.features || {};
  return {
    id: String(entry.id),
    name: entry.label || entry.id,
    job: entry.job,
    tag: tagFor(entry),
    description: entry.description || "Restaurante conectado à rede comercial de Obscuria.",
    features: {
      menu: features.menu !== false && Boolean(entry.menuImageUrl || recipes.length),
      location: features.location !== false && Boolean(entry.location?.x),
      call: features.call !== false,
    },
    availability: { open: entry.isOpen === true, label: entry.isOpen === true ? "Disponível" : "Indisponível" },
    media: { coverUrl: entry.coverUrl || "" },
    menu: {
      enabled: features.menu !== false,
      imageUrl: entry.menuImageUrl || "",
      categories: menu.categories || [],
      recipes,
    },
    notes: {
      enabled: true,
      text: entry.notes?.text || "Consulte o estabelecimento para informações de atendimento.",
      updatedAt: entry.notes?.updatedAt || null,
      updatedBy: entry.notes?.updatedBy || "",
    },
    location: entry.location || null,
    locationText: entry.locationLabel || "Local do estabelecimento",
    callText: entry.callText || "Abra um chamado para solicitar atendimento.",
    members: management?.members || [],
    jobGrades: management?.jobGrades || [],
    management,
    isMember: entry.isMember === true,
    canWork: entry.canWork === true,
    canManage: entry.canManage === true,
    isBoss: entry.isBoss === true,
  };
}

function applyPayload(payload) {
  const incoming = Array.isArray(payload?.restaurants)
    ? payload.restaurants.map(mapEstablishment).sort((left, right) => left.name.localeCompare(right.name, "pt-BR"))
    : [];
  const previous = selectedId.value;
  establishments.value = incoming;
  Object.assign(player, {
    id: payload?.profile?.id || payload?.profile?.source || "",
    name: payload?.profile?.name || "Cidadão",
    isStaff: payload?.isStaff === true,
    groups: incoming.filter((entry) => entry.isMember === true).map((entry) => entry.id),
    leaderOf: incoming.filter((entry) => entry.isBoss).map((entry) => entry.id),
  });
  selectedId.value = incoming.some((entry) => entry.id === previous) ? previous : incoming[0]?.id ?? null;
}

/**
 * UI STATE
 */
const tab = ref("estabs"); // "estabs" | "grupo" | "staff"
const query = ref("");
const selectedId = ref(establishments.value[0]?.id ?? null);

watch(() => props.payload, applyPayload, { immediate: true, deep: true });

const selected = computed(() => {
  const found = establishments.value.find((e) => e.id === selectedId.value);
  return found ?? establishments.value[0] ?? null;
});

const isStaff = computed(() => player.isStaff);
const canSeeStaff = computed(() => isStaff.value);
const canSeeGroup = computed(() => player.groups.length > 0);

const visibleTabs = computed(() => {
  const base = [{ id: "estabs", label: "Estabelecimentos", icon: Building2 }];
  if (canSeeGroup.value) base.push({ id: "grupo", label: "Grupo", icon: Users });
  if (canSeeStaff.value) base.push({ id: "staff", label: "Staff", icon: Shield });
  return base;
});

watch(visibleTabs, (tabs) => {
  if (!tabs.some((item) => item.id === tab.value)) tab.value = "estabs";
});

const filteredEstabs = computed(() => {
  const q = query.value.trim().toLowerCase();
  if (!q) return establishments.value;
  return establishments.value.filter((e) =>
    (e.name + " " + e.tag + " " + e.description).toLowerCase().includes(q)
  );
});

const myGroups = computed(() =>
  establishments.value.filter((e) => player.groups.includes(e.id))
);

const isLeaderOfSelected = computed(() => {
  const id = selected.value?.id;
  if (!id) return false;
  return player.leaderOf.includes(id);
});

/**
 * Permissões:
 * - Estabelecimentos: visualizar apenas (nota aparece, mas só leitura)
 * - Grupo: líder OU staff pode editar menu, imagem, notas e membros
 * - Staff: staff configura tudo global
 */
const canEditInGroupTab = computed(() => tab.value === "grupo" && (isStaff.value || selected.value?.canManage));
const canEditInStaffTab = computed(() => tab.value === "staff" && isStaff.value);

const canEditMenu = computed(() => canEditInGroupTab.value || canEditInStaffTab.value);
const canEditCover = computed(() => canEditInGroupTab.value || canEditInStaffTab.value);
const canEditNotes = computed(() => canEditInGroupTab.value || canEditInStaffTab.value);

const canEditFeatures = computed(() => canEditInStaffTab.value);
const canEditAvailability = computed(() => canEditInStaffTab.value);

/**
 * allowedList:
 * - grupo: NÃO tem lista no meio, mas ainda precisa "clamp" na seleção do único grupo
 */
const allowedList = computed(() => {
  if (tab.value === "grupo") return myGroups.value; // (só 1 grupo)
  if (tab.value === "staff") return filteredEstabs.value;
  return filteredEstabs.value;
});

function clampSelectionToAllowed() {
  const list = allowedList.value;

  // Grupo: trava automaticamente no primeiro grupo (só 1 por vez)
  if (tab.value === "grupo") {
    selectedId.value = list[0]?.id ?? null;
    return;
  }

  if (!list.length) {
    selectedId.value = null;
    return;
  }
  const ok = list.some((e) => e.id === selectedId.value);
  if (!ok) selectedId.value = list[0].id;
}

watch(tab, () => {
  query.value = "";
  clampSelectionToAllowed();
});

watch(allowedList, () => {
  clampSelectionToAllowed();
});

/**
 * Seleção
 */
function onSelect(e) {
  selectedId.value = e.id;
}

/**
 * Patch helper (organização)
 */
function patchSelected(patchFn) {
  const id = selectedId.value;
  if (!id) return;
  const idx = establishments.value.findIndex((e) => e.id === id);
  if (idx === -1) return;
  patchFn(establishments.value[idx]);
}

/**
 * =============================
 * TOAST
 * =============================
 */
const toastOpen = ref(false);
const toastText = ref("");

function openToast(text) {
  toastText.value = text;
  toastOpen.value = true;
  window.clearTimeout(openToast._t);
  openToast._t = window.setTimeout(() => {
    toastOpen.value = false;
  }, 2400);
}

function errorText(result) {
  const messages = {
    not_owner: "Somente a liderança ou a staff pode realizar esta ação.",
    staff_required: "Esta configuração é exclusiva da staff.",
    invalid_image: "Use uma imagem HTTPS ou deixe o campo vazio.",
    restaurant_closed: "O estabelecimento está indisponível no momento.",
    service_disabled: "Este estabelecimento não está recebendo chamados.",
    no_staff_online: "Não há funcionários em serviço para receber o chamado.",
    call_cooldown: `Aguarde ${Math.max(1, Number(result?.retryAfter) || 1)} segundos para chamar novamente.`,
    target_player_not_found: "O jogador informado não está online.",
    member_not_found: "Este membro não pertence mais ao estabelecimento.",
    maximum_grade: "Este membro já está no cargo mais alto.",
    minimum_grade: "Este membro já está no cargo inicial.",
    member_rank_protected: "Você não pode alterar seu próprio cargo ou um cargo igual ao seu.",
    job_update_failed: "O Qbox não conseguiu atualizar este emprego.",
    rate_limited: "Aguarde um instante antes de repetir a ação.",
    location_unavailable: "A localização ainda não foi configurada.",
  };
  return messages[result?.error] || "Não foi possível concluir esta ação.";
}

async function managementAction(action, data = {}) {
  if (!selected.value) return { ok: false };
  const result = await nui("restaurantManagementAction", {
    action,
    data: { restaurantId: selected.value.id, ...data },
  });
  if (!result?.ok) openToast(errorText(result));
  return result || { ok: false };
}

async function saveProfile(profile, successText) {
  const result = await managementAction("saveProfile", { profile });
  if (!result.ok) return false;
  openToast(successText);
  emit("refresh");
  return true;
}

/**
 * =============================
 * MODAL VISUALIZAR IMAGEM (CARDÁPIO / THUMB)
 * =============================
 */
const menuModalOpen = ref(false);
const menuModalUrl = ref("");
const menuCatalogOpen = ref(false);

function openMenuModal(url) {
  if (!url) {
    openToast("Imagem não configurada.");
    return;
  }
  menuModalUrl.value = url;
  menuModalOpen.value = true;
}

function closeMenuModal() {
  menuModalOpen.value = false;
  menuModalUrl.value = "";
}

function closeMenuCatalog() {
  menuCatalogOpen.value = false;
}

/**
 * =============================
 * MODAL VISUALIZAR NOTAS (somente leitura)
 * =============================
 */
const notesViewOpen = ref(false);

function openNotesView() {
  notesViewOpen.value = true;
}
function closeNotesView() {
  notesViewOpen.value = false;
}

/**
 * =============================
 * MODAL PROMPT - CARDÁPIO URL
 * =============================
 */
const menuPromptOpen = ref(false);
const menuPromptDraft = ref("");

function openMenuPrompt() {
  if (!canEditMenu.value || !selected.value) return;
  menuPromptDraft.value = selected.value.menu?.imageUrl ?? "";
  menuPromptOpen.value = true;
}
function closeMenuPrompt() {
  menuPromptOpen.value = false;
  menuPromptDraft.value = "";
}
async function confirmMenuPrompt() {
  if (!canEditMenu.value) return;
  const url = menuPromptDraft.value.trim();
  if (!await saveProfile({ menuImageUrl: url }, url ? "Cardápio atualizado." : "Imagem do cardápio removida.")) return;
  patchSelected((entry) => { entry.menu.imageUrl = url; });
  closeMenuPrompt();
}

/**
 * =============================
 * MODAL PROMPT - IMAGEM DO ESTABELECIMENTO (THUMB)
 * =============================
 */
const coverPromptOpen = ref(false);
const coverPromptDraft = ref("");

function openCoverPrompt() {
  if (!canEditCover.value || !selected.value) return;
  coverPromptDraft.value = selected.value.media?.coverUrl ?? "";
  coverPromptOpen.value = true;
}
function closeCoverPrompt() {
  coverPromptOpen.value = false;
  coverPromptDraft.value = "";
}
async function confirmCoverPrompt() {
  if (!canEditCover.value) return;
  const url = coverPromptDraft.value.trim();
  if (!await saveProfile({ coverUrl: url }, url ? "Imagem do estabelecimento atualizada." : "Imagem removida.")) return;
  patchSelected((entry) => { entry.media.coverUrl = url; });
  closeCoverPrompt();
}

/**
 * =============================
 * AÇÕES PÚBLICAS
 * =============================
 */
function openMenu(e) {
  if (!e?.features?.menu) return;
  const url = e.menu?.imageUrl || "";
  if (url) return openMenuModal(url);
  if (e.menu?.recipes?.length) {
    selectedId.value = e.id;
    menuCatalogOpen.value = true;
    return;
  }
  openToast("Este cardápio ainda não foi configurado.");
}
async function openLocation(e) {
  if (!e?.features?.location) return;
  const result = await nui("setEstablishmentWaypoint", { coords: e.location });
  openToast(result?.ok ? `GPS marcado para ${e.name}.` : errorText(result));
}
async function openCall(e) {
  if (!e?.features?.call) return;
  const result = await nui("callEstablishment", { restaurantId: e.id });
  openToast(result?.ok ? `Chamado enviado para ${e.name}.` : errorText(result));
}

/**
 * =============================
 * STAFF TOGGLES
 * =============================
 */
async function toggleFeature(estabId, featureKey) {
  if (!canEditFeatures.value) return;
  const e = establishments.value.find((x) => x.id === estabId);
  if (!e) return;
  const features = { ...e.features, [featureKey]: !e.features[featureKey] };
  if (await saveProfile({ features }, "Configuração atualizada.")) e.features = features;
}
async function toggleAvailability(estabId) {
  if (!canEditAvailability.value) return;
  const e = establishments.value.find((x) => x.id === estabId);
  if (!e) return;
  const next = !e.availability.open;
  const result = await nui("setRestaurantAvailability", { restaurantId: e.id, open: next });
  if (!result?.ok) return openToast(errorText(result));
  e.availability.open = next;
  e.availability.label = next ? "Disponível" : "Indisponível";
  openToast("Disponibilidade atualizada.");
  emit("refresh");
}

/**
 * =============================
 * GRUPO - gestão de membros
 * =============================
 */
const hirePromptOpen = ref(false);
const hirePlayerId = ref("");
const memberConfirm = ref(null);

function hire() {
  if (!selected.value || !canEditInGroupTab.value) return;
  hirePlayerId.value = "";
  hirePromptOpen.value = true;
}

async function confirmHire() {
  const playerId = Number(hirePlayerId.value);
  if (!Number.isInteger(playerId) || playerId < 1) return openToast("Informe um ID de jogador válido.");
  const result = await managementAction("hireMember", { playerId });
  if (!result.ok) return;
  patchSelected((entry) => { entry.members = result.members || entry.members; });
  hirePromptOpen.value = false;
  openToast("Membro contratado.");
  emit("refresh");
}

function fireMember(member) {
  memberConfirm.value = { type: "fire", member, title: `Demitir ${member.name}?`, text: "O emprego será removido imediatamente." };
}

function promote(member) {
  memberConfirm.value = { type: "up", member, title: `Promover ${member.name}?`, text: "O membro receberá o próximo cargo da hierarquia." };
}

function demote(member) {
  memberConfirm.value = { type: "down", member, title: `Rebaixar ${member.name}?`, text: "O membro receberá o cargo anterior da hierarquia." };
}

async function confirmMemberAction() {
  const pending = memberConfirm.value;
  if (!pending) return;
  const result = pending.type === "fire"
    ? await managementAction("fireMember", { citizenId: pending.member.citizenId || pending.member.id })
    : await managementAction("changeMemberGrade", { citizenId: pending.member.citizenId || pending.member.id, direction: pending.type });
  if (!result.ok) return;
  patchSelected((entry) => { entry.members = result.members || entry.members; });
  memberConfirm.value = null;
  openToast(pending.type === "fire" ? "Membro demitido." : "Cargo atualizado.");
  emit("refresh");
}

/**
 * =============================
 * GRUPO - NOTAS (editor)
 * =============================
 */
const notesEditing = ref(false);
const notesDraft = ref("");
const notesPromptOpen = ref(false);

function openNotesEditor() {
  if (!selected.value) return;
  notesDraft.value = selected.value.notes?.text ?? "";
  notesEditing.value = true;
  notesPromptOpen.value = tab.value === "staff";
}

function cancelNotesEditor() {
  notesEditing.value = false;
  notesPromptOpen.value = false;
  notesDraft.value = "";
}

async function saveNotes() {
  if (!selected.value || !canEditNotes.value) return;
  if (!await saveProfile({ notes: notesDraft.value }, "Notas atualizadas.")) return;
  patchSelected((entry) => {
    entry.notes.text = notesDraft.value;
    entry.notes.updatedAt = Date.now();
    entry.notes.updatedBy = player.name;
  });
  notesEditing.value = false;
  notesPromptOpen.value = false;
}

function addBullet() {
  notesDraft.value += (notesDraft.value.endsWith("\n") || notesDraft.value.length === 0 ? "• " : "\n• ");
}
function addLine() {
  notesDraft.value += (notesDraft.value.endsWith("\n") || notesDraft.value.length === 0 ? "— " : "\n— ");
}
function clearNotes() {
  notesDraft.value = "";
}

/**
 * Helpers (thumb)
 */
const selectedThumbUrl = computed(() => selected.value?.media?.coverUrl?.trim() || "");
const activeTabLabel = computed(() => visibleTabs.value.find((item) => item.id === tab.value)?.label || "Estabelecimentos");
const managementOpen = ref(false);
const managementPayload = ref(null);

async function loadManagement() {
  if (!selected.value?.canManage) return;
  const result = await nui("getRestaurantManagement", { restaurantId: selected.value.id });
  if (!result?.ok) return openToast(errorText(result));
  managementPayload.value = result;
  patchSelected((entry) => {
    entry.management = result;
    entry.members = result.members || entry.members;
    entry.jobGrades = result.jobGrades || entry.jobGrades;
  });
}

async function openManagement() {
  await loadManagement();
  if (managementPayload.value?.ok) managementOpen.value = true;
}

async function operationalRequest(action, data = {}) {
  return nui("restaurantManagementAction", {
    action,
    data: { restaurantId: selected.value?.id, ...data },
  });
}

async function reloadManagement() {
  await loadManagement();
  emit("refresh");
}
</script>

<template>
  <section class="est-root">
    <header class="screen-heading est-heading">
      <div>
        <small>Locais úteis</small>
        <h1>Estabelecimentos</h1>
        <p>Serviços, grupos e administração em um só lugar, com acesso rápido a cardápio, GPS e chamados.</p>
      </div>

      <div class="est-heading-card">
        <span>{{ activeTabLabel }}</span>
        <b>{{ allowedList.length }}</b>
        <small>{{ allowedList.length === 1 ? "registro" : "registros" }}</small>
      </div>
    </header>

    <div class="est-panel">
      <div class="est-shell" :class="{ 'is-staff': tab === 'staff', 'is-group': tab === 'grupo' }">
        <!-- LEFT SIDEBAR -->
        <aside class="est-sidebar">
          <div class="side-profile">
            <div class="side-avatar">{{ player.name.slice(0, 1).toUpperCase() }}</div>
            <div class="side-user">
              <div class="side-name">{{ player.name }}</div>
              <div class="side-meta">
                <span class="pill" :class="player.isStaff ? 'pill--on' : 'pill--off'">
                  {{ player.isStaff ? "STAFF" : "CIDADÃO" }}
                </span>
                <span class="pill pill--soft">Grupos: {{ player.groups.length }}</span>
              </div>
            </div>
          </div>

          <div class="side-divider"></div>

          <nav class="side-tabs">
            <button
              v-for="t in visibleTabs"
              :key="t.id"
              class="side-tab"
              :class="{ active: tab === t.id }"
              @click="tab = t.id"
            >
              <span class="side-tabIcon">
                <component :is="t.icon" :size="18" />
              </span>
              <span class="side-tabText">{{ t.label }}</span>
            </button>
          </nav>

          <div class="side-footer">
            <div class="side-title">
              <h2>ESTABELECIMENTOS</h2>
              <p>Serviços, grupos e administração em um só lugar.</p>
            </div>
          </div>
        </aside>

        <!-- CENTER (não existe no Grupo) -->
        <section v-if="tab !== 'grupo'" class="est-center" :class="{ compact: tab === 'staff' }">
          <header class="center-header">
            <div class="center-title">
              <div class="kicker">
                <span v-if="tab === 'staff'">Administração</span>
                <span v-else>Estabelecimentos</span>
              </div>
              <div class="count">({{ allowedList.length }})</div>
            </div>

            <!-- busca só em estabs e staff -->
            <div class="center-search">
              <div class="searchWrap">
                <Search :size="16" />
                <input v-model="query" placeholder="Buscar..." />
              </div>
            </div>
          </header>

          <div class="center-list est-scroll" :class="{ compact: tab === 'staff' }">
            <button
              v-for="e in allowedList"
              :key="e.id"
              class="est-cardRow"
              :class="{ active: selectedId === e.id, compact: tab === 'staff' }"
              @click="onSelect(e)"
            >
              <div class="est-thumb">
                <img v-if="e.media?.coverUrl" class="est-thumbImg" :src="e.media.coverUrl" alt="thumb" />
                <div v-else class="est-thumbFallback">?</div>
              </div>

              <div class="est-cardInfo">
                <div class="est-cardTop">
                  <div class="est-cardName">
                    <span class="est-cardNameText">{{ e.name }}</span>
                    <span class="est-tag">{{ e.tag }}</span>
                  </div>

                  <span class="statusPill" :class="e.availability.open ? 'on' : 'off'">
                    {{ e.availability.label }}
                  </span>
                </div>

                <div class="est-cardDesc" v-if="tab !== 'staff'">{{ e.description }}</div>

                <div class="est-miniActions" v-if="tab === 'estabs'">
                  <button v-if="e.features.menu" class="miniAction" @click.stop="openMenu(e)">
                    <UtensilsCrossed :size="16" /> Cardápio
                  </button>
                  <button v-if="e.features.location" class="miniAction" @click.stop="openLocation(e)">
                    <MapPin :size="16" /> GPS
                  </button>
                  <button v-if="e.features.call" class="miniAction" @click.stop="openCall(e)">
                    <Megaphone :size="16" /> Chamado
                  </button>
                </div>
              </div>
            </button>
          </div>

          <div class="center-footNote" v-if="tab === 'staff'">
            <span class="noteDot"></span>
            Selecione um estabelecimento na lista para administrar ao lado.
          </div>
        </section>

        <!-- RIGHT DETAILS (no Grupo ocupa o lugar do meio + direito via CSS) -->
        <main class="est-right" v-if="selected">
          <!-- HERO -->
          <div class="est-hero">
            <div class="est-heroShade"></div>

            <div class="est-heroTop">
              <div class="est-heroThumb">
                <img v-if="selectedThumbUrl" class="est-heroThumbImg" :src="selectedThumbUrl" alt="thumb" />
                <div v-else class="est-heroThumbFallback">
                  {{ selected.name.slice(0, 1).toUpperCase() }}
                </div>
              </div>

              <div class="est-heroInfo">
                <div class="est-heroName">
                  {{ selected.name }}
                  <span class="est-heroTag">{{ selected.tag }}</span>
                </div>

                <div class="est-heroDesc">{{ selected.description }}</div>

                <div class="heroChips">
                  <span class="statusPill" :class="selected.availability.open ? 'on' : 'off'">
                    {{ selected.availability.label }}
                  </span>

                  <span class="chipSoft" v-if="tab === 'grupo' && isLeaderOfSelected && !player.isStaff">
                    Líder do grupo
                  </span>
                  <span class="chipSoft" v-if="player.isStaff">
                    Staff
                  </span>
                </div>
              </div>
            </div>

            <!-- AÇÕES (somente em Estabelecimentos) -->
            <div class="heroQuick" v-if="tab === 'estabs'">
              <button class="qbtn" :disabled="!selected.features.menu" @click="openMenu(selected)">
                <span class="qico"><UtensilsCrossed :size="18" /></span>
                <span class="qtext">
                  <b>Cardápio</b>
                  <small>Visualizar</small>
                </span>
              </button>

              <button class="qbtn" :disabled="!selected.features.location" @click="openLocation(selected)">
                <span class="qico"><MapPin :size="18" /></span>
                <span class="qtext">
                  <b>Localização</b>
                  <small>Marcar GPS</small>
                </span>
              </button>

              <button class="qbtn" :disabled="!selected.features.call" @click="openCall(selected)">
                <span class="qico"><Megaphone :size="18" /></span>
                <span class="qtext">
                  <b>Chamado</b>
                  <small>Abrir</small>
                </span>
              </button>
            </div>
          </div>

          <!-- BODY -->
          <section class="est-section est-scroll">
            <!-- ESTABELECIMENTOS (VISUAL) -->
            <template v-if="tab === 'estabs'">
              <div class="est-sectionTitle">Resumo</div>

              <div class="infoGrid">
                <div class="infoCard">
                  <div class="infoHead">
                    <span class="infoIcon"><MapPin :size="16" /></span>
                    <div class="infoTitle">Localização</div>
                  </div>
                  <div class="infoBody">
                    <div class="infoMain">
                      {{ selected.features.location ? selected.locationText : "Indisponível" }}
                    </div>
                    <div class="infoHint">
                      {{
                        selected.features.location
                          ? "Use o botão acima para marcar no GPS."
                          : "A localização foi desativada."
                      }}
                    </div>
                  </div>
                </div>

                <div class="infoCard">
                  <div class="infoHead">
                    <span class="infoIcon"><UtensilsCrossed :size="16" /></span>
                    <div class="infoTitle">Cardápio</div>
                  </div>
                  <div class="infoBody">
                    <div class="infoMain">
                      <span v-if="selected.features.menu && selected.menu?.imageUrl">Disponível</span>
                      <span v-else-if="selected.features.menu && !selected.menu?.imageUrl">Não configurado</span>
                      <span v-else>Desativado</span>
                    </div>
                    <div class="infoHint">
                      <span v-if="selected.features.menu && selected.menu?.imageUrl">Abra o cardápio no botão acima.</span>
                      <span v-else-if="selected.features.menu && !selected.menu?.imageUrl">O responsável ainda não configurou.</span>
                      <span v-else>O staff desativou o cardápio.</span>
                    </div>
                  </div>
                </div>

                <div class="infoCard">
                  <div class="infoHead">
                    <span class="infoIcon"><Megaphone :size="16" /></span>
                    <div class="infoTitle">Atendimento</div>
                  </div>
                  <div class="infoBody">
                    <div class="infoMain">
                      {{ selected.features.call ? "Chamados ativos" : "Chamados desativados" }}
                    </div>
                    <div class="infoHint">
                      {{
                        selected.features.call
                          ? (selected.callText || "Abra um chamado para suporte.")
                          : "Este serviço está indisponível no momento."
                      }}
                    </div>
                  </div>
                </div>
              </div>

              <div class="dividerLine"></div>

              <!-- NOTAS (VISUAL) -->
              <div class="notesCard">
                <div class="notesCardHead">
                  <div class="notesTitle">
                    <NotebookPen :size="16" /> Notas do Grupo
                  </div>
                  <button class="bigBtn ghost" @click="openNotesView">
                    <Eye :size="16" /> Ver completo
                  </button>
                </div>

                <pre class="notesPreview">{{ selected.notes?.text || "Sem notas configuradas." }}</pre>

                <div class="notesHint">Para editar, use a aba <b>Grupo</b> ou <b>Staff</b>.</div>
              </div>

              <!-- <div class="mutedBlock">
                Para configurações (cardápio/imagem/notas), use as abas <b>Grupo</b> (líder/staff) ou <b>Staff</b>.
              </div> -->
            </template>

            <!-- GRUPO (sem coluna do meio) -->
            <template v-else-if="tab === 'grupo'">
              <div class="est-sectionTitle">
                Grupo
                <span class="pill pill--soft">Tag: {{ selected.tag }}</span>
                <span class="pill pill--soft" v-if="isLeaderOfSelected && !player.isStaff">Líder</span>
                <span class="pill pill--soft" v-if="player.isStaff">Staff</span>
              </div>

              <div class="groupGrid">
                <!-- Config -->
                <div class="groupCard">
                  <div class="groupCardHead">
                    <div class="groupCardTitle">Configurações</div>
                    <div class="groupCardSub">
                      {{ canEditInGroupTab ? "Você pode editar cardápio, imagem e notas." : "Somente líder ou staff podem editar." }}
                    </div>
                  </div>

                  <div class="groupCardBody">
                    <div class="rowLine">
                      <div class="rowInfo">
                        <b>Cardápio</b>
                        <small>{{ selected.menu?.imageUrl ? "Configurado" : "Não configurado" }}</small>
                      </div>

                      <div class="rowBtns">
                        <button class="bigBtn" :disabled="!canEditMenu" @click="openMenuPrompt">
                          <UtensilsCrossed :size="16" /> Configurar
                        </button>
                        <button class="bigBtn ghost" :disabled="!selected.menu?.imageUrl" @click="openMenu(selected)">
                          <Eye :size="16" /> Visualizar
                        </button>
                      </div>
                    </div>

                    <div class="rowLine">
                      <div class="rowInfo">
                        <b>Imagem do Estabelecimento (Thumb)</b>
                        <small>{{ selected.media?.coverUrl ? "Configurada" : "Não configurada" }}</small>
                      </div>

                      <div class="rowBtns">
                        <button class="bigBtn" :disabled="!canEditCover" @click="openCoverPrompt">
                          <ImageIcon :size="16" /> Alterar
                        </button>
                        <button class="bigBtn ghost" :disabled="!selected.media?.coverUrl" @click="openMenuModal(selected.media.coverUrl)">
                          <Eye :size="16" /> Visualizar
                        </button>
                      </div>
                    </div>

                    <div class="rowLine" v-if="selected.canManage">
                      <div class="rowInfo">
                        <b>Gestão operacional</b>
                        <small>Receitas, categorias, pontos, vendas e caixa</small>
                      </div>
                      <div class="rowBtns">
                        <button class="bigBtn" @click="openManagement">
                          <Building2 :size="16" /> Abrir gestão
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Notas -->
                <div class="groupCard">
                  <div class="groupCardHead">
                    <div class="groupCardTitle">Notas do Grupo</div>
                    <div class="groupCardSub">
                      <span v-if="selected.notes?.updatedAt">
                        Atualizado por <b>{{ selected.notes.updatedBy }}</b>
                      </span>
                      <span v-else>Sem atualizações</span>
                    </div>
                  </div>

                  <div class="groupCardBody">
                    <div v-if="!notesEditing">
                      <pre class="notesPre">{{ selected.notes?.text || "Sem notas. Clique em editar para adicionar." }}</pre>

                      <div class="rowBtns rowBtnsTop">
                        <button class="bigBtn" :disabled="!canEditNotes" @click="openNotesEditor">
                          <NotebookPen :size="16" /> Editar
                        </button>
                        <button class="bigBtn ghost" @click="openNotesView">
                          <Eye :size="16" /> Ver como player
                        </button>
                      </div>
                    </div>

                    <div v-else class="notesEditor">
                      <div class="notesToolbar">
                        <button class="toolBtn" @click="addBullet">• Lista</button>
                        <button class="toolBtn" @click="addLine">— Linha</button>
                        <button class="toolBtn danger" @click="clearNotes">
                          <Trash2 :size="16" /> Limpar
                        </button>
                      </div>

                      <textarea
                        class="notesArea"
                        v-model="notesDraft"
                        placeholder="Escreva as notas do grupo..."
                      ></textarea>

                      <div class="rowBtns">
                        <button class="bigBtn ghost" @click="cancelNotesEditor">
                          <X :size="16" /> Cancelar
                        </button>
                        <button class="bigBtn" :disabled="!canEditNotes" @click="saveNotes">
                          <Save :size="16" /> Salvar
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Gestão de membros -->
                <div class="groupCard">
                  <div class="groupCardHead">
                    <div class="groupCardTitle">Gestão de Membros</div>
                    <div class="groupCardSub">Equipe vinculada ao emprego no Qbox.</div>
                  </div>

                  <div class="groupCardBody">
                    <div class="rowBtns rowBtnsTop">
                      <button class="bigBtn" :disabled="!canEditInGroupTab" @click="hire">
                        <UserPlus :size="16" /> Contratar novo membro
                      </button>
                    </div>

                    <div class="dividerLine"></div>

                    <div class="est-members">
                      <div class="est-member" v-for="m in selected.members" :key="m.id">
                        <div class="dot" :class="m.online ? 'dot--on' : 'dot--off'"></div>
                        <div class="est-memberInfo">
                          <div class="est-memberName">{{ m.name }}</div>
                          <div class="est-memberRole">{{ m.role }}</div>
                        </div>

                        <div class="est-memberActions" v-if="canEditInGroupTab">
                          <button class="miniBtn" @click="promote(m)">
                            <ArrowUpWideNarrow :size="16" /> Promover
                          </button>
                          <button class="miniBtn" @click="demote(m)">
                            <ArrowDownWideNarrow :size="16" /> Rebaixar
                          </button>
                          <button class="miniBtn danger" @click="fireMember(m)">
                            <UserMinus :size="16" /> Demitir
                          </button>
                        </div>
                      </div>
                      <div class="mutedBlock" v-if="!selected.members?.length">Nenhum membro contratado.</div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mutedBlock" v-if="!myGroups.length">
                Você não possui grupo no momento.
              </div>
            </template>

            <!-- STAFF -->
            <template v-else-if="tab === 'staff'">
              <div class="est-sectionTitle">
                Painel Staff
                <span class="adminChip">Acesso administrativo</span>
              </div>

              <div class="adminLayout">
                <div class="adminCol">
                  <div class="adminCard">
                    <div class="adminCardHeader">
                      <div class="adminCardTitle">
                        <span class="adminCardTitleIcon">🟢</span> Status
                      </div>
                      <span class="adminChip">Global</span>
                    </div>

                    <div class="adminCardBody">
                      <div class="adminRow">
                        <div class="adminRowLeft">
                          <b>Disponibilidade</b>
                          <small>Exibir se está disponível ou não</small>
                        </div>

                        <button
                          class="adminToggle"
                          :class="selected.availability.open ? 'on' : 'off'"
                          @click="toggleAvailability(selected.id)"
                        >
                          {{ selected.availability.open ? "ON" : "OFF" }}
                        </button>
                      </div>

                      <div class="adminHint">A alteração é salva e sincronizada para todos.</div>
                    </div>
                  </div>

                  <div class="adminCard">
                    <div class="adminCardHeader">
                      <div class="adminCardTitle">
                        <span class="adminCardTitleIcon">⚙️</span> Ações do Card
                      </div>
                    </div>

                    <div class="adminCardBody">
                      <div class="adminRow">
                        <div class="adminRowLeft">
                          <b>Cardápio</b>
                          <small>Habilitar botão e seção</small>
                        </div>
                        <button
                          class="adminToggle"
                          :class="selected.features.menu ? 'on' : 'off'"
                          @click="toggleFeature(selected.id, 'menu')"
                        >
                          {{ selected.features.menu ? "ON" : "OFF" }}
                        </button>
                      </div>

                      <div class="adminRow">
                        <div class="adminRowLeft">
                          <b>Localização</b>
                          <small>Habilitar GPS</small>
                        </div>
                        <button
                          class="adminToggle"
                          :class="selected.features.location ? 'on' : 'off'"
                          @click="toggleFeature(selected.id, 'location')"
                        >
                          {{ selected.features.location ? "ON" : "OFF" }}
                        </button>
                      </div>

                      <div class="adminRow">
                        <div class="adminRowLeft">
                          <b>Chamado</b>
                          <small>Habilitar chamados</small>
                        </div>
                        <button
                          class="adminToggle"
                          :class="selected.features.call ? 'on' : 'off'"
                          @click="toggleFeature(selected.id, 'call')"
                        >
                          {{ selected.features.call ? "ON" : "OFF" }}
                        </button>
                      </div>

                      <div class="adminHint">Essas opções removem/mostram botões para todos.</div>
                    </div>
                  </div>
                </div>

                <div class="adminCol">
                  <div class="adminCard">
                    <div class="adminCardHeader">
                      <div class="adminCardTitle">
                        <span class="adminCardTitleIcon">🖼️</span> Imagens / Notas
                      </div>
                    </div>

                    <div class="adminCardBody">
                      <div class="adminMediaRow">
                        <div class="adminMediaLabel">
                          <b>Imagem do Estabelecimento (Thumb)</b>
                          <small>Substitui o ícone/thumbnail</small>
                        </div>

                        <div class="adminMediaBtns">
                          <button class="bigBtn" @click="openCoverPrompt">
                            <ImageIcon :size="16" /> Configurar
                          </button>
                          <button
                            class="bigBtn ghost"
                            v-if="selected.media?.coverUrl"
                            @click="openMenuModal(selected.media.coverUrl)"
                          >
                            <Eye :size="16" /> Visualizar
                          </button>
                        </div>
                      </div>

                      <div class="adminMediaRow">
                        <div class="adminMediaLabel">
                          <b>Cardápio (URL)</b>
                          <small>Imagem abre em modal</small>
                        </div>

                        <div class="adminMediaBtns">
                          <button class="bigBtn" @click="openMenuPrompt">
                            <UtensilsCrossed :size="16" /> Configurar
                          </button>
                          <button class="bigBtn ghost" v-if="selected.menu?.imageUrl" @click="openMenu(selected)">
                            <Eye :size="16" /> Visualizar
                          </button>
                        </div>
                      </div>

                      <div class="adminMediaRow">
                        <div class="adminMediaLabel">
                          <b>Notas do Grupo</b>
                          <small>Editável por staff</small>
                        </div>

                        <div class="adminMediaBtns">
                          <button class="bigBtn" @click="openNotesEditor" :disabled="!canEditNotes">
                            <NotebookPen :size="16" /> Editar
                          </button>
                          <button class="bigBtn ghost" @click="openNotesView">
                            <Eye :size="16" /> Ver
                          </button>
                        </div>
                      </div>

                      <div class="adminHint">Imagens e notas são validadas e salvas no banco de dados.</div>
                    </div>
                  </div>

                  <div class="mutedBlock">
                    Observação: a aba <b>Estabelecimentos</b> é somente visual. Alterações em <b>Grupo</b> (líder/staff) ou <b>Staff</b>.
                  </div>
                  <button class="bigBtn" v-if="selected.canManage" @click="openManagement">
                    <Building2 :size="16" /> Abrir gestão operacional
                  </button>
                </div>
              </div>
            </template>
          </section>
        </main>
      </div>
    </div>

    <!-- MODAL VISUALIZAR IMAGEM -->
    <div v-if="menuModalOpen" class="menuModal">
      <div class="menuModalBox">
        <div class="menuModalHeader">
          <div class="menuModalTitle">Visualização</div>
          <button class="menuModalClose" @click="closeMenuModal">
            <X :size="18" />
          </button>
        </div>

        <div class="menuModalBody est-scroll">
          <img class="menuModalImg" :src="menuModalUrl" alt="Imagem" />
        </div>
      </div>
    </div>

    <!-- MODAL VISUALIZAR NOTAS (READONLY) -->
    <div v-if="notesViewOpen" class="menuModal">
      <div class="menuModalBox">
        <div class="menuModalHeader">
          <div class="menuModalTitle">Notas do Grupo</div>
          <button class="menuModalClose" @click="closeNotesView">
            <X :size="18" />
          </button>
        </div>

        <div class="menuModalBody est-scroll">
          <pre class="notesModalPre">{{ selected?.notes?.text || "Sem notas configuradas." }}</pre>
        </div>
      </div>
    </div>

    <!-- PROMPT: CARDÁPIO -->
    <div v-if="menuPromptOpen" class="uiModal">
      <div class="uiModalBox">
        <div class="uiModalHeader">
          <div class="uiModalTitle">Configurar Cardápio</div>
          <button class="uiModalClose" @click="closeMenuPrompt">
            <X :size="18" />
          </button>
        </div>

        <div class="uiModalBody">
          <div class="uiHelp">
            Cole a <b>URL HTTPS</b> da imagem do cardápio (PNG, JPG ou WebP).
          </div>

          <div class="uiField">
            <div class="uiLabel">URL da imagem</div>
            <input class="uiInput" v-model="menuPromptDraft" placeholder="https://..." />
            <div class="uiHelp">A imagem será exibida para todos após salvar.</div>
          </div>
        </div>

        <div class="uiModalFooter">
          <button class="bigBtn ghost" @click="closeMenuPrompt">Cancelar</button>
          <button class="bigBtn ghost" v-if="menuPromptDraft.trim()" @click="openMenuModal(menuPromptDraft.trim())">
            <Eye :size="16" /> Visualizar
          </button>
          <button class="bigBtn" @click="confirmMenuPrompt">
            <Save :size="16" /> Salvar
          </button>
        </div>
      </div>
    </div>

    <!-- PROMPT: IMAGEM DO THUMB -->
    <div v-if="coverPromptOpen" class="uiModal">
      <div class="uiModalBox">
        <div class="uiModalHeader">
          <div class="uiModalTitle">Configurar Imagem do Estabelecimento (Thumb)</div>
          <button class="uiModalClose" @click="closeCoverPrompt">
            <X :size="18" />
          </button>
        </div>

        <div class="uiModalBody">
          <div class="uiHelp">
            Cole a <b>URL</b> da imagem (PNG/JPG/WebP). Ela substitui o ícone/thumbnail.
          </div>

          <div class="uiField">
            <div class="uiLabel">URL da imagem</div>
            <input class="uiInput" v-model="coverPromptDraft" placeholder="https://..." />
            <div class="uiHelp">Imagens quadradas oferecem o melhor enquadramento.</div>
          </div>
        </div>

        <div class="uiModalFooter">
          <button class="bigBtn ghost" @click="closeCoverPrompt">Cancelar</button>
          <button class="bigBtn ghost" v-if="coverPromptDraft.trim()" @click="openMenuModal(coverPromptDraft.trim())">
            <Eye :size="16" /> Visualizar
          </button>
          <button class="bigBtn" @click="confirmCoverPrompt">
            <Save :size="16" /> Salvar
          </button>
        </div>
      </div>
    </div>

    <!-- CARDÁPIO GERADO PELOS PRODUTOS CADASTRADOS -->
    <div v-if="menuCatalogOpen" class="menuModal">
      <div class="menuModalBox menuCatalogBox">
        <div class="menuModalHeader">
          <div class="menuModalTitle">Cardápio de {{ selected?.name }}</div>
          <button class="menuModalClose" @click="closeMenuCatalog"><X :size="18" /></button>
        </div>
        <div class="menuModalBody est-scroll">
          <div class="menuCatalogGrid">
            <article v-for="item in selected?.menu?.recipes || []" :key="item.id" class="menuCatalogItem">
              <img v-if="item.image" :src="item.image" :alt="item.name" />
              <div>
                <small>{{ item.badge || selected?.tag }}</small>
                <b>{{ item.name }}</b>
                <p>{{ item.description || "Preparado pelo estabelecimento." }}</p>
              </div>
              <strong>$ {{ Number(item.price || 0).toLocaleString("pt-BR") }}</strong>
            </article>
          </div>
        </div>
      </div>
    </div>

    <!-- CONTRATAR MEMBRO -->
    <div v-if="hirePromptOpen" class="uiModal">
      <div class="uiModalBox">
        <div class="uiModalHeader">
          <div class="uiModalTitle">Contratar membro</div>
          <button class="uiModalClose" @click="hirePromptOpen = false"><X :size="18" /></button>
        </div>
        <div class="uiModalBody">
          <div class="uiField">
            <div class="uiLabel">ID do jogador online</div>
            <input class="uiInput" v-model="hirePlayerId" inputmode="numeric" placeholder="Ex.: 42" @keyup.enter="confirmHire" />
          </div>
        </div>
        <div class="uiModalFooter">
          <button class="bigBtn ghost" @click="hirePromptOpen = false">Cancelar</button>
          <button class="bigBtn" @click="confirmHire"><UserPlus :size="16" /> Contratar</button>
        </div>
      </div>
    </div>

    <!-- CONFIRMAR ALTERAÇÃO DE MEMBRO -->
    <div v-if="memberConfirm" class="uiModal">
      <div class="uiModalBox">
        <div class="uiModalHeader">
          <div class="uiModalTitle">{{ memberConfirm.title }}</div>
          <button class="uiModalClose" @click="memberConfirm = null"><X :size="18" /></button>
        </div>
        <div class="uiModalBody"><div class="uiHelp">{{ memberConfirm.text }}</div></div>
        <div class="uiModalFooter">
          <button class="bigBtn ghost" @click="memberConfirm = null">Cancelar</button>
          <button class="bigBtn" :class="{ danger: memberConfirm.type === 'fire' }" @click="confirmMemberAction">Confirmar</button>
        </div>
      </div>
    </div>

    <!-- GESTÃO OPERACIONAL -->
    <div v-if="managementOpen && managementPayload" class="operationModal">
      <RestaurantManagement
        :payload="managementPayload"
        :request="operationalRequest"
        :available="selected.availability.open"
        @close="managementOpen = false"
        @reload="reloadManagement"
        @feedback="(text) => openToast(text)"
        @availability="toggleAvailability(selected.id)"
      />
    </div>

    <!-- EDITOR DE NOTAS PARA STAFF -->
    <div v-if="notesPromptOpen" class="uiModal">
      <div class="uiModalBox">
        <div class="uiModalHeader">
          <div class="uiModalTitle">Notas de {{ selected?.name }}</div>
          <button class="uiModalClose" @click="cancelNotesEditor"><X :size="18" /></button>
        </div>
        <div class="uiModalBody">
          <div class="notesToolbar">
            <button class="toolBtn" @click="addBullet">• Lista</button>
            <button class="toolBtn" @click="addLine">— Linha</button>
            <button class="toolBtn danger" @click="clearNotes"><Trash2 :size="16" /> Limpar</button>
          </div>
          <textarea class="notesArea staffNotesArea" v-model="notesDraft" placeholder="Escreva as notas do grupo..."></textarea>
        </div>
        <div class="uiModalFooter">
          <button class="bigBtn ghost" @click="cancelNotesEditor">Cancelar</button>
          <button class="bigBtn" @click="saveNotes"><Save :size="16" /> Salvar</button>
        </div>
      </div>
    </div>

    <!-- TOAST -->
    <div v-if="toastOpen" class="uiToast">
      {{ toastText }}
    </div>
  </section>
</template>

<style src="../styles/estabelecimentos.css"></style>
