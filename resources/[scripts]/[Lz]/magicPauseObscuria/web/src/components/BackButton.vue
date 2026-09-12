<template>
  <teleport to="body">
    <button class="back-btn-global" @click="backToMain" title="Voltar">
      <i class="fa-solid fa-chevron-left"></i>
    </button>
  </teleport>
</template>

<script setup>
import { backToMain } from "../store/menu";
</script>

<style>
.back-btn-global {
  position: fixed;
  top: 28px;
  left: 90px;

  width: 48px;
  height: 48px;
  border-radius: 14px;

  display: flex;
  align-items: center;
  justify-content: center;

  cursor: pointer;
  color: rgba(255, 255, 255, 0.96);

  border: 1px solid rgba(255, 255, 255, 0.16);
  background:
    radial-gradient(circle at 30% 20%, rgba(255,255,255,0.12), transparent 55%),
    radial-gradient(circle at 70% 0%, rgba(139, 92, 246, 0.22), transparent 55%),
    rgba(15, 8, 34, 0.92);

  box-shadow:
    0 18px 48px rgba(0,0,0,0.75),
    inset 0 0 18px rgba(255,255,255,0.04);

  z-index: 100000;

  transition:
    transform 0.14s ease,
    box-shadow 0.14s ease,
    border-color 0.14s ease,
    background 0.14s ease;
}

.back-btn-global i {
  font-size: 15px;
  filter: drop-shadow(0 0 10px rgba(192, 132, 252, 0.45));
  transition: transform 0.14s ease;
}

.back-btn-global:hover {
  border-color: rgba(56, 189, 248, 0.35);
  box-shadow:
    0 22px 60px rgba(0,0,0,0.9),
    0 0 36px rgba(56, 189, 248, 0.15);
  transform: translateY(-1px);
}

.back-btn-global:hover i {
  transform: translateX(-2px);
}

.back-btn-global:active {
  transform: scale(0.96);
}

@media (max-width: 900px) {
  .back-btn-global {
    top: 14px;
    right: 14px;
  }
}
</style>
