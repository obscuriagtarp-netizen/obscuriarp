import { reactive } from "vue";

export const state = reactive({
  visible: false,
  screen: "main",
  currentSection: null,
  menuItems: []
});

export function openSection(item) {
  state.currentSection = item;
  state.screen = item.id;

  fetch(`https://${GetParentResourceName()}/openSection`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    },
    body: JSON.stringify({ id: item.id })
  }).catch((e) => console.error("openSection error:", e));
}

export function backToMain() {
  state.screen = "main";
  state.currentSection = null;
}

export function closeMenu() {
  fetch(`https://${GetParentResourceName()}/closeMenu`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    },
    body: JSON.stringify({})
  });
}

export function handleNuiMessage(data) {
  if (data.action === "open") {
    state.menuItems = data.menuItems || [];
    state.screen = data.screen || "geral";
    state.currentSection = null;
    state.visible = true;
  } else if (data.action === "close") {
    state.visible = false;
  } else if (data.action === "refreshFactions") {
    window.dispatchEvent(new CustomEvent("magicpause:refresh-factions"));
  }
}
