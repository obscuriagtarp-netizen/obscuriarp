<script setup>
import { computed, ref } from "vue";
import { Banknote, Check, CreditCard, ReceiptText } from "lucide-vue-next";
import { nuiRequest } from "../nui";

const props = defineProps({ payload: { type: Object, required: true } });
const emit = defineEmits(["feedback", "refresh"]);
const payments = computed(() => props.payload.payments || []);
const paying = ref(null);

function money(value) {
  return `$ ${Math.floor(Number(value) || 0).toLocaleString("pt-BR")}`;
}

function accountLabel(account) {
  return account === "cash" ? "Dinheiro" : "Banco";
}

async function pay(payment) {
  paying.value = payment.id;
  const result = await nuiRequest("pay", { paymentId: payment.id });
  paying.value = null;
  if (!result.ok) return emit("feedback", result.error, "error");
  emit("feedback", `Pagamento de ${money(result.amount)} aprovado.`, "success");
  emit("refresh");
}
</script>

<template>
  <div class="customer-terminal-view">
    <div v-if="payments.length" class="receipt-stack">
      <article v-for="payment in payments" :key="payment.id" class="customer-receipt">
        <header>
          <ReceiptText :size="19" />
          <div><small>{{ payment.restaurant_label || payload.restaurant.label }}</small><strong>Nota do pedido</strong></div>
          <b>{{ payment.public_code || "AVULSO" }}</b>
        </header>

        <div class="receipt-customer">
          <span>Cliente</span>
          <strong>{{ payment.customer_name || payload.player.name }}</strong>
        </div>

        <ul v-if="payment.items?.length" class="receipt-items">
          <li v-for="item in payment.items" :key="`${payment.id}-${item.recipeId || item.name}`">
            <span><b>{{ item.amount }}x</b> {{ item.name }}</span>
            <strong>{{ money(item.total) }}</strong>
          </li>
        </ul>
        <div v-else class="receipt-generic">Cobrança avulsa registrada pelo atendente.</div>

        <p v-if="payment.notes" class="receipt-notes"><span>Observação</span>{{ payment.notes }}</p>

        <div class="receipt-payment">
          <span>Total</span>
          <strong>{{ money(payment.amount) }}</strong>
          <small><Banknote v-if="payment.account === 'cash'" :size="14" /><CreditCard v-else :size="14" /> {{ accountLabel(payment.account) }}</small>
        </div>

        <button class="receipt-confirm" :disabled="paying === payment.id" @click="pay(payment)">
          <Check :size="16" /> {{ paying === payment.id ? "Confirmando..." : "Confirmar pagamento" }}
        </button>
      </article>
    </div>
    <div v-else class="terminal-empty-receipt">
      <ReceiptText :size="30" />
      <strong>Nenhuma comanda pendente</strong>
      <span>Peça ao atendente para emitir a cobrança antes de usar a maquininha.</span>
    </div>
  </div>
</template>
