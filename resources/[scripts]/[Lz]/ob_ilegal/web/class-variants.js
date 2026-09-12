(function () {
    const TAU = Math.PI * 2;

    const themes = {
        bruxa: { accent: '#c078ff', pale: '#f0dcff', dark: '#311443' },
        vampiro: { accent: '#e63c58', pale: '#ffd9de', dark: '#460d19' },
        curandeira: { accent: '#63d985', pale: '#ddffe5', dark: '#123b22' },
    };
    const previousSequences = new Map();

    function clamp(value, minimum, maximum) {
        return Math.min(maximum, Math.max(minimum, value));
    }

    function distance(first, second) {
        return Math.hypot(first.x - second.x, first.y - second.y);
    }

    function shuffledIndexes(length) {
        const indexes = Array.from({ length }, (_, index) => index);
        for (let index = indexes.length - 1; index > 0; index -= 1) {
            const next = Math.floor(Math.random() * (index + 1));
            [indexes[index], indexes[next]] = [indexes[next], indexes[index]];
        }
        return indexes;
    }

    function uniqueShuffledIndexes(length, count, key) {
        let indexes;
        let signature;
        const previous = previousSequences.get(key);
        for (let attempt = 0; attempt < 8; attempt += 1) {
            indexes = shuffledIndexes(length).slice(0, count);
            signature = indexes.join(':');
            if (signature !== previous) break;
        }
        previousSequences.set(key, signature);
        return indexes;
    }

    function point(normalized, width, height) {
        return { x: normalized[0] * width, y: normalized[1] * height };
    }

    function strokePath(context, points) {
        if (!points || points.length < 2) return;
        context.beginPath();
        context.moveTo(points[0].x, points[0].y);
        for (let index = 1; index < points.length; index += 1) {
            context.lineTo(points[index].x, points[index].y);
        }
        context.stroke();
    }

    function closestPathDistance(cursor, points) {
        let closest = Number.POSITIVE_INFINITY;
        for (let index = 1; index < points.length; index += 1) {
            const start = points[index - 1];
            const end = points[index];
            const dx = end.x - start.x;
            const dy = end.y - start.y;
            const length = (dx * dx) + (dy * dy);
            const ratio = length === 0 ? 0 : clamp((((cursor.x - start.x) * dx) + ((cursor.y - start.y) * dy)) / length, 0, 1);
            closest = Math.min(closest, distance(cursor, { x: start.x + (dx * ratio), y: start.y + (dy * ratio) }));
        }
        return closest;
    }

    function drawDiamond(context, x, y, radius, fill, stroke) {
        context.save();
        context.translate(x, y);
        context.rotate(Math.PI / 4);
        context.fillStyle = fill;
        context.strokeStyle = stroke;
        context.lineWidth = 1.5;
        context.fillRect(-radius, -radius, radius * 2, radius * 2);
        context.strokeRect(-radius, -radius, radius * 2, radius * 2);
        context.restore();
    }

    function createWitchLock(api) {
        const shapes = [
            [[0.17, 0.73], [0.31, 0.22], [0.49, 0.67], [0.68, 0.22], [0.83, 0.73], [0.50, 0.47], [0.17, 0.47]],
            [[0.20, 0.24], [0.20, 0.77], [0.73, 0.77], [0.48, 0.51], [0.76, 0.24], [0.20, 0.24]],
            [[0.18, 0.53], [0.36, 0.20], [0.72, 0.24], [0.83, 0.55], [0.60, 0.80], [0.26, 0.73], [0.18, 0.53], [0.52, 0.52]],
            [[0.18, 0.76], [0.50, 0.18], [0.82, 0.76], [0.50, 0.58], [0.18, 0.76], [0.82, 0.76]],
            [[0.22, 0.22], [0.22, 0.78], [0.50, 0.52], [0.78, 0.78], [0.78, 0.22], [0.50, 0.48], [0.22, 0.22]],
            [[0.24, 0.82], [0.24, 0.20], [0.76, 0.20], [0.24, 0.46], [0.66, 0.46]],
            [[0.20, 0.20], [0.76, 0.20], [0.42, 0.48], [0.78, 0.48], [0.24, 0.80], [0.80, 0.80]],
            [[0.22, 0.20], [0.78, 0.20], [0.50, 0.50], [0.78, 0.80], [0.22, 0.80], [0.50, 0.50], [0.22, 0.20]],
            [[0.18, 0.27], [0.35, 0.47], [0.50, 0.18], [0.65, 0.47], [0.82, 0.27], [0.50, 0.66], [0.50, 0.84]],
            [[0.50, 0.15], [0.75, 0.38], [0.59, 0.38], [0.59, 0.81], [0.41, 0.81], [0.41, 0.38], [0.25, 0.38], [0.50, 0.15]],
            [[0.20, 0.76], [0.38, 0.20], [0.50, 0.52], [0.62, 0.20], [0.80, 0.76], [0.50, 0.66], [0.20, 0.76]],
            [[0.19, 0.34], [0.50, 0.17], [0.81, 0.34], [0.66, 0.78], [0.34, 0.78], [0.19, 0.34], [0.50, 0.50], [0.81, 0.34]],
        ];
        const ritualCount = 3;
        const shapeOrder = uniqueShuffledIndexes(shapes.length, ritualCount, 'witch-lock');
        const lineTolerance = clamp(Number(api.options.lineTolerance) || 18, 12, 26);
        let sigilIndex = 0;
        let attempts = Number(api.options.attempts) || 3;
        let drawing = false;
        let trace = [];
        let anchorIndex = 1;
        let guideHits = 0;
        let guideChecks = 0;

        function anchors() {
            const fitted = api.fit();
            const shape = shapes[shapeOrder[Math.min(sigilIndex, ritualCount - 1)]] || shapes[0];
            return shape.map((item) => point(item, fitted.width, fitted.height));
        }

        function fail(reason) {
            drawing = false;
            trace = [];
            anchorIndex = 1;
            guideHits = 0;
            guideChecks = 0;
            attempts -= 1;
            api.flash('wrong', 380);
            api.state(reason);
            api.secondary(`${attempts} TENTATIVAS`);
            if (attempts <= 0) api.finish(false, 'LACRE REAGIU AO RITUAL');
        }

        return {
            start() {
                api.progress('SIGILO 1 / 3');
                api.secondary('TRAMA ESTÁVEL');
                api.state('TRACE O PRIMEIRO LACRE');
            },
            pointerDown(event) {
                const positions = anchors();
                const cursor = api.position(event);
                if (distance(cursor, positions[0]) > 34) {
                    fail('INICIE NO FOCO RÚNICO');
                    return;
                }
                api.capture(event);
                drawing = true;
                trace = [cursor];
                anchorIndex = 1;
                guideHits = 1;
                guideChecks = 1;
                api.state('MANTENHA O TRAÇO NO LACRE');
            },
            pointerMove(event) {
                if (!drawing) return;
                const positions = anchors();
                const cursor = api.position(event);
                const previous = trace[trace.length - 1];
                if (previous && distance(previous, cursor) < 2) return;
                if (closestPathDistance(cursor, positions) > lineTolerance) {
                    fail('VOCÊ SAIU DO TRAÇADO');
                    return;
                }
                trace.push(cursor);
                guideChecks += 1;
                if (closestPathDistance(cursor, positions) <= 24) guideHits += 1;
                while (anchorIndex < positions.length && distance(cursor, positions[anchorIndex]) <= 31) anchorIndex += 1;
            },
            pointerUp() {
                if (!drawing) return;
                drawing = false;
                const positions = anchors();
                const accuracy = guideHits / Math.max(1, guideChecks);
                if (anchorIndex < positions.length || accuracy < 0.86) {
                    fail('SIGILO CORROMPIDO');
                    return;
                }
                sigilIndex += 1;
                trace = [];
                api.flash('hit', 420);
                if (sigilIndex >= ritualCount) {
                    api.state('LACRE DISSOLVIDO');
                    window.setTimeout(() => api.finish(true), 620);
                    return;
                }
                api.progress(`SIGILO ${sigilIndex + 1} / ${ritualCount}`);
                api.state('PRÓXIMO LACRE REVELADO');
            },
            render(now) {
                const { context, width, height } = api.fit();
                const positions = anchors();
                context.clearRect(0, 0, width, height);
                context.save();
                context.lineCap = 'round';
                context.lineJoin = 'round';
                context.setLineDash([4, 7]);
                context.strokeStyle = 'rgba(214, 181, 235, 0.34)';
                context.lineWidth = 2;
                strokePath(context, positions);
                context.setLineDash([]);
                positions.forEach((position, index) => {
                    const active = index === 0 || index === anchorIndex;
                    const pulse = active ? 5 + (Math.sin(now / 150) * 1.5) : 3;
                    drawDiamond(context, position.x, position.y, pulse, active ? themes.bruxa.pale : themes.bruxa.dark, themes.bruxa.accent);
                });
                if (trace.length > 1) {
                    context.strokeStyle = themes.bruxa.accent;
                    context.lineWidth = 7;
                    context.globalAlpha = 0.36;
                    strokePath(context, trace);
                    context.globalAlpha = 1;
                    context.strokeStyle = themes.bruxa.pale;
                    context.lineWidth = 2.5;
                    strokePath(context, trace);
                }
                context.restore();
            },
        };
    }

    function createVampireLock(api) {
        const chamberCount = clamp(Math.round(Number(api.options.chambers) || 4), 3, 6);
        const chambers = Array.from({ length: chamberCount }, () => ({
            pressure: 0,
            target: 0.42 + (Math.random() * 0.38),
            sealed: false,
        }));
        let current = 0;
        let attempts = Number(api.options.attempts) || 3;
        let holding = false;
        let lastNow = performance.now();

        function fail(reason) {
            holding = false;
            chambers[current].pressure = 0;
            attempts -= 1;
            api.flash('wrong', 380);
            api.state(reason);
            api.secondary(`${attempts} TENTATIVAS`);
            if (attempts <= 0) api.finish(false, 'PRESSÃO HEMÁTICA ROMPIDA');
        }

        return {
            start() {
                api.progress(`CÂMARA 1 / ${chamberCount}`);
                api.secondary('FLUXO CONTIDO');
                api.state('PRESSIONE A PRIMEIRA CÂMARA');
            },
            pointerDown(event) {
                const { width } = api.fit();
                const cursor = api.position(event);
                const selected = clamp(Math.floor(cursor.x / (width / chamberCount)), 0, chamberCount - 1);
                if (selected !== current) {
                    fail('O SANGUE TOMOU A VÁLVULA ERRADA');
                    return;
                }
                api.capture(event);
                holding = true;
                api.state('SOLTE NA FAIXA DE PRESSÃO');
            },
            pointerUp() {
                if (!holding) return;
                holding = false;
                const chamber = chambers[current];
                const tolerance = Number(api.options.tolerance) || 0.075;
                if (Math.abs(chamber.pressure - chamber.target) > tolerance) {
                    fail(chamber.pressure > chamber.target ? 'PRESSÃO EXCESSIVA' : 'PRESSÃO INSUFICIENTE');
                    return;
                }
                chamber.sealed = true;
                chamber.pressure = chamber.target;
                current += 1;
                api.flash('hit', 320);
                if (current >= chamberCount) {
                    api.state('CILINDRO HEMÁTICO ABERTO');
                    window.setTimeout(() => api.finish(true), 620);
                    return;
                }
                api.progress(`CÂMARA ${current + 1} / ${chamberCount}`);
                api.state('ALIMENTE A PRÓXIMA VÁLVULA');
            },
            render(now) {
                const { context, width, height } = api.fit();
                const elapsed = Math.min(40, now - lastNow);
                lastNow = now;
                if (holding) {
                    chambers[current].pressure = Math.min(1, chambers[current].pressure + (elapsed * 0.00062));
                    if (chambers[current].pressure >= 1) fail('A CÂMARA SE ROMPEU');
                }
                context.clearRect(0, 0, width, height);
                const gap = width * 0.035;
                const chamberWidth = (width - (gap * (chamberCount + 1))) / chamberCount;
                chambers.forEach((chamber, index) => {
                    const x = gap + (index * (chamberWidth + gap));
                    const y = height * 0.12;
                    const h = height * 0.72;
                    context.fillStyle = '#10090c';
                    context.strokeStyle = index === current ? themes.vampiro.accent : 'rgba(181, 153, 132, 0.38)';
                    context.lineWidth = index === current ? 2.5 : 1.5;
                    context.fillRect(x, y, chamberWidth, h);
                    context.strokeRect(x, y, chamberWidth, h);
                    const targetY = y + (h * (1 - chamber.target));
                    context.fillStyle = 'rgba(255, 205, 212, 0.25)';
                    context.fillRect(x + 2, targetY - 5, chamberWidth - 4, 10);
                    const liquidHeight = h * chamber.pressure;
                    const liquidY = y + h - liquidHeight;
                    context.fillStyle = chamber.sealed ? '#d43b54' : '#8f1028';
                    context.fillRect(x + 4, liquidY, chamberWidth - 8, liquidHeight);
                    context.strokeStyle = themes.vampiro.pale;
                    context.beginPath();
                    context.moveTo(x + 4, liquidY);
                    context.lineTo(x + chamberWidth - 4, liquidY);
                    context.stroke();
                    const pulse = 3 + ((Math.sin((now / 120) + index) + 1) * 2);
                    context.fillStyle = themes.vampiro.pale;
                    context.beginPath();
                    context.arc(x + (chamberWidth / 2), y + h + 13, pulse, 0, TAU);
                    context.fill();
                });
            },
        };
    }

    function createHealerLock(api) {
        const normalizedNodes = [
            [0.12, 0.80], [0.29, 0.61], [0.20, 0.35], [0.47, 0.45],
            [0.62, 0.22], [0.72, 0.55], [0.88, 0.30],
        ];
        const sequence = [0, 1, 2, 3, 4, 5, 6];
        let current = 0;
        let attempts = Number(api.options.attempts) || 3;

        function fail() {
            attempts -= 1;
            api.flash('wrong', 360);
            api.state('A RAIZ RECUOU');
            api.secondary(`${attempts} TENTATIVAS`);
            if (attempts <= 0) api.finish(false, 'RAÍZES RESSECADAS');
        }

        return {
            start() {
                api.progress(`BROTO 1 / ${sequence.length}`);
                api.secondary('SEIVA ESTÁVEL');
                api.state('DESPERTE O PRIMEIRO BROTO');
            },
            pointerDown(event) {
                const { width, height } = api.fit();
                const cursor = api.position(event);
                const points = normalizedNodes.map((item) => point(item, width, height));
                let selected = -1;
                points.forEach((node, index) => {
                    if (distance(cursor, node) <= 25) selected = index;
                });
                if (selected !== sequence[current]) {
                    fail();
                    return;
                }
                current += 1;
                api.flash('hit', 280);
                if (current >= sequence.length) {
                    api.state('RAÍZES LIBERARAM O FECHO');
                    window.setTimeout(() => api.finish(true), 620);
                    return;
                }
                api.progress(`BROTO ${current + 1} / ${sequence.length}`);
                api.state('A RAIZ PROCURA O PRÓXIMO BROTO');
            },
            render(now) {
                const { context, width, height } = api.fit();
                const points = normalizedNodes.map((item) => point(item, width, height));
                context.clearRect(0, 0, width, height);
                context.save();
                context.lineCap = 'round';
                context.lineJoin = 'round';
                for (let index = 1; index < points.length; index += 1) {
                    context.strokeStyle = index < current ? themes.curandeira.accent : 'rgba(117, 152, 103, 0.24)';
                    context.lineWidth = index < current ? 7 : 2;
                    context.beginPath();
                    context.moveTo(points[index - 1].x, points[index - 1].y);
                    const middleX = (points[index - 1].x + points[index].x) / 2;
                    context.bezierCurveTo(middleX, points[index - 1].y, middleX, points[index].y, points[index].x, points[index].y);
                    context.stroke();
                }
                points.forEach((node, index) => {
                    const isNext = index === sequence[current];
                    const awakened = index < current;
                    const radius = isNext ? 10 + (Math.sin(now / 150) * 2) : 7;
                    context.fillStyle = awakened ? themes.curandeira.pale : (isNext ? '#f1ffe9' : themes.curandeira.dark);
                    context.strokeStyle = themes.curandeira.accent;
                    context.lineWidth = isNext ? 3 : 1.5;
                    context.beginPath();
                    for (let petal = 0; petal < 6; petal += 1) {
                        const angle = (petal / 6) * TAU;
                        const x = node.x + (Math.cos(angle) * radius);
                        const y = node.y + (Math.sin(angle) * radius);
                        if (petal === 0) context.moveTo(x, y); else context.lineTo(x, y);
                    }
                    context.closePath();
                    context.fill();
                    context.stroke();
                });
                context.restore();
            },
        };
    }

    function drawRuneGlyph(context, x, y, size, index, color) {
        context.save();
        context.translate(x, y);
        context.rotate((index % 4) * (Math.PI / 4));
        context.strokeStyle = color;
        context.lineWidth = 1.6;
        context.beginPath();
        context.moveTo(-size, size);
        context.lineTo(0, -size);
        context.lineTo(size, size);
        if (index % 2 === 0) {
            context.moveTo(-size * 0.62, size * 0.25);
            context.lineTo(size * 0.62, size * 0.25);
        } else {
            context.moveTo(0, -size);
            context.lineTo(0, size);
        }
        context.stroke();
        context.restore();
    }

    function createWitchVault(api) {
        const runeCount = clamp(Math.round(Number(api.options.rings) || 4), 3, 6);
        const runeSlots = [
            [0.50, 0.145], [0.815, 0.335], [0.775, 0.705],
            [0.50, 0.855], [0.225, 0.705], [0.185, 0.335],
        ];
        const sequence = uniqueShuffledIndexes(runeSlots.length, runeCount, 'witch-vault');

        const sealed = new Set();
        let current = 0;
        let attempts = Number(api.options.attempts) || 4;
        let awakened = false;
        let hovered = -1;
        let lastResonanceAt = 0;

        function positions(width, height) {
            return runeSlots.map((item) => point(item, width, height));
        }

        function selectedRune(cursor, width, height) {
            const runes = positions(width, height);
            const radius = Math.min(width, height) * 0.115;
            let selected = -1;
            let nearest = Number.POSITIVE_INFINITY;
            runes.forEach((rune, index) => {
                const runeDistance = distance(cursor, rune);
                if (runeDistance < radius && runeDistance < nearest) {
                    selected = index;
                    nearest = runeDistance;
                }
            });
            return selected;
        }

        function resonance(index) {
            if (index < 0 || sealed.has(index)) return 0.05;
            const target = sequence[current];
            const difference = Math.abs(index - target);
            const circularSteps = Math.min(difference, runeSlots.length - difference);
            return clamp(1 - (circularSteps * 0.24), 0.20, 1);
        }

        function playResonance(now, force = false) {
            if (!awakened || hovered < 0 || sealed.has(hovered)) return;
            if (!force && now - lastResonanceAt < 620) return;
            lastResonanceAt = now;
            api.sound?.('runeProbe', { strength: resonance(hovered) });
        }

        return {
            start() {
                api.progress(`RESSONÂNCIA 1 / ${runeCount}`);
                api.secondary('NÚCLEO ADORMECIDO');
                api.state('CLIQUE NO NÚCLEO PARA DESPERTAR A MATRIZ');
            },
            pointerDown(event) {
                const { width, height } = api.fit();
                const cursor = api.position(event);
                const center = { x: width / 2, y: height / 2 };
                const baseRadius = Math.min(width, height);

                if (!awakened) {
                    if (distance(cursor, center) > baseRadius * 0.14) {
                        api.state('DESPERTE O NÚCLEO CENTRAL PRIMEIRO');
                        return;
                    }
                    awakened = true;
                    api.sound?.('awaken');
                    api.flash('hit', 420);
                    api.secondary('ESCUTE ANTES DE ESCOLHER');
                    api.state('PASSE O CURSOR SOBRE CADA RUNA');
                    return;
                }

                const selected = selectedRune(cursor, width, height);
                if (selected < 0 || sealed.has(selected)) return;
                if (selected !== sequence[current]) {
                    attempts -= 1;
                    api.flash('wrong', 340);
                    api.state('A RUNA RESPONDEU EM DISSONÂNCIA');
                    api.secondary(`${attempts} TENTATIVAS`);
                    if (attempts <= 0) api.finish(false, 'RESSONÂNCIA RÚNICA ROMPIDA');
                    return;
                }

                sealed.add(selected);
                current += 1;
                hovered = -1;
                api.flash('hit', 420);
                if (current >= runeCount) {
                    api.state('O NÚCLEO RECONHECEU TODAS AS RUNAS');
                    window.setTimeout(() => api.finish(true), 680);
                    return;
                }
                api.progress(`RESSONÂNCIA ${current + 1} / ${runeCount}`);
                api.secondary('A FREQUÊNCIA MUDOU');
                api.state('ESCUTE NOVAMENTE AS RUNAS LIVRES');
            },
            pointerMove(event) {
                if (!awakened) return;
                const { width, height } = api.fit();
                const selected = selectedRune(api.position(event), width, height);
                if (selected === hovered) return;
                hovered = selected;
                if (hovered >= 0 && !sealed.has(hovered)) {
                    playResonance(performance.now(), true);
                    api.secondary('OUÇA A RESSONÂNCIA');
                }
            },
            render(now) {
                const { context, width, height } = api.fit();
                const centerX = width / 2;
                const centerY = height / 2;
                const baseRadius = Math.min(width, height);
                const runes = positions(width, height);
                context.clearRect(0, 0, width, height);
                playResonance(now);

                context.save();
                context.globalCompositeOperation = 'lighter';
                runes.forEach((rune, index) => {
                    const isHovered = index === hovered && !sealed.has(index);
                    const isSealed = sealed.has(index);
                    context.strokeStyle = isSealed
                        ? 'rgba(242, 224, 255, 0.92)'
                        : (isHovered ? 'rgba(192, 120, 255, 0.78)' : 'rgba(133, 82, 171, 0.12)');
                    context.lineWidth = isHovered || isSealed ? 3 : 1;
                    context.beginPath();
                    context.arc(rune.x, rune.y, baseRadius * (isHovered ? 0.095 : 0.082), 0, TAU);
                    context.stroke();
                    if (isHovered) {
                        context.strokeStyle = 'rgba(192, 120, 255, 0.28)';
                        context.beginPath();
                        context.moveTo(centerX, centerY);
                        context.lineTo(rune.x, rune.y);
                        context.stroke();
                    }
                });

                const pulse = awakened ? 13 + (Math.sin(now / 180) * 3) : 10 + (Math.sin(now / 260) * 2);
                context.fillStyle = awakened ? 'rgba(192, 120, 255, 0.24)' : 'rgba(132, 96, 158, 0.16)';
                context.beginPath();
                context.arc(centerX, centerY, pulse * 2.2, 0, TAU);
                context.fill();
                drawDiamond(
                    context,
                    centerX,
                    centerY,
                    pulse,
                    awakened ? themes.bruxa.pale : themes.bruxa.dark,
                    themes.bruxa.accent
                );
                context.restore();
            },
        };
    }

    function createVampireVault(api) {
        const nodes = [
            [0.10, 0.50], [0.27, 0.22], [0.27, 0.75], [0.48, 0.15],
            [0.48, 0.48], [0.48, 0.82], [0.70, 0.25], [0.70, 0.70],
            [0.90, 0.50],
        ];
        const links = [[0, 1], [0, 2], [1, 3], [1, 4], [2, 4], [2, 5], [3, 6], [4, 6], [4, 7], [5, 7], [6, 8], [7, 8]];
        const routes = [
            [0, 1, 3, 6, 8], [0, 1, 4, 6, 8], [0, 1, 4, 7, 8],
            [0, 2, 4, 6, 8], [0, 2, 4, 7, 8], [0, 2, 5, 7, 8],
        ];
        const route = routes[shuffledIndexes(routes.length)[0]];
        let current = 0;
        let attempts = Number(api.options.attempts) || 3;

        return {
            start() {
                api.progress(`VÁLVULA 1 / ${route.length}`);
                api.secondary('PRESSÃO ESTÁVEL');
                api.state('ATIVE O RESERVATÓRIO DE SANGUE');
            },
            pointerDown(event) {
                const { width, height } = api.fit();
                const cursor = api.position(event);
                const positions = nodes.map((item) => point(item, width, height));
                let selected = -1;
                positions.forEach((node, index) => {
                    if (distance(cursor, node) <= 22) selected = index;
                });
                if (selected !== route[current]) {
                    attempts -= 1;
                    api.flash('wrong', 360);
                    api.state('VÁLVULA REJEITOU O FLUXO');
                    api.secondary(`${attempts} TENTATIVAS`);
                    if (attempts <= 0) api.finish(false, 'CIRCUITO HEMÁTICO ROMPIDO');
                    return;
                }
                current += 1;
                api.flash('hit', 260);
                if (current >= route.length) {
                    api.state('SANGUE ALCANÇOU O NÚCLEO');
                    window.setTimeout(() => api.finish(true), 680);
                    return;
                }
                api.progress(`VÁLVULA ${current + 1} / ${route.length}`);
                api.state('CONDUZA O FLUXO ADIANTE');
            },
            render(now) {
                const { context, width, height } = api.fit();
                const positions = nodes.map((item) => point(item, width, height));
                context.clearRect(0, 0, width, height);
                links.forEach(([from, to]) => {
                    const active = current > 1 && route.slice(0, current).includes(from) && route.slice(0, current).includes(to);
                    context.strokeStyle = active ? themes.vampiro.accent : 'rgba(129, 91, 75, 0.32)';
                    context.lineWidth = active ? 6 : 2;
                    context.beginPath();
                    context.moveTo(positions[from].x, positions[from].y);
                    context.lineTo(positions[to].x, positions[to].y);
                    context.stroke();
                    if (active) {
                        const flow = ((now / 700) + (from * 0.13)) % 1;
                        context.fillStyle = themes.vampiro.pale;
                        context.beginPath();
                        context.arc(
                            positions[from].x + ((positions[to].x - positions[from].x) * flow),
                            positions[from].y + ((positions[to].y - positions[from].y) * flow),
                            3,
                            0,
                            TAU
                        );
                        context.fill();
                    }
                });
                positions.forEach((node, index) => {
                    const expected = index === route[current];
                    const reached = route.slice(0, current).includes(index);
                    const radius = expected ? 10 + (Math.sin(now / 130) * 2) : 8;
                    context.fillStyle = reached ? themes.vampiro.accent : '#16090d';
                    context.strokeStyle = expected ? themes.vampiro.pale : themes.vampiro.accent;
                    context.lineWidth = expected ? 3 : 1.5;
                    context.beginPath();
                    context.arc(node.x, node.y, radius, 0, TAU);
                    context.fill();
                    context.stroke();
                });
            },
        };
    }

    function createHealerVault(api) {
        const normalizedNodes = [
            [0.50, 0.13], [0.78, 0.27], [0.87, 0.57], [0.66, 0.82],
            [0.34, 0.82], [0.13, 0.57], [0.22, 0.27],
        ];
        const sequenceLength = clamp(Math.round(Number(api.options.blooms) || 5), 4, 7);
        const sequence = [];
        while (sequence.length < sequenceLength) {
            const value = Math.floor(Math.random() * normalizedNodes.length);
            if (sequence[sequence.length - 1] !== value) sequence.push(value);
        }
        let phase = 'show';
        let showStartedAt = performance.now() + 450;
        let current = 0;
        let attempts = Number(api.options.attempts) || 3;

        function replay() {
            phase = 'show';
            showStartedAt = performance.now() + 450;
            current = 0;
            api.progress('OBSERVE A FLORAÇÃO');
            api.state('MEMORIZE A ORDEM DOS BROTOS');
        }

        return {
            start() {
                api.secondary('SEIVA EM REPOUSO');
                replay();
            },
            pointerDown(event) {
                if (phase !== 'input') return;
                const { width, height } = api.fit();
                const cursor = api.position(event);
                const positions = normalizedNodes.map((item) => point(item, width, height));
                let selected = -1;
                positions.forEach((node, index) => {
                    if (distance(cursor, node) <= 24) selected = index;
                });
                if (selected !== sequence[current]) {
                    attempts -= 1;
                    api.flash('wrong', 360);
                    api.secondary(`${attempts} TENTATIVAS`);
                    if (attempts <= 0) {
                        api.finish(false, 'SELO NATURAL ADORMECEU');
                        return;
                    }
                    api.state('A SEQUÊNCIA SE DESFEZ');
                    window.setTimeout(replay, 650);
                    return;
                }
                current += 1;
                api.flash('hit', 260);
                if (current >= sequence.length) {
                    api.state('SELO NATURAL FLORESCEU');
                    window.setTimeout(() => api.finish(true), 680);
                    return;
                }
                api.progress(`BROTO ${current + 1} / ${sequence.length}`);
                api.state('CONTINUE A FLORAÇÃO');
            },
            render(now) {
                const { context, width, height } = api.fit();
                const positions = normalizedNodes.map((item) => point(item, width, height));
                if (phase === 'show' && now >= showStartedAt + (sequence.length * 650)) {
                    phase = 'input';
                    api.progress(`BROTO 1 / ${sequence.length}`);
                    api.state('REPRODUZA A FLORAÇÃO');
                }
                const shownIndex = phase === 'show' ? Math.floor((now - showStartedAt) / 650) : -1;
                context.clearRect(0, 0, width, height);
                context.strokeStyle = 'rgba(87, 154, 91, 0.42)';
                context.lineWidth = 4;
                positions.forEach((node, index) => {
                    const next = positions[(index + 1) % positions.length];
                    context.beginPath();
                    context.moveTo(node.x, node.y);
                    context.quadraticCurveTo(width / 2, height / 2, next.x, next.y);
                    context.stroke();
                });
                positions.forEach((node, index) => {
                    const active = shownIndex >= 0 && shownIndex < sequence.length && sequence[shownIndex] === index;
                    const completed = phase === 'input' && sequence.slice(0, current).includes(index);
                    const radius = active ? 15 + (Math.sin(now / 100) * 2) : 10;
                    context.fillStyle = active ? themes.curandeira.pale : (completed ? themes.curandeira.accent : themes.curandeira.dark);
                    context.strokeStyle = themes.curandeira.accent;
                    context.lineWidth = active ? 4 : 2;
                    context.beginPath();
                    for (let petal = 0; petal < 8; petal += 1) {
                        const angle = (petal / 8) * TAU;
                        const x = node.x + (Math.cos(angle) * radius);
                        const y = node.y + (Math.sin(angle) * radius);
                        if (petal === 0) context.moveTo(x, y); else context.lineTo(x, y);
                    }
                    context.closePath();
                    context.fill();
                    context.stroke();
                });
                context.fillStyle = themes.curandeira.dark;
                context.strokeStyle = themes.curandeira.pale;
                context.lineWidth = 2;
                context.beginPath();
                context.arc(width / 2, height / 2, Math.min(width, height) * 0.13, 0, TAU);
                context.fill();
                context.stroke();
            },
        };
    }

    function create(type, variant, api) {
        if (variant === 'bruxa') return type === 'lock' ? createWitchLock(api) : createWitchVault(api);
        if (variant === 'vampiro') return type === 'lock' ? createVampireLock(api) : createVampireVault(api);
        if (variant === 'curandeira') return type === 'lock' ? createHealerLock(api) : createHealerVault(api);
        return null;
    }

    window.ObIlegalVariantGames = { create };
}());
