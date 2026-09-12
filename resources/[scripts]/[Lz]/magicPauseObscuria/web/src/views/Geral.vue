<script setup>
import characterMalePNG from "../public/characters/character-male.png";
import characterFemalePNG from "../public/characters/character-female.png";
import { computed, onMounted, ref } from "vue";
import runeIcon from "../assets/imgs/runa-icon.png";

const playerInfo = ref({
  name: "",
  passport: "",
  gender: "",
  maritalStatus: "",
  phone: "",
  wallet: 0,
  bank: 0,
  vipMoney: 0,
  job: "",
  jobLevel: null,
  org: "",
  backpackCurrent: 0,
  backpackMax: 0,
  inventoryItems: 0,
  houses: 0,
  vehicles: 0,
  vipTier: "",
  vipExpiresAt: null,
  playTime: "0h",
  wantedLevel: 0,
  classLabel: "",
  classAffinity: "",
  classWeakness: ""
});
const previewMode = new URLSearchParams(window.location.search).get("preview") === "1";

const money = (value) => Number(value || 0).toLocaleString("pt-BR");
const characterImage = computed(() => {
  const gender = String(playerInfo.value.gender || "").trim().toLowerCase();
  return ["f", "female", "feminino", "1"].includes(gender) ? characterFemalePNG : characterMalePNG;
});
const weightPercent = computed(() => {
  const max = Number(playerInfo.value.backpackMax || 0);
  if (max <= 0) return 0;
  return Math.min(100, Math.max(0, Math.floor((Number(playerInfo.value.backpackCurrent || 0) / max) * 100)));
});

const identityRows = computed(() => [
  { label: "Nome", value: playerInfo.value.name || "-" },
  { label: "Gênero", value: playerInfo.value.gender || "Indefinido" },
  { label: "Estado civil", value: playerInfo.value.maritalStatus || "Indefinido" },
  { label: "Telefone", value: playerInfo.value.phone || "N/A" }
]);

const statusRows = computed(() => [
  { label: "Emprego", value: playerInfo.value.job || "Desempregado" },
  { label: "Patente", value: playerInfo.value.jobLevel || "Sem patente" },
  { label: "Organização", value: playerInfo.value.org || "Nenhuma" },
  { label: "Procurado", value: playerInfo.value.wantedLevel > 0 ? `${playerInfo.value.wantedLevel} estrelas` : "Não" }
]);

const propertyRows = computed(() => [
  { label: "Casas", value: playerInfo.value.houses || 0 },
  { label: "Itens", value: playerInfo.value.inventoryItems || 0 },
  { label: "Veículos", value: playerInfo.value.vehicles || 0 },
  { label: "Tempo de jogo", value: playerInfo.value.playTime || "0h" }
]);

const vipDisplay = computed(() => {
  const tier = playerInfo.value.vipTier || "Nenhum";
  const expiresAt = Number(playerInfo.value.vipExpiresAt || 0);
  if (tier === "Nenhum" || !expiresAt) return tier;
  const date = new Date(expiresAt * 1000).toLocaleDateString("pt-BR");
  return `${tier} · até ${date}`;
});

const classRows = computed(() => [
  { label: "Classe", value: playerInfo.value.classLabel || "Sem classe" },
  { label: "Afinidade", value: playerInfo.value.classAffinity || "Indefinido" },
  { label: "Fraqueza", value: playerInfo.value.classWeakness || "Indefinido" },
  { label: "VIP atual", value: vipDisplay.value, vip: playerInfo.value.vipTier && playerInfo.value.vipTier !== "Nenhum" }
]);

async function fetchNui(eventName, data = {}) {
  const resource = (window.GetParentResourceName && window.GetParentResourceName()) || "MagicPause";
  const res = await fetch(`https://${resource}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data)
  });
  return res.json().catch(() => ({}));
}

onMounted(async () => {
  if (previewMode) {
    playerInfo.value = {
      ...playerInfo.value,
      name: "Morgana Vale",
      passport: "1842",
      gender: "Feminino",
      maritalStatus: "Solteira",
      phone: "859-042",
      wallet: 4270,
      bank: 186540,
      vipMoney: 2450,
      job: "Investigadora",
      jobLevel: "Especialista",
      org: "Sem vínculo",
      backpackCurrent: 34,
      backpackMax: 75,
      inventoryItems: 28,
      houses: 1,
      vehicles: 4,
      vipTier: "VIP ECLIPSE",
      vipExpiresAt: Math.floor(Date.now() / 1000) + 2592000,
      playTime: "126h",
      wantedLevel: 0,
      classLabel: "Bruxa",
      classAffinity: "Magia",
      classWeakness: "Fogo"
    };
    return;
  }
  const info = await fetchNui("getPlayerInfo");
  if (info && typeof info === "object") playerInfo.value = { ...playerInfo.value, ...info };
});
</script>

<template>
  <section class="general-screen">
    <header class="general-hero">
      <div class="general-hero-copy">
        <small>Visão geral do personagem</small>
        <h1>{{ playerInfo.name || "Cidadão" }}</h1>
        <div class="general-hero-meta">
          <span><i class="fa-solid fa-briefcase"></i>{{ playerInfo.job || "Desempregado" }}</span>
          <span><i class="fa-solid fa-people-group"></i>{{ playerInfo.org || "Nenhuma organização" }}</span>
        </div>
      </div>

      <div class="general-hero-id">
        <span>Passaporte</span>
        <b>#{{ playerInfo.passport || "-" }}</b>
      </div>
    </header>

    <div class="general-layout">
      <aside class="general-person">
        <div class="general-person-stage">
          <img :src="characterImage" alt="Silhueta do personagem" />
        </div>

        <div class="general-person-footer">
          <div>
            <small>VIP</small>
            <strong>{{ playerInfo.vipTier || "Sem VIP" }}</strong>
          </div>
          <div>
            <small>Classe</small>
            <strong>{{ playerInfo.classLabel || "Nenhuma" }}</strong>
          </div>
          <div>
            <small>Tempo</small>
            <strong>{{ playerInfo.playTime || "0h" }}</strong>
          </div>
        </div>
      </aside>

      <main class="general-dashboard">
        <section class="general-money-grid">
          <article class="money-card wallet">
            <span><i class="fa-solid fa-wallet"></i> Carteira</span>
            <b>$ {{ money(playerInfo.wallet) }}</b>
          </article>
          <article class="money-card bank">
            <span><i class="fa-solid fa-building-columns"></i> Banco</span>
            <b>$ {{ money(playerInfo.bank) }}</b>
          </article>
          <article class="money-card runes">
            <span><img class="rune-icon" :src="runeIcon" alt="" /> Runas</span>
            <b>{{ money(playerInfo.vipMoney) }}</b>
          </article>
        </section>

        <section class="general-focus-grid">
          <article class="focus-card inventory-focus">
            <div class="focus-title">
              <span><i class="fa-solid fa-box"></i> Mochila</span>
              <b>{{ weightPercent }}%</b>
            </div>
            <div class="weight-line">
              <span :style="{ width: weightPercent + '%' }"></span>
            </div>
            <p>{{ playerInfo.backpackCurrent || 0 }} / {{ playerInfo.backpackMax || 0 }} kg utilizados</p>
          </article>

          <article class="focus-card class-focus">
            <span><i class="fa-solid fa-wand-magic-sparkles"></i> Classe</span>
            <h2>{{ playerInfo.classLabel || "Sem classe" }}</h2>
            <div class="class-traits">
              <span><i class="fa-solid fa-bolt"></i>{{ playerInfo.classAffinity || "Indefinido" }}</span>
              <span><i class="fa-solid fa-shield-halved"></i>{{ playerInfo.classWeakness || "Indefinido" }}</span>
            </div>
          </article>
        </section>

        <section class="general-info-grid">
          <article class="info-card tone-identity">
            <h3><i class="fa-solid fa-id-card"></i> Identidade</h3>
            <dl>
              <div v-for="row in identityRows" :key="row.label">
                <dt>{{ row.label }}</dt>
                <dd>{{ row.value }}</dd>
              </div>
            </dl>
          </article>

          <article class="info-card tone-bonds">
            <h3><i class="fa-solid fa-briefcase"></i> Vínculos</h3>
            <dl>
              <div v-for="row in statusRows" :key="row.label">
                <dt>{{ row.label }}</dt>
                <dd>{{ row.value }}</dd>
              </div>
            </dl>
          </article>

          <article class="info-card tone-property">
            <h3><i class="fa-solid fa-warehouse"></i> Patrimônio</h3>
            <dl>
              <div v-for="row in propertyRows" :key="row.label">
                <dt>{{ row.label }}</dt>
                <dd>{{ row.value }}</dd>
              </div>
            </dl>
          </article>

          <article class="info-card tone-profile">
            <h3><i class="fa-solid fa-star"></i> Perfil</h3>
            <dl>
              <div v-for="row in classRows" :key="row.label">
                <dt>{{ row.label }}</dt>
                <dd :class="{ 'vip-value': row.vip }"><i v-if="row.vip" class="fa-solid fa-crown"></i>{{ row.value }}</dd>
              </div>
            </dl>
          </article>
        </section>
      </main>
    </div>
  </section>
</template>

<style src="../styles/geral.css"></style>
