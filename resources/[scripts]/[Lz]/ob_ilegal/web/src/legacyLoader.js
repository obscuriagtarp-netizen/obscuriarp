const runtimeFiles = ['audio.js', 'class-variants.js', 'script.js'];
const runtimeVersion = 'react-20260806-4';

function loadScript(source) {
    return new Promise((resolve, reject) => {
        const existing = document.querySelector(`script[data-ob-runtime="${source}"]`);
        if (existing) {
            if (existing.dataset.loaded === 'true') resolve();
            else existing.addEventListener('load', resolve, { once: true });
            return;
        }

        const script = document.createElement('script');
        script.dataset.obRuntime = source;
        const runtimeUrl = new URL(`${import.meta.env.DEV ? './' : '../'}${source}`, window.location.href);
        runtimeUrl.searchParams.set('v', runtimeVersion);
        script.src = runtimeUrl.href;
        script.addEventListener('load', () => {
            script.dataset.loaded = 'true';
            resolve();
        }, { once: true });
        script.addEventListener('error', reject, { once: true });
        document.body.appendChild(script);
    });
}

export function loadLegacyRuntime() {
    if (!window.__obIlegalRuntime) {
        window.__obIlegalRuntime = runtimeFiles.reduce(
            (chain, source) => chain.then(() => loadScript(source)),
            Promise.resolve(),
        );
    }
    return window.__obIlegalRuntime;
}
