<script setup>
import { onMounted, ref } from 'vue'
import GpsIcon from '@/assets/gps.png'
import MoveIcon from '@/assets/move.png'
import MicrophoneIconActive from '@/assets/microphoneactive.png'
import MicrophoneIcon from '@/assets/microphone.png'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { members } = storeToRefs(menuData)

const left = ref('1vw')
const top = ref('1vw')

onMounted(() => {
  left.value = localStorage.getItem('membersBoxLeft') || 'auto'
  top.value = localStorage.getItem('membersBoxTop') || 'auto'

  let membersBox = document.querySelector('.members')
  const moveIcon = document.querySelector('.move-icon')

  if (!membersBox || !moveIcon) return

  moveIcon.addEventListener('mousedown', (e) => {
    e.preventDefault()

    let shiftX = e.clientX - membersBox.getBoundingClientRect().left
    let shiftY = e.clientY - membersBox.getBoundingClientRect().top

    membersBox.style.position = 'absolute'
    membersBox.style.zIndex = 1000
    document.body.append(membersBox)

    moveAt(e.pageX, e.pageY)

    function moveAt(pageX, pageY) {
      membersBox.style.left = pageX - shiftX + 'px'
      membersBox.style.top = pageY - shiftY + 'px'
    }

    function onMouseMove(e) {
      moveAt(e.pageX, e.pageY)
    }

    document.addEventListener('mousemove', onMouseMove)

    membersBox.onmouseup = function () {
      document.removeEventListener('mousemove', onMouseMove)
      membersBox.onmouseup = null
      localStorage.setItem('membersBoxLeft', membersBox.style.left)
      localStorage.setItem('membersBoxTop', membersBox.style.top)

      left.value = membersBox.style.left
      top.value = membersBox.style.top
    }
  })
})
</script>

<template>
  <Transition name="fade">
    <div class="members" :style="{ left, top }" v-show="members?.length > 0">
      <div class="members-header">
        <div class="icon"><img :src="GpsIcon" alt="Aty Radio Script" /></div>
        <div class="title">CONNECTED USERS ({{ members?.length || 0 }})</div>
        <div class="icon move-icon"><img :src="MoveIcon" alt="Aty Radio Script" /></div>
      </div>

      <div class="members-wrapper">
        <TransitionGroup name="list">
          <template v-for="member in members" :key="member.name">
            <div class="member">
              <div class="member-title-wrapper">
                <div class="title">CONNECTED</div>
                <div class="name">{{ member?.name }}</div>
              </div>

              <div class="icon">
                <img :src="MicrophoneIconActive" alt="Aty Radio Script" v-if="member.isTalking" />
                <img :src="MicrophoneIcon" alt="Aty Radio Script" v-else />
              </div>
            </div>
          </template>
        </TransitionGroup>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.members {
  position: absolute;
  left: auto;
  top: auto;
  bottom: auto;
  right: auto;
  width: 20vw;
  height: fit-content;
  display: flex;
  flex-direction: column;
  gap: 1vh;
}

.members-header {
  width: 100%;
  height: fit-content;
  display: flex;
  align-items: center;
  position: relative;
  gap: 1vw;
  padding: 1.5vh;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 16px;
  color: #ffffff;
  background: linear-gradient(
    90deg,
    rgba(42, 42, 42, 0.7) 0%,
    rgba(61, 61, 61, 0.7) 48.9%,
    rgba(42, 42, 42, 0.7) 100%
  );
  border: 2px solid rgba(255, 255, 255, 0.16);
}

.members-header img {
  height: 2.5vh;
}

.members-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.7vh;
}

.move-icon {
  position: absolute;
  right: 2vh;
  opacity: 0.3;
  cursor: move;
}

.icon {
  display: flex;
  align-items: center;
}

.member {
  width: 100%;
  height: fit-content;
  display: flex;
  align-items: center;
  gap: 1vw;
  padding: 1vh;
  background: rgba(22, 30, 33, 0.63);
  border: 1.07895px solid rgba(255, 255, 255, 0.41);
  box-shadow: inset 0px 10.9827px 10.9827px rgba(255, 255, 255, 0.06);
}

.member .title {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 12px;
  color: #34abde;
}

.member .name {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 14px;
  color: #ffffff;
}

.member img {
  height: 1.5vh;
  position: absolute;
  right: 1.5vh;
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

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s;
}

.fade-enter,
.fade-leave-to {
  opacity: 0;
}
</style>
