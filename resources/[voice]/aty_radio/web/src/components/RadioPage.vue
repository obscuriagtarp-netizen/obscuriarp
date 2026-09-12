<script setup>
import ConnectPage from './radioPages/ConnectPage.vue'
import FavoritesPages from './radioPages/FavoritesPages.vue'
import RequestsPage from './radioPages/RequestsPage.vue'
import SettingsPage from './radioPages/SettingsPage.vue'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'

const menuData = useMenuData()
const { page } = storeToRefs(menuData)

const components = {
  ConnectPage,
  FavoritesPages,
  RequestsPage,
  SettingsPage
}

const currentComponent = computed(() => components[page.value] || ConnectPage)

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    menuData.toggleMenu(false)
    menuData.setPage('ConnectPage')
  }
})
</script>

<template>
  <main>
    <TransitionGroup name="page">
      <component :is="currentComponent" :key="currentComponent" />
    </TransitionGroup>
  </main>
</template>

<style scoped>
.page-move,
.page-enter-active,
.page-leave-active {
  transition: all 0.2s ease;
}

.page-leave-to {
  transform: translateY(100%);
}

.page-enter-from {
  transform: translateY(-100%);
}

.page-leave-active {
  position: absolute;
}
</style>
