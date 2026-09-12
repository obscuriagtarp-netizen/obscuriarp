<script setup>
import { computed, ref, watch } from "vue";

const props = defineProps({
  payload: {
    type: Object,
    default: null
  }
});
const emit = defineEmits(["refresh"]);

const selectedKey = ref("");
const leaderId = ref("");
const memberId = ref("");
const feedback = ref(null);
const busy = ref(false);
const activeTab = ref("catalog");
const confirmation = ref(null);
const storageChoice = ref(null);
const renameChoice = ref(null);

const factions = computed(() => props.payload?.factions || []);
const selected = computed(() => factions.value.find((item) => item.key === selectedKey.value) || factions.value[0]);
const myFaction = computed(() => props.payload?.myFaction || null);
const isStaff = computed(() => props.payload?.isStaff === true);
const texts = computed(() => props.payload?.texts || {});
const canShowCatalog = computed(() => isStaff.value || myFaction.value);
const testMode = computed(() => props.payload?.testNonStaff === true);
const includedFeatures = computed(() => props.payload?.includedFeatures || []);
const upgrades = computed(() => props.payload?.upgrades || []);
const positionReset = computed(() => props.payload?.positionReset || { singlePrice: 30, allPrice: 100 });
const pointFeatures = computed(() => (myFaction.value?.features || []).filter((feature) => isPositionable(feature)));
const storageFeatures = computed(() => pointFeatures.value.filter((feature) => String(feature.feature_type || feature.type || "") === "storage" && feature.id && feature.coords));
const monthlyFeatures = computed(() => (myFaction.value?.features || []).filter((feature) => feature.recurring));
const clanMembers = computed(() => myFaction.value?.members || []);
const adminFactions = computed(() => factions.value.filter((item) => !item.available));
const availableFactions = computed(() => factions.value.filter((item) => item.available));
const tabs = computed(() => {
  const list = [{ id: "catalog", label: "Clãs", icon: "fa-solid fa-table-cells-large" }];
  if (myFaction.value) list.push({ id: "mine", label: "Meu Clã", icon: "fa-solid fa-crown" });
  if (isStaff.value) list.push({ id: "admin", label: "Administração", icon: "fa-solid fa-user-shield" });
  return list;
});

watch(
  [factions, myFaction, isStaff],
  ([list, own, staff]) => {
    if (!list.length) {
      selectedKey.value = "";
      return;
    }
    if (!selectedKey.value && own?.key && list.some((item) => item.key === own.key)) {
      selectedKey.value = own.key;
    } else if (!selectedKey.value || !list.some((item) => item.key === selectedKey.value)) {
      selectedKey.value = list[0]?.key || "";
    }
    if (own && activeTab.value === "catalog" && !staff) activeTab.value = "mine";
    if (!tabs.value.some((item) => item.id === activeTab.value)) activeTab.value = own ? "mine" : "catalog";
  },
  { immediate: true }
);

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "MagicPause";
}

async function nui(eventName, data = {}) {
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

function formatDate(timestamp) {
  const value = Number(timestamp) || 0;
  if (!value) return "-";
  return new Date(value * 1000).toLocaleDateString("pt-BR");
}

function showFeedback(message, kind = "info") {
  feedback.value = { message, kind };
  window.setTimeout(() => {
    if (feedback.value?.message === message) feedback.value = null;
  }, 5000);
}

async function runNui(eventName, data = {}, successTab = null) {
  if (busy.value) return;
  busy.value = true;
  const result = await nui(eventName, data);
  busy.value = false;
  showFeedback(result.message || (result.ok ? "Ação concluída." : "Não foi possível concluir."), result.kind || (result.ok ? "success" : "error"));
  if (result.ok && successTab) activeTab.value = successTab;
  if (result.payload) emit("refresh");
  return result;
}

function ask(title, description, button, action, warning = "Confirme apenas se deseja concluir esta ação agora.", icon = "fa-solid fa-circle-question") {
  confirmation.value = { title, description, button, action, warning, icon };
}

function runConfirmation() {
  if (!confirmation.value) return;
  const action = confirmation.value.action;
  confirmation.value = null;
  action();
}

async function setLeader() {
  if (!selected.value || !leaderId.value) return;
  const result = await runNui("setFactionLeader", { key: selected.value.key, target: leaderId.value });
  if (result?.ok) leaderId.value = "";
}

function submitMember() {
  const id = memberId.value.replace(/\D/g, "");
  if (!id) return;
  memberId.value = "";
  runNui("addMember", { userId: id });
}

function removeMember(userId) {
  runNui("removeMember", { userId });
}

function rowForIncluded(id) {
  return (myFaction.value?.features || []).find((feature) => (feature.feature_id || feature.featureId) === id && feature.source_kind === "included");
}

function installed(id) {
  return Boolean(rowForIncluded(id)?.coords);
}

function isPositionable(feature) {
  return !["panel", "member_capacity"].includes(String(feature.feature_type || feature.type || ""));
}

function coordsLabel(feature) {
  return feature?.coords ? `${Number(feature.coords.x).toFixed(1)}, ${Number(feature.coords.y).toFixed(1)}` : "";
}

function includedStatus(feature) {
  if (feature.automatic) return "Liberado automaticamente";
  const row = rowForIncluded(feature.id);
  return row?.coords ? coordsLabel(row) : "Aguardando instalação";
}

function featureIcon(feature) {
  const icons = {
    storage: "fa-solid fa-box-archive",
    garage: "fa-solid fa-car",
    craft: "fa-solid fa-flask",
    farm: "fa-solid fa-route",
    sound: "fa-solid fa-music",
    clothing: "fa-solid fa-shirt",
    store: "fa-solid fa-store"
  };
  return icons[String(feature.feature_type || feature.type || "")] || "fa-solid fa-location-dot";
}

function initials(name) {
  return String(name || "?").split(" ").slice(0, 2).map((word) => word.charAt(0)).join("").toUpperCase();
}

function isStorageFeature(feature) {
  return String(feature.feature_type || feature.type || "") === "storage";
}

function isGarageFeature(feature) {
  return String(feature.feature_type || feature.type || "") === "garage";
}

function garageSpawn(feature, slot) {
  const points = feature?.metadata?.spawnPoints;
  if (!points) return null;
  if (Array.isArray(points)) return points[slot - 1] || points[slot] || null;
  return points[String(slot)] || null;
}

function garageSpawnLabel(feature, slot) {
  const point = garageSpawn(feature, slot);
  return point ? `${Number(point.x).toFixed(1)}, ${Number(point.y).toFixed(1)}` : "não definido";
}

function confirmIncluded(feature) {
  ask(
    feature.label,
    `Instalar este módulo incluído para uso exclusivo de ${myFaction.value?.label || "seu clã"}. Se desejar mover depois, haverá cobrança de ${positionReset.value.singlePrice} Runas.`,
    "Instalar aqui",
    () => runNui("placeIncluded", { id: feature.id }),
    "O ponto será criado exatamente na sua posição atual quando você aceitar.",
    "fa-solid fa-location-crosshairs"
  );
}

function confirmUpgrade(upgrade) {
  if (String(upgrade.type) === "storage") {
    storageChoice.value = {
      upgrade,
      mode: "new",
      targetFeatureId: storageFeatures.value[0]?.id || null
    };
    return;
  }
  if (!upgrade.requiresLocation) {
    ask(upgrade.label, `A compra custará ${money(upgrade.price)} Runas e será aplicada imediatamente ao seu clã.`, "Confirmar compra", () => runNui("buyUpgrade", { id: upgrade.id }), "Confirme apenas se deseja descontar o valor agora.", upgrade.icon || "fa-solid fa-cart-shopping");
    return;
  }
  ask(upgrade.label, `A compra custará ${money(upgrade.price)} Runas e o ponto ficará na posição atual. Uma troca futura custará ${positionReset.value.singlePrice} Runas.`, "Comprar e instalar", () => runNui("buyUpgrade", { id: upgrade.id, mode: "new" }), "O ponto será criado exatamente na sua posição atual quando você aceitar.", "fa-solid fa-location-crosshairs");
}

function confirmSetLocation(feature) {
  ask(feature.label, "Este módulo já pertence ao seu clã. Confirme para ativá-lo gratuitamente na posição atual.", "Instalar aqui", () => runNui("setFeatureLocation", { id: feature.id }), "O ponto será ativado exatamente onde você estiver quando aceitar.", "fa-solid fa-location-crosshairs");
}

function confirmReposition(feature) {
  ask(feature.label, `Esta alteração moverá apenas este ponto e cobrará ${positionReset.value.singlePrice} Runas do seu saldo.`, `Mover por ${positionReset.value.singlePrice} Runas`, () => runNui("repositionFeature", { id: feature.id }), "Ao confirmar, este ponto será movido imediatamente para a sua posição atual.", "fa-solid fa-location-arrow");
}

function confirmGarageSpawn(feature, slot) {
  ask("Spawn " + slot + " da garagem", "Confirme para salvar sua posição atual como local em que o veículo vai aparecer.", "Definir spawn " + slot, () => runNui("setGarageSpawn", { id: feature.id, slot }), "O local precisa estar no máximo a 20m do ponto principal da garagem.", "fa-solid fa-car-side");
}

function confirmResetAll() {
  ask("Resetar todas as posições", `Serão removidos os locais atuais por ${positionReset.value.allPrice} Runas. Os módulos e o conteúdo dos baús permanecem salvos, aguardando nova instalação.`, `Resetar por ${positionReset.value.allPrice} Runas`, () => runNui("resetAllPositions"), "Depois disso, você escolhe novamente cada local pelo painel.", "fa-solid fa-rotate-left");
}

function selectStorageMode(mode) {
  if (!storageChoice.value) return;
  storageChoice.value.mode = mode;
  if (mode === "expand" && !storageChoice.value.targetFeatureId) {
    storageChoice.value.targetFeatureId = storageFeatures.value[0]?.id || null;
  }
}

function confirmStorageChoice() {
  if (!storageChoice.value) return;
  const choice = storageChoice.value;
  if (choice.mode === "expand" && !choice.targetFeatureId) return;
  storageChoice.value = null;
  runNui("buyUpgrade", {
    id: choice.upgrade.id,
    mode: choice.mode,
    targetFeatureId: choice.mode === "expand" ? choice.targetFeatureId : undefined
  });
}

function openRenameFeature(feature) {
  if (!feature.id) return;
  renameChoice.value = { id: feature.id, label: feature.label || "Baú" };
}

function confirmRenameFeature() {
  if (!renameChoice.value) return;
  const label = renameChoice.value.label.trim();
  if (label.length < 2 || label.length > 32) return;
  const id = renameChoice.value.id;
  renameChoice.value = null;
  runNui("renameFeature", { id, label });
}
</script>

<template>
  <section class="factions-screen">
    <header class="screen-heading">
      <div>
        <small>Clãs</small>
        <h1>Clãs</h1>
        <p v-if="activeTab === 'admin'">Defina líderes, acompanhe clãs ocupados e veja quais ainda estão livres.</p>
        <p v-else-if="activeTab === 'mine'">Administre membros, pontos, baús, garagens, rotas e upgrades.</p>
        <p v-else-if="isStaff">{{ texts.staffDescription || "Gerencie líderes e clãs cadastrados." }}</p>
        <p v-else>Consulte seu clã, benefícios e permissões disponíveis.</p>
        <small v-if="testMode" class="faction-test-mode">Modo teste: visão de jogador comum</small>
      </div>
    </header>

    <Transition name="feedback">
      <div v-if="feedback" class="faction-feedback" :class="feedback.kind">
        <i :class="feedback.kind === 'success' ? 'fa-solid fa-check' : feedback.kind === 'error' ? 'fa-solid fa-xmark' : 'fa-solid fa-circle-info'"></i>
        <span>{{ feedback.message }}</span>
      </div>
    </Transition>

    <div v-if="!payload" class="empty-state">
      <i class="fa-solid fa-circle-notch fa-spin"></i>
      <h2>Carregando clãs</h2>
      <p>Aguarde enquanto buscamos as informações.</p>
    </div>

    <div v-else-if="!canShowCatalog" class="empty-state faction-empty-state">
      <i class="fa-solid fa-user-lock"></i>
      <h2>{{ texts.noFactionTitle || "Você não faz parte de um clã" }}</h2>
      <p>{{ texts.noFactionDescription || "A entrada em um clã é definida pela staff." }}</p>
    </div>

    <div v-else class="faction-workspace">
      <nav class="faction-tabs">
        <button v-for="tab in tabs" :key="tab.id" type="button" :class="{ active: activeTab === tab.id }" @click="activeTab = tab.id">
          <i :class="tab.icon"></i>
          {{ tab.label }}
        </button>
      </nav>

      <div v-if="activeTab === 'catalog'" class="faction-layout">
        <aside class="faction-list">
          <button v-for="faction in factions" :key="faction.key" type="button" class="faction-card" :class="{ active: selected?.key === faction.key }" @click="selectedKey = faction.key">
            <span class="faction-logo" :style="{ '--accent': faction.accent || '#a855f7' }">
              <img v-if="faction.image" :src="faction.image" :alt="faction.label" />
              <i v-else class="fa-solid fa-building-shield"></i>
            </span>
            <span>
              <b>{{ faction.label }}</b>
              <small v-if="faction.available">Disponível</small>
              <small v-else>{{ faction.ownerName || "Ocupado" }}</small>
            </span>
          </button>
        </aside>

        <article v-if="selected" class="faction-detail">
          <section class="faction-hero" :style="{ '--accent': selected.accent || '#a855f7' }">
            <div class="hero-image">
              <img v-if="selected.image" :src="selected.image" :alt="selected.label" />
              <i v-else class="fa-solid fa-shield-halved"></i>
            </div>
            <div>
              <small>{{ selected.available ? "Clã disponível" : "Clã ocupado" }}</small>
              <h2>{{ selected.label }}</h2>
              <p>{{ selected.description }}</p>
            </div>
          </section>

          <div class="faction-metrics">
            <span><small>Forma de acesso</small><b>Definido pela staff</b></span>
            <span><small>Membros iniciais</small><b>{{ selected.memberLimit }}</b></span>
            <span><small>Produto</small><b>{{ selected.product || "Configurável" }}</b></span>
          </div>

          <section v-if="myFaction" class="owned-panel">
            <div>
              <small>Meu clã</small>
              <h3>{{ myFaction.label || myFaction.group_name }}</h3>
              <p>Status: {{ myFaction.status || "active" }}</p>
            </div>
            <button type="button" class="panel-link" @click="activeTab = 'mine'">Administrar <i class="fa-solid fa-arrow-right"></i></button>
          </section>

          <div class="detail-columns">
            <div><h3>Autonomia</h3><p v-for="item in payload.autonomy || []" :key="item"><i class="fa-solid fa-check"></i>{{ item }}</p></div>
            <div><h3>Benefícios</h3><p v-for="item in payload.benefits || []" :key="item"><i class="fa-solid fa-check"></i>{{ item }}</p></div>
          </div>
        </article>
      </div>

      <article v-else-if="activeTab === 'mine'" class="mine-layout">
        <div v-if="!myFaction" class="empty-state soft">
          <i class="fa-solid fa-building-circle-exclamation"></i>
          <h2>Nenhum clã vinculado</h2>
          <p>Quando você for contratado ou assumir um clã, a administração aparece aqui.</p>
        </div>

        <template v-else>
          <div class="subscription-card permanent">
            <div>
              <small>Organização permanente</small>
              <strong>{{ myFaction.label || myFaction.group_name }}</strong>
              <p>Sem mensalidade ou data de expiração</p>
            </div>
            <div class="subscription-metrics">
              <span><small>Membros</small><b>{{ clanMembers.length || 1 }} / {{ myFaction.member_limit }}</b></span>
              <span><small>Posse</small><b>Permanente</b></span>
            </div>
          </div>

          <section class="owned-section member-section">
            <div class="section-heading">
              <div>
                <h2>Membros</h2>
                <p>Ao adicionar um jogador, o cargo inicial do clã é aplicado automaticamente.</p>
              </div>
              <form class="member-add" @submit.prevent="submitMember">
                <input v-model="memberId" inputmode="numeric" pattern="[0-9]*" placeholder="ID do jogador" />
                <button type="submit" :disabled="!memberId.trim()"><i class="fa-solid fa-user-plus"></i> Adicionar</button>
              </form>
            </div>
            <div class="member-list">
              <article v-for="member in clanMembers" :key="member.user_id">
                <span class="member-avatar">{{ initials(member.display_name) }}</span>
                <div>
                  <b>{{ member.display_name }}</b>
                  <small>ID {{ member.user_id }} · {{ member.grade >= 3 ? "Líder" : "Membro" }}</small>
                </div>
                <button v-if="member.grade < 3" type="button" class="remove-member" @click="removeMember(member.user_id)">
                  <i class="fa-solid fa-user-minus"></i>
                </button>
                <span v-else class="leader-tag">Líder</span>
              </article>
            </div>
          </section>

          <section class="owned-section">
            <div class="section-heading">
              <div>
                <h2>Estrutura incluída</h2>
                <p>Os pontos são privados e liberados somente para membros do clã.</p>
              </div>
            </div>
            <div class="placement-alert">
              <i class="fa-solid fa-location-dot"></i>
              <p>Antes de instalar, fique exatamente no local desejado. Mover um ponto depois custa <b>{{ positionReset.singlePrice }} Runas</b>.</p>
            </div>
            <div class="included-grid">
              <article v-for="feature in includedFeatures" :key="feature.id">
                <i :class="feature.icon"></i>
                <div>
                  <b>{{ feature.label }}</b>
                  <small v-if="feature.modelLabel" class="point-model">{{ feature.modelLabel }}</small>
                  <small>{{ includedStatus(feature) }}</small>
                </div>
                <button v-if="!feature.automatic && !installed(feature.id)" type="button" @click="confirmIncluded(feature)">Instalar aqui</button>
                <span v-else class="delivered-tag">Ativo</span>
              </article>
            </div>
          </section>

          <section v-if="pointFeatures.length" class="owned-section location-section">
            <div class="section-heading">
              <div>
                <h2>Pontos do clã</h2>
                <p>Baús, garagens, mesas e rotas criados para o grupo {{ myFaction.group_name }}.</p>
              </div>
              <button class="reset-all-button" type="button" @click="confirmResetAll">
                <i class="fa-solid fa-rotate-left"></i> Resetar tudo · {{ positionReset.allPrice }} Runas
              </button>
            </div>
            <div class="points-list">
              <article v-for="feature in pointFeatures" :key="feature.id">
                <span class="point-icon"><i :class="featureIcon(feature)"></i></span>
                <div class="point-detail">
                  <b>{{ feature.label }}</b>
                  <small v-if="feature.modelLabel" class="point-model"><i class="fa-solid fa-cubes"></i> {{ feature.modelLabel }}</small>
                  <small v-if="feature.coords"><i class="fa-solid fa-location-dot"></i> {{ coordsLabel(feature) }}</small>
                  <small v-else class="pending-location"><i class="fa-solid fa-circle-exclamation"></i> Defina um local para ativar</small>
                  <div v-if="isGarageFeature(feature) && feature.coords" class="garage-spawn-summary">
                    <span v-for="slot in 2" :key="slot"><i class="fa-solid fa-car-side"></i> Spawn {{ slot }}: {{ garageSpawnLabel(feature, slot) }}</span>
                  </div>
                </div>
                <span class="point-access"><i class="fa-solid fa-lock"></i> {{ myFaction.group_name }}</span>
                <div class="point-actions">
                  <button v-if="isStorageFeature(feature)" type="button" class="point-action icon-only" title="Renomear baú" @click="openRenameFeature(feature)"><i class="fa-solid fa-pen"></i></button>
                  <button v-if="isGarageFeature(feature) && feature.coords" type="button" class="point-action" @click="confirmGarageSpawn(feature, 1)">Spawn 1</button>
                  <button v-if="isGarageFeature(feature) && feature.coords" type="button" class="point-action" @click="confirmGarageSpawn(feature, 2)">Spawn 2</button>
                  <button v-if="feature.coords" type="button" class="point-action" @click="confirmReposition(feature)">Mover · {{ positionReset.singlePrice }} Runas</button>
                  <button v-else type="button" class="point-action" @click="confirmSetLocation(feature)">Instalar aqui</button>
                </div>
              </article>
            </div>
          </section>

          <section class="owned-section">
            <div class="section-heading">
              <div>
                <h2>Upgrades</h2>
                <p>Novos pontos são instalados no local em que você confirmar a compra.</p>
              </div>
            </div>
            <div class="upgrade-grid">
              <article v-for="upgrade in upgrades" :key="upgrade.id">
                <span><i :class="upgrade.icon"></i></span>
                <div>
                  <b>{{ upgrade.label }}</b>
                  <p>{{ upgrade.description }}</p>
                  <small>{{ upgrade.permanent ? "Permanente" : "Mensal" }}<template v-if="upgrade.requiresLocation"> · Local atual</template></small>
                </div>
                <strong>{{ money(upgrade.price) }} <em>Runas</em></strong>
                <button type="button" @click="confirmUpgrade(upgrade)">Comprar</button>
              </article>
            </div>
          </section>

          <section v-if="monthlyFeatures.length" class="owned-section compact-section">
            <div class="section-heading"><h2>Serviços mensais</h2></div>
            <article v-for="feature in monthlyFeatures" :key="feature.id" class="monthly-row">
              <span>{{ feature.label }}</span>
              <small :class="{ blocked: feature.status === 'blocked' }">{{ feature.status === "blocked" ? "Bloqueado" : `Até ${formatDate(feature.paid_until || 0)}` }}</small>
              <button type="button" @click="runNui('renewUpgrade', { id: feature.id })">Renovar</button>
            </article>
          </section>
        </template>
      </article>

      <article v-else-if="activeTab === 'admin'" class="staff-admin-view">
        <section class="staff-admin-head">
          <div>
            <small>Painel staff</small>
            <h2>Administrar clãs</h2>
            <p>Selecione um clã na lista, informe o ID do jogador online e defina a liderança.</p>
          </div>
          <div class="staff-admin-counters">
            <span><b>{{ adminFactions.length }}</b><small>Ocupados</small></span>
            <span><b>{{ availableFactions.length }}</b><small>Livres</small></span>
          </div>
        </section>
        <div class="staff-admin-layout">
          <aside class="faction-list admin-list">
            <button v-for="faction in factions" :key="faction.key" type="button" class="faction-card" :class="{ active: selected?.key === faction.key }" @click="selectedKey = faction.key">
              <span class="faction-logo" :style="{ '--accent': faction.accent || '#a855f7' }">
                <img v-if="faction.image" :src="faction.image" :alt="faction.label" />
                <i v-else class="fa-solid fa-building-shield"></i>
              </span>
              <span><b>{{ faction.label }}</b><small>{{ faction.available ? "Livre para setar" : faction.ownerName || "Ocupado" }}</small></span>
            </button>
          </aside>
          <section v-if="selected" class="staff-manage-card">
            <div class="staff-selected-hero">
              <div class="hero-image mini">
                <img v-if="selected.image" :src="selected.image" :alt="selected.label" />
                <i v-else class="fa-solid fa-shield-halved"></i>
              </div>
              <div><small>{{ selected.available ? "Sem líder" : "Com liderança" }}</small><h3>{{ selected.label }}</h3><p>{{ selected.description }}</p></div>
            </div>
            <div class="faction-metrics two">
              <span><small>Grupo</small><b>{{ selected.group }}</b></span>
              <span><small>Dono atual</small><b>{{ selected.ownerName || "Nenhum" }}</b></span>
            </div>
            <section class="staff-panel expanded">
              <div><small>Definir liderança</small><h3>Setar líder do clã</h3><p>O jogador precisa estar online. O cargo configurado será aplicado direto no grupo do clã.</p></div>
              <div class="staff-actions">
                <input v-model="leaderId" type="text" inputmode="numeric" placeholder="ID do jogador" />
                <button type="button" :disabled="busy || !leaderId" @click="setLeader"><i class="fa-solid fa-user-shield"></i> Setar líder</button>
              </div>
            </section>
          </section>
        </div>
      </article>
    </div>

    <Teleport to="body" :disabled="true">
      <Transition name="confirm">
        <div v-if="confirmation" class="placement-confirm-backdrop">
          <section class="placement-confirm" role="dialog" aria-modal="true">
            <span class="confirm-icon"><i :class="confirmation.icon"></i></span>
            <div><small>Confirmar ação</small><h2>{{ confirmation.title }}</h2><p>{{ confirmation.description }}</p></div>
            <div class="confirm-warning"><i class="fa-solid fa-circle-info"></i>{{ confirmation.warning }}</div>
            <footer><button class="cancel-button" type="button" @click="confirmation = null">Cancelar</button><button type="button" @click="runConfirmation">{{ confirmation.button }}</button></footer>
          </section>
        </div>
      </Transition>
    </Teleport>

    <Teleport to="body" :disabled="true">
      <Transition name="confirm">
        <div v-if="storageChoice" class="placement-confirm-backdrop">
          <section class="placement-confirm storage-confirm" role="dialog" aria-modal="true">
            <span class="confirm-icon"><i class="fa-solid fa-box-archive"></i></span>
            <div><small>Baú do clã</small><h2>{{ storageChoice.upgrade.label }}</h2><p>Escolha entre criar um novo baú no local atual ou aumentar o peso de um baú existente.</p></div>
            <div class="storage-choice-grid">
              <button type="button" :class="{ active: storageChoice.mode === 'new' }" @click="selectStorageMode('new')"><i class="fa-solid fa-location-dot"></i><span>Novo local</span><small>Cria um baú de {{ storageChoice.upgrade.weight || 200 }}Kg onde você estiver.</small></button>
              <button type="button" :class="{ active: storageChoice.mode === 'expand', disabled: !storageFeatures.length }" :disabled="!storageFeatures.length" @click="selectStorageMode('expand')"><i class="fa-solid fa-weight-hanging"></i><span>Aumentar peso</span><small>Adiciona {{ storageChoice.upgrade.weight || 200 }}Kg em um baú já instalado.</small></button>
            </div>
            <div v-if="storageChoice.mode === 'expand'" class="storage-select">
              <span>Selecionar baú</span>
              <div class="storage-target-list">
                <button v-for="feature in storageFeatures" :key="feature.id" type="button" :class="{ active: storageChoice.targetFeatureId === feature.id }" @click="storageChoice.targetFeatureId = feature.id">
                  <b>{{ feature.label }}</b><small>{{ feature.weight || 0 }}Kg atuais</small>
                </button>
              </div>
            </div>
            <div class="confirm-warning"><i class="fa-solid fa-circle-info"></i>{{ storageChoice.mode === "new" ? "Ao confirmar, um novo baú será criado imediatamente na sua posição atual." : "Ao confirmar, o peso será somado no baú selecionado sem alterar a posição dele." }}</div>
            <footer><button class="cancel-button" type="button" @click="storageChoice = null">Cancelar</button><button type="button" :disabled="storageChoice.mode === 'expand' && !storageChoice.targetFeatureId" @click="confirmStorageChoice">Confirmar compra</button></footer>
          </section>
        </div>
      </Transition>
    </Teleport>

    <Teleport to="body" :disabled="true">
      <Transition name="confirm">
        <div v-if="renameChoice" class="placement-confirm-backdrop">
          <section class="placement-confirm" role="dialog" aria-modal="true">
            <span class="confirm-icon"><i class="fa-solid fa-box-archive"></i></span>
            <div><small>Nome do baú</small><h2>Renomear armazenamento</h2><p>Esse nome será usado no hover e na tela do inventário para os membros do clã.</p></div>
            <label class="rename-field"><span>Novo nome</span><input v-model="renameChoice.label" maxlength="32" placeholder="Baú" @keyup.enter="confirmRenameFeature" /></label>
            <div class="confirm-warning"><i class="fa-solid fa-circle-info"></i>Use um nome curto e fácil de reconhecer no local do baú.</div>
            <footer><button class="cancel-button" type="button" @click="renameChoice = null">Cancelar</button><button type="button" :disabled="renameChoice.label.trim().length < 2" @click="confirmRenameFeature">Salvar nome</button></footer>
          </section>
        </div>
      </Transition>
    </Teleport>
  </section>
</template>
