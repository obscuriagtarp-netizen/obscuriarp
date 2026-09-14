import { computed, createApp, ref } from 'vue';

declare const GetParentResourceName: undefined | (() => string);

type UiMode = 'store' | 'admin';
type DealershipKind = 'normal' | 'vip' | string;
type Currency = 'money' | 'crypto';
type NotifyType = 'success' | 'error' | 'info';
type PurchaseType = 'daily' | 'weekly' | 'monthly' | 'permanent' | string;

type Category = {
  id: string;
  label: string;
  icon?: string;
};

type PlayerInfo = {
  name: string;
  money: number;
  bank: number;
  crypto: number;
};

type Dealership = {
  id: DealershipKind;
  label: string;
  subtitle?: string;
  currency: Currency;
  categories: Category[];
};

type Vehicle = {
  id: number;
  dealership: DealershipKind;
  category: string;
  model: string;
  name: string;
  brand?: string;
  price: number;
  tax: number;
  taxLabel?: string;
  total: number;
  stock: number;
  purchaseType: PurchaseType;
  durationDays?: number | null;
  durationLabel?: string;
  durationShort?: string;
  available: boolean;
  enabled?: boolean;
  image?: string;
};

type TestDriveConfig = {
  enabled?: boolean;
  price?: number;
  seconds?: number;
  currency?: Currency;
};

type PeriodConfig = {
  label: string;
  short?: string;
  days?: number;
};

type DealershipPayload = {
  ok?: boolean;
  dealership: Dealership;
  player: PlayerInfo;
  vehicles: Vehicle[];
  testDrive?: TestDriveConfig;
  fallbackImage?: string;
};

type AdminPayload = {
  ok?: boolean;
  mode?: 'admin';
  dealerships: Dealership[];
  vehicles: Vehicle[];
  periods?: Record<string, PeriodConfig>;
  fallbackImage?: string;
};

type NuiResponse = {
  ok?: boolean;
  message?: string;
  payload?: DealershipPayload | AdminPayload;
};

type Toast = {
  id: number;
  message: string;
  type: NotifyType;
};

type AdminForm = {
  id: number | null;
  dealership: string;
  category: string;
  model: string;
  name: string;
  brand: string;
  price: number;
  stock: number;
  purchaseType: PurchaseType;
  image: string;
  enabled: boolean;
  displayOrder: number;
};

const emptyForm = (): AdminForm => ({
  id: null,
  dealership: 'normal',
  category: 'carro',
  model: '',
  name: '',
  brand: '',
  price: 0,
  stock: 0,
  purchaseType: 'permanent',
  image: '',
  enabled: true,
  displayOrder: 0
});

async function nui<T = NuiResponse>(event: string, payload: unknown = {}): Promise<T> {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ob_concessionaria';
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 15000);

  try {
    const response = await fetch(`https://${resource}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    return (await response.json()) as T;
  } catch {
    return { ok: false, message: 'A concessionária demorou para responder. Tente novamente.' } as T;
  } finally {
    window.clearTimeout(timeout);
  }
}

function money(value: number, currency: Currency = 'money'): string {
  const prefix = currency === 'crypto' ? 'CR ' : '$ ';
  return prefix + Math.floor(Number(value) || 0).toLocaleString('pt-BR');
}

function periodText(vehicle: Pick<Vehicle, 'durationLabel' | 'durationShort' | 'purchaseType'> | null): string {
  if (!vehicle) return 'Permanente';
  return vehicle.durationShort || vehicle.durationLabel || String(vehicle.purchaseType || 'permanent');
}

function toBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const text = value.toLowerCase();
    if (['1', 'true', 'sim', 'yes', 'on'].includes(text)) return true;
    if (['0', 'false', 'nao', 'não', 'no', 'off'].includes(text)) return false;
  }
  return fallback;
}

function iconAssetFor(value?: string): string {
  const map: Record<string, string> = {
    grid: './assets/icons/category-all.png',
    all: './assets/icons/category-all.png',
    car: './assets/icons/category-car.png',
    carro: './assets/icons/category-car.png',
    automobile: './assets/icons/category-automobile.png',
    bike: './assets/icons/category-motorcycle.png',
    moto: './assets/icons/category-motorcycle.png',
    suv: './assets/icons/category-suv.png',
    sport: './assets/icons/category-sport.png',
    esportivo: './assets/icons/category-sport.png',
    police: './assets/icons/category-police.png',
    policial: './assets/icons/category-police.png'
  };
  return map[value || ''] || map.grid;
}

function categoryIconSvg(value?: string): string {
  const icons: Record<string, string> = {
    all: '<rect x="4" y="4" width="6" height="6" rx="1"></rect><rect x="14" y="4" width="6" height="6" rx="1"></rect><rect x="4" y="14" width="6" height="6" rx="1"></rect><rect x="14" y="14" width="6" height="6" rx="1"></rect>',
    grid: '<rect x="4" y="4" width="6" height="6" rx="1"></rect><rect x="14" y="4" width="6" height="6" rx="1"></rect><rect x="4" y="14" width="6" height="6" rx="1"></rect><rect x="14" y="14" width="6" height="6" rx="1"></rect>',
    car: '<path d="M5 17h14M6.5 17l1-5h9l1 5M8 12l1.2-3h5.6L16 12M7 17v2M17 17v2"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle>',
    carro: '<path d="M5 17h14M6.5 17l1-5h9l1 5M8 12l1.2-3h5.6L16 12M7 17v2M17 17v2"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle>',
    automobile: '<path d="M5 17h14M6.5 17l1-5h9l1 5M8 12l1.2-3h5.6L16 12M7 17v2M17 17v2"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle>',
    bike: '<circle cx="6.5" cy="17" r="3"></circle><circle cx="17.5" cy="17" r="3"></circle><path d="m6.5 17 4-7 3 7m-5-3h7l-2-5h2"></path>',
    moto: '<circle cx="6.5" cy="17" r="3"></circle><circle cx="17.5" cy="17" r="3"></circle><path d="m6.5 17 4-7 3 7m-5-3h7l-2-5h2"></path>',
    suv: '<path d="M4 17h16M5.5 17l1-6h10.5l2 6M8 11l1-3h5.5l2.5 3M6 17v2M18 17v2"></path><circle cx="8" cy="16.5" r="1"></circle><circle cx="16.5" cy="16.5" r="1"></circle>',
    sport: '<path d="M3.5 16.5h17M5 16.5l2-4.5 3-2h5l4 6.5M8 12h9"></path><circle cx="7" cy="16.5" r="1.5"></circle><circle cx="17" cy="16.5" r="1.5"></circle>',
    esportivo: '<path d="M3.5 16.5h17M5 16.5l2-4.5 3-2h5l4 6.5M8 12h9"></path><circle cx="7" cy="16.5" r="1.5"></circle><circle cx="17" cy="16.5" r="1.5"></circle>',
    police: '<path d="M5 17h14M6.5 17l1-5h9l1 5M9 12l1-3h4l1 3M10 7h4"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle>',
    policial: '<path d="M5 17h14M6.5 17l1-5h9l1 5M9 12l1-3h4l1 3M10 7h4"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle>'
  };
  const body = icons[value || ''] || icons.all;
  return `<svg viewBox="0 0 24 24" aria-hidden="true">${body}</svg>`;
}

function normalizeImagePath(value?: string | null): string {
  const path = String(value || '').trim().replace(/\\/g, '/');
  if (!path) return './assets/images/ss.png';

  if (/^(https?:|data:|blob:|nui:)/i.test(path)) return path;
  if (path.startsWith('./')) return path;
  if (path.startsWith('/assets/')) return `.${path}`;
  if (path.startsWith('assets/')) return `./${path}`;
  if (path.startsWith('/images/')) return `./assets${path}`;
  if (path.startsWith('images/')) return `./assets/${path}`;
  if (path.startsWith('web/')) return `./${path.slice(4)}`;

  const filename = path.split('/').pop() || path;
  return `./assets/images/${filename}`;
}

createApp({
  setup() {
    const visible = ref(false);
    const mode = ref<UiMode>('store');
    const payload = ref<DealershipPayload | null>(null);
    const admin = ref<AdminPayload | null>(null);
    const search = ref('');
    const activeCategory = ref('all');
    const selectedId = ref<number | null>(null);
    const adminSearch = ref('');
    const adminDealership = ref('all');
    const adminForm = ref<AdminForm>(emptyForm());
    const storeAction = ref<'buy' | 'testDrive' | null>(null);
    const adminBusy = ref(false);
    const toasts = ref<Toast[]>([]);
    let toastId = 0;

    const buying = computed(() => storeAction.value === 'buy');
    const testingVehicle = computed(() => storeAction.value === 'testDrive');

    const dealership = computed(() => payload.value?.dealership);
    const player = computed(() => payload.value?.player);
    const vehicles = computed(() => payload.value?.vehicles || []);
    const currency = computed<Currency>(() => dealership.value?.currency || 'money');

    const categories = computed<Category[]>(() => [
      { id: 'all', label: 'Todos', icon: 'grid' },
      ...(dealership.value?.categories || [])
    ]);

    const filteredVehicles = computed(() => {
      const term = search.value.trim().toLowerCase();
      return vehicles.value
        .filter((vehicle) => activeCategory.value === 'all' || vehicle.category === activeCategory.value)
        .filter((vehicle) => {
          if (!term) return true;
          return `${vehicle.name} ${vehicle.brand || ''} ${vehicle.category}`.toLowerCase().includes(term);
        })
        .sort((a, b) => Number(b.available) - Number(a.available) || a.name.localeCompare(b.name, 'pt-BR'));
    });

    function categoryCount(categoryId: string): number {
      if (categoryId === 'all') return vehicles.value.length;
      return vehicles.value.filter((vehicle) => vehicle.category === categoryId).length;
    }

    const selected = computed<Vehicle | null>(() => {
      const fromId = filteredVehicles.value.find((vehicle) => vehicle.id === selectedId.value);
      return fromId || filteredVehicles.value[0] || null;
    });

    const balance = computed(() => {
      const data = player.value;
      if (!data) return 0;
      return currency.value === 'crypto' ? data.crypto : data.money + data.bank;
    });

    const adminVehicles = computed(() => admin.value?.vehicles || []);
    const adminDealerships = computed(() => admin.value?.dealerships || []);
    const adminPeriods = computed(() => admin.value?.periods || {});
    const periodOptions = computed(() => {
      const entries = Object.entries(adminPeriods.value);
      if (!entries.length) {
        return [
          { id: 'daily', label: 'Diário', short: '24h' },
          { id: 'weekly', label: 'Semanal', short: '7 dias' },
          { id: 'monthly', label: 'Mensal', short: '30 dias' },
          { id: 'permanent', label: 'Permanente', short: 'Perm.' }
        ];
      }
      return entries.map(([id, item]) => ({ id, label: item.label || id, short: item.short || item.label || id }));
    });

    const currentAdminDealership = computed(() => {
      return adminDealerships.value.find((item) => item.id === adminForm.value.dealership) || adminDealerships.value[0] || null;
    });

    const adminCategories = computed<Category[]>(() => {
      const categories = currentAdminDealership.value?.categories || [];
      return categories.length ? categories : [{ id: 'carro', label: 'Carros', icon: 'car' }];
    });

    const filteredAdminVehicles = computed(() => {
      const term = adminSearch.value.trim().toLowerCase();
      return adminVehicles.value
        .filter((vehicle) => adminDealership.value === 'all' || vehicle.dealership === adminDealership.value)
        .filter((vehicle) => {
          if (!term) return true;
          return `${vehicle.name} ${vehicle.brand || ''} ${vehicle.model} ${vehicle.category}`.toLowerCase().includes(term);
        })
        .sort((a, b) => String(a.dealership).localeCompare(String(b.dealership), 'pt-BR') || a.name.localeCompare(b.name, 'pt-BR'));
    });

    const adminStats = computed(() => {
      const list = adminVehicles.value;
      return [
        { label: 'Cadastrados', value: list.length },
        { label: 'Ativos', value: list.filter((vehicle) => toBoolean(vehicle.enabled, true)).length },
        { label: 'Estoque total', value: list.reduce((sum, vehicle) => sum + Math.max(0, Number(vehicle.stock) || 0), 0) }
      ];
    });

    function showToast(message: string, type: NotifyType = 'info') {
      const id = ++toastId;
      toasts.value.push({ id, message, type });
      window.setTimeout(() => {
        toasts.value = toasts.value.filter((toast) => toast.id !== id);
      }, 3200);
    }

    function setStorePayload(data: DealershipPayload) {
      payload.value = data;
      mode.value = 'store';
      visible.value = true;
      storeAction.value = null;
      selectedId.value = data.vehicles?.[0]?.id || null;
      activeCategory.value = 'all';
      search.value = '';
    }

    function refreshStore(data: DealershipPayload) {
      payload.value = data;
      if (!vehicles.value.some((vehicle) => vehicle.id === selectedId.value)) {
        selectedId.value = data.vehicles?.[0]?.id || null;
      }
    }

    function setAdminPayload(data: AdminPayload, resetView = false) {
      const selectedFormId = resetView ? null : adminForm.value.id;
      admin.value = data;
      mode.value = 'admin';
      visible.value = true;
      adminBusy.value = false;

      if (resetView) {
        adminSearch.value = '';
        adminDealership.value = 'all';
        adminForm.value = emptyForm();
        newVehicle();
        return;
      }

      const refreshedVehicle = selectedFormId
        ? data.vehicles.find((vehicle) => vehicle.id === selectedFormId)
        : null;

      if (refreshedVehicle) editVehicle(refreshedVehicle);
      else if (!selectedFormId) newVehicle();
    }

    const previewParams = new URLSearchParams(window.location.search);
    if (previewParams.get('preview') === '1') {
      const previewImage = './assets/images/ss.png';
      setStorePayload({
        ok: true,
        dealership: {
          id: 'normal',
          label: 'Obscuria',
          subtitle: 'Concessionária',
          currency: 'money',
          categories: [
            { id: 'carro', label: 'Carros', icon: 'car' },
            { id: 'moto', label: 'Motos', icon: 'bike' },
            { id: 'suv', label: 'SUVs', icon: 'suv' },
            { id: 'esportivo', label: 'Esportivos', icon: 'sport' }
          ]
        },
        player: { name: 'Morgana Vale', money: 184500, bank: 920000, crypto: 74, currency: 'money' },
        vehicles: [
          { id: 1, dealership: 'normal', category: 'carro', model: 'blista', name: 'Blista', brand: 'Dinka', price: 35000, tax: 2800, taxLabel: 'Taxa de emplacamento', total: 37800, stock: -1, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: true, enabled: true, image: previewImage },
          { id: 2, dealership: 'normal', category: 'esportivo', model: 'sultan', name: 'Sultan', brand: 'Karin', price: 82000, tax: 6560, taxLabel: 'Taxa de emplacamento', total: 88560, stock: 3, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: true, enabled: true, image: previewImage },
          { id: 3, dealership: 'normal', category: 'suv', model: 'baller', name: 'Baller', brand: 'Gallivanter', price: 126000, tax: 10080, taxLabel: 'Taxa de emplacamento', total: 136080, stock: 2, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: true, enabled: true, image: previewImage },
          { id: 4, dealership: 'normal', category: 'moto', model: 'bati', name: 'Bati 801', brand: 'Pegassi', price: 64000, tax: 5120, taxLabel: 'Taxa de emplacamento', total: 69120, stock: 1, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: true, enabled: true, image: previewImage },
          { id: 5, dealership: 'normal', category: 'carro', model: 'oracle', name: 'Oracle', brand: 'Ubermacht', price: 98000, tax: 7840, taxLabel: 'Taxa de emplacamento', total: 105840, stock: 0, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: false, enabled: true, image: previewImage },
          { id: 6, dealership: 'normal', category: 'esportivo', model: 'comet2', name: 'Comet', brand: 'Pfister', price: 165000, tax: 13200, taxLabel: 'Taxa de emplacamento', total: 178200, stock: 4, purchaseType: 'permanent', durationLabel: 'Permanente', durationShort: 'Permanente', available: true, enabled: true, image: previewImage }
        ],
        testDrive: { enabled: true, price: 500, seconds: 45, currency: 'money' },
        fallbackImage: previewImage
      });

      if (previewParams.get('mode') === 'admin') {
        setAdminPayload({
          ok: true,
          mode: 'admin',
          dealerships: payload.value ? [payload.value.dealership] : [],
          vehicles: payload.value?.vehicles || [],
          periods: {
            daily: { label: 'Diário', short: '24h', days: 1 },
            weekly: { label: 'Semanal', short: '7 dias', days: 7 },
            monthly: { label: 'Mensal', short: '30 dias', days: 30 },
            permanent: { label: 'Permanente', short: 'Perm.' }
          },
          fallbackImage: previewImage
        });
      }
    }

    function close() {
      visible.value = false;
      nui('close');
    }

    function fallbackImage(): string {
      return normalizeImagePath(admin.value?.fallbackImage || payload.value?.fallbackImage);
    }

    function imageFor(vehicle: { image?: string | null } | null): string {
      return normalizeImagePath(vehicle?.image || fallbackImage());
    }

    function useImageFallback(event: Event): void {
      const image = event.currentTarget as HTMLImageElement | null;
      if (!image || image.dataset.fallbackApplied === 'true') return;
      image.dataset.fallbackApplied = 'true';
      image.src = './assets/images/ss.png';
    }

    function useIconFallback(event: Event): void {
      const image = event.currentTarget as HTMLImageElement | null;
      if (!image || image.dataset.fallbackApplied === 'true') return;
      image.dataset.fallbackApplied = 'true';
      image.src = './assets/icons/category-all.png';
    }

    function newVehicle() {
      const firstDealership = adminDealerships.value[0]?.id || 'normal';
      const next = emptyForm();
      next.dealership = String(firstDealership);
      next.category = currentAdminDealership.value?.categories?.[0]?.id || 'carro';
      adminForm.value = next;
    }

    function editVehicle(vehicle: Vehicle) {
      adminForm.value = {
        id: vehicle.id,
        dealership: String(vehicle.dealership || 'normal'),
        category: vehicle.category || 'carro',
        model: vehicle.model || '',
        name: vehicle.name || '',
        brand: vehicle.brand || '',
        price: Number(vehicle.price) || 0,
        stock: Number(vehicle.stock) || 0,
        purchaseType: vehicle.purchaseType || 'permanent',
        image: vehicle.image || '',
        enabled: toBoolean(vehicle.enabled, true),
        displayOrder: 0
      };
    }

    function setAdminDealership(value: string) {
      adminForm.value.dealership = value;
      const firstCategory = adminDealerships.value.find((item) => item.id === value)?.categories?.[0]?.id;
      if (firstCategory) adminForm.value.category = firstCategory;
    }

    function setAdminDealershipFromEvent(event: Event) {
      const target = event.target as HTMLSelectElement | null;
      setAdminDealership(target?.value || 'normal');
    }

    async function buyVehicle() {
      const vehicle = selected.value;
      if (!vehicle || storeAction.value || !vehicle.available) return;

      storeAction.value = 'buy';
      try {
        const result = await nui<NuiResponse>('buyVehicle', { id: vehicle.id });
        if (result.message) showToast(result.message, result.ok ? 'success' : 'error');
        if (result.payload && 'dealership' in result.payload) refreshStore(result.payload);
      } finally {
        storeAction.value = null;
      }
    }

    async function testDrive() {
      const vehicle = selected.value;
      if (!vehicle || storeAction.value || payload.value?.testDrive?.enabled === false) return;

      storeAction.value = 'testDrive';
      try {
        const result = await nui<NuiResponse>('testDrive', { id: vehicle.id });
        if (result.message) showToast(result.message, result.ok ? 'success' : 'error');
      } finally {
        storeAction.value = null;
      }
    }

    async function saveAdminVehicle() {
      if (adminBusy.value) return;
      adminBusy.value = true;
      try {
        const result = await nui<NuiResponse>('adminSaveVehicle', adminForm.value);
        if (result.message) showToast(result.message, result.ok ? 'success' : 'error');
        if (result.payload && 'dealerships' in result.payload) setAdminPayload(result.payload);
      } finally {
        adminBusy.value = false;
      }
    }

    async function toggleAdminVehicle(vehicle: Vehicle) {
      if (adminBusy.value) return;
      adminBusy.value = true;
      try {
        const result = await nui<NuiResponse>('adminSetVehicleEnabled', { id: vehicle.id, enabled: !toBoolean(vehicle.enabled, true) });
        if (result.message) showToast(result.message, result.ok ? 'success' : 'error');
        if (result.payload && 'dealerships' in result.payload) setAdminPayload(result.payload);
      } finally {
        adminBusy.value = false;
      }
    }

    async function deleteAdminVehicle() {
      if (!adminForm.value.id || adminBusy.value) return;
      const confirmed = window.confirm('Remover este veiculo da concessionaria?');
      if (!confirmed) return;

      adminBusy.value = true;
      try {
        const result = await nui<NuiResponse>('adminDeleteVehicle', { id: adminForm.value.id });
        if (result.message) showToast(result.message, result.ok ? 'success' : 'error');
        if (result.payload && 'dealerships' in result.payload) {
          adminForm.value = emptyForm();
          setAdminPayload(result.payload);
        }
      } finally {
        adminBusy.value = false;
      }
    }

    window.addEventListener('message', (event: MessageEvent) => {
      const data = event.data || {};
      if (data.action === 'open' && data.data) setStorePayload(data.data);
      if (data.action === 'refresh' && data.data) refreshStore(data.data);
      if (data.action === 'openAdmin' && data.data) setAdminPayload(data.data, true);
      if (data.action === 'refreshAdmin' && data.data) setAdminPayload(data.data);
      if (data.action === 'close') visible.value = false;
    });

    window.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && visible.value) close();
    });

    return {
      visible,
      mode,
      payload,
      dealership,
      player,
      categories,
      activeCategory,
      search,
      selectedId,
      selected,
      filteredVehicles,
      balance,
      buying,
      testingVehicle,
      adminBusy,
      toasts,
      currency,
      admin,
      adminSearch,
      adminDealership,
      adminDealerships,
      adminCategories,
      filteredAdminVehicles,
      adminStats,
      adminForm,
      money,
      periodText,
      periodOptions,
      toBoolean,
      iconAssetFor,
      categoryIconSvg,
      categoryCount,
      imageFor,
      useImageFallback,
      useIconFallback,
      fallbackImage,
      close,
      buyVehicle,
      testDrive,
      newVehicle,
      editVehicle,
      setAdminDealership,
      setAdminDealershipFromEvent,
      saveAdminVehicle,
      toggleAdminVehicle,
      deleteAdminVehicle
    };
  },
  template: `
    <main v-if="visible" class="dealership-shell">

      <section v-if="mode === 'store' && payload" class="dealership-panel">

        <header class="topbar">
          <div class="topbar-title">
            <small>{{ dealership?.subtitle }}</small>
            <h1>{{ dealership?.label }}</h1>
          </div>

          <div class="topbar-center">
             <label class="modern-search">
              <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="m20 20-4-4"></path></svg>
              <input v-model="search" type="text" placeholder="Buscar veículo..." aria-label="Buscar veículo" />
              <span class="search-result-count">{{ filteredVehicles.length }}</span>
            </label>
          </div>

          <div class="topbar-actions">
            <div class="balance-badge">
              <span>Saldo Disponível</span>
              <strong>{{ money(balance, currency) }}</strong>
            </div>
            <button class="btn-close" type="button" aria-label="Fechar concessionária" title="Fechar" @click="close">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"></path></svg>
            </button>
          </div>
        </header>

        <section class="content-grid">

          <aside class="sidebar">
            <button
              v-for="category in categories"
              :key="category.id"
              type="button"
              class="cat-btn"
              :class="{ active: activeCategory === category.id }"
              :title="category.label"
              :aria-label="category.label"
              @click="activeCategory = category.id"
            >
              <b class="cat-icon" aria-hidden="true" v-html="categoryIconSvg(category.icon || category.id)"></b>
              <span>{{ category.label }}</span>
              <small>{{ categoryCount(category.id) }}</small>
            </button>
          </aside>

          <section class="vehicle-list">
            <button
              v-for="vehicle in filteredVehicles"
              :key="vehicle.id"
              type="button"
              class="vehicle-card"
              :class="{ selected: selected?.id === vehicle.id, locked: !vehicle.available }"
              @click="selectedId = vehicle.id"
            >
              <div class="card-image">
                <img :src="imageFor(vehicle)" alt="" @error="useImageFallback" />
                <span class="stock-tag" :class="{ empty: !vehicle.available }">
                  {{ vehicle.stock < 0 ? 'Disponível' : vehicle.stock > 0 ? vehicle.stock + ' un.' : 'Esgotado' }}
                </span>
              </div>

              <div class="card-info">
                <div class="card-title">
                  <strong>{{ vehicle.name }}</strong>
                  <em>{{ vehicle.brand || vehicle.category }}</em>
                </div>
                <div class="card-price">
                  <b>{{ money(vehicle.total, currency) }}</b>
                  <i>{{ periodText(vehicle) }}</i>
                </div>
              </div>
            </button>

            <div v-if="!filteredVehicles.length" class="empty-state">
              Nenhum veículo encontrado.
            </div>
          </section>

          <aside class="detail-pane" v-if="selected">
            <div class="hero-image">
              <img :key="selected.id" :src="imageFor(selected)" alt="" @error="useImageFallback" />
              <div class="hero-badge" :class="{ empty: !selected.available }">
                {{ selected.stock < 0 ? 'Disponível' : selected.stock > 0 ? selected.stock + ' em estoque' : 'Sem estoque' }}
              </div>
            </div>

            <div class="detail-header">
              <span>{{ selected.brand || selected.category }}</span>
              <h2>{{ selected.name }}</h2>
              <p>{{ selected.category }}</p>
            </div>

            <div class="price-grid">
              <div class="price-item">
                <span>Valor Base</span>
                <strong>{{ money(selected.price, currency) }}</strong>
              </div>
              <div class="price-item">
                <span>{{ selected.taxLabel || 'Taxa' }}</span>
                <strong>{{ money(selected.tax, currency) }}</strong>
              </div>
              <div class="price-item total-item">
                <span>Valor Final</span>
                <strong>{{ money(selected.total, currency) }}</strong>
              </div>
            </div>

            <div class="meta-grid">
              <article>
                <span>Pagamento</span>
                <strong>{{ currency === 'crypto' ? 'Cripto Qbox' : 'Dinheiro/Banco' }}</strong>
              </article>
              <article>
                <span>Categoria</span>
                <strong>{{ selected.category }}</strong>
              </article>
              <article>
                <span>Entrega</span>
                <strong>Garagem</strong>
              </article>
              <article>
                <span>Período</span>
                <strong>{{ selected.durationLabel || periodText(selected) }}</strong>
              </article>
            </div>

            <div class="action-footer">
              <button type="button" class="btn-ghost" :disabled="buying || testingVehicle || !selected.available" @click="testDrive">
                <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="13" r="7"></circle><path d="M12 13l3-3M9 3h6M12 6V3"></path></svg>
                <span>Test drive · {{ payload.testDrive?.seconds || 45 }}s</span>
                <b>{{ payload.testDrive?.price ? money(payload.testDrive.price, payload.testDrive.currency || 'money') : 'Grátis' }}</b>
              </button>
              <button type="button" class="btn-primary" :disabled="buying || testingVehicle || !selected.available" @click="buyVehicle">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 17h14M7 17l1-5h8l1 5M8 12l1.2-3h5.6L16 12"></path><circle cx="8.5" cy="16.5" r="1"></circle><circle cx="15.5" cy="16.5" r="1"></circle></svg>
                <span>{{ buying ? 'Processando...' : 'Comprar veículo' }}</span>
                <svg class="action-arrow" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"></path></svg>
              </button>
            </div>
          </aside>
        </section>
      </section>

      <section v-if="mode === 'admin' && admin" class="dealership-panel admin-panel">

        <header class="topbar">
          <div class="topbar-title">
            <small>PAINEL STAFF</small>
            <h1>Gerenciar Concessionária</h1>
          </div>

          <div class="topbar-center admin-filters">
            <label class="modern-search">
              <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="m20 20-4-4"></path></svg>
              <input v-model="adminSearch" type="text" placeholder="Filtrar veículos..." aria-label="Filtrar veículos" />
            </label>

            <select class="modern-select" v-model="adminDealership">
              <option value="all">Todas as Lojas</option>
              <option v-for="item in adminDealerships" :key="item.id" :value="item.id">{{ item.label }}</option>
            </select>
          </div>

          <div class="topbar-actions">
            <button class="btn-new" type="button" @click="newVehicle"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"></path></svg>Adicionar veículo</button>
            <button class="btn-close" type="button" aria-label="Fechar painel" title="Fechar" @click="close">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"></path></svg>
            </button>
          </div>
        </header>

        <section class="admin-grid">

          <section class="admin-list">
            <div class="stats-row">
              <article v-for="stat in adminStats" :key="stat.label">
                <strong>{{ stat.value }}</strong>
                <span>{{ stat.label }}</span>
              </article>
            </div>

            <div class="list-wrapper">
              <button
                v-for="vehicle in filteredAdminVehicles"
                :key="vehicle.id"
                class="admin-row"
                :class="{ selected: adminForm.id === vehicle.id, disabled: !toBoolean(vehicle.enabled, true) }"
                type="button"
                @click="editVehicle(vehicle)"
              >
                <img :src="imageFor(vehicle)" alt="" @error="useImageFallback" />
                <div class="row-info">
                  <strong>{{ vehicle.name }}</strong>
                  <em>{{ vehicle.dealership }} &bull; {{ vehicle.category }} &bull; Spawn: {{ vehicle.model }}</em>
                </div>
                <div class="row-price">
                  <b>{{ money(vehicle.price, vehicle.dealership === 'vip' ? 'crypto' : 'money') }}</b>
                  <i>{{ periodText(vehicle) }}</i>
                </div>
                <div class="row-stock">
                  <span class="stock-tag" :class="{ empty: vehicle.stock <= 0 }">{{ vehicle.stock }} un.</span>
                </div>
              </button>

              <div v-if="!filteredAdminVehicles.length" class="empty-state">
                Nenhum veículo cadastrado.
              </div>
            </div>
          </section>

          <aside class="admin-sidebar">
            <div class="admin-preview">
              <img :src="imageFor(adminForm)" alt="" @error="useImageFallback" />
            </div>

            <div class="form-wrapper">
              <div class="input-group">
                <label>Loja Vinculada</label>
                <select class="modern-select" :value="adminForm.dealership" @change="setAdminDealershipFromEvent">
                  <option v-for="item in adminDealerships" :key="item.id" :value="item.id">{{ item.label }}</option>
                </select>
              </div>

              <div class="input-group">
                <label>Categoria</label>
                <select class="modern-select" v-model="adminForm.category">
                  <option v-for="category in adminCategories" :key="category.id" :value="category.id">{{ category.label }}</option>
                </select>
              </div>

              <div class="input-group">
                <label>Modelo (Spawn Code)</label>
                <input class="modern-input" v-model.trim="adminForm.model" type="text" placeholder="ex: adder" />
              </div>

              <div class="input-group">
                <label>Nome de Exibição</label>
                <input class="modern-input" v-model.trim="adminForm.name" type="text" placeholder="ex: Adder" />
              </div>

              <div class="input-group">
                <label>Marca (Opcional)</label>
                <input class="modern-input" v-model.trim="adminForm.brand" type="text" placeholder="ex: Truffade" />
              </div>

              <div class="input-group">
                <label>Preço</label>
                <input class="modern-input" v-model.number="adminForm.price" min="0" type="number" />
              </div>

              <div class="input-group">
                <label>Estoque</label>
                <input class="modern-input" v-model.number="adminForm.stock" min="0" type="number" />
              </div>

              <div class="input-group">
                <label>Tipo de Venda</label>
                <select class="modern-select" v-model="adminForm.purchaseType">
                  <option v-for="period in periodOptions" :key="period.id" :value="period.id">{{ period.label }}</option>
                </select>
              </div>

              <div class="input-group full-width">
                <label>URL da Imagem</label>
                <input class="modern-input" v-model.trim="adminForm.image" type="text" placeholder="https://..." />
              </div>

              <div class="input-group full-width">
                <label>Ordem de Exibição (Filtro)</label>
                <input class="modern-input" v-model.number="adminForm.displayOrder" type="number" />
              </div>

              <label class="toggle-switch full-width">
                <input v-model="adminForm.enabled" type="checkbox" />
                <span>Veículo Ativo e Visível na Loja</span>
              </label>
            </div>

            <div class="action-footer">
              <button type="button" class="btn-danger" :disabled="!adminForm.id || adminBusy" @click="deleteAdminVehicle">Excluir</button>
              <button type="button" class="btn-ghost" :disabled="!adminForm.id || adminBusy" @click="toggleAdminVehicle({ ...adminForm, id: adminForm.id || 0, total: adminForm.price, tax: 0, available: adminForm.stock > 0 })">
                {{ adminForm.enabled ? 'Pausar' : 'Ativar' }}
              </button>
              <button type="button" class="btn-primary" :disabled="adminBusy" @click="saveAdminVehicle">
                {{ adminBusy ? 'Salvando...' : 'Salvar Dados' }}
              </button>
            </div>
          </aside>
        </section>
      </section>

      <div class="toast-stack">
        <div v-for="toast in toasts" :key="toast.id" class="toast-card" :class="toast.type">
          {{ toast.message }}
        </div>
      </div>
    </main>
  `
}).mount('#app');
