<script setup>
import ChannelBg from '@/assets/channels-bg.png'
import ChannelIcon from '@/assets/favorites.png'
import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { channels, channelMenu } = storeToRefs(menuData)

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    menuData.toggleChannelMenu(false)
  }
})
</script>

<template>
  <Transition name="fade">
    <div class="channels-menu" v-if="channelMenu">
      <div class="bg"><img :src="ChannelBg" alt="Aty Radio Script" /></div>

      <div class="title-wrapper">
        <div class="title">HACKED CHANNELS</div>
        <div class="description">Here are some the frequencies you've caught.</div>
      </div>

      <div class="channels-wrapper">
        <template v-if="channels.length === 0">
          <div class="channel" style="text-align: center">NO CHANNELS FOUND</div>
        </template>

        <template v-for="channel in channels" :key="channel.frequency" v-else>
          <div class="channel-box" @click="menuData.connectRadio(channel.frequency, true)">
            <div class="icon"><img :src="ChannelIcon" alt="Aty Radio Script" /></div>

            <div class="title-wrapper">
              <div class="title">FREQUENCY</div>
              <div class="channel">{{ channel.frequency }}</div>
            </div>

            <div class="text">CLICK TO LISTEN</div>
          </div>
        </template>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.channels-menu {
  width: 25vw;
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
  padding: 2vw;
  z-index: 1;
  overflow: hidden;
}

.channels-menu::after {
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

.channels-menu::before {
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

.channels-wrapper {
  display: flex;
  flex-direction: column;
  gap: 1vh;
  width: 100%;
}

.channel-box {
  width: 100%;
  display: flex;
  background: linear-gradient(
    180deg,
    rgba(24, 24, 24, 0.12) -61.11%,
    rgba(45, 45, 45, 0.12) 177.78%
  );
  box-shadow: 0 0 0 1.5px #545454;
  border-radius: 5px;
  position: relative;
  padding: 1.3vh;
  gap: 1vh;
  align-items: center;
  overflow: hidden;
  cursor: pointer;
}

.channel-box:hover {
  background: linear-gradient(
    180deg,
    rgba(45, 45, 45, 0.12) -61.11%,
    rgba(80, 80, 80, 0.12) 177.78%
  );
}

.icon {
  width: 2.5vh;
  height: 2.5vh;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.5;
}

.icon img {
  width: 100%;
}

.channels-wrapper .title-wrapper {
  display: flex;
  flex-direction: column;
  align-items: start;
  justify-content: center;
  position: relative;
  z-index: 1;
  width: fit-content;
}

.channels-wrapper .title-wrapper::after {
  content: '';
  position: absolute;
  width: 7vh;
  height: 7vh;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: -1;
  border-radius: 50%;
  background: #717171;
  filter: blur(40px);
}

.channels-wrapper .title {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 14px;
  line-height: 100%;
  color: rgba(255, 255, 255, 0.33);
}

.channel {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 18px;
  line-height: 100%;
  color: #b8b8b8;
}

.text {
  font-family: 'Rajdhani';
  font-weight: 400;
  font-size: 12px;
  line-height: 100%;
  text-align: right;
  color: rgba(184, 184, 184, 0.5);
  position: absolute;
  right: 1vw;
  top: 50%;
  transform: translateY(-50%);
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
