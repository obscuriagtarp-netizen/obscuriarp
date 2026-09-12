<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { postNui } from './nui'

const isVisible = ref(false)
const classes = ref([])
const currentIndex = ref(0)
const session = ref(0)
const audioLocked = ref(false)
const audioLabel = ref('')
const confirmationOpen = ref(false)
const pendingClass = ref(null)

let activeAudio = null
let confirmationAfterAudio = null
const playedAudioKeys = new Set()

const currentClass = computed(() => classes.value[currentIndex.value] ?? null)
const currentClassTheme = computed(() => (currentClass.value?.id ? `theme-${currentClass.value.id}` : ''))
const hasClasses = computed(() => classes.value.length > 0)

const previewClasses = [
  {
    id: 'bruxa',
    label: 'Bruxa',
    description: 'Mestre dos feitiços e da manipulação das forças ocultas.',
    image: 'img/class-bruxa.png',
    card: 'img/class-card-bruxa.png',
    panel: 'img/class-panel-bruxa.png',
    audio: '../audio/classes/bruxa.ogg',
    affinity: 'Magia',
    weakness: 'Fogo'
  },
  {
    id: 'vampiro',
    label: 'Vampiro',
    description: 'Criatura imortal que caminha entre a luz e a escuridão.',
    image: 'img/class-vampiro.png',
    card: 'img/class-card-vampiro.png',
    panel: 'img/class-panel-vampiro.png',
    audio: '../audio/classes/vampiro.ogg',
    affinity: 'Sangue',
    weakness: 'Luz'
  },
  {
    id: 'curandeira',
    label: 'Curandeira',
    description: 'Guardiã da vida, especialista em cura e regeneração.',
    image: 'img/class-curandeira.png',
    card: 'img/class-card-curandeira.png',
    panel: 'img/class-panel-curandeira.png',
    audio: '../audio/classes/curandeira.ogg',
    affinity: 'Cura',
    weakness: 'Veneno'
  },
  {
    id: 'humano',
    label: 'Humano',
    description: 'Mortal treinado para sobreviver ao sobrenatural com preparo, coragem e instinto.',
    image: 'img/class-humano.png',
    card: 'img/class-card-humano.png',
    panel: 'img/class-panel-humano.png',
    audio: '../audio/classes/humano.ogg',
    affinity: 'Versatilidade',
    weakness: 'Fragilidade'
  }
]

function normalizeClasses(value) {
  return Array.isArray(value) ? value.filter((item) => item?.id) : []
}

function audioKeyFor(cls) {
  return cls?.id ? `class:${session.value}:${cls.id}` : ''
}

function finishAudio(key, status = 'ended', notifyClient = true) {
  if (!activeAudio || (key && activeAudio.key !== key)) return

  const finished = activeAudio
  activeAudio = null
  finished.element.onended = null
  finished.element.onerror = null
  finished.element.pause()
  finished.element.removeAttribute('src')
  finished.element.load()
  audioLocked.value = false
  audioLabel.value = ''

  if (notifyClient) {
    postNui('audioFinished', { key: finished.key, status })
  }

  if (status !== 'stopped' && confirmationAfterAudio?.key === finished.key) {
    pendingClass.value = confirmationAfterAudio.cls
    confirmationOpen.value = true
    confirmationAfterAudio = null
  }
}

function stopAudio(notifyClient = true) {
  if (!activeAudio) {
    audioLocked.value = false
    audioLabel.value = ''
    return
  }

  finishAudio(activeAudio.key, 'stopped', notifyClient)
  confirmationAfterAudio = null
}

async function playAudio(audio = {}) {
  const key = String(audio.key || '')
  const src = String(audio.src || '')

  if (!key || !src || activeAudio || playedAudioKeys.has(key)) return false

  const element = new Audio(src)
  element.preload = 'auto'
  element.volume = Math.min(1, Math.max(0, Number(audio.volume ?? 1)))

  playedAudioKeys.add(key)
  activeAudio = { key, element }
  audioLocked.value = true
  audioLabel.value = audio.label || 'A voz ecoa'
  element.onended = () => finishAudio(key, 'ended')
  element.onerror = () => finishAudio(key, 'error')
  postNui('audioStarted', { key })

  try {
    await element.play()
    return true
  } catch {
    finishAudio(key, 'error')
    return false
  }
}

function openSelector(payload) {
  const nextSession = Number(payload.session ?? session.value)
  if (nextSession !== session.value) {
    playedAudioKeys.clear()
    session.value = nextSession
  }

  classes.value = normalizeClasses(payload.classes)
  currentIndex.value = 0
  confirmationOpen.value = false
  pendingClass.value = null
  confirmationAfterAudio = null
  isVisible.value = hasClasses.value
}

function closeSelector() {
  if (audioLocked.value || confirmationOpen.value) return

  isVisible.value = false
  stopAudio()
  postNui('close')
}

function requestClassBinding() {
  const selected = currentClass.value
  if (!selected?.id || audioLocked.value || confirmationOpen.value) return

  const key = audioKeyFor(selected)
  pendingClass.value = selected

  if (selected.audio && !playedAudioKeys.has(key)) {
    confirmationAfterAudio = { key, cls: selected }
    playAudio({
      key,
      src: selected.audio,
      volume: selected.audioVolume ?? 1,
      label: 'Sem rosto'
    })
    return
  }

  confirmationOpen.value = true
}

function confirmClassBinding() {
  if (!pendingClass.value?.id || audioLocked.value) return

  postNui('chooseClass', { classId: pendingClass.value.id })
  isVisible.value = false
}

function cancelClassBinding() {
  if (audioLocked.value) return

  confirmationOpen.value = false
  pendingClass.value = null
  confirmationAfterAudio = null
}

function selectClass(index) {
  if (audioLocked.value || confirmationOpen.value || !classes.value[index]) return

  currentIndex.value = index
}

function moveClass(direction) {
  if (!hasClasses.value || audioLocked.value || confirmationOpen.value) return

  const total = classes.value.length
  selectClass((currentIndex.value + direction + total) % total)
}

function handleMessage(event) {
  const payload = event.data ?? {}

  if (payload.action === 'open') openSelector(payload)
  if (payload.action === 'close') {
    isVisible.value = false
    stopAudio(false)
  }
  if (payload.action === 'playAudio') playAudio(payload.audio)
  if (payload.action === 'stopAudio') stopAudio(false)
}

function handleKeydown(event) {
  if (!isVisible.value) return

  if (confirmationOpen.value) {
    if (event.key === 'Escape') cancelClassBinding()
    if (event.key === 'Enter') confirmClassBinding()
    return
  }

  if (event.key === 'Escape') closeSelector()
  if (event.key === 'ArrowLeft') moveClass(-1)
  if (event.key === 'ArrowRight') moveClass(1)
  if (event.key === 'Enter') requestClassBinding()
}

onMounted(() => {
  window.addEventListener('message', handleMessage)
  window.addEventListener('keydown', handleKeydown)
  postNui('audioReady')

  if (import.meta.env.DEV || typeof GetParentResourceName !== 'function') {
    openSelector({ classes: previewClasses, session: 1 })
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleMessage)
  window.removeEventListener('keydown', handleKeydown)
  stopAudio(false)
})
</script>

<template>
  <main class="class-selector" :class="[{ 'is-visible': isVisible, 'is-audio-locked': audioLocked }, currentClassTheme]">
    <div class="scene-bg" />
    <div class="scene-vignette" />
    <div class="mist mist-one" />
    <div class="mist mist-two" />
    <div class="ember-field" />
    <div class="ui-frame" />

    <section class="selector-shell" aria-label="Seleção de classe arcana">
      <div class="hero-stage">
        <header class="selector-header">
          <p class="eyebrow">Ritual de vínculo</p>
          <h1>Destino arcano</h1>
        </header>

        <div class="summon-view">
          <article v-if="currentClass" :key="currentClass.id" class="summon-stage">
            <div class="summon-halo" />
            <div class="summon-sigil" />
            <div class="summon-light" />
            <img class="class-figure" :src="currentClass.image" :alt="currentClass.label" draggable="false">
            <div class="summon-smoke summon-smoke-left" />
            <div class="summon-smoke summon-smoke-right" />
          </article>
        </div>
      </div>

      <aside
        v-if="currentClass"
        class="class-panel"
        :style="currentClass.panel ? { backgroundImage: `url('${currentClass.panel}')` } : {}"
      >
        <div class="panel-content">
          <header class="panel-identity">
            <img class="panel-logo" :src="currentClass.image" alt="" draggable="false">
            <div class="panel-title">
              <p class="panel-kicker">Classe selecionada</p>
              <h2>{{ currentClass.label }}</h2>
            </div>
          </header>

          <p class="class-description">{{ currentClass.description }}</p>

          <dl class="class-stats">
            <div>
              <dt>Afinidade</dt>
              <dd>{{ currentClass.affinity || 'Indefinida' }}</dd>
            </div>
            <div>
              <dt>Fraqueza</dt>
              <dd>{{ currentClass.weakness || 'Indefinida' }}</dd>
            </div>
          </dl>

          <div v-if="audioLocked" class="audio-status" role="status">
            <span class="audio-bars" aria-hidden="true"><i /><i /><i /><i /></span>
            <span><small>Narração em curso</small><b>{{ audioLabel }}</b></span>
          </div>

          <footer class="actions">
            <button class="primary-action" type="button" :disabled="audioLocked" @click="requestClassBinding">
              Vincular classe
            </button>
            <button class="ghost-action" type="button" :disabled="audioLocked" @click="closeSelector">
              Recusar magia
            </button>
          </footer>
        </div>
      </aside>

      <aside class="class-rail" aria-label="Classes disponíveis">
        <button
          v-for="(cls, index) in classes"
          :key="cls.id"
          class="rail-item"
          :class="{ 'is-active': index === currentIndex }"
          type="button"
          :disabled="audioLocked || confirmationOpen"
          @click="selectClass(index)"
        >
          <img class="rail-card-bg" :src="cls.card" alt="" draggable="false">
          <img class="rail-card-image" :src="cls.image" alt="" draggable="false">
          <span class="rail-label"><b>{{ cls.label }}</b></span>
        </button>
      </aside>
    </section>

    <div v-if="confirmationOpen && pendingClass" class="confirmation-backdrop">
      <section class="confirmation-dialog" role="dialog" aria-modal="true" aria-labelledby="confirmation-title">
        <img :src="pendingClass.image" alt="" draggable="false">
        <p>Confirmar vínculo</p>
        <h2 id="confirmation-title">{{ pendingClass.label }}</h2>
        <span>Esta escolha definirá seu destino arcano.</span>
        <div class="confirmation-actions">
          <button type="button" class="confirmation-cancel" @click="cancelClassBinding">Voltar</button>
          <button type="button" class="confirmation-confirm" @click="confirmClassBinding">Confirmar escolha</button>
        </div>
      </section>
    </div>
  </main>
</template>
