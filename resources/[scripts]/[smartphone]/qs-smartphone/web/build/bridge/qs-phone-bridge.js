(function (global) {
    const BRIDGE_FLAG = '__qsPhoneBridge'
    const BRIDGE_VERSION = 1

    function isBridgeMessage(data) {
        if (!data || typeof data !== 'object') return false
        return data[BRIDGE_FLAG] === true
            && data.version === BRIDGE_VERSION
            && typeof data.appId === 'string'
            && typeof data.type === 'string'
    }

    const NON_TEXT_INPUT_TYPES = {
        button: true,
        checkbox: true,
        color: true,
        file: true,
        hidden: true,
        image: true,
        radio: true,
        range: true,
        reset: true,
        submit: true,
    }

    function isEditableTarget(target) {
        if (!target || typeof target !== 'object') return false
        if (target.isContentEditable) return true
        const tag = typeof target.tagName === 'string' ? target.tagName.toUpperCase() : ''
        if (tag === 'TEXTAREA' || tag === 'SELECT') return true
        if (tag === 'INPUT') {
            const normalizedType = String(target.type || 'text').trim().toLowerCase()
            return !NON_TEXT_INPUT_TYPES[normalizedType]
        }
        return false
    }

    function installAutoTextInputFocusGuard(emitFocus) {
        let lastFocused = null
        let rafId = null

        function postFocused(focused) {
            const next = focused === true
            if (lastFocused === next) return
            lastFocused = next
            emitFocus(next)
        }

        function onFocusIn(event) {
            postFocused(isEditableTarget(event.target))
        }

        function onFocusOut() {
            if (rafId != null) {
                window.cancelAnimationFrame(rafId)
            }
            rafId = window.requestAnimationFrame(function () {
                postFocused(isEditableTarget(document.activeElement))
                rafId = null
            })
        }

        window.addEventListener('focusin', onFocusIn, true)
        window.addEventListener('focusout', onFocusOut, true)
        postFocused(isEditableTarget(document.activeElement))

        return function destroyAutoTextInputFocusGuard() {
            window.removeEventListener('focusin', onFocusIn, true)
            window.removeEventListener('focusout', onFocusOut, true)
            if (rafId != null) {
                window.cancelAnimationFrame(rafId)
            }
            postFocused(false)
        }
    }

    function createExternalPhoneBridge(options) {
        if (!options || typeof options !== 'object') {
            throw new Error('bridge_options_required')
        }
        const appId = options.appId
        if (!appId || typeof appId !== 'string') {
            throw new Error('bridge_app_id_required')
        }

        const targetWindow = options.targetWindow || window.parent
        const targetOrigin = options.targetOrigin || '*'
        const requestTimeoutMs = typeof options.requestTimeoutMs === 'number' ? options.requestTimeoutMs : 7000
        const autoTextInputFocus = options.autoTextInputFocus !== false

        let ready = false
        let readyPayload = {}
        let resolveReadyWaiter = null
        const readyWaiter = new Promise((resolve) => {
            resolveReadyWaiter = resolve
        })
        const eventListeners = new Set()
        const readyListeners = new Set()
        const pending = new Map()

        function post(type, payload) {
            targetWindow.postMessage({
                [BRIDGE_FLAG]: true,
                version: BRIDGE_VERSION,
                appId,
                type,
                payload,
            }, targetOrigin)
        }

        const destroyAutoTextInputFocusGuard = autoTextInputFocus
            ? installAutoTextInputFocusGuard(function (focused) {
                post('app:event', { event: 'phone.input.focus', data: { focused: focused } })
            })
            : null

        function generateRequestId() {
            return `${Date.now()}-${Math.random().toString(16).slice(2)}`
        }

        function onMessage(event) {
            if (!isBridgeMessage(event.data) || event.data.appId !== appId) {
                const plain = event.data
                if (plain && plain.type === 'phone.theme.changed' && plain.source === 'qs-smartphone') {
                    eventListeners.forEach((listener) => listener('phone.theme.changed', plain.data))
                }
                return
            }

            if (event.data.type === 'phone:ready') {
                ready = true
                readyPayload = event.data.payload || {}
                if (resolveReadyWaiter) {
                    resolveReadyWaiter()
                    resolveReadyWaiter = null
                }
                readyListeners.forEach((listener) => listener(readyPayload))
                post('app:ready')
                return
            }

            if (event.data.type === 'phone:event') {
                const payload = event.data.payload || {}
                eventListeners.forEach((listener) => listener(payload.event, payload.data))
                return
            }

            if (event.data.type === 'phone:response') {
                const payload = event.data.payload || {}
                const requestId = payload.requestId
                if (!requestId || !pending.has(requestId)) return

                const req = pending.get(requestId)
                pending.delete(requestId)
                clearTimeout(req.timeoutId)

                if (payload.ok) {
                    req.resolve(payload.data)
                } else {
                    req.reject(new Error(payload.error || 'bridge_request_failed'))
                }
            }
        }

        window.addEventListener('message', onMessage)

        function request(method, data, timeoutMs) {
            const timeout = typeof timeoutMs === 'number' ? timeoutMs : requestTimeoutMs
            const requestId = generateRequestId()

            return new Promise((resolve, reject) => {
                let cancelled = false
                const timeoutId = setTimeout(() => {
                    cancelled = true
                    pending.delete(requestId)
                    reject(new Error('bridge_request_timeout'))
                }, timeout)
                if (cancelled) return
                pending.set(requestId, { resolve, reject, timeoutId })
                post('app:request', { requestId, method, data })
            })
        }

        return {
            isReady() {
                return ready
            },
            onReady(listener) {
                readyListeners.add(listener)
                if (ready) listener(readyPayload)
                return () => readyListeners.delete(listener)
            },
            onEvent(listener) {
                eventListeners.add(listener)
                return () => eventListeners.delete(listener)
            },
            emit(event, data) {
                post('app:event', { event, data })
            },
            request,
            destroy() {
                if (destroyAutoTextInputFocusGuard) {
                    destroyAutoTextInputFocusGuard()
                }
                window.removeEventListener('message', onMessage)
                pending.forEach((entry) => {
                    clearTimeout(entry.timeoutId)
                    entry.reject(new Error('bridge_destroyed'))
                })
                pending.clear()
                readyListeners.clear()
                eventListeners.clear()
            },
        }
    }

    function createPhoneBridgeFacade(bridge, config) {
        const requestTimeoutMs = config && typeof config.requestTimeoutMs === 'number'
            ? config.requestTimeoutMs
            : 7000

        return {
            onReady(listener) {
                return bridge.onReady(listener)
            },
            onEvent(listener) {
                return bridge.onEvent(listener)
            },
            async getPhoneState() {
                return bridge.request('phone.state.get', {}, requestTimeoutMs)
            },
            async openPhoneApp(targetAppId) {
                return bridge.request('phone.app.open', { appId: targetAppId }, requestTimeoutMs)
            },
            async closeCurrentPhoneApp() {
                return bridge.request('phone.app.close', {}, requestTimeoutMs)
            },
            async getThemeMode() {
                const payload = await bridge.request('phone.theme.get', {}, requestTimeoutMs)
                if (payload && typeof payload === 'object') {
                    return {
                        mode: payload.mode === 'dark' ? 'dark' : 'light',
                        darkMode: payload.mode === 'dark' || payload.darkMode === true,
                    }
                }
                return { mode: 'light', darkMode: false }
            },
            async getPhoneLocale() {
                const payload = await bridge.request('phone.i18n.getLocale', {}, requestTimeoutMs)
                if (payload && typeof payload === 'object' && typeof payload.language === 'string' && payload.language.trim() !== '') {
                    return payload.language
                }
                return 'en'
            },
            async translateText(translationKey, options) {
                if (!translationKey) return ''
                const translated = await bridge.request('phone.i18n.translate', {
                    key: translationKey,
                    options: options || {},
                }, requestTimeoutMs)
                if (typeof translated === 'string') return translated
                return translationKey
            },
            async showToastNotification(payload) {
                const data = payload || {}
                return bridge.request('phone.ui.notify', {
                    title: data.title || 'Notification',
                    subtitle: data.subtitle,
                    text: data.text || '',
                    closeTimeout: data.closeTimeout,
                }, requestTimeoutMs)
            },
            async openTextPrompt(payload) {
                const data = payload || {}
                const response = await bridge.request('phone.ui.promptText', {
                    title: data.title || '',
                    message: data.message || '',
                    placeholder: data.placeholder || '',
                    defaultValue: data.defaultValue || '',
                }, requestTimeoutMs)
                return response && typeof response === 'object' ? response.value ?? null : null
            },
            async openOptionPicker(payload) {
                const data = payload || {}
                const response = await bridge.request('phone.ui.pickOption', {
                    title: data.title || '',
                    options: Array.isArray(data.options) ? data.options : [],
                }, requestTimeoutMs)
                if (response && typeof response === 'object') {
                    return { key: response.key ?? null }
                }
                return { key: null }
            },
            async startRecorder() {
                return bridge.request('phone.recorder.start', {}, requestTimeoutMs)
            },
            async stopRecorder() {
                const response = await bridge.request('phone.recorder.stop', {}, requestTimeoutMs)
                return {
                    url: response && typeof response === 'object' ? response.url || '' : '',
                }
            },
            async pickGalleryMedia(payload) {
                const pickTimeoutMs = 120000
                const data = payload || {}
                const mf = data.mediaFilter
                const mediaFilter = mf === 'photos' || mf === 'videos' || mf === 'all' ? mf : 'all'
                return bridge.request('phone.ui.pickGallery', { mediaFilter }, pickTimeoutMs)
            },
            async pickCameraMedia() {
                const pickTimeoutMs = 120000
                return bridge.request('phone.ui.pickCamera', {}, pickTimeoutMs)
            },
            async pickGif() {
                const pickTimeoutMs = 120000
                return bridge.request('phone.ui.pickGif', {}, pickTimeoutMs)
            },
            async showDynamicIsland(payload) {
                const data = payload || {}
                return bridge.request('phone.ui.island.show', data, requestTimeoutMs)
            },
            async updateDynamicIsland(id, patch) {
                const data = Object.assign({}, patch || {}, { id: id })
                return bridge.request('phone.ui.island.update', data, requestTimeoutMs)
            },
            async hideDynamicIsland(id) {
                return bridge.request('phone.ui.island.hide', { id: id }, requestTimeoutMs)
            },
            async getDynamicIsland(id) {
                return bridge.request('phone.ui.island.get', { id: id }, requestTimeoutMs)
            },
        }
    }

    global.QSPhoneBridge = {
        create(options) {
            const bridge = createExternalPhoneBridge(options || {})
            const facade = createPhoneBridgeFacade(bridge, options || {})
            return { bridge, api: facade }
        },
        createExternalPhoneBridge,
        createPhoneBridgeFacade,
        version: '1.0.0',
    }
})(window)
