<script setup>
import Page from '@/assets/page.png'
import Xmark from '@/assets/x.png'

import { useMenuData } from '@/stores/data'
import { storeToRefs } from 'pinia'

const menuData = useMenuData()
const { questions, questionId, questionsMenu } = storeToRefs(menuData)

let selectedAnswer = null

function selectQuestion(id, el) {
  const boxes = document.querySelectorAll('.box')
  boxes.forEach((box) => {
    box.classList.remove('selected')
  })
  el.target.classList.add('selected')

  selectedAnswer = id
}

function nextQuestion() {
  menuData.nextQuestion(selectedAnswer)
  const boxes = document.querySelectorAll('.box')
  boxes.forEach((box) => {
    box.classList.remove('selected')
  })
}
</script>

<template>
  <Transition name="fade">
    <div class="question-page" v-if="questionsMenu">
      <div class="bg"><img :src="Page" alt="Aty Radio Script" /></div>

      <div class="close-btn">
        <svg width="6" height="6" viewBox="0 0 6 6" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path
            d="M0.174683 0.167337C0.0674141 0.274516 0.00715343 0.419861 0.00715343 0.571411C0.00715343 0.722961 0.0674141 0.868307 0.174683 0.975485L2.19795 2.99643L0.174683 5.01737C0.120033 5.07009 0.0764424 5.13316 0.0464544 5.20289C0.0164664 5.27262 0.000681808 5.34761 2.16043e-05 5.4235C-0.0006386 5.49939 0.0138387 5.57465 0.042609 5.64489C0.0713793 5.71513 0.113866 5.77894 0.167591 5.8326C0.221315 5.88626 0.285202 5.9287 0.355522 5.95744C0.425842 5.98618 0.501188 6.00064 0.577164 5.99998C0.653139 5.99932 0.728221 5.98355 0.798031 5.9536C0.867841 5.92364 0.930979 5.8801 0.983762 5.82552L3.00703 3.80458L5.0303 5.82552C5.13822 5.92963 5.28275 5.98723 5.43278 5.98593C5.58281 5.98463 5.72632 5.92452 5.83241 5.81855C5.9385 5.71259 5.99867 5.56924 5.99998 5.41939C6.00128 5.26953 5.94361 5.12516 5.83938 5.01737L3.81611 2.99643L5.83938 0.975485C5.94361 0.867693 6.00128 0.723322 5.99998 0.573468C5.99867 0.423614 5.9385 0.280266 5.83241 0.174299C5.72632 0.0683324 5.58281 0.00822468 5.43278 0.00692249C5.28275 0.0056203 5.13822 0.0632279 5.0303 0.167337L3.00703 2.18828L0.983762 0.167337C0.87646 0.0601913 0.730947 0 0.579223 0C0.427498 0 0.281985 0.0601913 0.174683 0.167337Z"
            fill="#E2E2E2"
          />
        </svg>
      </div>

      <div class="page-title-wrapper">
        <div class="title">Radio License Test</div>
        <div class="test-name">Answer The Questions Correctly.</div>
      </div>

      <div class="question-box">
        <div class="question-text">{{ questions[questionId].question }}</div>

        <div class="answers-box">
          <div class="answer-box">
            <div class="box selected" @click="selectQuestion(0, $event)">
              <img :src="Xmark" alt="Aty Radio Script" />
            </div>
            <div class="answer">A - {{ questions[questionId].answers[0] }}</div>
          </div>
          <div class="answer-box">
            <div class="box" @click="selectQuestion(1, $event)">
              <img :src="Xmark" alt="Aty Radio Script" />
            </div>
            <div class="answer">B - {{ questions[questionId].answers[1] }}</div>
          </div>
          <div class="answer-box">
            <div class="box" @click="selectQuestion(2, $event)">
              <img :src="Xmark" alt="Aty Radio Script" />
            </div>
            <div class="answer">C - {{ questions[questionId].answers[2] }}</div>
          </div>
          <div class="answer-box">
            <div class="box" @click="selectQuestion(3, $event)">
              <img :src="Xmark" alt="Aty Radio Script" />
            </div>
            <div class="answer">D - {{ questions[questionId].answers[3] }}</div>
          </div>
        </div>
      </div>

      <div class="close-btn-wrapper">
        <div class="button" @click="nextQuestion()">NEXT QUESTION</div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.question-page {
  position: absolute;
  width: 40vw;
  height: fit-content;
  display: flex;
  flex-direction: column;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 1;
  overflow: hidden;
  border-radius: 15px;
  padding: 4vh;
  gap: 4vh;
}

.bg {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  z-index: -1;
}

.title {
  font-family: 'Rajdhani';
  font-weight: 700;
  font-size: 27.1474px;
  line-height: 35px;
  color: #515151;
}

.test-name {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 21.9051px;
  line-height: 28px;
  color: #153c6b;
}

.question-box {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 2vh;
}

.question-text {
  font-family: 'Rajdhani';
  font-weight: 700;
  font-size: 17.6694px;
  line-height: 23px;
  text-align: justify;
  color: #515151;
}

.answers-box {
  display: flex;
  gap: 2vh;
  flex-wrap: wrap;
  width: 100%;
}

.answer-box {
  display: flex;
  gap: 0.5vw;
  align-items: center;
  width: calc(50% - 1vh);
  cursor: pointer;
}

.box {
  width: 2.5vh;
  height: 2.5vh;
  border-radius: 50%;
  background: rgba(167, 167, 167, 0.32);
  border: 2.24742px solid #3d3d3d;
  position: relative;
}

.answer {
  font-family: 'Rajdhani';
  font-weight: 700;
  font-size: 15.6694px;
  line-height: 20px;
  color: #515151;
}

.box img {
  width: 100%;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: none;
}

.box.selected img {
  display: block;
}

.close-btn-wrapper {
  width: 100%;
  display: flex;
  justify-content: end;
}

.button {
  font-family: 'Rajdhani';
  font-weight: 600;
  font-size: 12px;
  text-align: center;
  color: #ffffff;
  background: rgba(0, 0, 0, 0.73);
  border: 1.15505px solid rgba(255, 255, 255, 0.24);
  border-radius: 2px;
  padding: 1vh 2vw;
  cursor: pointer;
}

.button:hover {
  background: rgba(0, 0, 0, 0.8);
}

.close-btn {
  position: absolute;
  top: 2vh;
  right: 2vh;
  cursor: pointer;
  background: #383838;
  box-shadow: 0px 0px 84.8291px rgba(0, 102, 255, 0.24);
  border-radius: 2px;
  width: 3vh;
  height: 3vh;
  display: flex;
  justify-content: center;
  align-items: center;
}

.close-btn:hover {
  background: #515151;
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
