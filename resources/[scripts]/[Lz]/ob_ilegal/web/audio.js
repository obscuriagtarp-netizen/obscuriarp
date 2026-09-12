(function () {
    let context = null;
    let master = null;
    let lastProbeAt = 0;

    function ensureContext() {
        if (!context) {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            if (!AudioContext) return null;
            context = new AudioContext();
            master = context.createGain();
            master.gain.value = 0.34;
            master.connect(context.destination);
        }
        if (context.state === 'suspended') void context.resume();
        return context;
    }

    function tone(frequency, duration, volume, type = 'sine', endFrequency = frequency, delay = 0) {
        const audioContext = ensureContext();
        if (!audioContext || !master) return;
        const startsAt = audioContext.currentTime + delay;
        const endsAt = startsAt + duration;
        const oscillator = audioContext.createOscillator();
        const gain = audioContext.createGain();
        oscillator.type = type;
        oscillator.frequency.setValueAtTime(Math.max(30, frequency), startsAt);
        oscillator.frequency.exponentialRampToValueAtTime(Math.max(30, endFrequency), endsAt);
        gain.gain.setValueAtTime(0.0001, startsAt);
        gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, volume), startsAt + 0.018);
        gain.gain.exponentialRampToValueAtTime(0.0001, endsAt);
        oscillator.connect(gain);
        gain.connect(master);
        oscillator.start(startsAt);
        oscillator.stop(endsAt + 0.02);
    }

    function noise(duration, volume, delay = 0, frequency = 720, q = 1.4, filterType = 'bandpass') {
        const audioContext = ensureContext();
        if (!audioContext || !master) return;
        const frameCount = Math.max(1, Math.floor(audioContext.sampleRate * duration));
        const buffer = audioContext.createBuffer(1, frameCount, audioContext.sampleRate);
        const channel = buffer.getChannelData(0);
        for (let index = 0; index < frameCount; index += 1) {
            channel[index] = (Math.random() * 2 - 1) * (1 - (index / frameCount));
        }
        const source = audioContext.createBufferSource();
        const filter = audioContext.createBiquadFilter();
        const gain = audioContext.createGain();
        const startsAt = audioContext.currentTime + delay;
        filter.type = filterType;
        filter.frequency.value = frequency;
        filter.Q.value = q;
        gain.gain.setValueAtTime(volume, startsAt);
        gain.gain.exponentialRampToValueAtTime(0.0001, startsAt + duration);
        source.buffer = buffer;
        source.connect(filter);
        filter.connect(gain);
        gain.connect(master);
        source.start(startsAt);
    }

    function cue(name, detail) {
        const strength = Math.max(0, Math.min(1, Number(detail?.strength ?? detail) || 0));
        if (name === 'touch') {
            tone(260, 0.055, 0.018, 'triangle', 210);
        } else if (name === 'hit') {
            tone(390, 0.16, 0.045, 'sine', 610);
            tone(780, 0.22, 0.025, 'sine', 930, 0.035);
        } else if (name === 'wrong') {
            tone(145, 0.22, 0.05, 'sawtooth', 72);
            noise(0.13, 0.018);
        } else if (name === 'success') {
            tone(330, 0.30, 0.042, 'sine', 440);
            tone(495, 0.34, 0.035, 'sine', 660, 0.10);
            tone(742, 0.42, 0.030, 'sine', 990, 0.20);
        } else if (name === 'failure') {
            tone(190, 0.45, 0.045, 'triangle', 58);
            noise(0.28, 0.015);
        } else if (name === 'awaken') {
            tone(115, 0.48, 0.035, 'sine', 350);
            tone(230, 0.58, 0.027, 'sine', 700, 0.05);
        } else if (name === 'runeProbe') {
            const now = performance.now();
            if (now - lastProbeAt < 115) return;
            lastProbeAt = now;
            const base = 210 + (strength * 520);
            tone(base, 0.18, 0.018 + (strength * 0.022), 'sine', base * (1.02 + (strength * 0.06)));
            if (strength > 0.82) tone(base * 1.5, 0.24, 0.014, 'sine', base * 1.56, 0.02);
            else noise(0.08, 0.009 * (1 - strength));
        } else if (name === 'vaultContact') {

            noise(0.052, 0.125, 0, 2350, 0.72);
            tone(118, 0.075, 0.078, 'triangle', 64);
            noise(0.115, 0.052, 0.035, 980, 0.58);
            tone(76, 0.105, 0.064, 'triangle', 46, 0.048);
            noise(0.036, 0.105, 0.135, 3200, 1.05);
            tone(142, 0.050, 0.042, 'triangle', 88, 0.132);
        }
    }

    window.ObIlegalAudio = { unlock: ensureContext, cue };
}());
