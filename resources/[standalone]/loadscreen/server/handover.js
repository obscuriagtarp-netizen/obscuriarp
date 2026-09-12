const { readdirSync } = require('node:fs');
const { join } = require('node:path');

const loadscreen = GetCurrentResourceName();
const NUI_ASSETS = `nui://${loadscreen}/html/assets`;

const ASSETS = join(GetResourcePath(loadscreen), 'html', 'assets');

/**
 * @param {string} dir
 * @param {import("node:fs").ObjectEncodingOptions} options
 * @returns {string[]}
 */
function readAssetsSync(dir, options) {
    try {
        return readdirSync(join(ASSETS, dir), {
            ...options,
            withFileTypes: true,
        })
            .filter((f) => f.isFile())
            .map((f) => `${NUI_ASSETS}/${dir}/${f.name}`);
    } catch (e) {
        console.warn(/** @type {NodeJS.ErrnoException} */ (e).message);
        return [];
    }
}

/**
 * @param {string} name
 * @param {import("node:fs").ObjectEncodingOptions} options
 * @returns {string | undefined}
 */
function getFirstAssetWithNameSync(name, options) {
    try {
        return readdirSync(join(ASSETS), {
            ...options,
            withFileTypes: true,
        })
            .filter(
                (f) =>
                    f.isFile() &&
                    new RegExp(`^${name}\.[0-9A-Za-z]+$`).test(f.name),
            )
            .map((f) => `${NUI_ASSETS}/${f.name}`)[0];
    } catch (e) {
        console.warn(/** @type {NodeJS.ErrnoException} */ (e).message);
        return;
    }
}

const logo = getFirstAssetWithNameSync('logo', { encoding: 'utf8' });

const paths = {
    images: readAssetsSync('images', { encoding: 'utf8' }),
    music: readAssetsSync('music', { encoding: 'utf8' }).filter((path) =>
        path.endsWith('/obscuria-theme.mp3'),
    ),
    videos: readAssetsSync('videos', { encoding: 'utf8' }).filter(
        (path) => !path.endsWith('/waterfall.webm'),
    ),
    logo: logo ? `${logo}?v=eye-white-1` : undefined,
};

/**
 * @typedef {Object} Deferrals
 * @property {(obj: Record<string, unknown>) => void} handover
 */

/**
 * @param {string} name
 * @param {(reason: string) => void} _setKickReason
 * @param {Deferrals} deferrals
 */
function onPlayerConnecting(name, _setKickReason, deferrals) {
    /** @type {NuiHandoverData} */
    const data = {
        vars: {
            playerName: name,
            serverName: GetConvar(
                'sv_projectName',
                GetConvar('sv_hostname', ''),
            ),
        },

        paths,

        config: {
            style: GetConvar('loadscreen:style', 'obscuria'),
            background: GetConvar('loadscreen:background', 'video'),
            backgroundBrightness:
                GetConvarInt('loadscreen:backgroundBrightness', 100) / 100,
            textColor: GetConvar('loadscreen:textColor', 'rgb(244, 240, 244)'),
            primaryColor: GetConvar(
                'loadscreen:primaryColor',
                'rgb(193, 160, 202)',
            ),
            secondaryColor: GetConvar(
                'loadscreen:secondaryColor',
                'rgb(183, 175, 185)',
            ),
            shadowColor: GetConvar(
                'loadscreen:shadowColor',
                'rgba(8, 7, 11, 0.72)',
            ),
            fontFamily: GetConvar(
                'loadscreen:fontFamily',
                "'Obscuria Sans', 'Segoe UI', Arial, sans-serif",
            ),

            logo: GetConvarInt('loadscreen:logo', 1) == 1,
            serverMessage: GetConvar(
                'loadscreen:serverMessage',
                'Bem-vindo, ${playerName}',
            ),
            primaryBar: GetConvarInt('loadscreen:primaryBar', 1) == 1,
            secondaryBar: GetConvarInt('loadscreen:secondaryBar', 0) == 1,
            loadingAction: GetConvarInt('loadscreen:loadingAction', 0) == 1,
            finishingMessage: GetConvar(
                'loadscreen:finishingMessage',
                'Quase tudo pronto',
            ),
            logLine: GetConvarInt('loadscreen:logLine', 1) == 1,
            finishedMessage: GetConvar('loadscreen:finishedMessage', 'Entrada liberada'),
            finishedLine: GetConvar(
                'loadscreen:finishedLine',
                'Obscuria esta esperando por voce.',
            ),
            audioControls: GetConvarInt('loadscreen:audioControls', 1) == 1,
            audioMuteKey: GetConvar('loadscreen:audioMuteKey', 'Space'),
            rememberVolume: GetConvarInt('loadscreen:rememberVolume', 1) == 1,
            errorLog: GetConvarInt('loadscreen:errorLog', 1) == 1,

            initialAudioVolume:
                GetConvarInt('loadscreen:initialAudioVolume', 22) / 100,

            music: GetConvarInt('loadscreen:music', 1) == 1,
            musicShuffle: GetConvarInt('loadscreen:musicShuffle', 0) == 1,

            imageRate: GetConvarInt('loadscreen:imageRate', 7500),
            imageShuffle: GetConvarInt('loadscreen:imageShuffle', 0) == 1,
            videoShuffle: GetConvarInt('loadscreen:videoShuffle', 0) == 1,
            embedLink: GetConvar(
                'loadscreen:embedLink',
                'https://www.youtube.com/embed/NRBrS7OkZNY?autoplay=1&mute=1&controls=0&loop=1&playlist=NRBrS7OkZNY&modestbranding=1&rel=0&iv_load_policy=3&playsinline=1&disablekb=1',
            ),
            embedAccess: GetConvarInt('loadscreen:embedAccess', 0) == 1,
        },
    };

    deferrals.handover(/** @type {any} */ (data));
}

on('playerConnecting', onPlayerConnecting);
