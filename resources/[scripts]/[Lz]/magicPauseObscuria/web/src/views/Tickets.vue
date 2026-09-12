<script setup>
import { computed, nextTick, ref, watch } from "vue";
import "../styles/tickets.css";

const props = defineProps({
  payload: { type: Object, default: null },
  i18n: { type: Object, default: () => ({}) }
});

const emit = defineEmits(["refresh"]);

const selectedId = ref(null);
const feedback = ref(null);
const creating = ref(false);
const replying = ref(false);
const transcripting = ref(false);
const createForm = ref({ category: "", title: "", message: "" });
const replyMessage = ref("");
const filter = ref("all");
const search = ref("");
const mode = ref("player");
const messagesEl = ref(null);
const chatClosed = ref(false);

const locale = computed(() => props.i18n?.messages || props.payload?.locale?.messages || {});
const currentLocale = computed(() => props.i18n?.current || props.payload?.locale?.current || "pt-BR");
const tickets = computed(() => props.payload?.tickets || []);
const messages = computed(() => props.payload?.messages || []);
const isStaff = computed(() => props.payload?.isStaff === true);
const adminMode = computed(() => isStaff.value && mode.value === "staff");
const categories = computed(() => props.payload?.config?.categories || []);
const statuses = computed(() => props.payload?.config?.statuses || []);
const playerPassport = computed(() => String(props.payload?.profile?.passport || ""));

const visibleTickets = computed(() => {
  if (adminMode.value) return tickets.value;
  return tickets.value.filter((ticket) => String(ticket.passport || "") === playerPassport.value);
});

const selectedTicket = computed(() => {
  if (chatClosed.value) return null;
  const id = selectedId.value || props.payload?.selectedTicket?.id;
  return visibleTickets.value.find((ticket) => Number(ticket.id) === Number(id)) || null;
});

const filteredTickets = computed(() => {
  const term = search.value.trim().toLowerCase();
  return visibleTickets.value.filter((ticket) => {
    const statusOk = filter.value === "all" || ticket.status === filter.value;
    if (!statusOk) return false;
    if (!term) return true;

    return [
      ticket.id,
      ticket.title,
      ticket.playerName,
      ticket.passport,
      categoryLabel(ticket.category),
      statusLabel(ticket.status)
    ].some((value) => String(value || "").toLowerCase().includes(term));
  }).sort((a, b) => {
    if (isTicketUnread(a) !== isTicketUnread(b)) return isTicketUnread(a) ? -1 : 1;
    return (Number(b.updatedAt) || 0) - (Number(a.updatedAt) || 0);
  });
});

const unreadTickets = computed(() => visibleTickets.value.filter((ticket) => isTicketUnread(ticket)).length);

function resourceName() {
  return (window.GetParentResourceName && window.GetParentResourceName()) || "magicPauseObscuria";
}

async function nui(eventName, data = {}) {
  const response = await fetch(`https://${resourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data)
  });

  return response.json().catch(() => ({}));
}

function t(path, fallback, replacements = {}) {
  const parts = String(path || "").split(".");
  let value = locale.value;
  for (const part of parts) value = value?.[part];

  let text = typeof value === "string" ? value : (fallback || path);
  Object.entries(replacements || {}).forEach(([key, val]) => {
    text = text.replaceAll(`{${key}}`, String(val));
  });

  return text;
}

function categoryLabel(id) {
  return categories.value.find((row) => row.id === id)?.label || id || "-";
}

function isCategoryActive(id) {
  return createForm.value.category === id;
}

function selectCategory(id) {
  const next = String(id || "");
  if (!next) return;
  createForm.value.category = next;
}

function categoryIcon(id) {
  return categories.value.find((row) => row.id === id)?.icon || "fa-solid fa-ticket";
}

function statusRow(id) {
  return statuses.value.find((row) => row.id === id) || { label: id || "-", color: "#94a3b8" };
}

function statusLabel(id) {
  return statusRow(id).label;
}

function compactStatusLabel(id) {
  const labels = {
    open: t("tickets.statusOpenShort", "Aberto"),
    answered: t("tickets.statusAnsweredShort", "Resp."),
    waiting: t("tickets.statusWaitingShort", "Aguard."),
    closed: t("tickets.statusClosedShort", "Fech.")
  };

  return labels[id] || statusLabel(id);
}

function formatTime(value) {
  const ts = Number(value) || 0;
  if (!ts) return "-";
  return new Date(ts * 1000).toLocaleString(currentLocale.value);
}

function shortText(value, size = 32) {
  const text = String(value || "");
  return text.length > size ? `${text.slice(0, size - 1)}...` : text;
}

function isTicketUnread(ticket) {
  return ticket?.unread === true;
}

function showFeedback(message, kind = "success") {
  feedback.value = { message, kind };
  window.setTimeout(() => {
    if (feedback.value?.message === message) feedback.value = null;
  }, 4200);
}

async function scrollMessagesToBottom(behavior = "auto") {
  await nextTick();
  const el = messagesEl.value;
  if (!el) return;
  el.scrollTo({ top: el.scrollHeight, behavior });
}

function setMode(nextMode) {
  mode.value = nextMode;
  selectedId.value = null;
  chatClosed.value = false;
  filter.value = "all";
  search.value = "";
}

function closeChat() {
  selectedId.value = null;
  chatClosed.value = true;
}

async function refresh(ticketId = selectedId.value) {
  const payload = await nui("getTickets", ticketId ? { ticketId } : {});
  if (payload?.selectedTicket?.id) selectedId.value = payload.selectedTicket.id;
  emit("refresh", payload);
  scrollMessagesToBottom();
}

async function selectTicket(ticket) {
  selectedId.value = ticket.id;
  chatClosed.value = false;
  await refresh(ticket.id);
  scrollMessagesToBottom();
}

async function createTicket() {
  if (creating.value) return;
  if (!createForm.value.category) {
    showFeedback(t("tickets.selectCategory", "Selecione uma categoria."), "error");
    return;
  }

  creating.value = true;
  const result = await nui("createTicket", createForm.value);
  creating.value = false;

  showFeedback(result.message || t("tickets.created", "Ticket criado."), result.ok ? "success" : "error");

  if (result.ok) {
    createForm.value = { category: "", title: "", message: "" };
    selectedId.value = result.payload?.selectedTicket?.id || result.payload?.selectedTicketId || selectedId.value;
    chatClosed.value = false;
    emit("refresh", result.payload);
  }
}

async function sendReply() {
  if (replying.value || !selectedTicket.value) return;
  replying.value = true;
  const result = await nui("replyTicket", { ticketId: selectedTicket.value.id, message: replyMessage.value });
  replying.value = false;

  showFeedback(result.message || t("tickets.replied", "Resposta enviada."), result.ok ? "success" : "error");

  if (result.ok) {
    replyMessage.value = "";
    emit("refresh", result.payload);
    scrollMessagesToBottom("smooth");
  }
}

async function setStatus(status) {
  if (!selectedTicket.value) return;
  const result = await nui("setTicketStatus", { ticketId: selectedTicket.value.id, status });
  showFeedback(result.message || t("tickets.statusChanged", "Status atualizado."), result.ok ? "success" : "error");
  if (result.ok) emit("refresh", result.payload);
}

async function claimTicket() {
  if (!selectedTicket.value) return;
  const result = await nui("claimTicket", { ticketId: selectedTicket.value.id });
  showFeedback(result.message || t("tickets.claimed", "Ticket assumido."), result.ok ? "success" : "error");
  if (result.ok) emit("refresh", result.payload);
}

async function transcriptTicket() {
  if (transcripting.value || !selectedTicket.value || !adminMode.value) return;
  transcripting.value = true;
  const result = await nui("transcriptTicket", { ticketId: selectedTicket.value.id });
  transcripting.value = false;
  showFeedback(result.message || t("tickets.transcriptSent", "Transcript enviado."), result.ok ? "success" : "error");
  if (result.ok) {
    selectedId.value = null;
    chatClosed.value = true;
    emit("refresh", result.payload);
  }
}

watch(
  () => props.payload,
  (payload) => {
    if (!payload) return;
    if (!chatClosed.value && !selectedId.value && selectedTicket.value?.id) selectedId.value = selectedTicket.value.id;
    if (createForm.value.category && !categories.value.some((category) => category.id === createForm.value.category)) {
      createForm.value.category = "";
    }
    scrollMessagesToBottom();
  },
  { immediate: true }
);

watch(
  () => messages.value.map((message) => message.id).join(":"),
  () => scrollMessagesToBottom(),
  { flush: "post" }
);

watch(
  () => selectedTicket.value?.id,
  () => scrollMessagesToBottom(),
  { flush: "post" }
);
</script>

<template>
  <section class="tickets-screen">
    <header class="tickets-header">
      <div>
        <small>{{ adminMode ? t("tickets.allTickets", "Todos os tickets") : t("tickets.myTickets", "Meus tickets") }}</small>
        <h1>{{ t("tickets.title", "Central de suporte") }}</h1>
        <p>{{ adminMode ? t("tickets.staffSubtitle", "Acompanhe e responda aos atendimentos da cidade.") : t("tickets.subtitle", "Abra solicitações e acompanhe cada resposta da equipe.") }}</p>
      </div>

      <div class="tickets-header-actions">
        <div v-if="isStaff" class="tickets-mode-switch">
          <button type="button" :class="{ active: mode === 'player' }" @click="setMode('player')">
            <i class="fa-solid fa-user"></i>
            {{ t("tickets.playerMode", "Meus tickets") }}
          </button>
          <button type="button" :class="{ active: mode === 'staff' }" @click="setMode('staff')">
            <i class="fa-solid fa-user-shield"></i>
            {{ t("tickets.staffMode", "Equipe") }}
          </button>
        </div>

        <div class="tickets-header-count">
          <b>{{ visibleTickets.length }}</b>
          <span>{{ adminMode ? t("tickets.allTickets", "Tickets") : t("tickets.myTickets", "Tickets") }}</span>
        </div>
      </div>
    </header>

    <div v-if="feedback" class="tickets-feedback" :class="feedback.kind">
      <i :class="feedback.kind === 'success' ? 'fa-solid fa-check' : 'fa-solid fa-xmark'"></i>
      <span>{{ feedback.message }}</span>
    </div>

    <div v-if="!payload" class="tickets-loading">
      <i class="fa-solid fa-circle-notch fa-spin"></i>
      <span>{{ t("app.loading", "Carregando") }}...</span>
    </div>

    <div v-else class="tickets-layout organic" :class="{ admin: adminMode, player: !adminMode, 'chat-closed': chatClosed }">
      <aside class="tickets-left-rail">
        <section v-if="!adminMode" class="ticket-create-flow">
          <div class="ticket-flow-title">
            <span class="ticket-section-icon"><i class="fa-solid fa-pen-to-square"></i></span>
            <div>
              <small>{{ t("tickets.newTicket", "Novo ticket") }}</small>
              <h3>{{ t("tickets.createTitle", "Abrir atendimento") }}</h3>
            </div>
          </div>

          <p>{{ t("tickets.createDescription", "Explique o que aconteceu com clareza.") }}</p>

          <label>
            <span>{{ t("tickets.category", "Categoria") }}</span>
            <div class="tickets-category-grid">
              <button
                v-for="category in categories"
                :key="category.id"
                type="button"
                :class="{ active: isCategoryActive(category.id) }"
                @click.prevent="selectCategory(category.id)"
              >
                <i :class="category.icon || 'fa-solid fa-ticket'"></i>
                <span>{{ category.label }}</span>
              </button>
            </div>
          </label>

          <div class="ticket-create-fields">
            <label>
              <span>{{ t("tickets.subject", "Assunto") }}</span>
              <input v-model="createForm.title" :maxlength="payload.config.maxTitleLength" :placeholder="t('tickets.subjectPlaceholder', 'Resumo curto do problema')" />
            </label>

            <label>
              <span>{{ t("tickets.message", "Mensagem") }}</span>
              <textarea v-model="createForm.message" :maxlength="payload.config.maxMessageLength" :placeholder="t('tickets.messagePlaceholder', 'Descreva o que você precisa...')" />
            </label>
          </div>

          <button type="button" class="tickets-primary wide" :disabled="creating" @click="createTicket">
            <i class="fa-solid fa-plus"></i>
            {{ creating ? t("common.processing", "Processando...") : t("tickets.sendTicket", "Enviar ticket") }}
          </button>
        </section>

        <section class="tickets-list-panel">
          <div class="tickets-panel-title">
            <span class="ticket-section-icon"><i class="fa-solid fa-list-check"></i></span>
            <div>
              <small>{{ adminMode ? t("tickets.allTickets", "Todos os tickets") : t("tickets.myTickets", "Meus tickets") }}</small>
              <b>{{ visibleTickets.length }} {{ visibleTickets.length === 1 ? "ticket" : "tickets" }}</b>
              <em v-if="unreadTickets">{{ unreadTickets }} {{ t("tickets.unread", "não lido") }}</em>
            </div>
          </div>

          <div class="tickets-toolbar">
            <div class="tickets-search">
              <i class="fa-solid fa-magnifying-glass"></i>
              <input v-model="search" :placeholder="adminMode ? t('tickets.searchStaff', 'Buscar ticket, pessoa ou ID') : t('tickets.searchPlayer', 'Buscar meus tickets')" />
            </div>
            <div class="tickets-filter">
              <button type="button" :class="{ active: filter === 'all' }" @click="filter = 'all'">{{ t("common.all", "Todos") }}</button>
              <button v-for="status in statuses" :key="status.id" type="button" :class="{ active: filter === status.id }" @click="filter = status.id">
                {{ compactStatusLabel(status.id) }}
              </button>
            </div>
          </div>

          <div class="tickets-list">
            <button
              v-for="ticket in filteredTickets"
              :key="ticket.id"
              type="button"
              class="ticket-card"
              :class="{ active: selectedTicket?.id === ticket.id, unread: isTicketUnread(ticket) }"
              @click="selectTicket(ticket)"
            >
              <span class="ticket-card-icon"><i :class="categoryIcon(ticket.category)"></i></span>
              <span class="ticket-card-main">
                <b>{{ shortText(ticket.title, 34) }}</b>
                <small>{{ t("tickets.ticketNumber", "Ticket #{id}", { id: ticket.id }) }} · {{ categoryLabel(ticket.category) }}</small>
                <em v-if="adminMode">{{ shortText(ticket.playerName, 28) }}</em>
              </span>
              <span class="ticket-card-meta">
                <i v-if="isTicketUnread(ticket)" class="ticket-unread-dot"></i>
                <span class="ticket-status" :style="{ '--status-color': statusRow(ticket.status).color }">
                  {{ isTicketUnread(ticket) ? t("tickets.unread", "Não lido") : statusLabel(ticket.status) }}
                </span>
              </span>
            </button>

            <div v-if="!filteredTickets.length" class="tickets-empty">
              <i class="fa-regular fa-message"></i>
              <span>{{ t("tickets.noTickets", "Nenhum ticket encontrado.") }}</span>
            </div>
          </div>
        </section>
      </aside>

      <main v-if="!chatClosed" class="ticket-conversation ticket-stage" :class="{ 'has-admin-strip': adminMode && selectedTicket }">
        <template v-if="selectedTicket">
          <div class="ticket-conversation-head">
            <div>
              <span class="ticket-stage-step"><i class="fa-regular fa-comments"></i></span>
              <small>{{ t("tickets.ticketNumber", "Ticket #{id}", { id: selectedTicket.id }) }}</small>
              <h2>{{ selectedTicket.title }}</h2>
              <p>
                {{ categoryLabel(selectedTicket.category) }} ·
                {{ t("tickets.updatedAt", "Atualizado") }} {{ formatTime(selectedTicket.updatedAt) }}
              </p>
            </div>
            <div class="ticket-conversation-actions">
              <span class="ticket-status big" :style="{ '--status-color': statusRow(selectedTicket.status).color }">
                {{ statusLabel(selectedTicket.status) }}
              </span>
              <button type="button" class="ticket-chat-close" :title="t('tickets.closeChat', 'Fechar conversa')" @click="closeChat">
                <i class="fa-solid fa-xmark"></i>
              </button>
            </div>
          </div>

          <div v-if="adminMode" class="ticket-admin-strip">
            <div>
              <small>{{ t("tickets.assignedTo", "Responsável") }}</small>
              <b>{{ selectedTicket.assignedName || t("tickets.unassigned", "Sem responsável") }}</b>
            </div>
            <button type="button" class="tickets-secondary compact" @click="claimTicket">
              <i class="fa-solid fa-user-check"></i>
              {{ t("tickets.claim", "Assumir") }}
            </button>
            <div class="ticket-status-actions inline">
              <button type="button" @click="setStatus('open')">{{ t("tickets.reopen", "Reabrir") }}</button>
              <button type="button" @click="setStatus('waiting')">{{ t("tickets.setWaitingShort", "Aguardar") }}</button>
              <button type="button" @click="setStatus('answered')">{{ t("tickets.setAnsweredShort", "Respondido") }}</button>
              <button type="button" class="danger" @click="setStatus('closed')">{{ t("tickets.close", "Fechar") }}</button>
              <button type="button" class="transcript" :disabled="transcripting" @click="transcriptTicket">
                {{ transcripting ? t("common.processing", "Processando...") : t("tickets.transcript", "Arquivar") }}
              </button>
            </div>
          </div>

          <div ref="messagesEl" class="ticket-messages">
            <article v-for="message in messages" :key="message.id" class="ticket-message" :class="{ staff: message.staff }">
              <header>
                <b>{{ message.playerName || (message.staff ? t("tickets.staff", "Equipe") : t("tickets.player", "Jogador")) }}</b>
                <span>{{ message.staff ? t("tickets.staff", "Equipe") : t("tickets.player", "Jogador") }} · {{ formatTime(message.createdAt) }}</span>
              </header>
              <p>{{ message.message }}</p>
            </article>
          </div>

          <footer class="ticket-reply">
            <textarea v-model="replyMessage" :placeholder="t('tickets.replyPlaceholder', 'Escreva uma resposta...')" />
            <button type="button" class="tickets-primary" :disabled="replying || selectedTicket.status === 'closed'" @click="sendReply">
              <i class="fa-solid fa-paper-plane"></i>
              {{ replying ? t("common.processing", "Processando...") : t("tickets.sendReply", "Responder") }}
            </button>
          </footer>
        </template>

        <div v-else class="tickets-empty large">
          <i class="fa-regular fa-comments"></i>
          <b>{{ adminMode ? t("tickets.noSelection", "Selecione um ticket para ver a conversa.") : t("tickets.createTitle", "Abrir atendimento") }}</b>
          <span>{{ adminMode ? t("tickets.staffSubtitle", "Selecione um atendimento para acompanhar a conversa.") : t("tickets.subtitle", "Crie um ticket ou selecione um atendimento existente.") }}</span>
        </div>
      </main>
    </div>
  </section>
</template>
