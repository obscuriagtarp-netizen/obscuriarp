const params = new URLSearchParams(window.location.search);
export const previewMode = params.get("preview") === "1";
const customerPreview = params.get("customer") === "1";
const previewModeName = customerPreview ? "terminal" : (params.get("mode") || "pos");

const now = new Date().toISOString();
const previewRestaurant = {
  id: "moomoo_cafe",
  label: "MooMoo Cafe",
  job: "moomoo",
  commission_rate: 0.3,
  theme: "moomoo",
};

export const previewContext = {
  mode: previewModeName,
  restaurantId: previewRestaurant.id,
  pointId: params.get("point") === "0" ? null : 1,
};

const previewRecipes = [
  { id: 1, category_key: "meals", name: "Hamburguer da Casa", description: "Pao tostado, carne e salada fresca.", price: 280, old_price: 340, menu_badge: "Oferta da semana", featured: true, prep_time: 8, output_item: "produto_restaurante", output_amount: 1, product_type: "food", item_weight: 280, icon: "sandwich", enabled: true, effects: { hunger: 25 }, ingredients: [{ item: "pao", label: "Pao", amount: 1 }, { item: "carne", label: "Carne", amount: 1 }] },
  { id: 2, category_key: "meals", name: "Batatas da Casa", description: "Porcao crocante preparada na hora.", price: 140, prep_time: 6, output_item: "produto_restaurante", output_amount: 1, product_type: "food", item_weight: 180, icon: "salad", enabled: true, effects: { hunger: 15 }, ingredients: [{ item: "batata", label: "Batata", amount: 2 }] },
  { id: 3, category_key: "drinks", name: "Refrigerante", description: "Bebida gelada no copo da casa.", price: 90, prep_time: 3, output_item: "produto_restaurante", output_amount: 1, product_type: "drink", item_weight: 300, icon: "cup-soda", enabled: true, effects: { thirst: 22 }, ingredients: [{ item: "water", label: "Agua", amount: 1 }] },
  { id: 4, category_key: "combos", name: "Combo da Casa", description: "Hamburguer, batatas e bebida em uma embalagem.", price: 460, prep_time: 12, output_item: "produto_restaurante", output_amount: 1, product_type: "food", item_weight: 850, icon: "package-open", enabled: true, is_combo: true, effects: { hunger: 30, thirst: 25 }, ingredients: [{ item: "hamburguer", label: "Hamburguer", amount: 1 }] },
];

const previewOrders = [
  { id: 31, public_code: "M01", customer_name: "Morgana Vale", status: "queued", items: [{ name: "Combo da Casa", amount: 1, total: 460 }], notes: "Sem cebola", total: 460, created_at: now },
  { id: 32, public_code: "M02", customer_name: "Lucien Moreau", status: "preparing", items: [{ name: "Hamburguer da Casa", amount: 2, total: 560 }], notes: "", total: 560, created_at: now },
  { id: 33, public_code: "M03", customer_name: "Aurora Bell", status: "ready", items: [{ name: "Batatas da Casa", amount: 1, total: 140 }], notes: "", total: 140, created_at: now },
];

export const previewPayload = {
  ok: true,
  mode: previewModeName,
  restaurant: previewRestaurant,
  player: { source: 1, name: "Morgana Vale", job: { name: "moomoo", label: "MooMoo Cafe", grade: 4 } },
  permissions: customerPreview ? { work: false, manage: false, admin: false } : { work: true, manage: true, admin: true },
  commissionRate: 0.3,
  recipeEffects: { maxSelected: 2, maxAmount: 50, defaultAmount: 20 },
  inventoryItems: [
    { name: "agua", label: "Água" },
    { name: "batata", label: "Batata" },
    { name: "carne", label: "Carne preparada" },
    { name: "pao", label: "Pão artesanal" },
    { name: "salad", label: "Salada fresca" },
    { name: "xarope", label: "Xarope de refrigerante" },
  ],
  categories: [
    { category_key: "meals", label: "Pratos", icon: "utensils", enabled: true },
    { category_key: "drinks", label: "Bebidas", icon: "cup-soda", enabled: true },
    { category_key: "combos", label: "Combos", icon: "package-open", enabled: true },
  ],
  recipes: previewRecipes,
  menu: { popularRecipeIds: [4, 1] },
  orders: previewOrders,
  productions: [],
  payments: [{ id: 8, customer_name: "Morgana Vale", restaurant_label: "MooMoo Cafe", amount: 460, total: 460, public_code: "M01", account: "bank", status: "pending", notes: "Sem cebola", items: [{ recipeId: 4, name: "Combo da Casa", amount: 1, total: 460 }] }],
  points: [
    { id: 1, type: "pos", label: "Caixa principal", coords: { x: -1, y: 1, z: 1 }, enabled: true },
    { id: 2, type: "kitchen", label: "Cozinha", coords: { x: -2, y: 1, z: 1 }, enabled: true },
    { id: 3, type: "menu", label: "Consultar cardápio", coords: { x: -3, y: 1, z: 1 }, enabled: true },
  ],
  dashboard: {
    accountBalance: 18240,
    totals: { today_gross: 4850, week_gross: 28110, month_gross: 98540, today_commission: 1455, today_sales: 17 },
    products: [{ name: "Combo da Casa", amount: 83, revenue: 38180 }, { name: "Hamburguer da Casa", amount: 61, revenue: 17080 }],
    team: [{ employee_name: "Morgana Vale", sales: 23, gross: 7380, commission: 2214 }],
  },
};

function mock(action, data) {
  if (action === "bootstrap") return Promise.resolve({ ...previewPayload, mode: data.mode || "pos" });
  if (action === "deleteRecipe") {
    const index = previewRecipes.findIndex((recipe) => Number(recipe.id) === Number(data.recipeId));
    if (index >= 0) previewRecipes.splice(index, 1);
    return Promise.resolve({ ok: index >= 0, error: index >= 0 ? undefined : "recipe_not_found" });
  }
  if (action === "nearbyCustomers") return Promise.resolve({ ok: true, customers: [{ source: 2, name: "Lucien Moreau" }, { source: 3, name: "Aurora Bell" }] });
  if (action === "display") return Promise.resolve({ ok: true, restaurant: previewRestaurant, orders: previewOrders });
  if (action === "getOrders") return Promise.resolve({ ok: true, orders: previewOrders });
  if (action === "getPayments") return Promise.resolve({ ok: true, payments: previewPayload.payments });
  if (action === "getProductions") return Promise.resolve({ ok: true, productions: [] });
  return Promise.resolve({ ok: true, orderId: 41, publicCode: "M04", paymentId: 12, total: 460, prepTime: 8, productionId: 5 });
}

export async function nuiRequest(action, data = {}) {
  if (previewMode) return mock(action, data);
  const resource = window.GetParentResourceName?.() || "ob_restaurantes";
  try {
    const response = await fetch(`https://${resource}/request`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify({ action, data }),
    });
    return await response.json();
  } catch {
    return { ok: false, error: "nui_unavailable" };
  }
}

export function closeNui() {
  if (previewMode) return Promise.resolve({ ok: true });
  const resource = window.GetParentResourceName?.() || "ob_restaurantes";
  return fetch(`https://${resource}/close`, { method: "POST", body: "{}" }).catch(() => null);
}
