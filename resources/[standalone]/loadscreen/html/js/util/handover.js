/**
 * @type {NuiHandoverData}
 */
const DEFAULT_HANDOVER_DATA = {
    vars: {
        playerName: 'Player',
        serverName: 'Server',
    },
    paths: {
        images: ['./assets/images/moon.png', './assets/images/vinewood.png'],
        music: ['./assets/music/obscuria-theme.mp3'],
        videos: ['./assets/videos/obscuria-loading.mp4'],
        logo: './assets/logo.png?v=eye-white-1',
    },
    config: {
        style: 'obscuria',
        background: 'video',
        backgroundBrightness: 1,
        textColor: 'rgb(244, 240, 244)',
        primaryColor: 'rgb(193, 160, 202)',
        secondaryColor: 'rgb(183, 175, 185)',
        shadowColor: 'rgba(8, 7, 11, 0.72)',
        fontFamily: "'Obscuria Sans', 'Segoe UI', Arial, sans-serif",
        logo: true,
        serverMessage: 'Bem-vindo, ${playerName}',
        primaryBar: true,
        secondaryBar: false,
        loadingAction: false,
        finishingMessage: 'Quase tudo pronto',
        logLine: true,
        finishedMessage: 'Entrada liberada',
        finishedLine: 'Obscuria esta esperando por voce.',
        audioControls: true,
        audioMuteKey: 'Space',
        rememberVolume: true,
        errorLog: true,
        initialAudioVolume: 0.22,
        music: true,
        musicShuffle: false,
        imageRate: 7500,
        imageShuffle: false,
        videoShuffle: false,
        embedLink:
            'https://www.youtube.com/embed/NRBrS7OkZNY?autoplay=1&mute=1&controls=0&loop=1&playlist=NRBrS7OkZNY&modestbranding=1&rel=0&iv_load_policy=3&playsinline=1&disablekb=1',
        embedAccess: false,
    },
};

/**
 * @returns {NuiHandoverData}
 */
export function getHandoverData() {
    return /** @type {any} */ (window).nuiHandoverData ?? DEFAULT_HANDOVER_DATA;
}

/**
 * @readonly
 * @enum {number}
 */
const BackgroundType = {
    CSS: 0,
    Image: 1,
    Video: 2,
    Embed: 3,
};

/**
 * @param {NuiHandoverData} handoverData
 * @returns {BackgroundType}
 */
function getBackgroundType({ config: { background } }) {
    return (
        {
            image: BackgroundType.Image,
            video: BackgroundType.Video,
            embed: BackgroundType.Embed,
        }[background] ?? BackgroundType.CSS
    );
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowBackgroundCSS(handoverData) {
    return getBackgroundType(handoverData) === BackgroundType.CSS;
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowBackgroundImages(handoverData) {
    return (
        getBackgroundType(handoverData) === BackgroundType.Image &&
        handoverData.paths.images.length > 0
    );
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowBackgroundVideos(handoverData) {
    return (
        getBackgroundType(handoverData) === BackgroundType.Video &&
        handoverData.paths.videos.length > 0
    );
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowBackgroundEmbed(handoverData) {
    return (
        getBackgroundType(handoverData) === BackgroundType.Embed &&
        handoverData.config.embedLink.trim().length > 0
    );
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowLogo({ paths, config }) {
    return config.logo && typeof paths.logo !== 'undefined';
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldPlayBackgroundMusic({ paths, config }) {
    return config.music && paths.music.length > 0;
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowAudioControls(handoverData) {
    return (
        handoverData.config.audioControls &&
        shouldPlayBackgroundMusic(handoverData)
    );
}

/**
 * @param {NuiHandoverData} handoverData
 * @returns {boolean}
 */
export function shouldShowSecondaryWrapper({ config }) {
    return config.secondaryBar && config.loadingAction;
}
