<script setup>
import { ref, onMounted } from "vue";
import backCard from "../assets/imgs/back.png";
import frontCard from "../assets/imgs/front.png";

const REWARD_BASE_PATH = "../imgs/rewards/";

function getRewardImageUrl(key) {
  if (!key) return "";
  return `${REWARD_BASE_PATH}${key}.png`;
}

const cards = ref([
  { id: 1, revealed: false, rewardText: "???", rewardAmount: "", rewardName: "", rewardImage: "" },
  { id: 2, revealed: false, rewardText: "???", rewardAmount: "", rewardName: "", rewardImage: "" },
  { id: 3, revealed: false, rewardText: "???", rewardAmount: "", rewardName: "", rewardImage: "" },
]);

const loading = ref(false);
const resultMessage = ref("");
const hasPlayedToday = ref(false);

function getResourceName() {
  if (typeof window !== "undefined" && window.GetParentResourceName) {
    return window.GetParentResourceName();
  }
  return "magicPause";
}

async function postNui(event, data = {}) {
  const resource = getResourceName();
  const res = await fetch(`https://${resource}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  });
  return await res.json();
}

function getShortRewardName(reward) {
  if (!reward) return "Prêmio";

  switch (reward.type) {
    case "money":
      return "Dólares";
    case "bank":
      return "Banco";
    case "item":
      return reward.item || "Item";
    case "vehicle":
      return (reward.vehicle || "Veículo").toUpperCase();
    case "premium":
      return reward.permission || "VIP";
    case "none":
      return "Tente amanhã";
    default:
      return "Prêmio";
  }
}

function applyRewardToCard(card, reward, fallbackLabel) {
  if (!reward) {
    card.rewardText = fallbackLabel || "Sem prêmio desta vez...";
    card.rewardAmount = "";
    card.rewardName = "Tente amanhã";
    card.rewardImage = "";
    return;
  }

  card.rewardText = reward.label || fallbackLabel || "Sem prêmio desta vez...";

  if (reward.type === "money") {
    card.rewardAmount = reward.amount ? `$${reward.amount}` : "$0";
  } else if (reward.type === "item") {
    card.rewardAmount = reward.amount ? `x${reward.amount}` : "x1";
  } else {
    card.rewardAmount = "";
  }

  card.rewardName = getShortRewardName(reward);
  card.rewardImage = reward?.image ? getRewardImageUrl(reward.image) : "";
}

async function loadStatus() {
  try {
    const res = await postNui("getRaspadinhaStatus");
    if (!res) return;

    if (res.playedToday && res.chosenCard) {
      hasPlayedToday.value = true;

      const card = cards.value.find((c) => c.id === res.chosenCard);
      if (card) {
        card.revealed = true;
        applyRewardToCard(card, res.reward, res.rewardLabel || "Resultado de hoje");
      }

      resultMessage.value = res.message || "Você já usou a raspadinha hoje.";
    }
  } catch (e) {

  }
}

async function revealCard(card) {
  if (hasPlayedToday.value) return;
  if (cards.value.some((c) => c.revealed) || loading.value) return;

  card.revealed = true;
  card.rewardText = "Consultando...";
  card.rewardAmount = "";
  card.rewardName = "";
  card.rewardImage = "";
  loading.value = true;
  resultMessage.value = "";

  try {
    const res = await postNui("playRaspadinha", { card: card.id });

    if (!res) {
      card.rewardText = "Erro";
      card.rewardName = "Erro";
      resultMessage.value = "Falha na comunicação.";
      return;
    }

    if (res.alreadyPlayed) {
      hasPlayedToday.value = true;
      applyRewardToCard(card, res.reward, res.rewardLabel || res.message);
      resultMessage.value = res.message;
      return;
    }

    resultMessage.value = res.message || "Resultado da raspadinha:";

    if (res.ok === false) {
      card.rewardText = res.message || "Sem prêmio";
      card.rewardName = "Nenhum prêmio";
      return;
    }

    applyRewardToCard(card, res.reward, res.message);
    hasPlayedToday.value = true;
  } catch (e) {
    console.error(e);
    resultMessage.value = "Erro ao se comunicar com a sorte.";
    card.rewardText = "Erro";
    card.rewardName = "Erro";
  } finally {
    loading.value = false;
  }
}

onMounted(() => loadStatus());
</script>

<template>
  <section class="rasp-screen">
    <header class="screen-heading rasp-heading">
      <div>
        <small>Ritual diário</small>
        <h1>Raspadinhas</h1>
        <p>Escolha uma das três cartas flutuantes e revele sua recompensa diária.</p>
      </div>

    </header>

    <div class="rasp-playfield">
      <div class="rasp-ambient"></div>
      <div class="rasp-particles" aria-hidden="true">
        <span v-for="particle in 18" :key="particle"></span>
      </div>
      <div class="rasp-table-glow"></div>

      <div v-if="resultMessage" class="rasp-result-title">
        <small>Resultado</small>
        <strong>{{ resultMessage }}</strong>
      </div>

      <div class="rasp-cards">
        <div
          v-for="card in cards"
          :key="card.id"
          class="rasp-card-wrapper"
        >
          <div
            class="rasp-card"
            :class="{ revealed: card.revealed }"
            @click="revealCard(card)"
          >
            <div
              class="rasp-card-face rasp-front"
              :style="{ backgroundImage: `url('${backCard}')` }"
            ></div>

            <div
              class="rasp-card-face rasp-back"
              :style="{ backgroundImage: `url('${frontCard}')` }"
            >
              <div class="reward-card">
                <div v-if="card.rewardImage" class="reward-image">
                  <img :src="card.rewardImage" alt="Prêmio" />
                </div>

                <div v-if="card.rewardAmount" class="reward-amount">
                  {{ card.rewardAmount }}
                </div>

                <div class="reward-name">
                  {{ card.rewardName || card.rewardText }}
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style src="../styles/raspadinha.css"></style>
