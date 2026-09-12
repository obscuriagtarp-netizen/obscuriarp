<script setup>
import RadioHeader from './RadioHeader.vue'
import RadioNavigation from './RadioNavigation.vue'
import RadioPage from './RadioPage.vue'
import RadioBg from '../assets/radio.png'
import { convertValue } from '@/utils/index'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { settings, open } = storeToRefs(menuData)
</script>

<template>
  <Transition name="radioAnim">
    <div
      v-if="open"
      class="radio-outer"
      :style="'transform: scale(' + convertValue(settings.size, 30, 100, 0.8, 1.1) + ')'"
    >
      <img :src="RadioBg" alt="Aty Radio Script" class="radio-bg" />

      <div class="radio-screen">
        <RadioHeader />
        <RadioPage />
        <RadioNavigation />
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.radio-outer {
  height: 88vh;
  bottom: -5vw;
  right: 1vw;
  position: absolute;
  transform-origin: 100% 100%;
  transition: transform 0.5s ease-in-out;
}

.radio-outer .radio-bg {
  width: 100%;
  height: 100%;
  object-fit: cover;
  pointer-events: none;
}

.radio-screen {
  width: 42%;
  height: 37.5%;
  position: absolute;
  top: 44%;
  left: 37%;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: center;
  overflow: hidden;
  z-index: 1;
}

.radio-screen::after {
  content: '';
  position: absolute;
  width: 10vh;
  height: 10vh;
  border-radius: 50%;
  background: #34abde;
  top: -20%;
  filter: blur(45px);
  z-index: -1;
  opacity: 0.5;
}

.radio-screen::before {
  content: '';
  position: absolute;
  width: 10vh;
  height: 10vh;
  border-radius: 50%;
  background: #34abde;
  bottom: -20%;
  filter: blur(45px);
  z-index: -1;
  opacity: 0.5;
}

.radioAnim-enter-active,
.radioAnim-leave-active {
  transition: 0.3s ease;
}

.radioAnim-enter-from,
.radioAnim-leave-to {
  opacity: 0;
  bottom: -15vw;
}
</style>
