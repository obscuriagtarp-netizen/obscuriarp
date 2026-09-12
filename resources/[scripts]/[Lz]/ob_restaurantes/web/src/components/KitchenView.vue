<script setup>
import { computed, ref } from "vue";
import { BellRing, CheckCheck, ChefHat, Clock3, PackageCheck, RefreshCw } from "lucide-vue-next";
import { nuiRequest } from "../nui";

const props = defineProps({ payload: { type: Object, required: true } });
const emit = defineEmits(["feedback", "refresh"]);
const busyOrder = ref(null);
const columns = computed(() => [
  { key: "queued", label: "Na fila", icon: Clock3, orders: (props.payload.orders || []).filter((item) => item.status === "queued") },
  { key: "preparing", label: "Em preparo", icon: ChefHat, orders: (props.payload.orders || []).filter((item) => item.status === "preparing") },
  { key: "ready", label: "Prontos", icon: BellRing, orders: (props.payload.orders || []).filter((item) => item.status === "ready") },
]);

function money(value) { return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`; }
function nextStatus(status) { return status === "queued" ? "preparing" : status === "preparing" ? "ready" : "delivered"; }
function nextLabel(status) { return status === "queued" ? "Assumir preparo" : status === "preparing" ? "Finalizar e chamar" : "Entregar pedido"; }

async function advance(order) {
  busyOrder.value = order.id;
  const result = await nuiRequest("setOrderStatus", { restaurantId: props.payload.restaurant.id, orderId: order.id, status: nextStatus(order.status) });
  busyOrder.value = null;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", order.status === "preparing" ? `Pedido ${order.public_code} finalizado e anunciado.` : "Pedido atualizado.", "success");
  emit("refresh");
}
</script>

<template>
  <section class="kitchen-view">
    <header class="section-toolbar">
      <div><small>Operação em tempo real</small><h2>Cozinha e retirada</h2></div>
      <button class="icon-command" title="Atualizar pedidos" @click="$emit('refresh')"><RefreshCw :size="18" /></button>
    </header>
    <div class="kitchen-board">
      <section v-for="column in columns" :key="column.key" class="kitchen-column" :data-status="column.key">
        <header><component :is="column.icon" :size="18" /><b>{{ column.label }}</b><span><i>{{ column.orders.length }}</i></span></header>
        <div class="order-stack">
          <article v-for="order in column.orders" :key="order.id" class="kitchen-order">
            <div class="order-heading"><strong>{{ order.public_code }}</strong><div><b>{{ order.customer_name }}</b><small>{{ money(order.total) }}</small></div></div>
            <ul><li v-for="item in order.items" :key="`${order.id}-${item.recipeId}`"><b>{{ item.amount }}x</b> {{ item.name }}</li></ul>
            <p v-if="order.notes"><span>Observação</span>{{ order.notes }}</p>
            <button :disabled="busyOrder === order.id" @click="advance(order)">
              <ChefHat v-if="order.status === 'queued'" :size="17" />
              <CheckCheck v-else-if="order.status === 'preparing'" :size="17" />
              <PackageCheck v-else :size="17" />
              {{ nextLabel(order.status) }}
            </button>
          </article>
          <div v-if="!column.orders.length" class="column-empty">Nenhum pedido nesta etapa.</div>
        </div>
      </section>
    </div>
  </section>
</template>
