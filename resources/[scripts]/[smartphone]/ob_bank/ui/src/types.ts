export type Person = {
  citizenid: string
  name: string
  nickname?: string
  online?: boolean
  source?: number
}

export type Account = Person & {
  balance: number
}

export type Transaction = {
  id: string
  kind: 'pix' | 'bank'
  direction: 'in' | 'out'
  title: string
  counterparty: string
  counterpartyCitizenId?: string
  amount: number
  description: string
  createdAt: number
}

export type Dashboard = {
  account: Account
  history: Transaction[]
  recent: Person[]
  favorites: Person[]
  transferBlocked: boolean
  credit: CreditState | null
}

export type CreditTransaction = {
  id: string
  type: 'charge' | 'payment' | 'interest' | 'refund'
  amount: number
  merchant: string
  description: string
  createdAt: number
}

export type CreditState = {
  citizenid: string
  score: number
  limit: number
  used: number
  available: number
  totalDue: number
  principalDue: number
  interest: number
  dueAt?: number
  daysUntilDue?: number
  overdueDays: number
  status: 'active' | 'blocked'
  blocked: boolean
  blockedReason?: string
  blockedAt?: number
  cycleDays: number
  blockAfterDays: number
  dailyInterestPercent: number
  history: CreditTransaction[]
}

export type Receipt = {
  id: string
  amount: number
  description: string
  recipient: Person
  sender: Person
  createdAt: number
  balance: number
}

export type ApiResponse<T> = {
  ok: boolean
  error?: string
  data?: T
}
