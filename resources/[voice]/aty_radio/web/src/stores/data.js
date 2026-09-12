import { fetchNui } from '@/utils'
import { defineStore } from 'pinia'

export const useMenuData = defineStore('menuData', {
  state: () => ({
    open: false,
    hackMenu: false,
    channelMenu: false,
    questionsMenu: false,
    questionId: 0,
    questions: [
      {
        question: 'What is the minimum age to obtain a radio license?',
        answers: ['18', '16', '21', '14'],
        correct: '18'
      },
      {
        question: 'What is the maximum power output for a radio station?',
        answers: ['1000W', '500W', '100W', '50W'],
        correct: '100W'
      },
      {
        question: 'What is the maximum bandwidth for a radio station?',
        answers: ['100kHz', '50kHz', '20kHz', '10kHz'],
        correct: '20kHz'
      },
      {
        question: 'What is the maximum antenna height for a radio station?',
        answers: ['100m', '50m', '20m', '10m'],
        correct: '20m'
      },
      {
        question: 'What is the maximum range for a radio station?',
        answers: ['100km', '50km', '20km', '10km'],
        correct: '50km'
      },
      {
        question: 'What is the maximum number of channels for a radio station?',
        answers: ['10', '5', '3', '1'],
        correct: '5'
      }
    ],
    page: 'ConnectPage',
    codes: [],
    crackTime: 0,
    hackTime: 0,
    channels: [],
    requests: [],
    members: [],
    connected: '',
    favorites: localStorage.getItem('favorites')
      ? JSON.parse(localStorage.getItem('favorites'))
      : [
          {
            channel: '123'
          }
        ],
    settings: {
      volume: localStorage.getItem('settings')
        ? JSON.parse(localStorage.getItem('settings')).volume
        : 50,
      size: localStorage.getItem('settings')
        ? JSON.parse(localStorage.getItem('settings')).size
        : 50
    }
  }),

  actions: {
    toggleMenu(val) {
      this.open = val

      if (!val) {
        fetchNui('closeMenu')
        this.setPage('ConnectPage')
      }
    },

    setPage(newPage) {
      const validPages = ['ConnectPage', 'FavoritesPages', 'RequestsPage', 'SettingsPage']
      if (validPages.includes(newPage)) {
        this.page = newPage
      } else {
        console.warn(`Invalid page name: ${newPage}`)
      }
    },

    updateSettings(setting, val) {
      this.settings[setting] = val
      localStorage.setItem('settings', JSON.stringify(this.settings))
    },

    resetSettings() {
      this.settings = {
        volume: 50,
        size: 50
      }
      localStorage.setItem('settings', JSON.stringify(this.settings))
    },

    removeFavorite(channel) {
      this.favorites = this.favorites.filter((favorite) => favorite.channel !== channel)
      localStorage.setItem('favorites', JSON.stringify(this.favorites))
    },

    addFavorite(channel) {
      this.favorites.push({ channel })
      localStorage.setItem('favorites', JSON.stringify(this.favorites))
    },

    toggleFavorite(channel) {
      if (this.favorites.some((favorite) => favorite.channel === channel)) {
        this.removeFavorite(channel)
      } else {
        this.addFavorite(channel)
      }
    },

    async acceptRequest(identifier) {
      let resp = await fetchNui('acceptRequest', identifier)

      if (resp) {
        this.requests = this.requests.filter((request) => request.identifier !== identifier)
      }
    },

    async declineRequest(identifier) {
      let resp = await fetchNui('declineRequest', identifier)

      if (resp.status === 'ok') {
        this.requests = this.requests.filter((request) => request.identifier !== identifier)
      }
    },

    async connectRadio(radio, forced = false) {
      let resp = await fetchNui('joinChannel', { radio: radio, forced: forced })

      if (resp.status === 'success') {
        this.connected = radio
        this.setRequests(resp.requests)
      }
    },

    async disconnectRadio() {
      let resp = await fetchNui('leaveChannel')

      if (resp.status === 'success') {
        this.connected = ''
        this.members = []
        this.requests = []
      }
    },

    connectFavorite(channel) {
      this.connectRadio(channel)
    },

    setRequests(requests) {
      this.requests = (requests && Object.values(requests)) || []
    },

    setMembers(members) {
      this.members = Object.values(members)
    },

    startCracking(hackTime) {
      this.hackMenu = true
      this.hackTime = hackTime

      let int = setInterval(async () => {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]

        for (let i = 0; i < 4; i++) {
          this.codes[i] = numbers[Math.floor(Math.random() * numbers.length)]
        }

        this.crackTime += 0.5

        if (this.crackTime >= hackTime * 10) {
          clearInterval(int)
          let resp = await fetchNui('cracked', this.codes.join(''))

          if (resp.status === 'success') {
            this.crackTime = 0
            this.codes = []
            this.hackMenu = false

            this.channelMenu = true
            this.channels = (resp?.channels && Object.values(resp.channels)) || []
          }
        }
      }, 100)
    },

    toggleChannelMenu(val) {
      this.channelMenu = val
      this.questionsMenu = val
      fetchNui('closeNoAnim')
    },

    nextQuestion(selectedAnswer) {
      fetchNui('answerQuestion', selectedAnswer === this.questions[this.questionId].correct)

      if (this.questionId + 1 < this.questions.length) {
        this.questionId++
      } else {
        this.questionsMenu = false
        this.questionId = 0

        fetchNui('finishExam')
      }
    },

    setQuestions(questions) {
      this.questionsMenu = true
      this.questions = questions
    }
  }
})
