<script setup>
import { computed } from "vue";
import { BellRing, ChefHat, Clock3 } from "lucide-vue-next";

const props = defineProps({ payload: { type: Object, default: null } });
const activeOrders = computed(() => props.payload?.orders || []);
const preparing = computed(() => (props.payload?.orders || []).filter((order) => order.status !== "ready"));
const ready = computed(() => (props.payload?.orders || []).filter((order) => order.status === "ready"));
</script>

<template>
  <section v-if="payload && activeOrders.length" class="public-display" aria-label="Painel de pedidos">
    <header class="display-header">
      <div class="display-brand">
        <span class="display-sign"><BellRing :size="20" /></span>
        <div>
          <small>{{ payload.restaurant?.label }}</small>
          <strong>Retirada de pedidos</strong>
        </div>
      </div>
      <span class="display-online"><i></i> Atendimento ativo</span>
    </header>
    <div class="display-columns">
      <section class="display-column">
        <header>
          <Clock3 :size="17" />
          <div><small>Acompanhe seu número</small><strong>Em preparo</strong></div>
          <b><span>{{ preparing.length }}</span></b>
        </header>
        <div class="display-codes">
          <article v-for="order in preparing" :key="order.id">
            <strong>{{ order.public_code }}</strong><span>{{ order.customer_name }}</span>
          </article>
          <p v-if="!preparing.length">Nenhum pedido nesta etapa.</p>
        </div>
      </section>
      <section class="display-column ready">
        <header>
          <ChefHat :size="17" />
          <div><small>Seu pedido está pronto</small><strong>Retirar no balcão</strong></div>
          <b><span>{{ ready.length }}</span></b>
        </header>
        <div class="display-codes">
          <article v-for="order in ready" :key="order.id">
            <strong>{{ order.public_code }}</strong><span>{{ order.customer_name }}</span>
          </article>
          <p v-if="!ready.length">Aguarde a chamada do balcão.</p>
        </div>
      </section>
    </div>
  </section>
</template>
