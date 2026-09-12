<script setup>
import RadioProp from './components/RadioProp.vue'
import RadioMembers from './components/RadioMembers.vue'
import CodesMenu from './components/CodesMenu.vue'
import ChannelsMenu from './components/ChannelsMenu.vue'
import ExamPage from './components/ExamPage.vue'

import nuiEvents from './utils/nui-events'
import { onMounted } from 'vue'

onMounted(() => {
  nuiEvents()
})
</script>

<template>
  <RadioProp />
  <RadioMembers />
  <CodesMenu />
  <ChannelsMenu />
  <ExamPage />
</template>

<style scoped></style>
