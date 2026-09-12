<script setup>
import { computed, ref } from "vue";

const props = defineProps({
  payload: { type: Object, default: null }
});

const activeTopic = ref("donations");
const topics = [
  {
    id: "donations",
    label: "Doações",
    title: "Maiores apoiadores",
    description: "Runas adquiridas pelos maiores apoiadores da cidade.",
    icon: "fa-solid fa-hand-holding-heart"
  },
  {
    id: "vehicles",
    label: "Veículos",
    title: "Maiores coleções",
    description: "Quantidade de veículos registrados por personagem.",
    icon: "fa-solid fa-car-side"
  },
  {
    id: "money",
    label: "Dinheiro",
    title: "Maiores patrimônios financeiros",
    description: "Soma do dinheiro em carteira e no banco.",
    icon: "fa-solid fa-sack-dollar"
  }
];

const activeDefinition = computed(() => topics.find((topic) => topic.id === activeTopic.value) || topics[0]);
const entries = computed(() => props.payload?.rankings?.[activeTopic.value] || []);
const currentPlacement = computed(() => props.payload?.current?.[activeTopic.value] || null);
const hallEntries = computed(() => [2, 1, 3]
  .map((position) => entries.value.find((entry) => Number(entry.position) === position))
  .filter(Boolean));
const remainingEntries = computed(() => entries.value.filter((entry) => Number(entry.position) > 3));
const isLoading = computed(() => !props.payload);

function initials(name) {
  return String(name || "OB")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

function number(value) {
  return Math.floor(Number(value) || 0).toLocaleString("pt-BR");
}

function valueLabel(entry) {
  if (activeTopic.value === "donations") return `${number(entry.value)} Runas`;
  if (activeTopic.value === "vehicles") return `${number(entry.value)} ${Number(entry.value) === 1 ? "veículo" : "veículos"}`;
  return `$ ${number(entry.value)}`;
}

function detailLabel(entry) {
  if (activeTopic.value === "donations") return "";
  if (activeTopic.value === "vehicles") return "Veículos registrados na cidade";
  return `Carteira $ ${number(entry.cash)}  ·  Banco $ ${number(entry.bank)}`;
}
</script>

<template>
  <section class="rankings-screen">
    <header class="screen-heading rankings-heading">
      <div>
        <small>Destaques de Obscuria</small>
        <h1>Ranking da cidade</h1>
        <p>Os personagens que mais se destacam em apoio, veículos e patrimônio financeiro.</p>
      </div>
      <div class="ranking-limit">
        <span>Classificação</span>
        <strong>TOP {{ payload?.limit || 10 }}</strong>
      </div>
    </header>

    <nav class="ranking-tabs" aria-label="Categorias do ranking">
      <button
        v-for="topic in topics"
        :key="topic.id"
        type="button"
        :class="{ active: activeTopic === topic.id }"
        @click="activeTopic = topic.id"
      >
        <i :class="topic.icon"></i>
        <span>{{ topic.label }}</span>
      </button>
    </nav>

    <section class="ranking-board">
      <header class="ranking-board-heading">
        <div class="ranking-topic-icon"><i :class="activeDefinition.icon"></i></div>
        <div class="ranking-board-copy">
          <small>{{ activeDefinition.label }}</small>
          <h2>{{ activeDefinition.title }}</h2>
          <p>{{ activeDefinition.description }}</p>
        </div>
        <div class="ranking-self" :class="{ outside: currentPlacement && !currentPlacement.inTop }">
          <small>Sua posição</small>
          <strong v-if="currentPlacement">#{{ currentPlacement.position }}</strong>
          <strong v-else>--</strong>
          <span v-if="currentPlacement">
            {{ currentPlacement.inTop ? `No Top ${payload?.limit || 10}` : `Fora do Top ${payload?.limit || 10}` }}
          </span>
          <span v-else>Não classificado</span>
        </div>
      </header>

      <div v-if="isLoading" class="ranking-empty">
        <i class="fa-solid fa-spinner fa-spin"></i>
        <strong>Carregando classificação</strong>
      </div>

      <div v-else-if="!entries.length" class="ranking-empty">
        <i class="fa-solid fa-ranking-star"></i>
        <strong>Nenhum resultado registrado</strong>
        <span>O ranking será preenchido conforme a cidade avançar.</span>
      </div>

      <div v-else class="ranking-content">
        <section class="ranking-hall" aria-label="Hall dos três primeiros colocados">
          <article
            v-for="entry in hallEntries"
            :key="`hall-${activeTopic}-${entry.passport}`"
            class="hall-entry"
            :class="[`position-${entry.position}`, { current: entry.isCurrent }]"
          >
            <div class="hall-avatar">{{ initials(entry.name) }}</div>
            <span class="hall-rank">
              <i :class="entry.position === 1 ? 'fa-solid fa-crown' : 'fa-solid fa-medal'"></i>
              {{ entry.position }}º lugar
            </span>
            <div class="hall-name">
              <strong>{{ entry.name }}</strong>
              <span v-if="entry.isCurrent">Você</span>
            </div>
            <small v-if="detailLabel(entry)">{{ detailLabel(entry) }}</small>
            <b>{{ valueLabel(entry) }}</b>
          </article>
        </section>

        <section v-if="remainingEntries.length" class="ranking-runners">
          <header>
            <strong>Demais posições</strong>
            <span>{{ remainingEntries.length }} classificados</span>
          </header>
          <ol class="ranking-list">
            <li
              v-for="entry in remainingEntries"
              :key="`${activeTopic}-${entry.passport}`"
              :class="{ current: entry.isCurrent }"
            >
              <div class="ranking-position">{{ entry.position }}</div>
              <div class="ranking-avatar">{{ initials(entry.name) }}</div>
              <div class="ranking-player">
                <div>
                  <strong>{{ entry.name }}</strong>
                  <span v-if="entry.isCurrent">Você</span>
                </div>
                <small v-if="detailLabel(entry)">{{ detailLabel(entry) }}</small>
              </div>
              <b class="ranking-value">{{ valueLabel(entry) }}</b>
            </li>
          </ol>
        </section>
      </div>
    </section>
  </section>
</template>

<style scoped>
.rankings-screen {
  height: 100%;
  min-height: 0;
  display: grid;
  grid-template-rows: auto auto minmax(0, 1fr);
  gap: 10px;
  font-family: var(--ob-display);
  -webkit-font-smoothing: auto;
  text-rendering: auto;
}

.rankings-heading {
  min-height: 88px;
}

.ranking-limit {
  min-width: 124px;
  padding: 10px 12px;
  border: 1px solid var(--ob-line);
  border-radius: 6px;
  background: var(--ob-surface-deep);
  text-align: right;
}

.ranking-limit span {
  display: block;
  color: var(--ob-text-muted);
  font-size: 10px;
  font-weight: 650;
  text-transform: uppercase;
}

.ranking-limit strong {
  display: block;
  margin-top: 3px;
  color: var(--ob-text-strong);
  font-size: 19px;
}

.ranking-tabs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
  padding: 6px;
  border: 1px solid var(--ob-line);
  border-radius: 6px;
  background: var(--ob-panel);
}

.ranking-tabs button {
  min-width: 0;
  height: 39px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: 1px solid transparent;
  border-radius: 5px;
  background: transparent;
  color: var(--ob-text-muted);
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  transition: border-color .16s ease, background .16s ease, color .16s ease;
}

.ranking-tabs button:hover {
  border-color: var(--ob-line);
  background: var(--ob-surface);
  color: var(--ob-text-strong);
}

.ranking-tabs button.active {
  border-color: var(--ob-line-strong);
  background: var(--ob-surface-active);
  color: var(--ob-text-strong);
}

.ranking-tabs i {
  color: var(--ob-accent);
  font-size: 14px;
}

.ranking-board {
  min-height: 0;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
  overflow: hidden;
  border: 1px solid var(--ob-line);
  border-radius: 6px;
  background: var(--ob-panel);
}

.ranking-board-heading {
  min-height: 72px;
  padding: 10px 14px;
  display: flex;
  align-items: center;
  gap: 11px;
  border-bottom: 1px solid var(--ob-line);
  background: var(--ob-surface);
}

.ranking-topic-icon {
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  display: grid;
  place-items: center;
  border: 1px solid var(--ob-line-strong);
  border-radius: 6px;
  background: var(--ob-surface-active);
  color: var(--ob-accent-soft);
  font-size: 16px;
}

.ranking-board-heading small {
  color: var(--ob-accent);
  font-size: 10px;
  font-weight: 750;
  text-transform: uppercase;
}

.ranking-board-heading h2 {
  margin: 1px 0 2px;
  color: var(--ob-text-strong);
  font-size: 17px;
  font-weight: 650;
}

.ranking-board-heading p {
  margin: 0;
  color: var(--ob-text-muted);
  font-size: 11.5px;
}

.ranking-board-copy {
  min-width: 0;
}

.ranking-self {
  min-width: 116px;
  margin-left: auto;
  padding: 7px 10px;
  display: grid;
  grid-template-columns: auto auto;
  align-items: baseline;
  column-gap: 8px;
  border-left: 1px solid var(--ob-line);
  text-align: right;
}

.ranking-self small {
  grid-column: 1 / -1;
  color: var(--ob-text-muted);
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
}

.ranking-self strong {
  color: var(--ob-accent-soft);
  font-size: 18px;
  font-weight: 750;
}

.ranking-self span {
  color: var(--ob-text-muted);
  font-size: 9.5px;
  font-weight: 650;
  white-space: nowrap;
}

.ranking-self.outside strong {
  color: var(--ob-warning);
}

.ranking-content {
  min-height: 0;
  padding: 10px;
  display: grid;
  grid-template-rows: auto auto;
  align-content: start;
  gap: 9px;
  overflow-y: auto;
}

.ranking-hall {
  min-height: 146px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-items: end;
  gap: 8px;
}

.hall-entry {
  position: relative;
  min-width: 0;
  min-height: 130px;
  padding: 11px;
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr);
  grid-template-areas:
    "avatar rank"
    "avatar name"
    "avatar detail"
    "value value";
  column-gap: 10px;
  align-content: center;
  border: 1px solid var(--ob-line);
  border-top: 2px solid var(--hall-color, var(--ob-line-strong));
  border-radius: 6px;
  background: #19151e;
}

.hall-entry.position-1 {
  min-height: 144px;
  --hall-color: #dfbe72;
  background: rgba(223, 190, 114, .075);
}

.hall-entry.position-2 {
  --hall-color: #bcc4d2;
  background: rgba(188, 196, 210, .045);
}

.hall-entry.position-3 {
  --hall-color: #bd8268;
  background: rgba(189, 130, 104, .05);
}

.hall-entry.current {
  box-shadow: inset 2px 0 0 var(--ob-accent);
}

.hall-avatar {
  grid-area: avatar;
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border: 1px solid var(--hall-color, var(--ob-line-strong));
  border-radius: 5px;
  background: rgba(255, 255, 255, .045);
  color: var(--ob-text-strong);
  font-size: 12px;
  font-weight: 800;
}

.hall-rank {
  grid-area: rank;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--hall-color, var(--ob-accent));
  font-size: 10px;
  font-weight: 750;
  text-transform: uppercase;
}

.hall-name {
  grid-area: name;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 6px;
}

.hall-name strong {
  min-width: 0;
  overflow: hidden;
  color: var(--ob-text-strong);
  font-size: 13px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hall-name span,
.ranking-player span {
  flex: 0 0 auto;
  padding: 2px 5px;
  border: 1px solid var(--ob-line-strong);
  border-radius: 3px;
  color: var(--ob-accent-soft);
  font-size: 8px;
  font-weight: 800;
  text-transform: uppercase;
}

.hall-entry > small {
  grid-area: detail;
  min-width: 0;
  overflow: hidden;
  color: var(--ob-text-muted);
  font-size: 10.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hall-entry > b {
  grid-area: value;
  margin-top: 10px;
  padding-top: 9px;
  border-top: 1px solid rgba(255, 255, 255, .075);
  color: var(--ob-text-strong);
  font-size: 15px;
  font-weight: 750;
  text-align: right;
}

.ranking-runners {
  min-width: 0;
  overflow: hidden;
  border: 1px solid var(--ob-line);
  border-radius: 6px;
  background: rgba(255, 255, 255, .018);
}

.ranking-runners > header {
  min-height: 34px;
  padding: 0 11px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  border-bottom: 1px solid var(--ob-line);
}

.ranking-runners > header strong {
  color: var(--ob-text-strong);
  font-size: 11px;
}

.ranking-runners > header span {
  color: var(--ob-text-dim);
  font-size: 10px;
}

.ranking-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.ranking-list li {
  min-height: 47px;
  padding: 6px 10px;
  display: grid;
  grid-template-columns: 30px 34px minmax(0, 1fr) auto;
  align-items: center;
  gap: 9px;
  border-bottom: 1px solid rgba(255, 255, 255, .055);
}

.ranking-list li:last-child {
  border-bottom: 0;
}

.ranking-list li.current {
  background: rgba(203, 158, 214, .075);
  box-shadow: inset 2px 0 0 var(--ob-accent);
}

.ranking-position {
  width: 27px;
  height: 27px;
  display: grid;
  place-items: center;
  border: 1px solid var(--ob-line);
  border-radius: 4px;
  color: var(--ob-text-muted);
  font-size: 11px;
  font-weight: 800;
}

.ranking-avatar {
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  border: 1px solid var(--ob-line);
  border-radius: 5px;
  background: var(--ob-surface);
  color: var(--ob-accent-soft);
  font-size: 10px;
  font-weight: 800;
}

.ranking-player {
  min-width: 0;
}

.ranking-player > div {
  display: flex;
  align-items: center;
  gap: 7px;
}

.ranking-player strong {
  overflow: hidden;
  color: var(--ob-text-strong);
  font-size: 12px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ranking-player small {
  display: block;
  margin-top: 2px;
  overflow: hidden;
  color: var(--ob-text-muted);
  font-size: 10.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ranking-value {
  padding-left: 12px;
  color: var(--ob-text-strong);
  font-size: 13px;
  font-weight: 750;
  text-align: right;
  white-space: nowrap;
}

.ranking-empty {
  min-height: 190px;
  display: grid;
  place-content: center;
  justify-items: center;
  gap: 8px;
  color: var(--ob-text-muted);
  text-align: center;
}

.ranking-empty i {
  color: var(--ob-accent);
  font-size: 22px;
}

.ranking-empty strong {
  color: var(--ob-text-strong);
  font-size: 13px;
}

.ranking-empty span {
  color: var(--ob-text-dim);
  font-size: 11px;
}

@media (max-width: 1120px) {
  .ranking-board-heading p {
    display: none;
  }

  .ranking-hall {
    min-height: 132px;
  }

  .hall-entry,
  .hall-entry.position-1 {
    min-height: 124px;
  }

  .hall-entry {
    grid-template-columns: 36px minmax(0, 1fr);
    column-gap: 8px;
  }

  .hall-avatar {
    width: 36px;
    height: 36px;
  }
}
</style>
