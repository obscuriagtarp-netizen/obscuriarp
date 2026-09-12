import { createApp } from "vue";
import App from "./App.vue";
import { handleNuiMessage } from "./store/menu";
import "./styles/globals.css";
import "./styles/theme-sync.css";

const app = createApp(App);
app.mount("#app");

window.addEventListener("message", (event) => {
  handleNuiMessage(event.data);
});
