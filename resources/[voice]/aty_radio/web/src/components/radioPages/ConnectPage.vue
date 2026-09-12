<script setup>
import LineImage from '@/assets/line.png'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { connected, favorites } = storeToRefs(menuData)

function connectRadio() {
  const gps = document.getElementById('gps').value
  if (gps) {
    menuData.connectRadio(gps)
  }
}

function isFavorite(channel) {
  for (const favorite of favorites.value) {
    if (favorite.channel === channel) {
      return true
    }
  }
  return false
}

function checkInput(event) {
  const input = event.target
  if (input.value.length > 6) {
    input.value = input.value.slice(0, 6)
  }
}
</script>

<template>
  <div class="connect page">
    <div class="connect-wrapper">
      <div class="connect-box" v-if="parseInt(connected) === 0 || !connected">
        <div class="connect-input-wrapper">
          <input
            type="number"
            placeholder="00.00"
            id="gps"
            min="0"
            max="887945"
            @input="checkInput($event)"
          />
          <button @click="connectRadio()">Connect</button>
        </div>
      </div>

      <div class="connect-box disconnect" v-else>
        <div class="connect-input-wrapper">
          <div
            class="star"
            :class="isFavorite(connected) ? 'active' : ''"
            @click="menuData.toggleFavorite(connected)"
          >
            <svg
              width="34"
              height="34"
              viewBox="0 0 34 34"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M12.1604 5.79424C14.3136 1.93142 15.3904 0 17 0C18.6096 0 19.6864 1.93142 21.8396 5.79424L22.3968 6.79359C23.0086 7.89127 23.3146 8.44013 23.7916 8.80227C24.2686 9.16439 24.8628 9.29883 26.051 9.56767L27.1328 9.81243C31.3142 10.7586 33.405 11.2316 33.9024 12.8312C34.3998 14.4306 32.9744 16.0974 30.1238 19.4308L29.3864 20.2932C28.5762 21.2406 28.1712 21.7142 27.989 22.3002C27.8068 22.886 27.868 23.518 27.9906 24.7818L28.102 25.9324C28.533 30.38 28.7484 32.6038 27.4462 33.5924C26.144 34.581 24.1864 33.6796 20.2714 31.877L19.2584 31.4106C18.146 30.8984 17.5896 30.6422 17 30.6422C16.4104 30.6422 15.854 30.8984 14.7416 31.4106L13.7286 31.877C9.81354 33.6796 7.856 34.581 6.55376 33.5924C5.2515 32.6038 5.467 30.38 5.89798 25.9324L6.00948 24.7818C6.13194 23.518 6.19318 22.886 6.01096 22.3002C5.82876 21.7142 5.42372 21.2406 4.61366 20.2932L3.87616 19.4308C1.02552 16.0974 -0.399802 14.4306 0.0976178 12.8312C0.595018 11.2316 2.68576 10.7586 6.86722 9.81243L7.949 9.56767C9.13724 9.29883 9.73136 9.16439 10.2084 8.80227C10.6854 8.44013 10.9914 7.89129 11.6033 6.79359L12.1604 5.79424Z"
                fill="white"
                fill-opacity="0.41"
              />
            </svg>
          </div>

          <div class="input-wrapper">
            <img :src="LineImage" alt="Aty Radio Script" />
            <img :src="LineImage" alt="Aty Radio Script" />

            <div class="input-title">CONNECTED</div>
            <input type="text" placeholder="00.00" :value="connected" disabled />
          </div>
          <button @click="menuData.disconnectRadio">Disconnect</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.connect {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  width: 100%;
  overflow: hidden;
}

.connect-wrapper {
  width: 95%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5vh;
  position: relative;
}

.connect-input-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  gap: 1vh;
}

input {
  width: 100%;
  height: fit-content;
  background: none;
  outline: none;
  border: none;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 27.8068px;
  line-height: 35px;
  text-align: center;
  color: #b8b8b8;
}

button {
  background: rgba(16, 59, 67, 0.69);
  border-radius: 3px;
  font-family: 'Rajdhani';
  font-weight: 700;
  font-size: 12px;
  color: #44e3ff;
  border: 0;
  width: 80%;
  padding: 1vh 0;
  cursor: pointer;
}

button:hover {
  background: rgba(16, 59, 67, 0.89);
}

.star svg {
  width: 3vh;
  height: 3vh;
  cursor: pointer;
}

.star svg:hover path {
  fill-opacity: 0.5;
}

.star.active svg path {
  fill: #34abde;
  fill-opacity: 1;
}

.disconnect button {
  color: #ff4444;
  background: rgba(66, 15, 15, 0.69);
}

.disconnect button:hover {
  background: rgba(66, 15, 15, 0.89);
}

.disconnect .connect-input-wrapper {
  gap: 2vh;
}

.input-wrapper {
  text-align: center;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 13px;
  line-height: 100%;
  text-align: center;
  color: #ffffff;
  position: relative;
}

.input-wrapper img {
  height: 2vh;
  position: absolute;
  left: -5%;
  width: 30%;
  top: 10%;
  filter: drop-shadow(0px 0px 20px rgba(255, 255, 255, 0.5));
}

.input-wrapper img:nth-child(2) {
  left: auto;
  right: -5%;
  scale: -1;
}

input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
</style>
