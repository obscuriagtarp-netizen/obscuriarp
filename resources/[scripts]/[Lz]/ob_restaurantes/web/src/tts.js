const queue = [];
const seen = new Map();
let speaking = false;
let voices = [];

function loadVoices() {
  voices = window.speechSynthesis?.getVoices?.() || [];
}

loadVoices();
if (window.speechSynthesis) window.speechSynthesis.onvoiceschanged = loadVoices;

function chime() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const context = new AudioContext();
    const gain = context.createGain();
    gain.gain.setValueAtTime(0.0001, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.16, context.currentTime + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.7);
    gain.connect(context.destination);
    [659.25, 987.77].forEach((frequency, index) => {
      const oscillator = context.createOscillator();
      oscillator.type = "sine";
      oscillator.frequency.value = frequency;
      oscillator.connect(gain);
      oscillator.start(context.currentTime + index * 0.11);
      oscillator.stop(context.currentTime + 0.7);
    });
    window.setTimeout(() => context.close(), 900);
  } catch {}
}

function normalize(text) {
  return String(text || "")
    .replace(/\bP(\d{3})\b/gi, (_, number) => `pedido ${number.split("").join(" ")}`)
    .replace(/\s+/g, " ")
    .trim();
}

function localSpeech(item) {
  return new Promise((resolve) => {
    if (!window.speechSynthesis || !window.SpeechSynthesisUtterance) return resolve();
    const utterance = new SpeechSynthesisUtterance(normalize(item.message));
    const preferred = voices.find((voice) => /^pt-BR$/i.test(voice.lang)) || voices.find((voice) => /^pt/i.test(voice.lang));
    if (preferred) utterance.voice = preferred;
    utterance.lang = item.tts?.language || "pt-BR";
    utterance.rate = Number(item.tts?.rate || 0.92);
    utterance.pitch = Number(item.tts?.pitch || 1);
    utterance.volume = Number(item.tts?.volume || 1);
    let started = false;
    let finished = false;
    const finish = () => {
      if (finished) return;
      finished = true;
      resolve();
    };
    utterance.onstart = () => { started = true; };
    utterance.onend = finish;
    utterance.onerror = finish;
    window.speechSynthesis.speak(utterance);
    window.setTimeout(() => {
      if (!started && !window.speechSynthesis.speaking) {
        window.speechSynthesis.cancel();
        window.speechSynthesis.speak(utterance);
      }
    }, 650);
    window.setTimeout(finish, Math.max(15000, normalize(item.message).length * 250));
  });
}

function externalAudio(item) {
  return new Promise((resolve, reject) => {
    if (!item.audioUrl) return reject(new Error("missing audio"));
    const audio = new Audio(item.audioUrl);
    audio.preload = "auto";
    audio.onended = resolve;
    audio.onerror = reject;
    audio.play().catch(reject);
  });
}

async function drain() {
  if (speaking || !queue.length) return;
  speaking = true;
  const item = queue.shift();
  const delay = Math.max(0, Number(item.startAt || 0) - Date.now());
  if (delay) await new Promise((resolve) => window.setTimeout(resolve, delay));
  item.lifecycle?.onStart?.(item);
  chime();
  await new Promise((resolve) => window.setTimeout(resolve, 700));
  try {
    await externalAudio(item);
  } catch {
    await localSpeech(item);
  }
  item.lifecycle?.onEnd?.(item, { hasNext: queue.length > 0 });
  speaking = false;
  drain();
}

export function queueAnnouncement(item, lifecycle = {}) {
  if (!item?.message) return false;
  const key = String(item.id || `${item.restaurantId}:${item.orderId}:${item.message}`);
  const ttl = Number(item.tts?.dedupeSeconds || 8) * 1000;
  const previous = seen.get(key) || 0;
  if (Date.now() - previous < ttl) return false;
  seen.set(key, Date.now());
  queue.push({ ...item, lifecycle });
  drain();
  return true;
}
