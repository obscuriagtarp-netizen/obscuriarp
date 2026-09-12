<script setup>
import CodeBg from '@/assets/cracker-bg.png'
import { convertValue } from '@/utils'
import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { codes, crackTime, hackMenu, hackTime } = storeToRefs(menuData)
</script>

<template>
  <Transition name="fade">
    <div class="codes-menu" v-if="hackMenu">
      <div class="bg"><img :src="CodeBg" alt="Aty Radio Script" /></div>

      <div class="title-wrapper">
        <div class="title">PINCRACKER</div>
        <div class="description">Finding the code to access the radio tower.</div>
      </div>

      <div class="boxes-wrapper">
        <div class="box">{{ (codes && codes[0]) || '?' }}</div>
        <div class="box">{{ (codes && codes[1]) || '?' }}</div>
        <div class="box">{{ (codes && codes[2]) || '?' }}</div>
        <div class="box">{{ (codes && codes[3]) || '?' }}</div>
      </div>

      <div
        class="button"
        :class="crackTime > 0 ? 'disabled' : ''"
        @click="menuData.startCracking()"
      >
        {{ crackTime > 0 ? 'CRACKING' : 'CRACK' }}
      </div>

      <div class="loading-box">
        <div
          class="loading-bar"
          :style="'width: ' + convertValue(crackTime, 0, hackTime * 10, 0, 100) + '%'"
        ></div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.codes-menu {
  width: 33vw;
  height: fit-content;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2vh;
  background: #0d0e0f;
  border-radius: 10px;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  padding: 2vw 2vw 2.5vw 2vw;
  z-index: 1;
  overflow: hidden;
}

.codes-menu::after {
  content: '';
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 30%;
  height: 1vh;
  background: #333536;
  border-radius: 0 0 4px 4px;
}

.codes-menu::before {
  content: '';
  position: absolute;
  width: 10vw;
  height: 10vw;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  border-radius: 50%;
  background: #373737;
  filter: blur(100px);
  z-index: -1;
}

.bg {
  width: 100%;
  position: absolute;
  top: 0;
  left: 0;
  z-index: -1;
}

.bg img {
  width: 100%;
  height: 100%;
  border-radius: 10px;
}

.title-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.title {
  font-weight: 700;
  font-size: 28px;
  line-height: 100%;
  text-align: center;
  color: #b8b8b8;
}

.description {
  font-weight: 500;
  line-height: 100%;
  font-size: 12px;
  text-align: center;
  color: #ffffff;
}

.boxes-wrapper {
  display: flex;
  gap: 2vh;
}

.box {
  width: 7vh;
  height: 7vh;
  background: rgba(35, 35, 37, 0.77);
  box-shadow: 0px 0px 0px 1.5px #5e5e5e;
  border-radius: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 500;
  font-size: 36px;
  color: #787878;
  font-family: 'Rajdhani', sans-serif;
  line-height: 100%;
}

.button {
  width: calc(7vh * 4 + 2vh * 3);
  height: 5vh;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  color: #ffffff;
}

.button.disabled {
  opacity: 0.3;
  pointer-events: none;
}

.button:hover {
  background: rgba(255, 255, 255, 0.12);
}

.loading-box {
  width: 100%;
  height: 1vh;
  background: rgba(217, 217, 217, 0.3);
  overflow: hidden;
  position: absolute;
  bottom: 0;
  left: 0;
}

.loading-bar {
  background: linear-gradient(90deg, #34abde 0%, #92c9e0 100%);
  box-shadow: 0px 0px 50px #34abde;
  height: 100%;
  width: 0%;
  transition: width 100ms linear;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s;
}

.fade-enter,
.fade-leave-to {
  opacity: 0;
}
</style>
