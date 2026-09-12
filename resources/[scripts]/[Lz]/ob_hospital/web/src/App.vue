<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue';
import {
  Activity, Ambulance, Bell, Boxes, BriefcaseBusiness, Check, ChevronRight, CircleUserRound, ClipboardList,
  Clock3, CreditCard, Eye, FilePlus2, HeartPulse, MapPin, Pencil, Plus, ReceiptText,
  RefreshCw, Save, Search, ShieldCheck, ShoppingBag, Stethoscope, Thermometer, Trash2,
  UserMinus, UserPlus, UserRoundSearch, UsersRound, X
} from 'lucide-vue-next';
import bodyFront from './assets/body-front.png';
import bodyBack from './assets/body-back.png';
import emblem from './assets/obscuria-emblem.png';
import { announceQueue, setQueueAudioEnabled } from './queue-voice';

const queryParams = new URLSearchParams(window.location.search);
const previewMode = queryParams.get('preview') === '1';
const resource = window.GetParentResourceName?.() || 'ob_hospital';

const visible = ref(previewMode);
const displayVisible = ref(false);
const mode = ref(queryParams.get('mode') || 'panel');
const view = ref(queryParams.get('view') || 'dashboard');
const payload = ref(null);
const calls = ref([]);
const clinicalQueue = ref([]);
const displayQueue = ref([]);
const finishingTickets = reactive(new Map());
const updatingTickets = reactive(new Set());
const displayLimit = ref(3);
const patientResults = ref([]);
const selectedPatient = ref(null);
const selectedRecord = ref(null);
const editingRecord = ref(false);
const patientSearch = ref('');
const searching = ref(false);
const saving = ref(false);
const feedback = reactive({ text: '', type: 'success', timer: null });
const bodyView = ref('front');
const bodyCanvas = ref(null);
const hoveredPart = ref(null);
const bodyPointer = reactive({ x: 50, y: 50 });
const bodyImages = { front: null, back: null };
const bodyMaps = { front: null, back: null };
let bodyFrame = null;

const profileDraft = reactive({ bloodType: '', allergies: '', conditions: '', notes: '', photoUrl: '' });
const triage = reactive({
  title: 'Triagem clínica',
  recordType: 'triage',
  severity: 'stable',
  bodyParts: [],
  vitals: { heartRate: '', pressure: '', temperature: '', oxygen: '', consciousness: 'Consciente' },
  diagnosis: '', treatment: '', notes: '', photos: []
});
const photoDraft = reactive({ url: '', caption: '' });
const recordDraft = reactive({ title: '', severity: 'stable', diagnosis: '', treatment: '', notes: '', bodyParts: [], vitals: {}, photos: [] });
const recordPartDraft = ref('');
const recordPhotoDraft = reactive({ url: '', caption: '' });
const nearbyBillingPatients = ref([]);
const selectedBillingSource = ref('');
const invoiceDraft = reactive({ amount: '', description: '' });
const billingBusy = ref('');
const management = reactive({ staff: [], grades: [], candidates: [], summary: { total: 0, online: 0, onDuty: 0, offline: 0 }, actor: {} });
const managementBusy = ref('');

const previewPayload = {
  mode: 'panel', user: { name: '', citizenid: '', grade: 4, isManager: true, isAdmin: false, canEditRecords: true, canManageStaff: true },
  doctorCount: 0, calls: [], queue: [],
  metrics: { records_today: 0, patients: 0, resolved_today: 0 },
  recentPatients: [], billing: { plan: { enabled: true, name: 'Plano Obscuria Saúde', monthlyPrice: 5000, intervalDays: 30 }, maxInvoiceAmount: 1000000 },
  severities: [
    { value: 'stable', label: 'Estável', color: '#4eb88a' },
    { value: 'observation', label: 'Observação', color: '#d5a85e' },
    { value: 'urgent', label: 'Urgente', color: '#e57b61' },
    { value: 'critical', label: 'Crítico', color: '#e54858' }
  ]
};

const previewBillingPayload = {
  ok: true, mode: 'billing', patient: { name: 'Paciente de teste', citizenid: 'OB-2048' },
  invoices: [{ id: 1, public_code: 'HOSP-204801', description: 'Consulta clínica e medicação', amount: 2750, employee_name: 'Dra. Helena Duarte', expires_at: '2026-09-05 22:30:00' }],
  subscription: { id: 1, status: 'pending', monthly_price: 5000, created_at: '2026-09-05 21:40:00' },
  plan: { enabled: true, name: 'Plano Obscuria Saúde', monthlyPrice: 5000, intervalDays: 30 }
};

const previewManagement = {
  ok: true,
  staff: [
    { citizenid: 'OB-1001', source: 4, name: 'Helena Duarte', grade: 4, role: 'Diretora Clínica', online: true, primary: true, onDuty: true },
    { citizenid: 'OB-2034', source: 12, name: 'Samuel Reis', grade: 2, role: 'Médico', online: true, primary: true, onDuty: false },
    { citizenid: 'OB-3178', name: 'Marina Costa', grade: 1, role: 'Paramédica', online: false, primary: false, onDuty: false }
  ],
  grades: [
    { grade: 0, label: 'Estagiário' }, { grade: 1, label: 'Paramédico' }, { grade: 2, label: 'Médico' },
    { grade: 3, label: 'Cirurgião' }, { grade: 4, label: 'Diretor Clínico', isBoss: true }
  ],
  candidates: [{ source: 27, citizenid: 'OB-4410', name: 'Lucas Martins', distance: 2.1 }],
  summary: { total: 3, online: 2, onDuty: 1, offline: 1 },
  actor: { citizenid: 'OB-1001', grade: 4, isAdmin: false }
};

const shopItems = [
  { name: 'gauze', label: 'Gaze estéril', price: 120, description: 'Curativo para ferimentos leves.' },
  { name: 'bandage', label: 'Bandagem', price: 180, description: 'Bandagem de uso emergencial.' },
  { name: 'painkillers', label: 'Analgésico', price: 260, description: 'Alívio temporário da dor.' },
  { name: 'firstaid', label: 'Primeiros socorros', price: 850, description: 'Kit completo de primeiros socorros.' },
  { name: 'medical_kit', label: 'Kit médico', price: 1400, description: 'Suprimentos médicos avançados.' }
];

const nav = [
  { id: 'dashboard', label: 'Visão geral', hint: 'Resumo do plantão', icon: Activity },
  { id: 'queue', label: 'Fila clínica', hint: 'Senhas e atendimento', icon: ClipboardList },
  { id: 'dispatch', label: 'Emergências', hint: 'Ocorrências externas', icon: Ambulance },
  { id: 'patients', label: 'Pacientes', hint: 'Prontuários e histórico', icon: UsersRound },
  { id: 'triage', label: 'Triagem', hint: 'Avaliação clínica', icon: Stethoscope },
  { id: 'reception', label: 'Recepção', hint: 'Planos e pagamentos', icon: CreditCard },
  { id: 'management', label: 'Gerência', hint: 'Equipe e plantão', icon: BriefcaseBusiness, managerOnly: true }
];

const frontRegions = [
  { key: 'head', label: 'Cabeça' }, { key: 'neck', label: 'Pescoço' },
  { key: 'chest', label: 'Tórax' }, { key: 'abdomen', label: 'Abdômen' }, { key: 'pelvis', label: 'Quadril' },
  { key: 'right_shoulder', label: 'Ombro direito' }, { key: 'left_shoulder', label: 'Ombro esquerdo' },
  { key: 'right_arm', label: 'Braço direito' }, { key: 'left_arm', label: 'Braço esquerdo' },
  { key: 'right_hand', label: 'Mão direita' }, { key: 'left_hand', label: 'Mão esquerda' },
  { key: 'right_thigh', label: 'Coxa direita' }, { key: 'left_thigh', label: 'Coxa esquerda' },
  { key: 'right_leg', label: 'Perna direita' }, { key: 'left_leg', label: 'Perna esquerda' },
  { key: 'right_foot', label: 'Pé direito' }, { key: 'left_foot', label: 'Pé esquerdo' }
];

const backRegions = [
  { key: 'back_head', label: 'Cabeça posterior' }, { key: 'back_neck', label: 'Nuca' },
  { key: 'upper_back', label: 'Costas superiores' }, { key: 'lower_back', label: 'Lombar' }, { key: 'back_pelvis', label: 'Quadril posterior' },
  { key: 'back_right_shoulder', label: 'Ombro direito posterior' }, { key: 'back_left_shoulder', label: 'Ombro esquerdo posterior' },
  { key: 'back_right_arm', label: 'Braço direito posterior' }, { key: 'back_left_arm', label: 'Braço esquerdo posterior' },
  { key: 'back_right_hand', label: 'Mão direita posterior' }, { key: 'back_left_hand', label: 'Mão esquerda posterior' },
  { key: 'back_right_thigh', label: 'Coxa direita posterior' }, { key: 'back_left_thigh', label: 'Coxa esquerda posterior' },
  { key: 'back_right_leg', label: 'Perna direita posterior' }, { key: 'back_left_leg', label: 'Perna esquerda posterior' },
  { key: 'back_right_foot', label: 'Pé direito posterior' }, { key: 'back_left_foot', label: 'Pé esquerdo posterior' }
];

const currentRegions = computed(() => bodyView.value === 'front' ? frontRegions : backRegions);
const activeCalls = computed(() => calls.value.filter(call => !['resolved', 'cancelled'].includes(call.status)));
const activeQueue = computed(() => clinicalQueue.value.filter(ticket => !['resolved', 'cancelled'].includes(ticket.status)));
const calledQueue = computed(() => activeQueue.value.filter(ticket => ticket.status === 'called'));
const boardQueue = computed(() => {
  const tickets = new Map([...finishingTickets.values()].map(ticket => [ticket.id, ticket]));
  displayQueue.value.filter(ticket => ['waiting', 'called'].includes(ticket.status)).forEach(ticket => tickets.set(ticket.id, ticket));
  return [...tickets.values()];
});
const selectedParts = computed(() => triage.bodyParts.map(key => [...frontRegions, ...backRegions].find(item => item.key === key)?.label || key));
const allBodyRegions = [...frontRegions, ...backRegions];
const canEditRecords = computed(() => payload.value?.user?.canEditRecords === true);
const navItems = computed(() => nav.filter(item => !item.managerOnly || payload.value?.user?.canManageStaff === true));
const selectedBillingPatient = computed(() => nearbyBillingPatients.value.find(patient => String(patient.source) === String(selectedBillingSource.value)) || null);
const vitalFields = [
  { key: 'heartRate', label: 'Frequência cardíaca' }, { key: 'pressure', label: 'Pressão arterial' },
  { key: 'temperature', label: 'Temperatura' }, { key: 'oxygen', label: 'Saturação' },
  { key: 'consciousness', label: 'Consciência' }
];
const screenTitle = computed(() => nav.find(item => item.id === view.value)?.label || 'Painel médico');
const screenHint = computed(() => nav.find(item => item.id === view.value)?.hint || 'Instituto Médico de Obscuria');

function toast(text, type = 'success') {
  feedback.text = text;
  feedback.type = type;
  clearTimeout(feedback.timer);
  feedback.timer = setTimeout(() => { feedback.text = ''; }, 2800);
}

async function nui(action, data = {}) {
  if (previewMode) {
    if (action === 'searchPatients') return { ok: true, patients: [] };
    if (action === 'patient') return { ok: false, error: 'patient_not_found' };
    if (action === 'createRecord') {
      if (!selectedPatient.value) return { ok: false, error: 'patient_not_found' };
      const patient = structuredClone(selectedPatient.value);
      patient.records.unshift({ id: Date.now(), title: data.title, record_type: data.recordType, severity: data.severity, medic_name: 'Equipe médica', diagnosis: data.diagnosis, treatment: data.treatment, body_parts: data.bodyParts, photos: data.photos, created_at: 'Agora' });
      return { ok: true, patient };
    }
    if (action === 'savePatient') return { ok: true, patient: selectedPatient.value };
    if (action === 'updateRecord') {
      const patient = structuredClone(selectedPatient.value);
      const index = patient.records.findIndex(record => record.id === data.id);
      if (index !== -1) patient.records[index] = { ...patient.records[index], ...data };
      return { ok: true, patient };
    }
    if (action === 'nearbyPatients') return { ok: true, patients: [{ source: 7, citizenid: 'OB-2048', name: 'Paciente de teste', distance: 1.4 }] };
    if (action === 'createInvoice') return { ok: true, covered: false, code: 'HOSP-204801', amount: Number(data.amount) };
    if (action === 'proposeSubscription') return { ok: true, plan: previewPayload.billing.plan };
    if (action === 'billing') return structuredClone(previewBillingPayload);
    if (['management', 'hireStaff', 'setStaffGrade', 'fireStaff'].includes(action)) return structuredClone(previewManagement);
    if (action === 'payInvoice') {
      const result = structuredClone(payload.value);
      result.invoices = (result.invoices || []).filter(invoice => invoice.id !== data.id);
      result.ok = true;
      result.paidAmount = 2750;
      return result;
    }
    if (action === 'acceptSubscription') {
      const result = structuredClone(payload.value);
      result.ok = true;
      result.subscription = { ...result.subscription, status: 'active', next_charge_at: '2026-10-05 21:40:00' };
      result.subscriptionActivated = true;
      return result;
    }
    if (action === 'cancelSubscription') {
      const result = structuredClone(payload.value);
      result.ok = true;
      result.subscription = { ...result.subscription, status: 'cancelled', cancelled_at: '2026-09-05 21:45:00' };
      result.subscriptionCancelled = true;
      return result;
    }
    if (action === 'updateCall') {
      calls.value = calls.value.map(call => call.id === data.id ? { ...call, status: data.status, assigned_name: 'Equipe médica' } : call);
      return { ok: true, calls: calls.value };
    }
    if (action === 'updateQueue') {
      if (data.status === 'repeat') return { ok: true, queue: clinicalQueue.value };
      clinicalQueue.value = clinicalQueue.value.map(ticket => ticket.id === data.id ? { ...ticket, status: data.status, called_by_name: 'Equipe médica' } : ticket);
      return { ok: true, queue: clinicalQueue.value };
    }
    return { ok: true };
  }
  const response = await fetch(`https://${resource}/request`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify({ action, data })
  });
  return response.json().catch(() => ({ ok: false, error: 'invalid_response' }));
}

function hydrate(next) {
  payload.value = next;
  calls.value = Array.isArray(next?.calls) ? next.calls : [];
  clinicalQueue.value = Array.isArray(next?.queue) ? next.queue : [];
}

function close() {
  if (previewMode) return;
  fetch(`https://${resource}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
}

function onMessage(event) {
  const message = event.data || {};
  if (message.action === 'open') {
    mode.value = message.mode || 'panel';
    visible.value = true;
    displayVisible.value = false;
    hydrate(message.payload || {});
    if (mode.value === 'panel') view.value = 'dashboard';
  } else if (message.action === 'close') {
    visible.value = false;
    selectedRecord.value = null;
    editingRecord.value = false;
  } else if (message.action === 'display') {
    displayVisible.value = message.visible === true;
    if (Array.isArray(message.payload?.queue)) displayQueue.value = message.payload.queue;
    if (Number.isInteger(message.payload?.displayLimit)) displayLimit.value = Math.min(3, Math.max(1, message.payload.displayLimit));
  } else if (message.action === 'dispatchUpdate') {
    const index = calls.value.findIndex(call => call.id === message.call?.id);
    if (index === -1) calls.value.unshift(message.call); else calls.value[index] = message.call;
  } else if (message.action === 'queueUpdate') {
    clinicalQueue.value = Array.isArray(message.queue) ? message.queue : [];
  } else if (message.action === 'billingUpdate') {
    updateBillingPayload(message.payload || {});
  } else if (message.action === 'subscriptionUpdate') {
    updatePatientPlan(message.citizenid, message.plan || {});
  } else if (message.action === 'queueAudio') {
    setQueueAudioEnabled(message.enabled);
  } else if (message.action === 'queueAnnouncement') {
    const announcement = message.announcement;
    const ticket = announcement?.phase === 'end' ? announcement.ticket : null;
    if (ticket && finishingTickets.has(ticket.id)) return;
    if (ticket) finishingTickets.set(ticket.id, ticket);
    const queued = announceQueue(announcement, message.voice, () => {
      if (ticket) finishingTickets.delete(ticket.id);
    });
    if (!queued && ticket) finishingTickets.delete(ticket.id);
  }
}

function onKey(event) {
  if (event.key !== 'Escape' || !visible.value) return;
  if (selectedRecord.value) closeRecord(); else close();
}

async function searchPatients() {
  searching.value = true;
  const response = await nui('searchPatients', { query: patientSearch.value });
  patientResults.value = response.ok ? response.patients || [] : [];
  searching.value = false;
}

function fillProfile(patient) {
  const profile = patient.profile || {};
  profileDraft.bloodType = profile.blood_type || '';
  profileDraft.allergies = profile.allergies || '';
  profileDraft.conditions = profile.conditions || '';
  profileDraft.notes = profile.notes || '';
  profileDraft.photoUrl = profile.photo_url || '';
}

async function openPatient(entry, nextView = 'patients') {
  const response = await nui('patient', { citizenid: entry.citizenid });
  if (!response.ok) { toast('Não foi possível carregar o prontuário.', 'error'); return; }
  selectedPatient.value = response.patient;
  selectedRecord.value = null;
  editingRecord.value = false;
  fillProfile(response.patient);
  view.value = nextView;
}

function fillRecordDraft(record) {
  recordDraft.title = record.title || '';
  recordDraft.severity = record.severity || 'stable';
  recordDraft.diagnosis = record.diagnosis || '';
  recordDraft.treatment = record.treatment || '';
  recordDraft.notes = record.notes || '';
  recordDraft.bodyParts.splice(0, recordDraft.bodyParts.length, ...(Array.isArray(record.body_parts) ? record.body_parts : []));
  recordDraft.vitals = { ...(record.vitals || {}) };
  recordDraft.photos.splice(0, recordDraft.photos.length, ...(Array.isArray(record.photos) ? record.photos.map(photo => ({ ...photo })) : []));
  recordPartDraft.value = '';
  recordPhotoDraft.url = '';
  recordPhotoDraft.caption = '';
}

function openRecord(record) {
  selectedRecord.value = JSON.parse(JSON.stringify(record));
  editingRecord.value = false;
  fillRecordDraft(record);
}

function closeRecord() {
  selectedRecord.value = null;
  editingRecord.value = false;
}

function cancelRecordEdit() {
  if (selectedRecord.value) fillRecordDraft(selectedRecord.value);
  editingRecord.value = false;
}

function addRecordPart() {
  if (!recordPartDraft.value || recordDraft.bodyParts.includes(recordPartDraft.value)) return;
  recordDraft.bodyParts.push(recordPartDraft.value);
  recordPartDraft.value = '';
}

function addRecordPhoto() {
  if (!recordPhotoDraft.url.trim()) return;
  recordDraft.photos.push({ url: recordPhotoDraft.url.trim(), caption: recordPhotoDraft.caption.trim() });
  recordPhotoDraft.url = '';
  recordPhotoDraft.caption = '';
}

async function saveRecord() {
  if (!selectedRecord.value || saving.value || !canEditRecords.value) return;
  saving.value = true;
  const response = await nui('updateRecord', {
    id: selectedRecord.value.id,
    title: recordDraft.title,
    severity: recordDraft.severity,
    diagnosis: recordDraft.diagnosis,
    treatment: recordDraft.treatment,
    notes: recordDraft.notes,
    bodyParts: [...recordDraft.bodyParts],
    vitals: { ...recordDraft.vitals },
    photos: recordDraft.photos.map(photo => ({ ...photo }))
  });
  saving.value = false;
  if (!response.ok) {
    toast(response.error === 'record_edit_forbidden' ? 'Sua graduação não permite editar prontuários.' : 'Não foi possível atualizar o registro.', 'error');
    return;
  }
  if (response.patient) {
    selectedPatient.value = response.patient;
    const updated = response.patient.records?.find(record => record.id === selectedRecord.value.id);
    if (updated) selectedRecord.value = JSON.parse(JSON.stringify(updated));
  }
  editingRecord.value = false;
  toast('Registro médico atualizado.');
}

async function saveProfile() {
  if (!selectedPatient.value) return;
  saving.value = true;
  const response = await nui('savePatient', { citizenid: selectedPatient.value.citizenid, ...profileDraft });
  saving.value = false;
  if (!response.ok) { toast('Não foi possível salvar o perfil.', 'error'); return; }
  if (response.patient) selectedPatient.value = response.patient;
  toast('Dados do paciente atualizados.');
}

function togglePart(key) {
  const index = triage.bodyParts.indexOf(key);
  if (index === -1) triage.bodyParts.push(key); else triage.bodyParts.splice(index, 1);
}

function anatomicalSide(side, x, part) {
  const right = side === 'front' ? x < 50 : x >= 50;
  return `${side === 'back' ? 'back_' : ''}${right ? 'right' : 'left'}_${part}`;
}

function torsoEdge(side, y) {
  if (side === 'front') {
    if (y <= 18) return 42;
    if (y <= 33) return 42 - ((y - 18) / 15) * 3;
    if (y <= 41) return 39 - ((y - 33) / 8) * 4;
    if (y <= 44) return 35 - ((y - 41) / 3) * 6.5;
    return 28.5;
  }
  if (y <= 18) return 40;
  if (y <= 36) return 40 - ((y - 18) / 18) * 3;
  if (y <= 44) return 37;
  return 35 - ((y - 44) / 10) * 2;
}

function classifyBodyPixel(side, x, y) {
  if (side === 'front') {
    if (y < 14) return 'head';
    if (y < 18 && x >= 42 && x <= 58) return 'neck';

    if (y < 52) {
      const edge = torsoEdge(side, y);
      if (x >= edge && x <= 100 - edge) {
        if (y < 33) return 'chest';
        if (y < 41) return 'abdomen';
        return 'pelvis';
      }
    }

    if (y < 31) return anatomicalSide(side, x, 'shoulder');
    if (y < 45.5) return anatomicalSide(side, x, 'arm');
    if (y < 57 && (x < 31 || x > 69)) return anatomicalSide(side, x, 'hand');
    if (y < 70) return anatomicalSide(side, x, 'thigh');
    if (y < 86) return anatomicalSide(side, x, 'leg');
    return anatomicalSide(side, x, 'foot');
  }

  if (y < 14) return 'back_head';
  if (y < 19 && x >= 41 && x <= 59) return 'back_neck';

  if (y < 54) {
    const edge = torsoEdge(side, y);
    if (x >= edge && x <= 100 - edge) {
      if (y < 36) return 'upper_back';
      if (y < 44) return 'lower_back';
      return 'back_pelvis';
    }
  }

  if (y < 32) return anatomicalSide(side, x, 'shoulder');
  if (y < 46) return anatomicalSide(side, x, 'arm');
  if (y < 58 && (x < 31 || x > 69)) return anatomicalSide(side, x, 'hand');
  if (y < 72) return anatomicalSide(side, x, 'thigh');
  if (y < 87) return anatomicalSide(side, x, 'leg');
  return anatomicalSide(side, x, 'foot');
}

function prepareBodyMap(side, image) {
  const source = document.createElement('canvas');
  source.width = image.naturalWidth;
  source.height = image.naturalHeight;
  const context = source.getContext('2d', { willReadFrequently: true });
  context.drawImage(image, 0, 0);
  const base = context.getImageData(0, 0, source.width, source.height);
  const regions = side === 'front' ? frontRegions : backRegions;
  const idToKey = [null, ...regions.map(region => region.key)];
  const keyToId = Object.fromEntries(idToKey.map((key, id) => [key, id]).slice(1));
  const regionIds = new Uint8Array(source.width * source.height);
  const buckets = Array.from({ length: idToKey.length }, () => []);

  for (let index = 0; index < regionIds.length; index += 1) {
    if (base.data[(index * 4) + 3] === 0) continue;
    const x = (((index % source.width) + 0.5) / source.width) * 100;
    const y = ((Math.floor(index / source.width) + 0.5) / source.height) * 100;
    const id = keyToId[classifyBodyPixel(side, x, y)] || 0;
    regionIds[index] = id;
    if (id) buckets[id].push(index);
  }

  bodyMaps[side] = {
    width: source.width,
    height: source.height,
    base,
    regionIds,
    idToKey,
    keyToId,
    pixels: buckets.map(bucket => Uint32Array.from(bucket))
  };
}

function tintPixels(data, pixels, color, strength) {
  pixels.forEach(index => {
    const offset = index * 4;
    data[offset] = Math.round(data[offset] + ((color[0] - data[offset]) * strength));
    data[offset + 1] = Math.round(data[offset + 1] + ((color[1] - data[offset + 1]) * strength));
    data[offset + 2] = Math.round(data[offset + 2] + ((color[2] - data[offset + 2]) * strength));
  });
}

function drawBodyMap() {
  const canvas = bodyCanvas.value;
  const map = bodyMaps[bodyView.value];
  if (!canvas || !map) return;

  if (canvas.width !== map.width) canvas.width = map.width;
  if (canvas.height !== map.height) canvas.height = map.height;
  const context = canvas.getContext('2d');
  const output = new Uint8ClampedArray(map.base.data);
  const selected = new Set(triage.bodyParts);
  selected.forEach(key => {
    const id = map.keyToId[key];
    if (id) tintPixels(output, map.pixels[id], [226, 43, 58], 0.74);
  });

  const hoveredId = map.keyToId[hoveredPart.value];
  if (hoveredId && !selected.has(hoveredPart.value)) tintPixels(output, map.pixels[hoveredId], [73, 164, 216], 0.24);
  context.putImageData(new ImageData(output, map.width, map.height), 0, 0);
}

function bodyRegionAt(event) {
  const rect = bodyCanvas.value?.getBoundingClientRect();
  const map = bodyMaps[bodyView.value];
  if (!rect || !map) return null;
  const x = ((event.clientX - rect.left) / rect.width) * 100;
  const y = ((event.clientY - rect.top) / rect.height) * 100;
  bodyPointer.x = x;
  bodyPointer.y = y;
  const px = Math.min(map.width - 1, Math.max(0, Math.floor((x / 100) * map.width)));
  const py = Math.min(map.height - 1, Math.max(0, Math.floor((y / 100) * map.height)));
  const key = map.idToKey[map.regionIds[(py * map.width) + px]];
  return currentRegions.value.find(region => region.key === key) || null;
}

function onBodyMove(event) {
  hoveredPart.value = bodyRegionAt(event)?.key || null;
}

function onBodyClick(event) {
  const region = bodyRegionAt(event);
  if (region) togglePart(region.key);
}

function scheduleBodyDraw() {
  if (bodyFrame !== null) return;
  bodyFrame = requestAnimationFrame(() => {
    bodyFrame = null;
    drawBodyMap();
  });
}

function loadBodyImages() {
  Object.entries({ front: bodyFront, back: bodyBack }).forEach(([side, source]) => {
    const image = new Image();
    image.decoding = 'async';
    image.onload = () => {
      bodyImages[side] = image;
      prepareBodyMap(side, image);
      if (side === bodyView.value) drawBodyMap();
    };
    image.src = source;
  });
}

function addPhoto() {
  if (!photoDraft.url.trim()) return;
  triage.photos.push({ url: photoDraft.url.trim(), caption: photoDraft.caption.trim() });
  photoDraft.url = '';
  photoDraft.caption = '';
}

function resetTriage() {
  triage.title = 'Triagem clínica'; triage.recordType = 'triage'; triage.severity = 'stable'; triage.bodyParts.splice(0);
  Object.assign(triage.vitals, { heartRate: '', pressure: '', temperature: '', oxygen: '', consciousness: 'Consciente' });
  triage.diagnosis = ''; triage.treatment = ''; triage.notes = ''; triage.photos.splice(0);
}

async function saveTriage() {
  if (saving.value) return;
  if (!selectedPatient.value) { toast('Selecione um paciente antes de registrar a triagem.', 'error'); return; }
  saving.value = true;
  const response = await nui('createRecord', { citizenid: selectedPatient.value.citizenid, patientSource: selectedPatient.value.source, ...triage, bodyParts: [...triage.bodyParts], vitals: { ...triage.vitals }, photos: [...triage.photos] });
  saving.value = false;
  if (!response.ok) { toast('Não foi possível salvar a triagem.', 'error'); return; }
  if (response.patient) selectedPatient.value = response.patient;
  if (Array.isArray(response.queue)) clinicalQueue.value = response.queue;
  resetTriage();
  if (response.queueError) {
    toast('Triagem salva, mas a entrada na fila falhou. Atualize a triagem para tentar novamente.', 'error');
  } else {
    toast(response.ticket ? `Triagem salva. Senha ${response.ticket.ticket_code} na fila de atendimento.` : 'Triagem anexada ao prontuário.');
  }
}

async function updateCall(call, status) {
  const response = await nui('updateCall', { id: call.id, status });
  if (!response.ok) { toast('Não foi possível atualizar o chamado.', 'error'); return; }
  calls.value = response.calls || calls.value;
  toast(status === 'resolved' ? 'Chamado finalizado.' : 'Chamado atualizado.');
}

async function updateQueue(ticket, status) {
  if (updatingTickets.has(ticket.id)) return;
  updatingTickets.add(ticket.id);
  let response;
  try {
    response = await nui('updateQueue', { id: ticket.id, status });
  } catch {
    response = { ok: false };
  } finally {
    updatingTickets.delete(ticket.id);
  }
  if (!response.ok) {
    const errors = {
      display_full: 'Aguarde uma das chamadas do telão terminar.',
      queue_busy: 'A fila está sendo atualizada. Tente novamente.',
      queue_changed: 'Esta senha já foi atualizada por outro profissional.',
      queue_owned: 'Este paciente está sob atendimento de outro profissional.',
      repeat_cooldown: 'Aguarde alguns segundos antes de repetir a chamada.'
    };
    toast(errors[response.error] || 'Não foi possível atualizar a senha.', 'error'); return;
  }
  clinicalQueue.value = response.queue || clinicalQueue.value;
  const messages = {
    called: `Senha ${ticket.ticket_code} chamada no telão.`,
    repeat: `Chamada da senha ${ticket.ticket_code} repetida.`,
    in_service: `Atendimento da senha ${ticket.ticket_code} iniciado.`,
    resolved: `Atendimento da senha ${ticket.ticket_code} finalizado.`,
    cancelled: `Senha ${ticket.ticket_code} cancelada.`
  };
  toast(messages[status] || 'Fila clínica atualizada.');
}

function waypoint(call) {
  if (previewMode) { toast('Rota marcada no GPS.'); return; }
  fetch(`https://${resource}/waypoint`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ coords: call.coords }) });
}

async function buy(item) {
  const response = await nui('purchase', { name: item.name, amount: 1 });
  toast(response.ok ? `${item.label} adicionado ao inventário.` : 'Compra não autorizada.', response.ok ? 'success' : 'error');
}

function formatStatus(status) {
  return { awaiting_triage: 'Aguardando triagem', waiting: 'Aguardando médico', called: 'Atendimento aceito', in_service: 'Em atendimento', assigned: 'Atribuído', on_scene: 'No local', transporting: 'Em transporte', resolved: 'Finalizado', cancelled: 'Cancelado' }[status] || status;
}

function doctorWithArticle(ticket) {
  if (!ticket?.called_by_name) return 'a equipe médica';
  const title = ticket.called_by_title === 'Doutora' ? 'Doutora' : 'Doutor';
  return `${title === 'Doutora' ? 'a' : 'o'} ${title} ${ticket.called_by_name}`;
}

function doctorAttribution(ticket) {
  if (!ticket?.called_by_name) return 'Chamado pela equipe médica';
  const title = ticket.called_by_title === 'Doutora' ? 'Doutora' : 'Doutor';
  return `Chamado ${title === 'Doutora' ? 'pela' : 'pelo'} ${title} ${ticket.called_by_name}`;
}

function formatTime(value) {
  if (!value) return '';
  const date = new Date(typeof value === 'number' ? value : String(value).replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

function formatSeverity(value) {
  return { low: 'Baixa', normal: 'Normal', stable: 'Estável', observation: 'Observação', urgent: 'Urgente', critical: 'Crítico' }[value] || value;
}

function formatRecordType(value) {
  return { triage: 'Triagem', consultation: 'Consulta', automatic: 'Atendimento automático' }[value] || value || 'Registro clínico';
}

function bodyPartLabel(key) {
  return allBodyRegions.find(region => region.key === key)?.label || key;
}

function money(value) {
  return Number(value || 0).toLocaleString('pt-BR');
}

function formatDate(value) {
  if (!value) return 'Não informado';
  const date = new Date(String(value).replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

function subscriptionStatus(status) {
  return { pending: 'Aguardando aceite', active: 'Ativo', past_due: 'Pagamento pendente', cancelled: 'Cancelado' }[status] || 'Sem plano';
}

function hasActivePlan(patient) {
  return patient?.plan?.active === true || Number(patient?.plan?.active) === 1;
}

function patientPlanTitle(patient) {
  if (!hasActivePlan(patient)) return '';
  const name = patient.plan?.name || payload.value?.billing?.plan?.name || 'Plano hospitalar';
  return patient.plan?.next_charge_at ? `${name} ativo até ${formatDate(patient.plan.next_charge_at)}` : `${name} ativo`;
}

function updatePatientPlan(citizenid, plan) {
  if (!citizenid) return;
  const apply = patient => patient?.citizenid === citizenid || patient?.patient_identifier === citizenid
    ? { ...patient, plan: { ...plan } }
    : patient;
  patientResults.value = patientResults.value.map(apply);
  nearbyBillingPatients.value = nearbyBillingPatients.value.map(apply);
  clinicalQueue.value = clinicalQueue.value.map(apply);
  if (Array.isArray(payload.value?.recentPatients)) payload.value.recentPatients = payload.value.recentPatients.map(apply);
  if (selectedPatient.value?.citizenid === citizenid) selectedPatient.value = apply(selectedPatient.value);
}

function billingError(error) {
  return {
    patient_not_nearby: 'O paciente selecionado não está mais próximo.', invalid_amount: 'Informe um valor válido para a comanda.',
    description_required: 'Descreva o atendimento da comanda.', insufficient_money: 'Saldo bancário insuficiente.',
    invoice_unavailable: 'Esta comanda não está mais disponível.', subscription_unavailable: 'A proposta de plano não está disponível.',
    plan_already_active: 'Este paciente já possui um plano ativo.', subscription_already_pending: 'Este paciente já possui uma proposta ou regularização pendente.', terminal_too_far: 'Aproxime-se da maquininha do hospital.'
  }[error] || 'Não foi possível concluir esta operação.';
}

async function loadNearbyBillingPatients() {
  const response = await nui('nearbyPatients');
  nearbyBillingPatients.value = response.ok ? response.patients || [] : [];
  if (!nearbyBillingPatients.value.some(patient => String(patient.source) === String(selectedBillingSource.value))) selectedBillingSource.value = '';
  if (!response.ok) toast(billingError(response.error), 'error');
}

async function createInvoice() {
  if (!selectedBillingPatient.value || billingBusy.value) { toast('Selecione um paciente próximo.', 'error'); return; }
  billingBusy.value = 'invoice';
  const response = await nui('createInvoice', { customerSource: selectedBillingPatient.value.source, amount: Number(invoiceDraft.amount), description: invoiceDraft.description });
  billingBusy.value = '';
  if (!response.ok) { toast(billingError(response.error), 'error'); return; }
  invoiceDraft.amount = ''; invoiceDraft.description = '';
  toast(response.covered ? `Comanda ${response.code} coberta pelo plano do paciente.` : `Comanda ${response.code} enviada à maquininha do paciente.`);
}

async function proposeSubscription() {
  if (!selectedBillingPatient.value || billingBusy.value) { toast('Selecione um paciente próximo.', 'error'); return; }
  billingBusy.value = 'plan';
  const response = await nui('proposeSubscription', { customerSource: selectedBillingPatient.value.source });
  billingBusy.value = '';
  if (!response.ok) { toast(billingError(response.error), 'error'); return; }
  toast('Proposta enviada. O paciente pode aceitar na maquininha.');
}

function updateBillingPayload(response) {
  payload.value = { ...payload.value, ...response };
}

async function payInvoice(invoice) {
  if (billingBusy.value) return;
  billingBusy.value = `invoice-${invoice.id}`;
  const response = await nui('payInvoice', { id: invoice.id });
  billingBusy.value = '';
  if (!response.ok) { toast(billingError(response.error), 'error'); return; }
  updateBillingPayload(response);
  toast(`Pagamento de $ ${money(response.paidAmount)} confirmado.`);
}

async function acceptSubscription() {
  if (billingBusy.value) return;
  billingBusy.value = 'accept-plan';
  const response = await nui('acceptSubscription');
  billingBusy.value = '';
  if (!response.ok) { toast(billingError(response.error), 'error'); return; }
  updateBillingPayload(response);
  toast(response.subscriptionActivated ? 'Plano hospitalar ativado.' : 'Plano regularizado.');
}

async function cancelSubscription() {
  if (billingBusy.value) return;
  billingBusy.value = 'cancel-plan';
  const response = await nui('cancelSubscription');
  billingBusy.value = '';
  if (!response.ok) { toast(billingError(response.error), 'error'); return; }
  updateBillingPayload(response);
  toast('Plano cancelado. Não haverá novas cobranças.');
}

function managementError(error) {
  return {
    not_manager: 'Acesso restrito à direção do hospital.',
    target_player_not_found: 'O jogador selecionado não está mais disponível.',
    target_not_nearby: 'O jogador precisa permanecer próximo para ser contratado.',
    already_staff: 'Esta pessoa já faz parte da equipe médica.',
    member_not_found: 'Este funcionário não pertence mais à equipe.',
    invalid_grade: 'O cargo selecionado não existe.',
    cannot_manage_self: 'Você não pode alterar o próprio vínculo por este painel.',
    manager_hierarchy: 'Você não pode alterar alguém do mesmo nível ou superior.',
    job_update_failed: 'O Qbox não conseguiu atualizar o vínculo profissional.'
  }[error] || 'Não foi possível atualizar a equipe médica.';
}

function applyManagement(response) {
  management.staff = Array.isArray(response.staff) ? response.staff : [];
  management.grades = Array.isArray(response.grades) ? response.grades : [];
  management.candidates = Array.isArray(response.candidates) ? response.candidates : [];
  management.summary = response.summary || { total: 0, online: 0, onDuty: 0, offline: 0 };
  management.actor = response.actor || {};
}

async function loadManagement() {
  if (managementBusy.value) return;
  managementBusy.value = 'refresh';
  const response = await nui('management');
  managementBusy.value = '';
  if (!response.ok) { toast(managementError(response.error), 'error'); return; }
  applyManagement(response);
}

function canManageMember(member) {
  if (management.actor?.isAdmin) return true;
  return member.citizenid !== management.actor?.citizenid && Number(member.grade) < Number(management.actor?.grade || 0);
}

function selectableGrades(member) {
  if (management.actor?.isAdmin) return management.grades;
  return management.grades.filter(grade => Number(grade.grade) < Number(management.actor?.grade || 0) || Number(grade.grade) === Number(member.grade));
}

function staffStatus(member) {
  if (member.onDuty) return 'Em serviço';
  if (member.online) return member.primary ? 'Fora de serviço' : 'Outro emprego ativo';
  return 'Offline';
}

async function hireStaff(candidate) {
  if (managementBusy.value) return;
  managementBusy.value = `hire-${candidate.source}`;
  const response = await nui('hireStaff', { source: candidate.source });
  managementBusy.value = '';
  if (!response.ok) { toast(managementError(response.error), 'error'); return; }
  applyManagement(response);
  toast(`${candidate.name} foi contratado para a equipe médica.`);
}

async function changeStaffGrade(member, event) {
  const grade = Number(event.target.value);
  if (grade === Number(member.grade) || managementBusy.value) return;
  managementBusy.value = `grade-${member.citizenid}`;
  const response = await nui('setStaffGrade', { citizenid: member.citizenid, grade });
  managementBusy.value = '';
  if (!response.ok) { event.target.value = String(member.grade); toast(managementError(response.error), 'error'); return; }
  applyManagement(response);
  toast(`Cargo de ${member.name} atualizado.`);
}

async function fireStaff(member) {
  if (managementBusy.value || !canManageMember(member)) return;
  if (!window.confirm(`Desligar ${member.name} da equipe médica?`)) return;
  managementBusy.value = `fire-${member.citizenid}`;
  const response = await nui('fireStaff', { citizenid: member.citizenid });
  managementBusy.value = '';
  if (!response.ok) { toast(managementError(response.error), 'error'); return; }
  applyManagement(response);
  toast(`${member.name} foi desligado da equipe.`);
}

watch(view, next => {
  if (next === 'reception') loadNearbyBillingPatients();
  if (next === 'management') loadManagement();
});

watch([bodyView, () => [...triage.bodyParts], hoveredPart], scheduleBodyDraw, { deep: true });
watch([view, selectedPatient], () => nextTick(scheduleBodyDraw));

onMounted(() => {
  window.addEventListener('message', onMessage);
  window.addEventListener('keydown', onKey);
  loadBodyImages();
  if (previewMode) {
    if (mode.value === 'display') {
      visible.value = false;
      displayVisible.value = true;
      displayQueue.value = [];
    } else if (mode.value === 'shop') hydrate({ mode: 'shop', items: shopItems, doctors: 0 });
    else if (mode.value === 'billing') hydrate(structuredClone(previewBillingPayload));
    else {
      hydrate(structuredClone(previewPayload));
      patientResults.value = [];
    }
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage);
  window.removeEventListener('keydown', onKey);
  if (bodyFrame !== null) cancelAnimationFrame(bodyFrame);
  setQueueAudioEnabled(false);
});
</script>

<template>
  <Transition name="fade">
    <section v-if="displayVisible && !visible && boardQueue.length" class="callboard">
      <header class="callboard-head">
        <div class="callboard-mark"><HeartPulse :size="20" /></div>
        <div><span>Instituto Médico</span><strong>Fila de atendimento</strong></div>
        <b>{{ boardQueue.length }}</b>
      </header>
      <div class="callboard-list">
        <article v-for="ticket in boardQueue.slice(0, displayLimit)" :key="ticket.id" class="callboard-call" :data-status="ticket.status">
          <div class="call-code"><i></i>{{ ticket.ticket_code }}</div>
          <strong>{{ ticket.patient_name }}</strong>
          <p>{{ ticket.status === 'called' ? `Dirija-se ao atendimento com ${doctorWithArticle(ticket)}.` : 'Aguarde o médico aceitar seu atendimento.' }}</p>
          <footer><span>{{ formatStatus(ticket.status) }}</span><time>{{ formatTime(ticket.called_at || ticket.created_at) }}</time></footer>
        </article>
      </div>
    </section>
  </Transition>

  <Transition name="panel">
    <section v-if="visible && mode === 'shop'" class="shop-overlay">
      <div class="shop-window">
        <header class="shop-header">
          <div class="brand-seal"><img :src="emblem" alt="" /></div>
          <div><span>Atendimento emergencial</span><h1>Suprimentos médicos</h1><p>Disponível enquanto não houver profissionais em plantão.</p></div>
          <button class="icon-button" title="Fechar" @click="close"><X :size="19" /></button>
        </header>
        <div class="shop-grid">
          <article v-for="item in (payload?.items || shopItems)" :key="item.name" class="shop-item">
            <div class="shop-icon"><ShoppingBag :size="22" /></div>
            <div class="shop-copy"><strong>{{ item.label }}</strong><p>{{ item.description }}</p></div>
            <div class="shop-price"><span>$ {{ Number(item.price).toLocaleString('pt-BR') }}</span><button @click="buy(item)">Comprar</button></div>
          </article>
        </div>
      </div>
    </section>
  </Transition>

  <Transition name="panel">
    <section v-if="visible && mode === 'billing'" class="billing-overlay">
      <div class="billing-terminal">
        <header class="billing-head">
          <div class="brand-seal"><img :src="emblem" alt="" /></div>
          <div><span>Instituto Médico de Obscuria</span><h1>Pagamentos e plano</h1><p>{{ payload?.patient?.name }} · {{ payload?.patient?.citizenid }}</p></div>
          <button class="icon-button" title="Fechar maquininha" @click="close"><X :size="19" /></button>
        </header>
        <div class="billing-terminal-scroll">
          <section class="billing-section">
            <header><div><span>COMANDAS</span><h2>Pagamentos pendentes</h2></div><b>{{ payload?.invoices?.length || 0 }}</b></header>
            <div v-if="payload?.invoices?.length" class="invoice-list">
              <article v-for="invoice in payload.invoices" :key="invoice.id" class="invoice-row">
                <div class="invoice-icon"><ReceiptText :size="19" /></div>
                <div><span>{{ invoice.public_code }}</span><strong>{{ invoice.description }}</strong><small>Emitida por {{ invoice.employee_name }} · válida até {{ formatDate(invoice.expires_at) }}</small></div>
                <strong>$ {{ money(invoice.amount) }}</strong>
                <button class="primary-button" :disabled="billingBusy !== ''" @click="payInvoice(invoice)"><CreditCard :size="15" />{{ billingBusy === `invoice-${invoice.id}` ? 'Processando...' : 'Pagar' }}</button>
              </article>
            </div>
            <div v-else class="billing-empty"><Check :size="22" /><span>Nenhuma comanda aguardando pagamento.</span></div>
          </section>

          <section class="billing-section plan-terminal-section">
            <header><div><span>ASSISTÊNCIA MENSAL</span><h2>{{ payload?.plan?.name || 'Plano hospitalar' }}</h2></div><b :data-status="payload?.subscription?.status || 'none'">{{ subscriptionStatus(payload?.subscription?.status) }}</b></header>
            <div class="plan-terminal-body">
              <div class="plan-price"><span>Mensalidade</span><strong>$ {{ money(payload?.subscription?.monthly_price || payload?.plan?.monthlyPrice) }}</strong><small>Cobrança automática no banco a cada {{ payload?.plan?.intervalDays || 30 }} dias.</small></div>
              <div class="plan-status-copy">
                <p v-if="payload?.subscription?.status === 'active'">Seus atendimentos hospitalares estão cobertos até {{ formatDate(payload.subscription.next_charge_at) }}.</p>
                <p v-else-if="payload?.subscription?.status === 'pending'">A recepção enviou uma proposta. O primeiro pagamento ativa a cobertura imediatamente.</p>
                <p v-else-if="payload?.subscription?.status === 'past_due'">A renovação não foi paga. Regularize para reativar sua cobertura.</p>
                <p v-else-if="payload?.subscription?.status === 'cancelled'">O plano foi cancelado e não realizará novas cobranças.</p>
                <p v-else>Solicite uma proposta do plano diretamente à recepção.</p>
                <div class="plan-terminal-actions">
                  <button v-if="['pending', 'past_due'].includes(payload?.subscription?.status)" class="primary-button" :disabled="billingBusy !== ''" @click="acceptSubscription"><ShieldCheck :size="15" />{{ billingBusy === 'accept-plan' ? 'Processando...' : payload.subscription.status === 'past_due' ? 'Regularizar plano' : 'Aceitar e pagar' }}</button>
                  <button v-if="['pending', 'active', 'past_due'].includes(payload?.subscription?.status)" class="secondary-button danger" :disabled="billingBusy !== ''" @click="cancelSubscription">{{ billingBusy === 'cancel-plan' ? 'Cancelando...' : 'Cancelar plano' }}</button>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </section>
  </Transition>

  <Transition name="panel">
    <section v-if="visible && mode === 'panel'" class="hospital-shell">
      <aside class="sidebar">
        <div class="brand">
          <div class="brand-seal"><img :src="emblem" alt="" /></div>
          <div><span>Obscuria</span><strong>Instituto Médico</strong></div>
        </div>

        <div class="staff-card">
          <div class="staff-avatar">{{ payload?.user?.name?.split(' ').map(part => part[0]).slice(0, 2).join('') || 'IM' }}</div>
          <div><span>Profissional em plantão</span><strong>{{ payload?.user?.name || 'Equipe médica' }}</strong><small>Registro {{ payload?.user?.citizenid || 'indisponível' }}</small></div>
          <i class="online-dot"></i>
        </div>

        <nav class="side-nav">
          <span class="side-caption">CENTRAL CLÍNICA</span>
          <button v-for="item in navItems" :key="item.id" :class="{ active: view === item.id }" @click="view = item.id">
            <span class="nav-icon"><component :is="item.icon" :size="18" /></span>
            <span><strong>{{ item.label }}</strong><small>{{ item.hint }}</small></span>
            <ChevronRight :size="15" />
          </button>
        </nav>

        <div class="shift-summary">
          <div><span class="pulse-dot"></span><strong>{{ payload?.doctorCount || 0 }}</strong><small>médicos online</small></div>
          <div><strong>{{ activeQueue.length }}</strong><small>pacientes na fila</small></div>
        </div>
      </aside>

      <main class="workspace">
        <header class="topbar">
          <div><span>Central hospitalar</span><h1>{{ screenTitle }}</h1><p>{{ screenHint }}</p></div>
          <div class="topbar-actions">
            <button class="notification-button" title="Emergências" @click="view = 'dispatch'"><Bell :size="18" /><b v-if="activeCalls.length">{{ activeCalls.length }}</b></button>
            <button class="icon-button" title="Fechar" @click="close"><X :size="20" /></button>
          </div>
        </header>

        <div class="content-scroll">
          <template v-if="view === 'dashboard'">
            <section class="metrics-grid">
              <article><div class="metric-icon blue"><ClipboardList :size="20" /></div><span>Registros de hoje</span><strong>{{ payload?.metrics?.records_today || 0 }}</strong><small>prontuários atualizados</small></article>
              <article><div class="metric-icon green"><UsersRound :size="20" /></div><span>Pacientes registrados</span><strong>{{ payload?.metrics?.patients || 0 }}</strong><small>histórico disponível</small></article>
              <article><div class="metric-icon amber"><ClipboardList :size="20" /></div><span>Fila clínica</span><strong>{{ activeQueue.length }}</strong><small>senhas em atendimento</small></article>
              <article><div class="metric-icon cyan"><Ambulance :size="20" /></div><span>Emergências</span><strong>{{ activeCalls.length }}</strong><small>ocorrências externas</small></article>
            </section>

            <div class="dashboard-grid">
              <section class="surface dispatch-preview">
                <header class="section-head"><div><span>Operação</span><h2>Chamados prioritários</h2></div><button class="text-button" @click="view = 'dispatch'">Ver todos <ChevronRight :size="15" /></button></header>
                <div v-if="activeCalls.length" class="compact-call-list">
                  <button v-for="call in activeCalls.slice(0, 4)" :key="call.id" class="compact-call" :data-priority="call.priority" @click="view = 'dispatch'">
                    <span class="priority-bar"></span><div><b>{{ call.public_code }}</b><strong>{{ call.patient_name }}</strong><small>{{ call.reason }}</small></div><time>{{ call.created_at }}</time>
                  </button>
                </div>
                <div v-else class="empty-state"><ShieldCheck :size="28" /><strong>Plantão tranquilo</strong><span>Nenhum chamado aguardando atendimento.</span></div>
              </section>

              <section class="surface recent-patients">
                <header class="section-head"><div><span>Prontuários</span><h2>Pacientes recentes</h2></div><button class="text-button" @click="view = 'patients'">Pesquisar <Search :size="15" /></button></header>
                <button v-for="patient in payload?.recentPatients || []" :key="patient.citizenid" class="patient-row" @click="openPatient(patient)">
                  <span class="patient-initials">{{ patient.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span>
                  <span><strong>{{ patient.name }}</strong><small>{{ patient.citizenid }}</small><span v-if="hasActivePlan(patient)" class="coverage-badge" :title="patientPlanTitle(patient)"><ShieldCheck :size="11" />Plano ativo</span></span>
                  <span class="patient-meta"><b>{{ patient.records }}</b><small>registros</small></span>
                  <ChevronRight :size="16" />
                </button>
              </section>
            </div>
          </template>

          <template v-else-if="view === 'queue'">
            <section class="dispatch-toolbar surface">
              <div><span class="live-indicator"><i></i> Recepção hospitalar</span><strong>{{ activeQueue.length }} {{ activeQueue.length === 1 ? 'paciente' : 'pacientes' }} na fila clínica</strong></div>
              <div class="queue-summary"><span><b>{{ activeQueue.filter(ticket => ticket.status === 'waiting').length }}</b> aguardando</span><span><b>{{ calledQueue.length }}</b> chamados</span></div>
            </section>
            <section v-if="activeQueue.length" class="queue-grid">
              <article v-for="ticket in activeQueue" :key="ticket.id" class="queue-card" :data-status="ticket.status">
                <header><strong>{{ ticket.ticket_code }}</strong><span class="status-pill">{{ formatStatus(ticket.status) }}</span></header>
                <div class="queue-patient"><span class="patient-initials">{{ ticket.patient_name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span><div><small>Paciente</small><strong>{{ ticket.patient_name }}</strong><span>Entrada {{ formatTime(ticket.created_at) }}</span><span v-if="hasActivePlan(ticket)" class="coverage-badge" :title="patientPlanTitle(ticket)"><ShieldCheck :size="11" />Plano ativo</span></div></div>
                <div v-if="ticket.called_by_name" class="queue-medic"><Stethoscope :size="14" /><span>{{ doctorAttribution(ticket) }}</span></div>
                <footer>
                  <button class="secondary-button" :disabled="updatingTickets.has(ticket.id)" @click="updateQueue(ticket, 'cancelled')">Cancelar</button>
                  <button v-if="ticket.status === 'awaiting_triage'" class="primary-button" @click="openPatient({ citizenid: ticket.patient_identifier }, 'triage')"><Stethoscope :size="15" />Fazer triagem</button>
                  <button v-else-if="ticket.status === 'waiting'" class="primary-button" :disabled="updatingTickets.has(ticket.id)" @click="updateQueue(ticket, 'called')"><Bell :size="15" />Aceitar atendimento</button>
                  <button v-else-if="ticket.status === 'called'" class="primary-button" :disabled="updatingTickets.has(ticket.id)" @click="updateQueue(ticket, 'repeat')"><Bell :size="15" />Repetir chamada</button>
                  <button v-else class="primary-button success" :disabled="updatingTickets.has(ticket.id)" @click="updateQueue(ticket, 'resolved')"><Check :size="15" />Finalizar</button>
                </footer>
              </article>
            </section>
            <section v-else class="surface empty-state"><ShieldCheck :size="28" /><strong>Recepção sem espera</strong><span>Nenhuma senha aguardando atendimento.</span></section>
          </template>

          <template v-else-if="view === 'dispatch'">
            <section class="dispatch-toolbar surface">
              <div><span class="live-indicator"><i></i> Atualização em tempo real</span><strong>{{ activeCalls.length }} ocorrências em aberto</strong></div>
              <div class="legend"><span><i class="critical"></i>Crítica</span><span><i class="urgent"></i>Urgente</span><span><i class="normal"></i>Normal</span></div>
            </section>
            <section class="dispatch-grid">
              <article v-for="call in activeCalls" :key="call.id" class="dispatch-card" :data-priority="call.priority">
                <header><div class="call-code"><i></i>{{ call.public_code }}</div><span class="status-pill">{{ formatStatus(call.status) }}</span></header>
                <div class="dispatch-patient"><span class="patient-initials">{{ call.patient_name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span><div><small>Paciente</small><strong>{{ call.patient_name }}</strong></div></div>
                <p>{{ call.reason }}</p>
                <div class="dispatch-meta"><span><Clock3 :size="14" />{{ call.created_at }}</span><span v-if="call.assigned_name"><Stethoscope :size="14" />{{ call.assigned_name }}</span></div>
                <footer>
                  <button class="secondary-button" @click="waypoint(call)"><MapPin :size="16" />GPS</button>
                  <button v-if="call.status === 'waiting'" class="primary-button" @click="updateCall(call, 'assigned')">Assumir</button>
                  <button v-else-if="call.status === 'assigned'" class="primary-button" @click="updateCall(call, 'on_scene')">No local</button>
                  <button v-else-if="call.status === 'on_scene'" class="primary-button" @click="updateCall(call, 'transporting')">Transportar</button>
                  <button v-else class="primary-button success" @click="updateCall(call, 'resolved')">Finalizar</button>
                </footer>
              </article>
            </section>
          </template>

          <template v-else-if="view === 'patients'">
            <div class="patients-layout">
              <aside class="patient-browser surface">
                <header class="section-head"><div><span>Arquivo clínico</span><h2>Localizar paciente</h2></div></header>
                <div class="search-field"><Search :size="17" /><input v-model="patientSearch" placeholder="Nome ou passaporte" @keyup.enter="searchPatients" /><button @click="searchPatients">{{ searching ? '...' : 'Buscar' }}</button></div>
                <div class="patient-result-list">
                  <button v-for="patient in patientResults.length ? patientResults : payload?.recentPatients || []" :key="patient.citizenid" :class="{ active: selectedPatient?.citizenid === patient.citizenid }" @click="openPatient(patient)">
                    <span class="patient-initials">{{ patient.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span><span><strong>{{ patient.name }}</strong><small>{{ patient.citizenid }}</small><span v-if="hasActivePlan(patient)" class="coverage-badge" :title="patientPlanTitle(patient)"><ShieldCheck :size="11" />Plano ativo</span></span><ChevronRight :size="15" />
                  </button>
                </div>
              </aside>

              <section v-if="selectedPatient" class="patient-file surface">
                <header class="patient-file-head">
                  <div class="patient-photo"><img v-if="profileDraft.photoUrl" :src="profileDraft.photoUrl" alt="" /><CircleUserRound v-else :size="34" /></div>
                  <div><span>{{ selectedPatient.online ? 'Paciente online' : 'Paciente offline' }}</span><h2>{{ selectedPatient.name }}</h2><p>{{ selectedPatient.citizenid }}</p><span v-if="hasActivePlan(selectedPatient)" class="coverage-badge" :title="patientPlanTitle(selectedPatient)"><ShieldCheck :size="11" />Plano ativo</span></div>
                  <button class="primary-button" @click="view = 'triage'"><FilePlus2 :size="16" />Nova triagem</button>
                </header>
                <div v-if="hasActivePlan(selectedPatient)" class="coverage-banner"><ShieldCheck :size="19" /><div><strong>{{ selectedPatient.plan.name || 'Plano hospitalar' }}</strong><span>Cobertura ativa<span v-if="selectedPatient.plan.next_charge_at"> até {{ formatDate(selectedPatient.plan.next_charge_at) }}</span>. As comandas elegíveis são cobertas automaticamente.</span></div></div>
                <div class="profile-grid">
                  <label><span>Tipo sanguíneo</span><input v-model="profileDraft.bloodType" placeholder="Ex.: O+" /></label>
                  <label><span>Alergias</span><input v-model="profileDraft.allergies" placeholder="Nenhuma registrada" /></label>
                  <label class="wide"><span>Condições clínicas</span><input v-model="profileDraft.conditions" placeholder="Condições permanentes" /></label>
                  <label class="wide"><span>Foto principal (URL HTTPS)</span><input v-model="profileDraft.photoUrl" placeholder="https://..." /></label>
                  <label class="wide"><span>Observações permanentes</span><textarea v-model="profileDraft.notes" rows="2" /></label>
                </div>
                <div class="profile-actions"><button class="secondary-button" @click="saveProfile">{{ saving ? 'Salvando...' : 'Salvar dados do paciente' }}</button></div>
                <div class="medical-status" v-if="selectedPatient.medicalStatus"><HeartPulse :size="18" /><div><strong>Estado atual no Qbox Medical</strong><span>{{ selectedPatient.medicalStatus.injuries?.join(', ') || 'Sem lesões registradas' }} · {{ selectedPatient.medicalStatus.bleedState || 'Sem sangramento' }}</span></div></div>
                <div class="record-list">
                  <header class="section-head"><div><span>Histórico</span><h2>{{ selectedPatient.records?.length || 0 }} registros médicos</h2></div></header>
                  <button v-for="record in selectedPatient.records || []" :key="record.id" class="record-row" @click="openRecord(record)">
                    <span class="record-icon"><ClipboardList :size="18" /></span><span class="record-summary"><small>{{ formatSeverity(record.severity) }} · {{ formatRecordType(record.record_type) }}</small><strong>{{ record.title }}</strong><p>{{ record.diagnosis || record.notes || 'Sem observações.' }}</p></span><span class="record-author"><b>{{ record.medic_name }}</b><time>{{ record.created_at }}</time></span><Eye :size="15" />
                  </button>
                  <div v-if="!selectedPatient.records?.length" class="record-empty"><ClipboardList :size="23" /><span>Nenhum atendimento registrado para este paciente.</span></div>
                </div>
              </section>
              <section v-else class="patient-empty surface"><UserRoundSearch :size="38" /><h2>Selecione um paciente</h2><p>Abra um prontuário para consultar histórico, fotos e informações clínicas.</p></section>
            </div>
          </template>

          <template v-else-if="view === 'reception'">
            <div class="reception-layout">
              <section class="reception-patients surface">
                <header class="section-head"><div><span>Atendimento no balcão</span><h2>Pacientes próximos</h2></div><button class="secondary-button" @click="loadNearbyBillingPatients"><Search :size="14" />Atualizar</button></header>
                <div class="reception-patient-list">
                  <button v-for="patient in nearbyBillingPatients" :key="patient.source" :class="{ active: String(selectedBillingSource) === String(patient.source) }" @click="selectedBillingSource = patient.source">
                    <span class="patient-initials">{{ patient.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span><span><strong>{{ patient.name }}</strong><small>{{ patient.citizenid }} · ID {{ patient.source }} · {{ patient.distance }} m</small><span v-if="hasActivePlan(patient)" class="coverage-badge" :title="patientPlanTitle(patient)"><ShieldCheck :size="11" />Plano ativo</span></span><Check v-if="String(selectedBillingSource) === String(patient.source)" :size="15" /><ChevronRight v-else :size="15" />
                  </button>
                  <div v-if="!nearbyBillingPatients.length" class="reception-empty"><UserRoundSearch :size="25" /><span>Nenhum paciente encontrado nas proximidades.</span></div>
                </div>
              </section>

              <div class="reception-actions">
                <section class="invoice-builder surface">
                  <header class="section-head"><div><span>Maquininha</span><h2>Criar comanda hospitalar</h2></div><ReceiptText :size="20" /></header>
                  <div class="reception-form">
                    <div class="selected-customer"><span>Paciente selecionado</span><strong>{{ selectedBillingPatient?.name || 'Selecione ao lado' }}</strong><small>{{ selectedBillingPatient?.citizenid || 'A comanda será vinculada ao paciente.' }}</small></div>
                    <label><span>Valor da comanda</span><div class="money-input"><b>$</b><input v-model="invoiceDraft.amount" type="number" min="1" :max="payload?.billing?.maxInvoiceAmount || 1000000" placeholder="0" /></div></label>
                    <label><span>Descrição do atendimento</span><textarea v-model="invoiceDraft.description" rows="4" maxlength="500" placeholder="Consulta, procedimento, materiais..." /></label>
                    <button class="primary-button" :disabled="!selectedBillingPatient || billingBusy !== ''" @click="createInvoice"><CreditCard :size="16" />{{ billingBusy === 'invoice' ? 'Emitindo...' : 'Enviar para pagamento' }}</button>
                  </div>
                </section>

                <section class="plan-builder surface">
                  <header class="section-head"><div><span>Plano mensal</span><h2>{{ payload?.billing?.plan?.name || 'Plano hospitalar' }}</h2></div><ShieldCheck :size="20" /></header>
                  <div class="plan-builder-body"><div><span>Mensalidade</span><strong>$ {{ money(payload?.billing?.plan?.monthlyPrice || 0) }}</strong><small>Renovação bancária automática a cada {{ payload?.billing?.plan?.intervalDays || 30 }} dias.</small></div><p>O balconista envia a proposta; o paciente revisa, aceita e paga a primeira mensalidade na maquininha.</p><button class="secondary-button" :disabled="!selectedBillingPatient || billingBusy !== '' || !payload?.billing?.plan?.enabled" @click="proposeSubscription"><Plus :size="15" />{{ billingBusy === 'plan' ? 'Enviando...' : 'Oferecer plano ao paciente' }}</button></div>
                </section>
              </div>
            </div>
          </template>

          <template v-else-if="view === 'management'">
            <section class="management-summary">
              <article><span>Equipe cadastrada</span><strong>{{ management.summary.total || 0 }}</strong><small>profissionais</small></article>
              <article><span>Conectados</span><strong>{{ management.summary.online || 0 }}</strong><small>na cidade</small></article>
              <article><span>Em serviço</span><strong>{{ management.summary.onDuty || 0 }}</strong><small>no plantão</small></article>
              <button class="secondary-button" :disabled="managementBusy !== ''" @click="loadManagement"><RefreshCw :size="15" />{{ managementBusy === 'refresh' ? 'Atualizando...' : 'Atualizar equipe' }}</button>
            </section>

            <div class="management-layout">
              <section class="staff-roster surface">
                <header class="section-head"><div><span>Quadro profissional</span><h2>Equipe do Instituto Médico</h2></div><b>{{ management.staff.length }}</b></header>
                <div class="staff-table-head"><span>Profissional</span><span>Situação</span><span>Cargo</span><span>Ações</span></div>
                <div class="staff-table-body">
                  <article v-for="member in management.staff" :key="member.citizenid" class="staff-member-row">
                    <div class="staff-member-identity">
                      <span class="patient-initials">{{ member.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span>
                      <div><strong>{{ member.name }}</strong><small>{{ member.citizenid }}<template v-if="member.source"> · ID {{ member.source }}</template></small></div>
                    </div>
                    <span class="duty-status" :data-status="member.onDuty ? 'duty' : member.online ? 'online' : 'offline'"><i></i>{{ staffStatus(member) }}</span>
                    <select :value="member.grade" :disabled="!canManageMember(member) || managementBusy !== ''" @change="changeStaffGrade(member, $event)">
                      <option v-for="grade in selectableGrades(member)" :key="grade.grade" :value="grade.grade">{{ grade.label }}</option>
                    </select>
                    <button class="staff-remove" title="Demitir profissional" :disabled="!canManageMember(member) || managementBusy !== ''" @click="fireStaff(member)"><UserMinus :size="16" /></button>
                  </article>
                  <div v-if="!management.staff.length" class="management-empty"><UsersRound :size="28" /><strong>Nenhum profissional cadastrado</strong><span>Os funcionários contratados aparecerão aqui.</span></div>
                </div>
              </section>

              <section class="hire-panel surface">
                <header class="section-head"><div><span>Recrutamento</span><h2>Jogadores próximos</h2></div><UserPlus :size="20" /></header>
                <p class="hire-hint">A contratação adiciona o jogador ao cargo inicial configurado para o hospital.</p>
                <div class="candidate-list">
                  <article v-for="candidate in management.candidates" :key="candidate.source">
                    <span class="patient-initials">{{ candidate.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</span>
                    <div><strong>{{ candidate.name }}</strong><small>ID {{ candidate.source }} · {{ candidate.distance }} m</small></div>
                    <button class="primary-button" :disabled="managementBusy !== ''" @click="hireStaff(candidate)"><UserPlus :size="14" />{{ managementBusy === `hire-${candidate.source}` ? 'Contratando...' : 'Contratar' }}</button>
                  </article>
                  <div v-if="!management.candidates.length" class="management-empty compact"><UserRoundSearch :size="25" /><strong>Ninguém por perto</strong><span>Aproxime o jogador e atualize a lista.</span></div>
                </div>
              </section>
            </div>
          </template>

          <template v-else-if="view === 'triage'">
            <section v-if="!selectedPatient" class="triage-select surface">
              <UserRoundSearch :size="36" /><h2>Escolha o paciente da triagem</h2><p>Pesquise pelo nome ou passaporte antes de iniciar a avaliação.</p>
              <div class="search-field"><Search :size="17" /><input v-model="patientSearch" placeholder="Nome ou passaporte" @keyup.enter="searchPatients" /><button @click="searchPatients">Buscar</button></div>
              <div class="triage-patient-results"><button v-for="patient in patientResults" :key="patient.citizenid" @click="openPatient(patient, 'triage')"><span class="triage-result-name"><strong>{{ patient.name }}</strong><span v-if="hasActivePlan(patient)" class="coverage-badge" :title="patientPlanTitle(patient)"><ShieldCheck :size="11" />Plano ativo</span></span><small>{{ patient.citizenid }}</small><ChevronRight :size="15" /></button></div>
            </section>
            <div v-else class="triage-layout">
              <section class="body-panel surface">
                <header class="section-head"><div><span>Mapa corporal</span><h2>Localização da dor</h2></div><div class="view-switch"><button :class="{ active: bodyView === 'front' }" @click="bodyView = 'front'">Frente</button><button :class="{ active: bodyView === 'back' }" @click="bodyView = 'back'">Costas</button></div></header>
                <div class="body-map">
                  <canvas ref="bodyCanvas" :aria-label="bodyView === 'front' ? 'Mapa corporal visto de frente' : 'Mapa corporal visto de costas'" @mousemove="onBodyMove" @mouseleave="hoveredPart = null" @click="onBodyClick"></canvas>
                  <span v-if="hoveredPart" class="body-tooltip" :style="{ left: `${bodyPointer.x}%`, top: `${bodyPointer.y}%` }">{{ currentRegions.find(region => region.key === hoveredPart)?.label }}</span>
                </div>
                <div class="selected-parts"><span v-if="!selectedParts.length">Clique nas regiões em que o paciente sente dor.</span><button v-for="part in selectedParts" :key="part">{{ part }}</button></div>
              </section>

              <section class="triage-form surface">
                <header class="triage-patient-head"><div class="patient-initials">{{ selectedPatient.name.split(' ').map(part => part[0]).slice(0, 2).join('') }}</div><div><span>Avaliando</span><strong>{{ selectedPatient.name }}</strong><small>{{ selectedPatient.citizenid }}</small><span v-if="hasActivePlan(selectedPatient)" class="coverage-badge" :title="patientPlanTitle(selectedPatient)"><ShieldCheck :size="11" />Plano ativo</span></div><button class="text-button" @click="selectedPatient = null">Trocar paciente</button></header>
                <div class="form-section"><span class="form-caption">CLASSIFICAÇÃO</span><div class="severity-options"><button v-for="severity in payload?.severities || previewPayload.severities" :key="severity.value" :class="{ active: triage.severity === severity.value }" :style="{ '--severity': severity.color }" @click="triage.severity = severity.value"><i></i>{{ severity.label }}</button></div></div>
                <div class="form-section"><span class="form-caption">SINAIS VITAIS</span><div class="vitals-grid">
                  <label><span><HeartPulse :size="14" />Frequência</span><input v-model="triage.vitals.heartRate" placeholder="72 bpm" /></label>
                  <label><span><Activity :size="14" />Pressão</span><input v-model="triage.vitals.pressure" placeholder="120/80" /></label>
                  <label><span><Thermometer :size="14" />Temperatura</span><input v-model="triage.vitals.temperature" placeholder="36,5 °C" /></label>
                  <label><span><HeartPulse :size="14" />Saturação</span><input v-model="triage.vitals.oxygen" placeholder="98%" /></label>
                  <label class="wide"><span>Consciência</span><select v-model="triage.vitals.consciousness"><option>Consciente</option><option>Confuso</option><option>Sonolento</option><option>Inconsciente</option></select></label>
                </div></div>
                <div class="form-section"><span class="form-caption">AVALIAÇÃO</span><div class="clinical-grid">
                  <label class="wide"><span>Título do registro</span><input v-model="triage.title" /></label>
                  <label><span>Diagnóstico</span><textarea v-model="triage.diagnosis" rows="3" placeholder="Hipótese ou diagnóstico clínico" /></label>
                  <label><span>Conduta / tratamento</span><textarea v-model="triage.treatment" rows="3" placeholder="Medicação, imobilização, exames..." /></label>
                  <label class="wide"><span>Observações</span><textarea v-model="triage.notes" rows="2" placeholder="Relato e detalhes adicionais" /></label>
                </div></div>
                <div class="form-section"><span class="form-caption">FOTOS DO REGISTRO</span><div class="photo-entry"><input v-model="photoDraft.url" placeholder="URL HTTPS da foto" /><input v-model="photoDraft.caption" placeholder="Legenda" /><button class="secondary-button" @click="addPhoto">Adicionar</button></div><div class="photo-list"><span v-if="!triage.photos.length">Nenhuma foto anexada.</span><button v-for="(photo, index) in triage.photos" :key="photo.url" @click="triage.photos.splice(index, 1)">{{ photo.caption || `Foto ${index + 1}` }} <X :size="12" /></button></div></div>
                <footer class="triage-actions"><button class="secondary-button" @click="resetTriage">Limpar</button><button class="primary-button" :disabled="saving" @click="saveTriage"><ClipboardList :size="16" />{{ saving ? 'Salvando...' : 'Salvar no prontuário' }}</button></footer>
              </section>
            </div>
          </template>
        </div>
      </main>
    </section>
  </Transition>

  <Transition name="fade">
    <div v-if="selectedRecord && visible && mode === 'panel'" class="record-modal-backdrop" @click.self="closeRecord">
      <section class="record-modal" role="dialog" aria-modal="true" aria-label="Detalhes do registro médico">
        <header class="record-modal-head">
          <div class="record-modal-mark"><ClipboardList :size="20" /></div>
          <div><span>{{ formatRecordType(selectedRecord.record_type) }} · {{ formatSeverity(selectedRecord.severity) }}</span><h2>{{ selectedRecord.title }}</h2><p>{{ selectedRecord.medic_name }} · {{ selectedRecord.created_at }}</p></div>
          <div class="record-modal-actions">
            <button v-if="canEditRecords && !editingRecord" class="secondary-button" @click="editingRecord = true"><Pencil :size="14" />Editar</button>
            <button class="icon-button" title="Fechar prontuário" @click="closeRecord"><X :size="18" /></button>
          </div>
        </header>

        <div v-if="!editingRecord" class="record-modal-scroll">
          <div class="record-overview">
            <div><span>Tipo</span><strong>{{ formatRecordType(selectedRecord.record_type) }}</strong></div>
            <div><span>Classificação</span><strong>{{ formatSeverity(selectedRecord.severity) }}</strong></div>
            <div><span>Profissional</span><strong>{{ selectedRecord.medic_name || 'Não informado' }}</strong></div>
            <div><span>Data</span><strong>{{ selectedRecord.created_at || 'Não informada' }}</strong></div>
          </div>
          <section class="record-detail-section"><span>Diagnóstico</span><p>{{ selectedRecord.diagnosis || 'Não informado.' }}</p></section>
          <section class="record-detail-section"><span>Conduta / tratamento</span><p>{{ selectedRecord.treatment || 'Não informado.' }}</p></section>
          <section class="record-detail-section"><span>Observações</span><p>{{ selectedRecord.notes || 'Sem observações.' }}</p></section>
          <section class="record-detail-section">
            <span>Sinais vitais</span>
            <div class="record-vitals"><div v-for="field in vitalFields" :key="field.key"><small>{{ field.label }}</small><strong>{{ selectedRecord.vitals?.[field.key] || 'Não informado' }}</strong></div></div>
          </section>
          <section class="record-detail-section">
            <span>Regiões sinalizadas</span>
            <div class="record-tags"><span v-for="part in selectedRecord.body_parts || []" :key="part">{{ bodyPartLabel(part) }}</span><small v-if="!selectedRecord.body_parts?.length">Nenhuma região registrada.</small></div>
          </section>
          <section class="record-detail-section">
            <span>Fotos anexadas</span>
            <div v-if="selectedRecord.photos?.length" class="record-photo-grid"><a v-for="(photo, index) in selectedRecord.photos" :key="`${photo.url}-${index}`" :href="photo.url" target="_blank" rel="noreferrer"><img :src="photo.url" alt="" /><strong>{{ photo.caption || `Foto ${index + 1}` }}</strong></a></div>
            <p v-else>Nenhuma foto anexada.</p>
          </section>
        </div>

        <form v-else class="record-modal-scroll record-editor" @submit.prevent="saveRecord">
          <div class="record-editor-grid">
            <label class="wide"><span>Título do registro</span><input v-model="recordDraft.title" maxlength="120" /></label>
            <label><span>Classificação</span><select v-model="recordDraft.severity"><option v-for="severity in payload?.severities || previewPayload.severities" :key="severity.value" :value="severity.value">{{ severity.label }}</option></select></label>
            <label><span>Tipo original</span><input :value="formatRecordType(selectedRecord.record_type)" disabled /></label>
            <label><span>Diagnóstico</span><textarea v-model="recordDraft.diagnosis" rows="4" /></label>
            <label><span>Conduta / tratamento</span><textarea v-model="recordDraft.treatment" rows="4" /></label>
            <label class="wide"><span>Observações</span><textarea v-model="recordDraft.notes" rows="3" /></label>
          </div>
          <section class="record-edit-section">
            <span class="form-caption">SINAIS VITAIS</span>
            <div class="record-edit-vitals"><label v-for="field in vitalFields" :key="field.key"><span>{{ field.label }}</span><input v-model="recordDraft.vitals[field.key]" /></label></div>
          </section>
          <section class="record-edit-section">
            <span class="form-caption">REGIÕES SINALIZADAS</span>
            <div class="record-add-row"><select v-model="recordPartDraft"><option value="">Selecione uma região</option><option v-for="region in allBodyRegions" :key="region.key" :value="region.key" :disabled="recordDraft.bodyParts.includes(region.key)">{{ region.label }}</option></select><button type="button" class="secondary-button" @click="addRecordPart"><Plus :size="14" />Adicionar</button></div>
            <div class="record-tags editable"><button v-for="(part, index) in recordDraft.bodyParts" :key="part" type="button" @click="recordDraft.bodyParts.splice(index, 1)">{{ bodyPartLabel(part) }}<X :size="12" /></button><small v-if="!recordDraft.bodyParts.length">Nenhuma região registrada.</small></div>
          </section>
          <section class="record-edit-section">
            <span class="form-caption">FOTOS ANEXADAS</span>
            <div class="record-photo-inputs"><input v-model="recordPhotoDraft.url" placeholder="URL HTTPS da foto" /><input v-model="recordPhotoDraft.caption" placeholder="Legenda" /><button type="button" class="secondary-button" @click="addRecordPhoto"><Plus :size="14" />Adicionar</button></div>
            <div class="record-photo-edit-list"><div v-for="(photo, index) in recordDraft.photos" :key="`${photo.url}-${index}`"><img :src="photo.url" alt="" /><span>{{ photo.caption || `Foto ${index + 1}` }}</span><button type="button" title="Remover foto" @click="recordDraft.photos.splice(index, 1)"><Trash2 :size="14" /></button></div><small v-if="!recordDraft.photos.length">Nenhuma foto anexada.</small></div>
          </section>
          <footer class="record-editor-actions"><button type="button" class="secondary-button" @click="cancelRecordEdit">Cancelar</button><button type="submit" class="primary-button" :disabled="saving"><Save :size="15" />{{ saving ? 'Salvando...' : 'Salvar alterações' }}</button></footer>
        </form>
      </section>
    </div>
  </Transition>

  <Transition name="toast"><div v-if="feedback.text" class="toast" :class="feedback.type">{{ feedback.text }}</div></Transition>
</template>
