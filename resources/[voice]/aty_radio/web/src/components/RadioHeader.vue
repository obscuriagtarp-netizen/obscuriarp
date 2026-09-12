<script setup>
import Wifi from '../assets/wifi.png'
import Charge from '../assets/charge.png'

setInterval(() => {
  const date = new Date()
  const hours = date.getHours()
  const minutes = date.getMinutes()
  const time = `${hours < 10 ? '0' + hours : hours}.${minutes < 10 ? '0' + minutes : minutes}`
  let timeBox = document.querySelector('.time')

  if (timeBox) {
    timeBox.textContent = time
  }
}, 10000)
</script>

<template>
  <header>
    <div class="icon"><img :src="Wifi" alt="Aty Radio Script" /></div>
    <div class="time">23.59</div>
    <div class="icon"><img :src="Charge" alt="Aty Radio Script" /></div>
  </header>
</template>

<style scoped>
header {
  width: 95%;
  height: 8%;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 12px;
  text-align: center;
  color: #34abde;
  text-shadow: 0px 0px 6.41205px #000000;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

header img {
  height: 0.9vh;
}
</style>
