import {
    audioControls,
    audioMute,
    audioMuteLabel,
    backgroundAudio,
} from '../util/elements.js';
import { shouldShowAudioControls } from '../util/handover.js';

const MUSIC_PAUSED_KEY = 'obscuria_music_paused';

/** @type {boolean} */
let paused = localStorage.getItem(MUSIC_PAUSED_KEY) === 'true';
/** @type {number} */
let volume = 0.22;
/** @type {string} */
let muteKey = 'Space';
/** @type {number[]} */
let retries = [];

function updateControl() {
    audioMute.setAttribute('aria-pressed', paused ? 'true' : 'false');
    audioMute.classList.toggle('is-paused', paused);
    audioMuteLabel.innerText = paused ? 'Retomar musica' : 'Pausar musica';
}

function applyPlaybackState() {
    backgroundAudio.volume = volume;
    backgroundAudio.muted = paused;

    if (paused) {
        backgroundAudio.pause();
    } else {
        backgroundAudio.play().catch(() => {});
    }

    updateControl();
}

function schedulePlaybackState() {
    retries.forEach(clearTimeout);
    retries = [150, 500, 1100, 2000].map((delay) =>
        setTimeout(applyPlaybackState, delay),
    );
}

function setPaused(nextPaused) {
    paused = nextPaused;
    localStorage.setItem(MUSIC_PAUSED_KEY, String(paused));
    applyPlaybackState();
    schedulePlaybackState();
}

export function setupAudioControls() {
    backgroundAudio.muted = paused;
    backgroundAudio.addEventListener('loadeddata', schedulePlaybackState);
    backgroundAudio.addEventListener('canplay', applyPlaybackState);
    audioMute.addEventListener('click', () => setPaused(!paused));
    window.addEventListener('keydown', ({ code, repeat }) => {
        if (!repeat && code === muteKey) setPaused(!paused);
    });
}

/**
 * @param {NuiHandoverData} handoverData
 */
export function configAudioControls(handoverData) {
    if (!shouldShowAudioControls(handoverData)) {
        audioControls.style.display = 'none';
        return;
    }

    const { config } = handoverData;
    volume = Math.max(0, Math.min(1, Number(config.initialAudioVolume) || 0.22));
    muteKey = String(config.audioMuteKey || 'Space');

    audioControls.style.display = '';
    applyPlaybackState();
    schedulePlaybackState();
}
