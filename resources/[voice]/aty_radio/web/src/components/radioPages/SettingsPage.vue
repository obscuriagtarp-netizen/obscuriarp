<script setup>
import GpsIcon from '@/assets/gps.png'
import SoundWaveIcon from '@/assets/soundWave.png'
import ScreenSiceIcon from '@/assets/screen-size.png'
import { convertValue } from '@/utils/index'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { settings } = storeToRefs(menuData)
</script>

<template>
  <div class="settings page">
    <div class="title-wrapper">
      <div class="title-icon"><img :src="GpsIcon" alt="Aty Radio Script" /></div>
      <div class="title">GPS SETTINGS</div>
      <div class="description">Setup your GPS as you like.</div>
    </div>

    <div class="settings-wrapper">
      <div class="setting-box">
        <div class="setting-title-wrapper">
          <div class="setting-icon"><img :src="SoundWaveIcon" alt="Aty Radio Script" /></div>
          <div class="setting-title">
            <div class="title">SOUND LEVEL</div>
            <div class="value">%{{ settings?.volume || 0 }}</div>
          </div>
        </div>

        <div class="bar-wrapper">
          <div class="bar" :style="{ width: `${settings?.volume || 0}%` }"></div>
          <input
            class="slider"
            type="range"
            name="sound"
            v-model="settings.volume"
            min="0"
            max="100"
            @input="menuData.updateSettings('volume', $event.target.value)"
          />
        </div>
      </div>

      <div class="setting-box">
        <div class="setting-title-wrapper">
          <div class="setting-icon"><img :src="ScreenSiceIcon" alt="Aty Radio Script" /></div>
          <div class="setting-title">
            <div class="title">GPS SIZE</div>
            <div class="value">
              %{{ convertValue(settings.size, 30, 100, 0, 100).toFixed(0) || 0 }}
            </div>
          </div>
        </div>

        <div class="bar-wrapper">
          <div
            class="bar"
            :style="{ width: `${convertValue(settings.size, 30, 100, 0, 100) || 0}%` }"
          ></div>
          <input
            class="slider"
            type="range"
            id=""
            v-model="settings.size"
            min="30"
            max="100"
            @input="menuData.updateSettings('size', $event.target.value)"
          />
        </div>
      </div>

      <div class="button" @click="menuData.resetSettings()">Reset Settings</div>
    </div>
  </div>
</template>

<style scoped>
.settings {
  height: 100%;
  justify-content: flex-start;
}

.settings-wrapper {
  width: 95%;
  display: flex;
  flex-direction: column;
  gap: 0.5vh;
}

.setting-box {
  width: 100%;
  height: fit-content;
  display: flex;
  justify-content: space-between;
  padding: 0.6vh;
  border-radius: 5px;
  background: linear-gradient(
    180deg,
    rgba(24, 24, 24, 0.12) -61.11%,
    rgba(45, 45, 45, 0.12) 177.78%
  );
  border: 0.51145px solid rgba(255, 255, 255, 0.16);
  box-shadow:
    4.0132e-16px 6.55406px 13.1081px rgba(7, 7, 7, 0.548),
    inset 2.03336e-16px 3.32072px 3.32072px #212121;
}

.setting-title-wrapper {
  display: flex;
  align-items: center;
  gap: 1vh;
}

.setting-icon {
  display: flex;
  align-items: center;
}

.setting-icon img {
  height: 2vh;
}

.setting-title {
  display: flex;
  flex-direction: column;
}

.setting-title .title {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.6);
}

.value {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 12px;
  color: #b8b8b8;
}

.bar-wrapper {
  width: 40%;
  height: 100%;
  display: flex;
  align-items: center;
  gap: 1vh;
  position: relative;
}

.bar {
  position: absolute;
  width: 50%;
  height: 0.3vh;
  background: linear-gradient(270deg, #7ed0f3 0%, #4cc0f2 100%);
  border-radius: 2.41882px;
  top: 50%;
  transform: translateY(-50%);
  left: 0;
  z-index: -1;
}

.slider {
  -webkit-appearance: none;
  appearance: none;
  width: 100%;
  height: 0.3vh;
  background: rgba(211, 211, 211, 0.15);
  outline: none;
}

.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 0.5vh;
  height: 0.8vh;
  background: #ffffff;
  border-radius: 2px;
  cursor: pointer;
  z-index: 2;
}

.button {
  width: 100%;
  padding: 1vh;
  background: rgba(66, 15, 15, 0.69);
  border-radius: 3px;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 12px;
  color: #ff4444;
  text-align: center;
  cursor: pointer;
}

.button:hover {
  background: rgba(66, 15, 15, 0.8);
}
</style>
