(function () {
    function resolveResourceName() {
        if (typeof window.GetParentResourceName === 'function') {
            return window.GetParentResourceName();
        }
        return 'qs-smartphone';
    }

    async function postNui(eventName, payload) {
        const resourceName = resolveResourceName();
        const response = await fetch(`https://${resourceName}/${eventName}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(payload || {}),
        });

        if (!response.ok) {
            throw new Error(`NUI request failed: ${eventName} (${response.status})`);
        }

        return response.json();
    }

    function readPresignedUrl(payload) {
        if (!payload) return '';
        if (payload.ok === false && typeof payload.error === 'string') {
            throw new Error(payload.error);
        }
        if (typeof payload.presignedUrl === 'string') return payload.presignedUrl;
        return '';
    }

    async function getPresignedUploadUrl(fileType) {
        const callbackData = await postNui('camera:upload:presigned', { fileType });
        const presignedUrl = readPresignedUrl(callbackData);
        if (!presignedUrl) {
            console.error('Upload URL is missing in backend response. Did you set fivemesh.apiKey or fivemanage.token in the server/webhooks.lua file?', callbackData);
            throw new Error('Upload URL is missing in backend response. Did you set fivemesh.apiKey or fivemanage.token in the server/webhooks.lua file?');
        }
        return {
            url: presignedUrl,
            provider: typeof callbackData?.provider === 'string' ? callbackData.provider : 'unknown',
        };
    }

    async function uploadFormData(uploadUrl, blob, fileName) {
        const formData = new FormData();
        formData.append('file', blob, fileName);

        const response = await fetch(uploadUrl, {
            method: 'POST',
            body: formData,
        });

        const responseText = await response.text();
        let parsed = null;
        if (responseText) {
            try {
                parsed = JSON.parse(responseText);
            } catch (_) {
                parsed = responseText;
            }
        }

        if (!response.ok) {
            // FiveMesh errors look like { success: false, error: { code, message } }
            const apiMessage = parsed && parsed.error && typeof parsed.error.message === 'string' ? parsed.error.message : null;
            throw new Error(apiMessage || `Upload failed: ${response.status} ${response.statusText}`);
        }

        if (parsed && parsed.success === false) {
            const apiMessage = parsed.error && typeof parsed.error.message === 'string' ? parsed.error.message : 'Upload rejected by the media host';
            throw new Error(apiMessage);
        }

        return parsed;
    }

    function firstResult(response) {
        if (!response || !Array.isArray(response.results) || !response.results.length) return null;
        const entry = response.results[0];
        if (!entry) return null;
        return entry.object || entry;
    }

    /**
     * Reads the public file URL out of the host response.
     * FiveManage  -> { data: { id, url } }
     * FiveMesh    -> { success: true, object: { key, publicUrl } } or { results: [ ... ] }
     */
    function extractUploadedUrl(response) {
        if (!response || typeof response !== 'object') return '';
        const candidates = [
            response.data && response.data.url,
            response.object && response.object.publicUrl,
            response.object && response.object.url,
            (firstResult(response) || {}).publicUrl,
            (firstResult(response) || {}).url,
            response.publicUrl,
            response.url,
        ];
        for (const candidate of candidates) {
            if (typeof candidate === 'string' && candidate.trim()) return candidate.trim();
        }
        return '';
    }

    function extractUploadedId(response) {
        if (!response || typeof response !== 'object') return null;
        const candidates = [
            response.data && response.data.id,
            response.object && response.object.key,
            (firstResult(response) || {}).key,
            response.id,
        ];
        for (const candidate of candidates) {
            if (typeof candidate === 'string' && candidate.trim()) return candidate.trim();
            if (typeof candidate === 'number') return candidate;
        }
        return null;
    }

    function randomSuffix() {
        return Math.random().toString(36).slice(2, 8);
    }

    async function uploadByType(blob, fileName, fileType, extension) {
        if (!(blob instanceof Blob)) {
            throw new Error(`customUpload${fileType[0].toUpperCase() + fileType.slice(1)} expected a Blob`);
        }

        // FiveMesh stores files by name, so keep names unique to avoid overwriting an earlier upload.
        const baseName = (fileName || `${fileType}-${Date.now()}`).replace(/\.[a-z0-9]+$/i, '');
        const resolvedFileName = `${baseName}-${randomSuffix()}.${extension}`;

        const { url: uploadUrl, provider } = await getPresignedUploadUrl(fileType);
        const uploadResponse = await uploadFormData(uploadUrl, blob, resolvedFileName);
        let url = extractUploadedUrl(uploadResponse);

        if (!url) {
            if (provider === 'fivemesh') {
                console.error('FiveMesh did not return a publicUrl for the upload', uploadResponse);
                throw new Error('FiveMesh did not return a public file URL');
            }
            // Legacy FiveManage behaviour: the presigned URL doubles as the file URL.
            url = uploadUrl;
        }

        return {
            id: extractUploadedId(uploadResponse),
            url,
            provider,
            uploadUrl,
            response: uploadResponse,
        };
    }

    window.customUploadImage = async function (blob, fileName) {
        return uploadByType(blob, fileName, 'image', 'webp');
    };

    window.customUploadVideo = async function (blob, fileName) {
        return uploadByType(blob, fileName, 'video', 'webm');
    };

    window.customUploadAudio = async function (blob, fileName) {
        const extMatch = /\.([a-z0-9]+)$/i.exec(fileName || '');
        const extension = extMatch ? extMatch[1].toLowerCase() : 'webm';
        return uploadByType(blob, fileName, 'audio', extension);
    };
})();
