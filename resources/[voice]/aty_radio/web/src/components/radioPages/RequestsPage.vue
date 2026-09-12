<script setup>
import RequtestIcon from '@/assets/request.png'
import CheckIcon from '@/assets/check.png'
import RejectIcon from '@/assets/xmark.png'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { requests } = storeToRefs(menuData)
</script>

<template>
  <div class="requests page">
    <div class="title-wrapper">
      <div class="title-icon"><img :src="RequtestIcon" alt="Aty Radio Script" /></div>
      <div class="title">REQUESTS</div>
      <div class="description">See the requests to your channel.</div>
    </div>

    <div class="requests-wrapper">
      <template v-if="requests.length > 0">
        <template v-for="request in requests" :key="request.identifier">
          <div class="request-item">
            <div class="request-title-wrapper">
              <div class="subtitle">REQUESTER</div>
              <div class="title">{{ request.name }}</div>
            </div>

            <div class="buttons-wrapper">
              <div class="button" @click="menuData.acceptRequest(request.identifier)">
                <img :src="CheckIcon" alt="Aty Radio Script" />
              </div>
              <div class="button" @click="menuData.declineRequest(request.identifier)">
                <img :src="RejectIcon" alt="Aty Radio Script" />
              </div>
            </div>
          </div>
        </template>
      </template>

      <template v-else>
        <div class="request-title-wrapper centered">
          <div class="title">No requests yet.</div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.requests {
  height: 100%;
  justify-content: flex-start;
}

.requests-wrapper {
  width: 95%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5vh;
  overflow-y: scroll;
  position: relative;
}

.requests-wrapper::-webkit-scrollbar {
  width: 0;
}

.request-item {
  width: 100%;
  height: fit-content;
  display: flex;
  justify-content: space-between;
  padding: 0.7vh;
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
  align-items: center;
}

.request-title-wrapper {
  text-align: left;
}

.request-title-wrapper .subtitle {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 10px;
  line-height: 100%;
  color: #717171;
}

.request-title-wrapper .title {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 14px;
  line-height: 100%;
  color: #fff;
}

.buttons-wrapper {
  display: flex;
  gap: 0.5vh;
}

.button {
  width: 2.5vh;
  height: 2.5vh;
  display: flex;
  justify-content: center;
  align-items: center;
  background: linear-gradient(
    180deg,
    rgba(24, 24, 24, 0.12) -61.11%,
    rgba(45, 45, 45, 0.12) 177.78%
  );
  border: 0.530393px solid rgba(255, 255, 255, 0.16);
  box-shadow:
    4.16184e-16px 6.7968px 13.5936px rgba(7, 7, 7, 0.548),
    inset 2.10867e-16px 3.44371px 3.44371px #212121;
  border-radius: 5px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.button:hover {
  background: linear-gradient(180deg, rgba(24, 24, 24, 0.7) -61.11%, rgba(45, 45, 45, 0.7) 177.78%);
}

.button img {
  height: 40%;
}

.button::after {
  content: '';
  width: 100%;
  height: 100%;
  border-radius: 50%;
  position: absolute;
  bottom: -30%;
  right: 50%;
  background: rgba(52, 171, 222, 0.5);
  filter: blur(10px);
}

.button:last-child:after {
  background: rgba(222, 52, 55, 0.5);
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
