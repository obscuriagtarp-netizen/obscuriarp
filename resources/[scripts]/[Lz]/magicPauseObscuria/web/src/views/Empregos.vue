<script setup>
import { computed, onMounted, ref } from "vue";
import {
  ArrowLeft,
  BriefcaseBusiness,
  ChartNoAxesCombined,
  ChevronRight,
  CircleDollarSign,
  Crown,
  Grid2X2Check,
  Medal,
  Navigation,
  RefreshCw,
  Star,
  TimerReset,
  TrendingUp,
} from "lucide-vue-next";

const previewMode = new URLSearchParams(window.location.search).get("preview") === "1";
const jobs = ref([]);
const summary = ref({ totalJobs: 0, totalScore: 0, combinedLevels: 0, overallPosition: null });
const rankings = ref({ overall: { entries: [], rewards: [] }, services: {} });
const currentJobId = ref(null);
const selectedJobId = ref(null);
const panelMode = ref("details");
const loading = ref(false);

const jobVisuals = {
  lenhador: { image: "imgs/jobs/lenhador-profissao.png", accent: "#9ebf86" },
  minerador: { image: "imgs/jobs/minerador-profissao.png", accent: "#c2a36f" },
  leiteiro: { image: "imgs/jobs/leiteiro-profissao.png", accent: "#b2ced8" },
  taxi: { image: "imgs/jobs/taxi-profissao.png", accent: "#d0ad57" },
  onibus: { image: "imgs/jobs/onibus-profissao.png", accent: "#83a9ce" },
  mergulhador: { image: "imgs/jobs/mergulhador-profissao.png", accent: "#58aebd" },
  cacador: { image: "imgs/jobs/cacador-profissao.png", accent: "#bc8079" },
  pescador: { image: "imgs/jobs/pescador-profissao.png", accent: "#70ad98" },
};

function previewPayload() {
  const definitions = [
    ["taxi", "Taxista", "imgs/jobs/taxi.png", 6840, 10, 2, 18, 11.25],
    ["minerador", "Minerador", "", 4380, 9, 0, 16, 10],
    ["pescador", "Pescador", "", 2970, 7, 0, 12, 7.5],
    ["lenhador", "Lenhador", "", 2210, 6, 0, 10, 6.25],
    ["onibus", "Motorista de ônibus", "", 1860, 5, 0, 8, 5],
    ["mergulhador", "Mergulhador", "", 1240, 5, 0, 8, 5],
    ["cacador", "Caçador", "", 760, 3, 0, 4, 2.5],
    ["leiteiro", "Leiteiro", "", 390, 2, 0, 2, 1.25],
  ];
  const names = ["Morgana Vale", "Dante Moretti", "Helena Ward", "Arthur Bell", "Nina Raven", "Caio Ferraz"];
  const serviceRewards = [5000, 3000, 2000];
  const mapped = definitions.map(([id, label, image, score, level, _, income, execution], index) => {
    const rankingEntries = names.map((name, rankIndex) => ({
      position: rankIndex + 1,
      name,
      score: Math.max(120, score + 820 - rankIndex * 510 - index * 90),
      isPlayer: rankIndex === Math.min(index, 4),
      reward: serviceRewards[rankIndex] || 0,
    }));
    const isMaster = level >= 10;
    return {
      id,
      label,
      image,
      description: `Construa sua reputação como ${label.toLowerCase()}, melhore seus resultados e dispute posições entre os profissionais de Obscuria.`,
      score,
      xp: score,
      level,
      maxLevel: 10,
      percent: isMaster ? 54 : (score % 1000) / 10,
      xpToNext: isMaster ? 460 : 1000 - (score % 1000),
      isMaster,
      masteryTier: isMaster ? 2 : 0,
      benefits: { incomePercent: income, executionPercent: execution },
      ranking: {
        entries: rankingEntries,
        playerPosition: Math.min(index, 4) + 1,
        playerScore: score,
        rewards: serviceRewards,
      },
    };
  });

  return {
    jobs: mapped,
    currentJobId: "taxi",
    summary: { totalJobs: mapped.length, totalScore: 20650, combinedLevels: 47, overallPosition: 4 },
    rankings: {
      cycle: "2026-W34",
      rewardAccount: "bank",
      overall: {
        playerPosition: 4,
        playerScore: 20650,
        rewards: [15000, 10000, 7500],
        entries: names.map((name, index) => ({
          position: index + 1,
          name,
          score: 26400 - index * 1850,
          services: 8 - Math.min(index, 3),
          isPlayer: index === 3,
          reward: [15000, 10000, 7500][index] || 0,
        })),
      },
    },
  };
}

async function fetchNui(eventName, data = {}) {
  if (previewMode) return eventName === "getJobsProgress" ? previewPayload() : { ok: true };
  const resource = window.GetParentResourceName?.() || "magicPauseObscuria";
  const response = await fetch(`https://${resource}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  });
  return response.json();
}

async function load() {
  if (loading.value) return;
  loading.value = true;
  try {
    const data = await fetchNui("getJobsProgress");
    jobs.value = Array.isArray(data?.jobs) ? data.jobs : [];
    summary.value = data?.summary || {};
    rankings.value = data?.rankings || { overall: { entries: [] }, services: {} };
    currentJobId.value = data?.currentJobId ?? currentJobId.value;
    if (!jobs.value.some((job) => String(job.id) === String(selectedJobId.value))) {
      selectedJobId.value = currentJobId.value || jobs.value[0]?.id || null;
    }
  } catch {
    jobs.value = [];
  } finally {
    loading.value = false;
  }
}

async function mark(job) {
  if (!job?.id) return;
  const result = await fetchNui("jobsMark", { jobId: job.id }).catch(() => ({ ok: false }));
  if (result?.ok) currentJobId.value = job.id;
}

function selectJob(job, mode = "details") {
  selectedJobId.value = job.id;
  panelMode.value = mode;
}

const selectedJob = computed(() =>
  jobs.value.find((job) => String(job.id) === String(selectedJobId.value)) || jobs.value[0] || null
);
const bestJob = computed(() => jobs.value.reduce((best, job) =>
  !best || Number(job.score || 0) > Number(best.score || 0) ? job : best
, null));
const isActive = (job) => String(job?.id) === String(currentJobId.value);
const activeBoard = computed(() =>
  panelMode.value === "overall-ranking" ? rankings.value?.overall : selectedJob.value?.ranking
);
const rankingTitle = computed(() =>
  panelMode.value === "overall-ranking" ? "Ranking geral" : `Ranking de ${selectedJob.value?.label || "serviço"}`
);
const rankingSubtitle = computed(() =>
  panelMode.value === "overall-ranking"
    ? "Índice formado pela soma da pontuação conquistada em todos os serviços."
    : "Classificação permanente deste serviço, inclusive após o nível 10."
);

function number(value) {
  return Math.floor(Number(value) || 0).toLocaleString("pt-BR");
}

function money(value) {
  return `$ ${number(value)}`;
}

function percent(value) {
  const parsed = Number(value) || 0;
  return Number.isInteger(parsed) ? parsed : parsed.toFixed(2).replace(".", ",");
}

const jobAccent = (job) => jobVisuals[String(job?.id)]?.accent || "#a87bdc";
function jobImage(job) {
  const path = jobVisuals[String(job?.id)]?.image;
  if (!path) return "";
  if (previewMode) return `../${path}`;
  const resource = window.GetParentResourceName?.() || "magicPauseObscuria";
  return `nui://${resource}/web/${path}`;
}

function positionLabel(position) {
  return position ? `#${position}` : "Sem posição";
}

onMounted(load);
</script>

<template>
  <section class="jobs-career">
    <header class="screen-heading jobs-career__heading">
      <div>
        <small>Carreira profissional</small>
        <h1>Empregos</h1>
        <p>Progresso permanente, benefícios de experiência e competição entre os profissionais de Obscuria.</p>
      </div>
      <div class="jobs-heading-actions">
        <button type="button" class="jobs-icon-button" title="Atualizar" :disabled="loading" @click="load">
          <RefreshCw :size="16" :class="{ spinning: loading }" />
        </button>
        <button type="button" class="jobs-ranking-button" @click="panelMode = 'overall-ranking'">
          <ChartNoAxesCombined :size="17" :stroke-width="1.7" />
          <span><small>Competição da cidade</small><b>Ranking geral</b></span>
          <ChevronRight :size="15" />
        </button>
      </div>
    </header>

    <div class="jobs-summary">
      <article>
        <span class="jobs-summary__icon"><Grid2X2Check :size="17" :stroke-width="1.7" /></span>
        <div><small>Serviços disponíveis</small><strong>{{ summary.totalJobs ?? jobs.length }}</strong><span>carreiras configuradas</span></div>
      </article>
      <article>
        <span class="jobs-summary__icon"><TrendingUp :size="17" :stroke-width="1.7" /></span>
        <div><small>Índice profissional</small><strong>{{ number(summary.totalScore) }}</strong><span>pontos acumulados</span></div>
      </article>
      <article>
        <span class="jobs-summary__icon"><Crown :size="17" :stroke-width="1.7" /></span>
        <div><small>Posição geral</small><strong>{{ positionLabel(summary.overallPosition) }}</strong><span>entre todos os jogadores</span></div>
      </article>
      <article>
        <span class="jobs-summary__icon"><Star :size="17" :stroke-width="1.7" /></span>
        <div><small>Especialidade</small><strong>{{ bestJob?.label || "Nenhuma" }}</strong><span>{{ number(bestJob?.score) }} pontos</span></div>
      </article>
    </div>

    <div v-if="jobs.length" class="jobs-workspace">
      <aside class="jobs-catalogue">
        <header>
          <div><small>Seus serviços</small><h2>Carreiras</h2></div>
          <span>{{ jobs.length }}</span>
        </header>
        <div class="jobs-catalogue__list">
          <article
            v-for="job in jobs"
            :key="job.id"
            class="job-career-card"
            :class="{ selected: selectedJob?.id === job.id, active: isActive(job) }"
            :style="{ '--job-accent': jobAccent(job) }"
            @click="selectJob(job)"
          >
            <div class="job-career-card__image">
              <img v-if="jobImage(job)" :src="jobImage(job)" alt="" draggable="false" />
              <BriefcaseBusiness v-else :size="21" :stroke-width="1.7" />
            </div>
            <div class="job-career-card__body">
              <div class="job-career-card__title">
                <strong>{{ job.label }}</strong>
                <span v-if="job.isMaster">M{{ job.masteryTier }}</span>
                <span v-else>NV {{ job.level }}</span>
              </div>
              <div class="job-career-card__score">{{ number(job.score) }} pontos</div>
              <div class="job-career-card__progress"><i :style="{ width: `${job.percent || 0}%` }"></i></div>
            </div>
            <ChevronRight :size="15" />
          </article>
        </div>
      </aside>

      <main v-if="selectedJob && panelMode === 'details'" class="jobs-detail">
        <header class="jobs-detail__hero" :style="{ '--job-accent': jobAccent(selectedJob) }">
          <div class="jobs-detail__identity">
            <div class="jobs-detail__image">
              <img v-if="jobImage(selectedJob)" :src="jobImage(selectedJob)" alt="" draggable="false" />
              <BriefcaseBusiness v-else :size="30" :stroke-width="1.55" />
            </div>
            <div>
              <small>{{ selectedJob.isMaster ? `Maestria ${selectedJob.masteryTier}` : `Nível ${selectedJob.level} de ${selectedJob.maxLevel}` }}</small>
              <h2>{{ selectedJob.label }}</h2>
              <p>{{ selectedJob.description }}</p>
            </div>
          </div>
          <button type="button" class="jobs-map-button" @click="mark(selectedJob)">
            <Navigation :size="16" :stroke-width="1.7" />
            <span>{{ isActive(selectedJob) ? "Rota marcada" : "Marcar no mapa" }}</span>
          </button>
        </header>

        <div class="jobs-detail__scroll">
          <section class="jobs-benefits">
            <header><small>Benefícios atuais</small><h3>Experiência aplicada</h3></header>
            <div class="jobs-benefits__grid">
              <article>
                <span><CircleDollarSign :size="18" :stroke-width="1.7" /></span>
                <div><small>Ganho por serviço</small><strong>+{{ percent(selectedJob.benefits?.incomePercent) }}%</strong><p>Multiplicador disponível para o pagamento deste emprego.</p></div>
              </article>
              <article>
                <span><TimerReset :size="18" :stroke-width="1.7" /></span>
                <div><small>Eficiência de execução</small><strong>+{{ percent(selectedJob.benefits?.executionPercent) }}%</strong><p>Redução disponível para o tempo das etapas do serviço.</p></div>
              </article>
            </div>
          </section>

          <section class="jobs-progression">
            <header>
              <div><small>Progressão permanente</small><h3>{{ selectedJob.isMaster ? `Ciclo de Maestria ${selectedJob.masteryTier}` : `Nível ${selectedJob.level}` }}</h3></div>
              <strong>{{ number(selectedJob.score) }} <small>pontos</small></strong>
            </header>
            <div class="jobs-progression__bar"><i :style="{ width: `${selectedJob.percent || 0}%` }"></i></div>
            <footer>
              <span>{{ selectedJob.percent || 0 }}% do ciclo atual</span>
              <span>Faltam {{ number(selectedJob.xpToNext) }} pontos</span>
            </footer>
            <p v-if="selectedJob.isMaster">O nível máximo foi alcançado, mas sua pontuação e os ciclos de Maestria continuam sem limite.</p>
          </section>

          <section class="jobs-ranking-preview">
            <header>
              <div><small>Competição do serviço</small><h3>Sua posição: {{ positionLabel(selectedJob.ranking?.playerPosition) }}</h3></div>
              <button type="button" @click="panelMode = 'service-ranking'">Ver ranking <ChevronRight :size="15" /></button>
            </header>
            <div class="jobs-podium-mini">
              <article v-for="entry in (selectedJob.ranking?.entries || []).slice(0, 3)" :key="entry.position">
                <Medal :size="16" />
                <span><small>#{{ entry.position }}</small><strong>{{ entry.name }}</strong></span>
                <b>{{ number(entry.score) }}</b>
              </article>
            </div>
          </section>
        </div>
      </main>

      <main v-else class="jobs-ranking-panel">
        <header>
          <button type="button" class="jobs-back-button" @click="panelMode = 'details'"><ArrowLeft :size="16" /></button>
          <div><small>{{ rankings.cycle || "Classificação atual" }}</small><h2>{{ rankingTitle }}</h2><p>{{ rankingSubtitle }}</p></div>
          <div class="jobs-player-rank"><small>Sua colocação</small><strong>{{ positionLabel(activeBoard?.playerPosition) }}</strong><span>{{ number(activeBoard?.playerScore) }} pontos</span></div>
        </header>

        <div class="jobs-ranking-panel__scroll">
          <section class="jobs-prizes">
            <article v-for="(reward, index) in (activeBoard?.rewards || []).slice(0, 3)" :key="index">
              <span :class="`place-${index + 1}`"><Medal :size="18" :stroke-width="1.7" /></span>
              <div><small>{{ index + 1 }}º lugar</small><strong>{{ money(reward) }}</strong></div>
            </article>
          </section>

          <section class="jobs-ranking-list">
            <header><span>Posição</span><span>Profissional</span><span>Pontuação</span><span>Prêmio</span></header>
            <article v-for="entry in activeBoard?.entries || []" :key="`${entry.position}-${entry.name}`" :class="{ player: entry.isPlayer }">
              <span class="jobs-rank-position">#{{ entry.position }}</span>
              <span class="jobs-rank-name"><i>{{ entry.name.slice(0, 1).toUpperCase() }}</i><b>{{ entry.name }}</b><small v-if="entry.services">{{ entry.services }} serviços</small></span>
              <strong>{{ number(entry.score) }}</strong>
              <span class="jobs-rank-reward">{{ entry.reward ? money(entry.reward) : "—" }}</span>
            </article>
            <div v-if="!(activeBoard?.entries || []).length" class="jobs-ranking-empty">Ainda não há pontuação suficiente para formar este ranking.</div>
          </section>
        </div>
      </main>
    </div>

    <div v-else class="empty-state jobs-empty">
      <BriefcaseBusiness :size="26" />
      <h2>Nenhum serviço configurado</h2>
      <p>As carreiras serão exibidas quando estiverem disponíveis.</p>
    </div>
  </section>
</template>

<style src="../styles/empregos.css"></style>
