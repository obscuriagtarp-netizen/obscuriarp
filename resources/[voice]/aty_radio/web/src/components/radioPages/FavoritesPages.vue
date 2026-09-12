<script setup>
import Favorites from '@/assets/favorites.png'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { favorites, connected } = storeToRefs(menuData)

function isFavorite(favorite) {
  return connected.value === favorite.channel
}
</script>

<template>
  <div class="favorites page">
    <div class="title-wrapper">
      <div class="title-icon"><img :src="Favorites" alt="Aty Radio Script" /></div>
      <div class="title">FAVORITES</div>
      <div class="description">You favorite channels.</div>
    </div>

    <div class="favorites-wrapper">
      <TransitionGroup name="list">
        <template v-if="favorites.length > 0">
          <template v-for="favorite in favorites" :key="favorite.channel">
            <div class="favorite-box">
              <div class="favorite-title-wrapper">
                <div class="favorite-icon"><img :src="Favorites" alt="Aty Radio Script" /></div>
                <div class="favorite-title">
                  <div class="subtitle">GPS CODE</div>
                  <div class="title">{{ favorite.channel }}</div>
                </div>
              </div>

              <div class="buttons-wrapper">
                <div
                  class="button"
                  :class="isFavorite(favorite) ? 'deactive ' : ''"
                  :disabled="isFavorite(favorite)"
                  @click="menuData.connectFavorite(favorite.channel)"
                >
                  {{ isFavorite(favorite) ? 'CONNECTED' : 'CONNECT' }}
                </div>

                <svg
                  @click="menuData.removeFavorite(favorite.channel)"
                  width="15"
                  height="15"
                  viewBox="0 0 15 15"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    d="M5.36488 2.55628C6.31482 0.852096 6.78988 0 7.5 0C8.21012 0 8.68517 0.852096 9.63511 2.55628L9.88094 2.99717C10.1508 3.48144 10.2858 3.72359 10.4963 3.88336C10.7067 4.04311 10.9689 4.10243 11.4931 4.22103L11.9704 4.32901C13.8151 4.74644 14.7375 4.95511 14.9569 5.66082C15.1764 6.36644 14.5475 7.10179 13.2899 8.5724L12.9646 8.95287C12.6071 9.37084 12.4285 9.57979 12.3481 9.83832C12.2677 10.0968 12.2947 10.3756 12.3488 10.9331L12.3979 11.4408C12.5881 13.4029 12.6831 14.384 12.1086 14.8202C11.5341 15.2563 10.6705 14.8586 8.94326 14.0634L8.49635 13.8576C8.00559 13.6316 7.76012 13.5186 7.5 13.5186C7.23988 13.5186 6.99441 13.6316 6.50364 13.8576L6.05673 14.0634C4.3295 14.8586 3.46588 15.2563 2.89136 14.8202C2.31684 14.384 2.41191 13.4029 2.60205 11.4408L2.65124 10.9331C2.70527 10.3756 2.73228 10.0968 2.65189 9.83832C2.57151 9.57979 2.39282 9.37084 2.03544 8.95287L1.71007 8.5724C0.452434 7.10179 -0.176383 6.36644 0.0430667 5.66082C0.262508 4.95511 1.18489 4.74644 3.02965 4.32901L3.50691 4.22103C4.03113 4.10243 4.29325 4.04311 4.5037 3.88336C4.71416 3.72359 4.84915 3.48145 5.1191 2.99717L5.36488 2.55628Z"
                    fill="#34ABDE"
                  />
                </svg>
              </div>
            </div>
          </template>
        </template>

        <template v-else>
          <div class="favorite-title centered">
            <div class="title">No favorites yet.</div>
          </div>
        </template>
      </TransitionGroup>
    </div>
  </div>
</template>

<style scoped>
.favorites {
  height: 100%;
  justify-content: flex-start;
}

.favorites-wrapper {
  width: 95%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5vh;
  position: relative;
}

.favorite-box {
  width: 100%;
  height: fit-content;
  display: flex;
  justify-content: space-between;
  align-items: center;
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

.favorite-title-wrapper {
  display: flex;
  align-items: center;
  gap: 1vh;
  padding: 0 0.5vh;
}

.favorite-icon {
  display: flex;
  align-items: center;
}

.favorite-icon img {
  height: 1.5vh;
  opacity: 0.5;
}

.favorite-title {
  display: flex;
  flex-direction: column;
}

.favorite-title .title {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.6);
}

.favorite-title-wrapper .subtitle {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 10px;
  line-height: 100%;
  color: rgba(255, 255, 255, 0.33);
}

.favorite-title-wrapper .title {
  font-family: 'Rajdhani';
  font-size: 14px;
  line-height: 100%;
  color: #b8b8b8;
  font-weight: 600;
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

.buttons-wrapper {
  display: flex;
  align-items: center;
  gap: 0.8vh;
}

svg {
  height: 2vh;
  width: 2vh;
  cursor: pointer;
}

svg:hover path {
  fill: #2dc0ff;
}

.button {
  width: 100%;
  padding: 0.3vh 1vh;
  padding-top: 0.4vh;
  background: rgba(66, 15, 15, 0.69);
  border-radius: 3px;
  font-family: 'Rajdhani';
  font-weight: 500;
  font-size: 8px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.24);
  text-align: center;
  cursor: pointer;
  color: #ffffff;
}

.button.deactive {
  pointer-events: none;
  opacity: 0.5;
}

.button:hover {
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.34);
}

.list-move,
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
  top: auto;
  left: auto;
}

.list-leave-active {
  position: absolute;
}

.centered .title {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-weight: 600;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.6);
  width: 100%;
  text-align: center;
}
</style>
