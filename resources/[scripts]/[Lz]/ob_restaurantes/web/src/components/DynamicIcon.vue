<script setup>
import {
  BadgeDollarSign,
  BellRing,
  ChefHat,
  CircleGauge,
  ClipboardList,
  CreditCard,
  CupSoda,
  Flame,
  LayoutDashboard,
  PackageOpen,
  Salad,
  Sandwich,
  Settings2,
  ShoppingBasket,
  Soup,
  Store,
  Utensils,
} from "lucide-vue-next";

defineProps({ name: { type: String, default: "utensils" }, size: { type: Number, default: 20 } });

const icons = {
  "badge-dollar-sign": BadgeDollarSign,
  bell: BellRing,
  "bell-ring": BellRing,
  chef: ChefHat,
  "chef-hat": ChefHat,
  gauge: CircleGauge,
  orders: ClipboardList,
  "clipboard-list": ClipboardList,
  "credit-card": CreditCard,
  "cup-soda": CupSoda,
  fire: Flame,
  "layout-dashboard": LayoutDashboard,
  package: PackageOpen,
  "package-open": PackageOpen,
  salad: Salad,
  sandwich: Sandwich,
  settings: Settings2,
  basket: ShoppingBasket,
  soup: Soup,
  store: Store,
  utensils: Utensils,
};
</script>

<template>
  <component :is="icons[name] || Utensils" :size="size" aria-hidden="true" />
</template>

