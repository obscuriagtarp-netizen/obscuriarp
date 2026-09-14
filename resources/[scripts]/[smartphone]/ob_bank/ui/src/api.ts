import type { ApiResponse, CreditState, Dashboard, Person, Receipt } from './types'

const mockPeople: Person[] = [
  { citizenid: 'MD832AC3', name: 'Jaspe Vermillion', nickname: 'Jaspe', online: true, source: 12 },
  { citizenid: 'GH1UB2J7', name: 'Troy Forrest', nickname: 'Troy', online: false },
  { citizenid: 'CH453X76', name: 'Lysandra Black', online: true, source: 27 },
]

const mockDashboard: Dashboard = {
  account: { citizenid: 'TH910YTS', name: 'Lz Dv_', balance: 256490, online: true },
  favorites: mockPeople.slice(0, 2),
  recent: mockPeople,
  transferBlocked: false,
  credit: {
    citizenid: 'TH910YTS', score: 728, limit: 30000, used: 7850, available: 22150,
    totalDue: 7850, principalDue: 7600, interest: 250, dueAt: Math.floor(Date.now() / 1000) + 259200,
    daysUntilDue: 3, overdueDays: 0, status: 'active', blocked: false, cycleDays: 7,
    blockAfterDays: 10, dailyInterestPercent: 1,
    history: [
      { id: 'CARD-2', type: 'charge', amount: 4600, merchant: 'Concessionária Central', description: 'Compra no cartão', createdAt: Math.floor(Date.now() / 1000) - 3600 },
      { id: 'CARD-1', type: 'charge', amount: 3000, merchant: 'Loja 24/7', description: 'Compra no cartão', createdAt: Math.floor(Date.now() / 1000) - 86400 },
      { id: 'INT-1', type: 'interest', amount: 250, merchant: 'Obscuria Bank', description: 'Juros de fatura anterior', createdAt: Math.floor(Date.now() / 1000) - 172800 },
    ],
  },
  history: [
    { id: 'PIX-3', kind: 'pix', direction: 'in', title: 'Pix recebido', counterparty: 'Jaspe Vermillion', counterpartyCitizenId: 'MD832AC3', amount: 12500, description: 'Pagamento', createdAt: Math.floor(Date.now() / 1000) - 480 },
    { id: 'PIX-2', kind: 'pix', direction: 'out', title: 'Pix enviado', counterparty: 'Troy Forrest', counterpartyCitizenId: 'GH1UB2J7', amount: 3200, description: 'Combustível', createdAt: Math.floor(Date.now() / 1000) - 86400 },
    { id: 'BANK-1', kind: 'bank', direction: 'in', title: 'Salário', counterparty: 'Obscuria', amount: 7500, description: 'Pagamento recebido', createdAt: Math.floor(Date.now() / 1000) - 172800 },
  ],
}

const isPreview = new URLSearchParams(window.location.search).get('preview') === '1'

async function mockRequest<T>(action: string, payload?: Record<string, unknown>): Promise<ApiResponse<T>> {
  await new Promise((resolve) => setTimeout(resolve, 220))
  if (action === 'bootstrap') return { ok: true, data: mockDashboard as T }
  if (action === 'resolve') {
    const key = String(payload?.target ?? '').toUpperCase()
    const person = mockPeople.find((item) => item.citizenid === key || String(item.source) === key) ?? mockPeople[0]
    return { ok: true, data: { recipient: person } as T }
  }
  if (action === 'transfer') {
    const recipient = mockPeople.find((item) => item.citizenid === payload?.target || String(item.source) === String(payload?.target)) ?? mockPeople[0]
    const amount = Number(payload?.amount ?? 0)
    const receipt: Receipt = {
      id: `PIX-${Date.now()}`,
      amount,
      description: String(payload?.description ?? ''),
      recipient,
      sender: mockDashboard.account,
      createdAt: Math.floor(Date.now() / 1000),
      balance: mockDashboard.account.balance - amount,
    }
    return { ok: true, data: { receipt } as T }
  }
  if (action === 'credit_state') return { ok: true, data: mockDashboard.credit as T }
  if (action === 'credit_pay') {
    const amount = Math.min(Number(payload?.amount || mockDashboard.credit?.totalDue || 0), mockDashboard.credit?.totalDue || 0)
    const credit: CreditState = { ...mockDashboard.credit!, totalDue: mockDashboard.credit!.totalDue - amount, used: mockDashboard.credit!.used - amount, available: mockDashboard.credit!.available + amount }
    mockDashboard.credit = credit
    return { ok: true, data: { paid: amount, state: credit } as T }
  }
  if (action === 'favorite_save') return { ok: true, data: { favorites: mockPeople } as T }
  if (action === 'favorite_delete') return { ok: true, data: { favorites: mockPeople.slice(1) } as T }
  return { ok: false, error: 'Operação indisponível no modo de visualização.' }
}

export async function bankRequest<T>(action: string, payload?: Record<string, unknown>): Promise<ApiResponse<T>> {
  if (isPreview) return mockRequest<T>(action, payload)
  const resource = typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'ob_bank'
  const response = await fetch(`https://${resource}/ob-bank:api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({ action, payload: payload ?? {} }),
  })
  return response.json() as Promise<ApiResponse<T>>
}

declare global {
  interface Window {
    GetParentResourceName?: () => string
    QSPhoneBridge?: {
      create: (options: { appId: string; targetOrigin: string }) => {
        bridge: { destroy: () => void }
        api: {
          onReady: (listener: () => void) => () => void
          onEvent: (listener: (event: string, data?: unknown) => void) => () => void
          getPhoneState: () => Promise<{ visible?: boolean; activeApp?: string }>
        }
      }
    }
  }
}
