<template>
  <section class="hub">
    <div class="hub-inner">

      <button
        class="hub-fab"
        @click="openGtaSettings()"
      >
        <i class="fa-solid fa-gear"></i>
      </button>

      <div class="hub-grid">

        <button
          class="hub-card hub-card--geral"
          @click="openSection({ id: 'geral', label: 'Geral' })"
        >
          <div class="hub-card-center">
            <span class="hub-title">GERAL</span>
            <span class="hub-sub">Acesso geral</span>
          </div>
        </button>

        <button
          class="hub-card hub-card--raspadinha"
          @click="openSection({ id: 'raspadinha', label: 'Raspadinhas' })"
        >
          <div class="hub-card-center">
            <i class="fa-solid fa-ticket hub-icon"></i>
            <span class="hub-title">Raspadinhas</span>
          </div>
        </button>

        <button
          class="hub-card hub-card--pelucias"
          @click="openSection({ id: 'pelucias', label: 'Pelúcias' })"
        >
          <div class="hub-card-center">
            <i class="fa-solid fa-bear hub-icon"></i>
            <span class="hub-title">Pelúcias</span>
            <span class="hub-sub">Colecionáveis</span>
          </div>
        </button>

        <button
          class="hub-card hub-card--empregos"
          @click="openSection({ id: 'empregos', label: 'Empregos' })"
        >
          <div class="hub-card-center">
            <span class="hub-title">Empregos</span>
            <span class="hub-sub">Trabalhos</span>
          </div>
        </button>

        <button
          class="hub-card hub-card--estabelecimentos"
          @click="openSection({ id: 'estabelecimentos', label: 'Estabelecimentos' })"
        >
          <div class="hub-card-center">
            <span class="hub-title">Estabelecimentos</span>
            <span class="hub-sub">Locais úteis</span>
          </div>
        </button>

        <button
          class="hub-card hub-card--lojavip"
          @click="openSection({ id: 'vip', label: 'Loja VIP' })"
        >
          <div class="hub-card-center">
            <i class="fa-solid fa-gem hub-icon"></i>
            <span class="hub-title">Loja VIP</span>
            <span class="hub-sub">Premium</span>
          </div>
        </button>

      </div>
    </div>
  </section>
</template>

<script setup>
import { openSection } from "../store/menu";
import { closeMenu } from "../store/menu";

async function fetchNui(eventName) {
  const resource = (window.GetParentResourceName && window.GetParentResourceName()) || "magicPause";
  await fetch(`https://${resource}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" }
  });
}

async function openGtaSettings() {
  await closeMenu();
  await fetchNui("openGtaSettings");
}
</script>

<style src="../styles/hub.css"></style>
