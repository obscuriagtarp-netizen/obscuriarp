const pending = [];
const seen = new Set();
let enabled = false;
let active = null;

function drain() {
  if (!enabled || active || !pending.length) return;
  const item = pending.shift();
  const synth = window.speechSynthesis;
  if (!synth || !window.SpeechSynthesisUtterance) {
    item.onFinish?.();
    pending.splice(0).forEach(entry => entry.onFinish?.());
    console.warn('[ob_hospital] Voz padrao indisponivel neste cliente.');
    return;
  }
  const utterance = new window.SpeechSynthesisUtterance(item.message);
  const voices = synth.getVoices();
  const voice = voices.find(entry => entry.localService && /^pt-BR$/i.test(entry.lang))
    || voices.find(entry => /^pt-BR$/i.test(entry.lang))
    || voices.find(entry => /^pt/i.test(entry.lang));
  if (voice) utterance.voice = voice;
  utterance.lang = item.voice?.language || 'pt-BR';
  utterance.rate = Number(item.voice?.rate ?? 0.92);
  utterance.volume = Math.max(0, Math.min(1, Number(item.voice?.volume ?? 1)));
  const current = { utterance, timer: null, onFinish: item.onFinish };
  active = current;
  const finish = () => {
    if (active !== current) return;
    clearTimeout(current.timer);
    active = null;
    current.onFinish?.();
    drain();
  };
  utterance.onend = finish;
  utterance.onerror = finish;
  current.timer = setTimeout(() => {
    synth.cancel();
    finish();
  }, Math.max(20000, item.message.length * 200));
  try {
    synth.speak(utterance);
  } catch {
    finish();
  }
}

export function setQueueAudioEnabled(value) {
  enabled = value === true;
  if (enabled) return;
  pending.splice(0).forEach(item => item.onFinish?.());
  if (active) {
    const previous = active;
    clearTimeout(previous.timer);
    active = null;
    previous.onFinish?.();
    window.speechSynthesis?.cancel();
  }
}

export function announceQueue(item, voice, onFinish) {
  if (!enabled || !item?.id || !item.message || seen.has(item.id)) return false;
  seen.add(item.id);
  if (seen.size > 256) seen.delete(seen.values().next().value);
  pending.push({ ...item, voice, onFinish });
  drain();
  return true;
}
