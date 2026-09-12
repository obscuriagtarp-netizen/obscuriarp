const RES_NAME = typeof GetParentResourceName === "function" ? GetParentResourceName() : "magicSpells";

const hud = document.getElementById("magic-hud");
const crosshair = document.getElementById("magic-crosshair");
const crosshairLabel = document.getElementById("crosshair-label");
const crosshairCharge = document.getElementById("crosshair-charge");
const hints = document.getElementById("magic-hints");
const cancelTip = document.getElementById("magic-cancel-tip");

const spellIcon = document.getElementById("spell-icon");
const spellEmblem = spellIcon.closest(".spell-emblem");
const spellCooldown = document.getElementById("spell-cooldown");
const spellCooldownLabel = document.getElementById("spell-cooldown-label");
const spellTitle = document.getElementById("spell-title");
const spellDescription = document.getElementById("spell-description");
const spellCounter = document.getElementById("spell-counter");
const spellShortcut = document.getElementById("spell-shortcut");
const spellActionPrimaryKey = document.getElementById("spell-action-primary-key");
const spellActionPrimaryLabel = document.getElementById("spell-action-primary-label");
const spellActionSecondary = document.getElementById("spell-action-secondary");
const spellActionSecondaryKey = document.getElementById("spell-action-secondary-key");
const spellActionSecondaryLabel = document.getElementById("spell-action-secondary-label");
const pageRight = document.getElementById("page-right");
const pageTurn = document.getElementById("page-turn");
const pageTurnSheet = document.getElementById("page-turn-sheet");
const navPrevKey = document.getElementById("nav-prev-key");
const navNextKey = document.getElementById("nav-next-key");

const portusMenu = document.getElementById("portus-menu");
const portusListEl = document.getElementById("portus-list");
const portusModeLabel = document.getElementById("portus-mode-label");

let spells = [];
let activeSpellName = "";
let portusLocations = [];
let portusEraseMode = false;
const PORTUS_MAX_LOCATIONS = 3;
const PORTUS_RUNE_LABELS = ["I", "II", "III"];
const PORTUS_RUNE_NAMES = ["Runa violeta", "Runa azul", "Runa verde"];
const PORTUS_EMPTY_ASSET = "assets/portus-rune-empty.png";
const PORTUS_RUNE_ASSETS = [
    "assets/portus-rune-purple.png",
    "assets/portus-rune-blue.png",
    "assets/portus-rune-green.png"
];
const cooldowns = new Map();
let castChargeTimer = null;
let textFitFrame = null;
let spellChargeActive = false;
let hudVisible = false;
let cooldownTimer = null;
let pageTurnFrame = null;
let pageTurnCommit = null;
let pageTurnCommitted = false;
const PAGE_TURN_FRAMES = 22;
const PAGE_TURN_DURATION = 440;

function nuiPost(name, payload = {}) {
    return fetch(`https://${RES_NAME}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(payload)
    }).catch(() => {});
}

function setVisible(visible) {
    hudVisible = visible;
    hud.classList.toggle("hidden", !visible);
    hud.setAttribute("aria-hidden", visible ? "false" : "true");

    if (!visible) {
        finishPageTurn(true);
        stopCooldownTick();
        setCancelTip(false);
        setHints([]);
        setSpellCharge({ active: false });
    } else {
        ensureCooldownTick();
    }
}

function finishPageTurn(commitPending = false) {
    if (pageTurnFrame !== null) {
        cancelAnimationFrame(pageTurnFrame);
        pageTurnFrame = null;
    }

    const pendingCommit = pageTurnCommit;
    const shouldCommit = commitPending && pendingCommit && !pageTurnCommitted;
    pageTurnCommit = null;
    pageTurnCommitted = false;

    if (shouldCommit) {
        pendingCommit();
    }

    pageTurn.classList.remove("is-active", "is-forward", "is-backward");
    hud.classList.remove("is-page-turning");
    pageTurnSheet.style.transform = "";
    pageTurn.style.setProperty("--turn-shadow", "0");
    pageTurn.style.setProperty("--turn-edge", "0.2");
}

function playPageTurn(direction, commit) {
    finishPageTurn(true);

    const turnDirection = direction >= 0 ? 1 : -1;
    const directionClass = turnDirection > 0 ? "is-forward" : "is-backward";
    pageTurnCommit = commit;
    pageTurnCommitted = false;
    pageTurn.classList.add("is-active", directionClass);
    hud.classList.add("is-page-turning");

    const startedAt = performance.now();
    let lastRenderedFrame = -1;

    const renderFrame = (now) => {
        const elapsed = Math.min(PAGE_TURN_DURATION, now - startedAt);
        const timelineProgress = elapsed / PAGE_TURN_DURATION;
        const frameIndex = Math.min(
            PAGE_TURN_FRAMES - 1,
            Math.floor(timelineProgress * PAGE_TURN_FRAMES)
        );

        if (frameIndex !== lastRenderedFrame) {
            lastRenderedFrame = frameIndex;
            const frameProgress = frameIndex / (PAGE_TURN_FRAMES - 1);
            const easedProgress = 0.5 - Math.cos(Math.PI * frameProgress) / 2;
            const fold = Math.sin(Math.PI * frameProgress);
            const rotation = (turnDirection > 0 ? -180 : 180) * easedProgress;

            pageTurnSheet.style.transform = `rotateY(${rotation.toFixed(2)}deg)`;
            pageTurn.style.setProperty("--turn-shadow", (0.04 + fold * 0.3).toFixed(3));
            pageTurn.style.setProperty("--turn-edge", (0.16 + fold * 0.66).toFixed(3));

            if (!pageTurnCommitted && frameProgress >= 0.5) {
                pageTurnCommitted = true;
                pageTurnCommit?.();
            }
        }

        if (timelineProgress < 1) {
            pageTurnFrame = requestAnimationFrame(renderFrame);
            return;
        }

        if (!pageTurnCommitted) {
            pageTurnCommitted = true;
            pageTurnCommit?.();
        }

        pageTurnFrame = null;
        finishPageTurn(false);
    };

    pageTurnFrame = requestAnimationFrame(renderFrame);
}

function setCrosshair(data) {
    const visible = !!data.visible;
    crosshair.classList.toggle("hidden", !visible);

    if (!visible) {
        crosshair.classList.remove("has-target");
        crosshairLabel.textContent = "";
        return;
    }

    crosshair.classList.toggle("has-target", !!data.target);
    crosshairLabel.textContent = data.label || "";
}

function setCastCharge(data) {
    const active = !!data.active;
    const duration = Number(data.duration || 0);

    if (castChargeTimer) {
        clearTimeout(castChargeTimer);
        castChargeTimer = null;
    }

    crosshair.classList.toggle("is-casting", active);
    crosshairCharge.style.transition = "none";
    crosshairCharge.style.transform = "scaleY(0)";
    crosshairCharge.style.opacity = active ? "1" : "0";

    if (!active || duration <= 0) {
        return;
    }

    void crosshairCharge.offsetHeight;
    crosshairCharge.style.transition = `transform ${duration}ms linear, opacity 140ms ease`;
    crosshairCharge.style.transform = "scaleY(1)";

    castChargeTimer = setTimeout(() => {
        crosshair.classList.remove("is-casting");
        crosshairCharge.style.opacity = "0";
        crosshairCharge.style.transition = "none";
        crosshairCharge.style.transform = "scaleY(0)";
        castChargeTimer = null;
    }, duration + 80);
}

function setNavigation(data) {
    const prev = data.prev || "ESQ";
    const next = data.next || "DIR";
    navPrevKey.textContent = prev;
    navNextKey.textContent = next;
    spellShortcut.textContent = `${prev}/${next}`;
}

function setCancelTip(visible) {
    cancelTip.classList.toggle("hidden", !visible);
}

function setHints(lines) {
    if (!lines || !lines.length) {
        hints.classList.add("hidden");
        hints.innerHTML = "";
        return;
    }

    hints.innerHTML = lines
        .map((line) => `<div class="magic-hint-line">${escapeHtml(String(line))}</div>`)
        .join("");
    hints.classList.remove("hidden");
}

function setSpells(nextSpells) {
    spells = Array.isArray(nextSpells) ? nextSpells : [];

    if (!activeSpellName && spells.length) {
        activeSpellName = spells[0].name;
    }

    renderActiveSpell();
}

function setActiveSpell(spellName, index, direction = 0) {
    const numericIndex = Number(index);
    const nextSpellName = spellName
        || (Number.isFinite(numericIndex) && spells[numericIndex - 1]?.name)
        || activeSpellName;
    const numericDirection = Number(direction);

    if (!nextSpellName) {
        return;
    }

    const commit = () => {
        activeSpellName = nextSpellName;
        renderActiveSpell();
    };

    if (!hudVisible || nextSpellName === activeSpellName || Math.abs(numericDirection) !== 1) {
        finishPageTurn(true);
        commit();
        return;
    }

    playPageTurn(numericDirection, commit);
}

function renderActiveSpell() {
    const spell = spells.find((entry) => entry.name === activeSpellName) || spells[0];

    if (!spell) {
        spellIcon.removeAttribute("src");
        spellTitle.textContent = "Grimorio";
        spellDescription.textContent = "Nenhum feitico conhecido.";
        spellCounter.textContent = "0 / 0";
        spellShortcut.textContent = "";
        spellCooldown.style.height = "0%";
        spellCooldownLabel.textContent = "";
        return;
    }

    activeSpellName = spell.name;
    spellIcon.src = spell.icon || "";
    setSpellTitle(spell.label || spell.shortLabel || spell.name);
    spellDescription.textContent = spell.description || "";
    renderSpellActions(spell);
    scheduleTextFit();

    const index = spells.findIndex((entry) => entry.name === activeSpellName);
    spellCounter.textContent = `${index + 1} / ${spells.length}`;
    const essenceCost = Math.max(0, Number(spell.essenceCost) || 0);
    spellShortcut.textContent = essenceCost > 0
        ? `CUSTO ${Math.floor(essenceCost)}`
        : "SEM CUSTO";
    updateCooldownVisual();
}

function pulseSpellError(spellName) {
    if (spellName && spellName !== activeSpellName) {
        return;
    }

    spellEmblem.classList.remove("is-denied");
    void spellEmblem.offsetWidth;
    spellEmblem.classList.add("is-denied");

    window.setTimeout(() => {
        spellEmblem.classList.remove("is-denied");
    }, 620);
}

function renderSpellActions(spell) {
    const primary = spell.actionPrimary || {};
    spellActionPrimaryKey.textContent = primary.key || "Mouse esquerdo";
    spellActionPrimaryLabel.textContent = primary.label || "Conjurar";

    const secondary = spell.actionSecondary;
    spellActionSecondary.classList.toggle("hidden", !secondary);
    if (secondary) {
        spellActionSecondaryKey.textContent = secondary.key || "Mouse direito";
        spellActionSecondaryLabel.textContent = secondary.label || "Auto conjurar";
    }
}

function setSpellTitle(title) {
    const value = String(title || "Magia");
    const isLong = value.length > 14;
    const isVeryLong = value.length > 22;
    pageRight.classList.toggle("is-long-title", isLong);
    pageRight.classList.toggle("is-very-long-title", isVeryLong);
    spellTitle.style.fontSize = "";
    spellTitle.style.lineHeight = "";

    if (isLong && value.includes(" ")) {
        spellTitle.innerHTML = balanceLines(value, isVeryLong ? 3 : 2)
            .filter(Boolean)
            .map((part) => escapeHtml(part))
            .join("<br>");
    } else {
        spellTitle.textContent = value;
    }

    scheduleTextFit();
}

function balanceLines(value, maxLines) {
    const words = String(value || "").split(/\s+/).filter(Boolean);
    if (words.length <= 1) return words;

    const totalLetters = words.reduce((sum, word) => sum + word.length, 0);
    const target = Math.ceil((totalLetters + words.length - 1) / maxLines);
    const lines = [];
    let line = "";

    for (const word of words) {
        const next = [line, word].filter(Boolean).join(" ");
        if (line && next.length > target && lines.length < maxLines - 1) {
            lines.push(line);
            line = word;
        } else {
            line = next;
        }
    }

    if (line) lines.push(line);
    return lines;
}

function scheduleTextFit() {
    if (textFitFrame) {
        cancelAnimationFrame(textFitFrame);
    }

    textFitFrame = requestAnimationFrame(() => {
        fitTextToBox(spellTitle, 10, 27);
        fitTextToBox(spellDescription, 8, 13);
        textFitFrame = null;
    });
}

function fitTextToBox(element, minPx, maxPx) {
    if (!element || !element.parentElement) return;

    element.style.fontSize = "";
    element.style.lineHeight = "";

    const computed = window.getComputedStyle(element);
    let size = Math.min(maxPx, parseFloat(computed.fontSize) || maxPx);

    while (size > minPx && (element.scrollWidth > element.clientWidth + 1 || element.scrollHeight > element.clientHeight + 1)) {
        size -= 1;
        element.style.fontSize = `${size}px`;
        element.style.lineHeight = element === spellTitle ? "0.96" : "1.12";
    }
}

function startCooldown(spellName, duration) {
    if (!spellName || !duration) return;

    cooldowns.set(spellName, {
        start: performance.now(),
        duration: Number(duration)
    });

    updateCooldownVisual();
    ensureCooldownTick();
}

function pruneExpiredCooldowns(now = performance.now()) {
    for (const [spellName, cooldown] of cooldowns) {
        if (now - cooldown.start >= cooldown.duration) {
            cooldowns.delete(spellName);
        }
    }
}

function updateCooldownVisual() {
    if (spellChargeActive) {
        return;
    }

    const now = performance.now();
    pruneExpiredCooldowns(now);

    const cd = cooldowns.get(activeSpellName);
    if (!cd) {
        spellCooldown.style.height = "0%";
        spellCooldownLabel.textContent = "";
        return;
    }

    const elapsed = now - cd.start;
    const remaining = Math.max(0, cd.duration - elapsed);

    if (remaining <= 0) {
        cooldowns.delete(activeSpellName);
        spellCooldown.style.height = "0%";
        spellCooldownLabel.textContent = "";
        return;
    }

    const percent = Math.round((remaining / cd.duration) * 100);
    spellCooldown.style.height = `${percent}%`;
    spellCooldownLabel.textContent = `${Math.ceil(remaining / 1000)}s`;
}

function setSpellCharge(data) {
    const active = !!data.active;
    const value = Math.max(0, Math.min(1, Number(data.value || 0)));

    spellChargeActive = active;
    spellEmblem.classList.toggle("is-pressure", active);

    if (!active) {
        updateCooldownVisual();
        ensureCooldownTick();
        return;
    }

    spellCooldown.style.height = `${Math.round(value * 100)}%`;
    spellCooldownLabel.textContent = `${Math.round(value * 100)}%`;
}

function stopCooldownTick() {
    if (cooldownTimer !== null) {
        clearTimeout(cooldownTimer);
        cooldownTimer = null;
    }
}

function ensureCooldownTick() {
    if (cooldownTimer !== null || !hudVisible || spellChargeActive || cooldowns.size === 0) {
        return;
    }

    const tick = () => {
        cooldownTimer = null;
        if (!hudVisible || spellChargeActive || cooldowns.size === 0) {
            return;
        }

        updateCooldownVisual();
        cooldownTimer = setTimeout(tick, 250);
    };

    cooldownTimer = setTimeout(tick, 250);
}

function escapeHtml(value) {
    return value
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function setPortusMenuVisible(show) {
    portusMenu.classList.toggle("hidden", !show);
    portusMenu.setAttribute("aria-hidden", show ? "false" : "true");
}

function renderPortusList(locations) {
    portusListEl.innerHTML = "";
    const savedLocations = Array.isArray(locations) ? locations.slice(0, PORTUS_MAX_LOCATIONS) : [];
    const locationsBySlot = new Map();

    savedLocations.forEach((location, fallbackIndex) => {
        const parsedSlot = Number.parseInt(location?.slot, 10);
        const slot = Number.isInteger(parsedSlot) && parsedSlot >= 1 && parsedSlot <= PORTUS_MAX_LOCATIONS
            ? parsedSlot
            : fallbackIndex + 1;
        locationsBySlot.set(slot, location);
    });

    for (let index = 0; index < PORTUS_MAX_LOCATIONS; index += 1) {
        const slot = index + 1;
        const loc = locationsBySlot.get(slot);
        const item = document.createElement("button");
        item.type = "button";
        item.className = `portus-rune${loc ? " is-bound" : " is-empty"}${portusEraseMode ? " erase-mode" : ""}`;
        item.dataset.slot = String(slot);
        item.disabled = portusEraseMode && !loc;
        item.setAttribute("aria-label", loc
            ? `${PORTUS_RUNE_NAMES[index]} marcada em ${loc.name || "destino salvo"}`
            : `${PORTUS_RUNE_NAMES[index]} vazia, marcar local atual`);
        item.title = loc
            ? (portusEraseMode ? "Apagar destino desta runa" : "Abrir portal para este destino")
            : "Marcar este local";

        const sigil = document.createElement("img");
        sigil.className = "portus-rune-sigil";
        sigil.src = loc ? PORTUS_RUNE_ASSETS[index] : PORTUS_EMPTY_ASSET;
        sigil.alt = `Runa ${PORTUS_RUNE_LABELS[index]}`;
        sigil.draggable = false;

        const indexLabel = document.createElement("span");
        indexLabel.className = "portus-rune-index";
        indexLabel.textContent = PORTUS_RUNE_LABELS[index];

        item.appendChild(sigil);
        item.appendChild(indexLabel);
        item.addEventListener("click", () => {
            setPortusMenuVisible(false);

            if (!loc) {
                nuiPost("portus_mark", { slot });
                return;
            }

            if (portusEraseMode) {
                nuiPost("portus_delete", { id: loc.id, slot });
                return;
            }

            nuiPost("portus_select", { id: loc.id, slot });
        });

        portusListEl.appendChild(item);
    }

    portusModeLabel.classList.toggle("hidden", !portusEraseMode);
    portusModeLabel.textContent = "Escolha a runa que sera apagada";
}

window.addEventListener("message", (event) => {
    const data = event.data || {};

    switch (data.action) {
        case "setVisible":
            setVisible(!!data.visible);
            break;
        case "setCrosshair":
            setCrosshair(data);
            break;
        case "setCastCharge":
            setCastCharge(data);
            break;
        case "setSpellCharge":
            setSpellCharge(data);
            break;
        case "setNavigation":
            setNavigation(data);
            break;
        case "setSpells":
            setSpells(data.spells || []);
            break;
        case "setActiveSpell":
            setActiveSpell(data.spell, data.index, data.direction);
            break;
        case "startCooldown":
            startCooldown(data.spell, data.duration || 0);
            break;
        case "pulseSpellError":
            pulseSpellError(data.spell);
            break;
        case "setCancelTip":
            setCancelTip(!!data.visible);
            break;
        case "setHints":
            setHints(data.lines || data.hints || []);
            break;
        case "openPortusMenu":
            portusLocations = Array.isArray(data.locations)
                ? data.locations.slice(0, PORTUS_MAX_LOCATIONS)
                : [];
            portusEraseMode = !!data.eraseMode;
            renderPortusList(portusLocations);
            setPortusMenuVisible(true);
            break;
        case "closePortusMenu":
            setPortusMenuVisible(false);
            break;
    }
});

window.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || portusMenu.classList.contains("hidden")) {
        return;
    }

    setPortusMenuVisible(false);
    nuiPost("portus_close");
});

const previewMode = new URLSearchParams(window.location.search).get("preview");

if (previewMode === "portus") {
    portusLocations = [
        { id: 1, slot: 1, name: "Runa violeta" },
        { id: 2, slot: 2, name: "Runa azul" }
    ];
    renderPortusList(portusLocations);
    setPortusMenuVisible(true);
}

if (previewMode === "grimoire") {
    const previewSpell = {
        name: "machina_reparatio",
        label: "Machina Reparatio",
        description: "Selecione o veiculo sob a mira e canalize novamente para restaurar sua estrutura por completo.",
        icon: "assets/spell-machina_reparatio.png",
        essenceCost: 18,
        actionPrimary: {
            key: "Mouse esquerdo",
            label: "Selecionar ou reparar veiculo",
        },
        actionSecondary: {
            key: "Mouse direito",
            label: "Cancelar alvo marcado",
        },
    };

    const previewBlink = {
        name: "blink",
        label: "Blink",
        description: "Carregue a distancia e atravesse o espaco na direcao indicada pela mira.",
        icon: "assets/spell-blink.png",
        essenceCost: 12,
        actionPrimary: {
            key: "Mouse esquerdo",
            label: "Carregar e avancar",
        },
    };

    setNavigation({ prev: "ESQ", next: "DIR" });
    setSpells([previewSpell, previewBlink]);
    setActiveSpell(previewSpell.name);
    setVisible(true);

    if (new URLSearchParams(window.location.search).get("animate") === "1") {
        let forward = true;
        window.setInterval(() => {
            const spell = forward ? previewBlink : previewSpell;
            setActiveSpell(spell.name, forward ? 2 : 1, forward ? 1 : -1);
            forward = !forward;
        }, 1400);
    }
}
